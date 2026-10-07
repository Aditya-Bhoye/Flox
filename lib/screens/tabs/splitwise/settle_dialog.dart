import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/models/money.dart';
import 'package:mobile_app/services/flox_repository.dart';

/// Asks how much was repaid and records a settlement with [friend].
/// Returns true when a settlement was saved.
Future<bool> showSettleDialog({
  required BuildContext context,
  required FloxRepository repo,
  required Friend friend,
  required void Function(Object error) onError,
}) async {
  final balance = repo.balances[friend.id] ?? 0;
  if (balance == 0) return false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => _SettleDialog(repo: repo, friend: friend, balance: balance, onError: onError),
  );
  return saved ?? false;
}

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.repo, required this.friend, required this.balance, required this.onError});

  final FloxRepository repo;
  final Friend friend;
  final int balance;
  final void Function(Object error) onError;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final TextEditingController _amountController;
  String? _error;
  bool _saving = false;

  int get _outstanding => widget.balance.abs();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: Money.toInput(_outstanding));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final paise = Money.parse(_amountController.text);
    if (paise == null || paise <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (paise > _outstanding) {
      setState(() => _error = 'Maximum is ${Money.format(_outstanding)}');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.repo.settleUp(widget.friend.id, paise);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      widget.onError(e);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friend.name;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Settle Up",
              style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.balance > 0
                  ? "$name owes you ${Money.format(_outstanding)}"
                  : "You owe $name ${Money.format(_outstanding)}",
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Amount Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _error != null ? Colors.redAccent : Colors.white12),
              ),
              child: Row(
                children: [
                  Text(
                    "₹",
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        hintText: "0",
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
            ],

            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    child: Text("Cancel", style: GoogleFonts.inter(color: Colors.white54, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            "Confirm",
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
