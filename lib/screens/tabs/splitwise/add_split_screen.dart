import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/models/ledger.dart';
import 'package:mobile_app/models/money.dart';
import 'package:mobile_app/models/split.dart';
import 'package:mobile_app/services/flox_repository.dart';
import 'package:mobile_app/widgets/flox_colors.dart';

/// One-screen flow for adding an expense, read top to bottom:
/// how much → what for → split with → paid by → how to split.
/// A plain-language summary shows exactly who will owe whom before saving.
class AddSplitScreen extends StatefulWidget {
  final FloxRepository repo;
  final VoidCallback onClose;
  final void Function(Object error) onError;

  /// Picks a new friend from contacts; returns null if cancelled.
  final Future<Friend?> Function() onAddFriend;

  const AddSplitScreen({
    super.key,
    required this.repo,
    required this.onClose,
    required this.onError,
    required this.onAddFriend,
  });

  @override
  State<AddSplitScreen> createState() => _AddSplitScreenState();
}

/// Rejects keystrokes that would not parse as an amount (max two decimals).
final _amountFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final text = newValue.text;
  if (text.isEmpty) return newValue;
  return Money.parse(text.endsWith('.') ? '${text}0' : text) == null ? oldValue : newValue;
});

const _field = Color(0x1AFFFFFF);

/// "You" gets its own colours so it stands out from friends.
const _youGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7C4DFF), Color(0xFF4FACFE)],
);

class _AddSplitScreenState extends State<AddSplitScreen> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  /// Friends splitting this expense, in the order they were picked.
  final List<Friend> _friends = [];
  bool _includeMe = true;

  /// Who paid: null = you.
  String? _payerId;

  bool _equally = true;

  /// Custom amounts per person; key null = you.
  final Map<String?, TextEditingController> _shareControllers = {};

  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── State helpers ────────────────────────────────────────────────────────

  int get _totalPaise => Money.parse(_amountController.text) ?? 0;

  bool _isPicked(Friend f) => _friends.any((p) => p.id == f.id);

  /// Everyone sharing the cost; null = you.
  List<String?> get _participants => [if (_includeMe) null, ..._friends.map((f) => f.id)];

  String _name(String? id) => id == null ? 'You' : widget.repo.nameOf(id);

  TextEditingController _shareController(String? id) => _shareControllers.putIfAbsent(id, TextEditingController.new);

  int _sharePaise(String? id) => Money.parse(_shareController(id).text) ?? 0;

  void _toggleFriend(Friend friend) {
    setState(() {
      if (_isPicked(friend)) {
        _friends.removeWhere((f) => f.id == friend.id);
        if (_payerId == friend.id) _payerId = null;
      } else {
        _friends.add(friend);
      }
    });
  }

  Future<void> _addNewFriend() async {
    final friend = await widget.onAddFriend();
    if (friend == null || !mounted) return;
    setState(() {
      if (!_isPicked(friend)) _friends.add(friend);
    });
  }

  /// The debts this expense will create, or a short reason why it can't be saved yet.
  ({List<DebtEntry> entries, String? problem}) _plan() {
    const none = <DebtEntry>[];
    final total = _totalPaise;
    if (total <= 0) return (entries: none, problem: 'Enter how much it cost');
    if (_friends.isEmpty) return (entries: none, problem: 'Pick at least one friend');
    if (_payerId != null && !_includeMe) {
      return (entries: none, problem: "Turn on \"You\" — you're not part of this expense");
    }

    if (_equally) {
      final entries = Ledger.equalSplit(
        totalPaise: total,
        friendIds: _friends.map((f) => f.id).toList(),
        includeMe: _includeMe,
        payerId: _payerId,
      );
      return (entries: entries, problem: null);
    }

    final shares = {for (final id in _participants) id: _sharePaise(id)};
    final assigned = shares.values.fold(0, (s, v) => s + v);
    if (assigned != total) {
      final diff = total - assigned;
      return (
        entries: none,
        problem: diff > 0 ? '${Money.format(diff)} still to assign' : '${Money.format(-diff)} too much assigned',
      );
    }
    final entries = Ledger.splitByShares(shares: shares, payerId: _payerId);
    if (!entries.any((e) => e.youOwe || e.youAreOwed)) {
      return (entries: none, problem: 'Nobody owes you or is owed by you');
    }
    return (entries: entries, problem: null);
  }

  Future<void> _save(List<DebtEntry> entries) async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    setState(() => _saving = true);
    try {
      await widget.repo.addSplit(
        title: title.isEmpty ? 'Expense' : title,
        totalPaise: _totalPaise,
        payerId: _payerId,
        entries: entries,
      );
      widget.onClose();
    } catch (e) {
      widget.onError(e);
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  // Black throughout; only the people (chips and share rows) are coloured.

  TextStyle _text(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(color: color, fontSize: size, fontWeight: weight);

  LinearGradient _gradientOf(String? id) => id == null ? _youGradient : FloxColors.gradientFor(id);

  @override
  Widget build(BuildContext context) {
    final plan = _plan();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _buildAmountCard(),
                  const SizedBox(height: 14),
                  _buildTitleField(),
                  _section('Split with', Icons.group_rounded),
                  _buildPeoplePicker(),
                  if (_friends.isNotEmpty) ...[
                    _section('Who paid?', Icons.account_balance_wallet_rounded),
                    _buildPayerPicker(),
                    _section('How to split?', Icons.pie_chart_rounded),
                    _buildSplitModeToggle(),
                    if (!_equally) ...[const SizedBox(height: 12), _buildCustomShares()],
                  ],
                  if (plan.problem == null) ...[const SizedBox(height: 24), _buildSummary(plan.entries)],
                ],
              ),
            ),
            _buildSaveButton(plan),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 4),
          Text('Add expense', style: _text(20, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _section(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: _text(15, color: Colors.white70, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW MUCH?',
            style: _text(12, color: Colors.white54, weight: FontWeight.w800),
          ),
          Row(
            children: [
              Text(
                '₹',
                style: _text(40, color: Colors.white54, weight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_amountFormatter],
                  onChanged: (_) => setState(() {}),
                  style: _text(48, weight: FontWeight.w900),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: _text(48, color: Colors.white24, weight: FontWeight.w900),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 200,
      style: _text(16),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        counterText: '',
        hintText: 'What was it for? (e.g. Dinner)',
        hintStyle: _text(16, color: Colors.white38),
        prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white38),
        fillColor: _field,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
      ),
    );
  }

  /// "You" plus every friend as a tappable chip, and a chip to add a new friend.
  Widget _buildPeoplePicker() {
    final allFriends = widget.repo.friends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            _personChip(
              id: null,
              label: 'You',
              selected: _includeMe,
              onTap: () => setState(() => _includeMe = !_includeMe),
            ),
            for (final f in allFriends)
              _personChip(id: f.id, label: f.name, selected: _isPicked(f), onTap: () => _toggleFriend(f)),
            _newFriendChip(),
          ],
        ),
        if (allFriends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Add a friend from your contacts to get started.', style: _text(13, color: Colors.white38)),
          ),
      ],
    );
  }

  /// The one chip style used for people, "New friend" and the split mode:
  /// no border, white when selected. Only [bubble] carries colour.
  Widget _pill({required Widget bubble, required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        decoration: BoxDecoration(color: selected ? Colors.white : _field, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: bubble),
            const SizedBox(width: 8),
            Text(
              label,
              style: _text(
                14,
                color: selected ? Colors.black : Colors.white,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Person chip: their coloured profile bubble (a tick once selected).
  Widget _personChip({
    required String? id,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _pill(
      label: label,
      selected: selected,
      onTap: onTap,
      bubble: Container(
        decoration: BoxDecoration(gradient: _gradientOf(id), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(label.isEmpty ? '?' : label[0].toUpperCase(), style: _text(13, weight: FontWeight.w800)),
      ),
    );
  }

  /// Neutral bubble holding an icon, for chips that aren't people.
  Widget _iconBubble(IconData icon, {bool selected = false}) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  Widget _newFriendChip() {
    return _pill(
      label: 'New friend',
      selected: false,
      onTap: _addNewFriend,
      bubble: _iconBubble(Icons.person_add_alt_1_rounded),
    );
  }

  /// Payer is always one of the people in the expense; you by default.
  Widget _buildPayerPicker() {
    final options = <String?>[null, ..._friends.map((f) => f.id)];
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final id in options)
          _personChip(id: id, label: _name(id), selected: _payerId == id, onTap: () => setState(() => _payerId = id)),
      ],
    );
  }

  /// Same chips as the sections above, so the whole form reads alike.
  Widget _buildSplitModeToggle() {
    Widget option(bool value, String label, IconData icon) => _pill(
      label: label,
      selected: _equally == value,
      onTap: () => setState(() => _equally = value),
      bubble: _iconBubble(icon, selected: _equally == value),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        option(true, 'Equally', Icons.drag_handle_rounded),
        option(false, 'Custom amounts', Icons.tune_rounded),
      ],
    );
  }

  /// One amount field per person sharing the cost; only the profile bubble is coloured.
  Widget _buildCustomShares() {
    return Column(
      children: [
        for (final id in _participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 8),
              decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(gradient: _gradientOf(id), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(_name(id)[0].toUpperCase(), style: _text(14, weight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_name(id), style: _text(15, weight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _shareController(id),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_amountFormatter],
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() {}),
                      style: _text(17, weight: FontWeight.w700),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: _text(17, color: Colors.white54),
                        hintText: '0',
                        hintStyle: _text(17, color: Colors.white24),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Plain sentences such as "Rahul owes you ₹250".
  Widget _buildSummary(List<DebtEntry> entries) {
    String sentence(DebtEntry e) {
      final amount = Money.format(e.amountPaise);
      if (e.youOwe) return 'You owe ${_name(e.creditorId)} $amount';
      if (e.youAreOwed) return '${_name(e.debtorId)} owes you $amount';
      return '${_name(e.debtorId)} owes ${_name(e.creditorId)} $amount';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'After saving',
            style: _text(13, color: Colors.white54, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    e.youOwe ? Icons.north_east_rounded : Icons.south_west_rounded,
                    size: 18,
                    color: e.youOwe ? FloxColors.owe : (e.youAreOwed ? FloxColors.owed : Colors.white38),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sentence(e), style: _text(15))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(({List<DebtEntry> entries, String? problem}) plan) {
    final canSave = plan.problem == null && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plan.problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(plan.problem!, style: _text(13, color: Colors.white54)),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canSave ? () => _save(plan.entries) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : Text(
                      _totalPaise > 0 ? 'Save ${Money.format(_totalPaise)}' : 'Save',
                      style: _text(18, color: canSave ? Colors.black : Colors.white38, weight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
