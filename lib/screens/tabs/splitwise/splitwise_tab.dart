import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/models/ledger.dart';
import 'package:mobile_app/models/money.dart';
import 'package:mobile_app/models/split.dart';
import 'package:mobile_app/services/flox_repository.dart';
import 'package:mobile_app/widgets/flox_colors.dart';
import 'add_split_screen.dart';
import 'settle_dialog.dart';
import 'split_details_sheet.dart';

class SplitwiseTab extends StatefulWidget {
  final FloxRepository repo;

  // Drill-down state: the friend whose history is open, if any.
  final String? selectedFriendId;
  final void Function(String? friendId) onFriendSelected;
  final void Function(Object error) onError;

  /// Picks a new friend from contacts; returns null if cancelled.
  final Future<Friend?> Function() onAddFriend;

  const SplitwiseTab({
    super.key,
    required this.repo,
    this.selectedFriendId,
    required this.onFriendSelected,
    required this.onError,
    required this.onAddFriend,
  });

  @override
  State<SplitwiseTab> createState() => _SplitwiseTabState();
}

class _SplitwiseTabState extends State<SplitwiseTab> {
  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final netBalances = repo.balances;
    final selectedId = widget.selectedFriendId;
    final visibleSplits = selectedId == null
        ? repo.splits
        : repo.splits.where((s) => s.entries.any((e) => e.involves(selectedId))).toList();

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Total Balance Card
                _buildTotalBalanceCard(netBalances),

                const SizedBox(height: 24),
                _buildFriendsList(context, netBalances),

                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft, // Keep it pinned to the left!
                      children: <Widget>[...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final inDirection = widget.selectedFriendId != null
                        ? const Offset(0.5, 0.0) // Slide from right to left
                        : const Offset(-0.5, 0.0); // Slide from left to right

                    final offsetAnimation = Tween<Offset>(
                      begin: child.key == ValueKey(widget.selectedFriendId) ? inDirection : -inDirection,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));

                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    selectedId != null ? "${repo.nameOf(selectedId)} History" : "Recent Activity",
                    key: ValueKey(widget.selectedFriendId), // Unique key forces the animated transition
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final inDirection = widget.selectedFriendId != null
                        ? const Offset(0.5, 0.0) // Slide from right to left
                        : const Offset(-0.5, 0.0); // Slide from left to right

                    final offsetAnimation = Tween<Offset>(
                      begin: child.key == ValueKey(widget.selectedFriendId) ? inDirection : -inDirection,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));

                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey(widget.selectedFriendId ?? "all_splits"),
                    children: [
                      if (visibleSplits.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Text(
                              repo.loading ? "Loading…" : "No splits yet",
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                            ),
                          ),
                        )
                      else
                        ...visibleSplits.map((split) => _buildSplitItem(context, split)),
                    ],
                  ),
                ),

                const SizedBox(height: 120), // Bottom padding
              ],
            ),
          ),

          // Floating Add Button
          Positioned(
            bottom: 130, // Positioned above the bottom nav bar (40 + ~80 height + gap)
            right: 24,
            child: _buildAddButton(context),
          ),
        ],
      ),
    );
  }

  /// Avatar colour per friend.
  Color _colorFor(Friend friend) => Colors.primaries[friend.id.hashCode.abs() % Colors.primaries.length];

  Widget _buildTotalBalanceCard(Map<String, int> netBalances) {
    final youOwe = Ledger.totalYouOwe(netBalances);
    final youAreOwed = Ledger.totalOwedToYou(netBalances);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: _buildBalanceItem("you owe", Money.format(youOwe), Colors.redAccent)),
              Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.2)),
              Expanded(child: _buildBalanceItem("you are owed", Money.format(youAreOwed), Colors.greenAccent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, Map<String, int> netBalances) {
    if (widget.selectedFriendId != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        width: double.infinity,
        child: _buildSelectedFriendCard(context, netBalances),
      );
    }

    // Active friends, plus removed friends who still have an open balance.
    final allFriends = widget.repo.allFriends.where((f) => !f.archived || (netBalances[f.id] ?? 0) != 0).toList();

    if (allFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Friends",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Horizontal Avatar Scroller
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: allFriends.map((friend) {
                final balance = netBalances[friend.id] ?? 0;
                final contactColor = _colorFor(friend);

                return GestureDetector(
                  onTap: () {
                    widget.onFriendSelected(friend.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: contactColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: balance == 0
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : (balance > 0
                                        ? Colors.greenAccent.withValues(alpha: 0.8)
                                        : Colors.redAccent.withValues(alpha: 0.8)),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            friend.initial,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friend.firstName,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFriendCard(BuildContext context, Map<String, int> netBalances) {
    final friend = widget.repo.friendById(widget.selectedFriendId);
    if (friend == null) return const SizedBox.shrink();
    final friendName = friend.name;
    final balance = netBalances[friend.id] ?? 0;
    final contactColor = _colorFor(friend);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: const ValueKey("CardLayout"), // Forces explicit fade
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: contactColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: balance > 0
                          ? Colors.greenAccent.withValues(alpha: 0.8)
                          : Colors.redAccent.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    friend.initial,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendName,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance == 0 ? "Settled Up" : (balance > 0 ? "Owes You" : "You Owe"),
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (balance != 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Money.format(balance.abs()),
                        style: GoogleFonts.inter(
                          color: balance > 0 ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final settled = await showSettleDialog(
                            context: context,
                            repo: widget.repo,
                            friend: friend,
                            onError: widget.onError,
                          );
                          if (settled) widget.onFriendSelected(null);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Settle",
                                style: GoogleFonts.inter(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String amount, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: GoogleFonts.inter(color: color, fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildSplitItem(BuildContext context, SplitItem split) {
    final selectedId = widget.selectedFriendId;
    final netBalance = selectedId != null ? split.netWith(selectedId) : split.owedToYouPaise - split.youOwePaise;

    String statusText;
    Color statusColor;

    if (netBalance > 0) {
      statusText = selectedId != null
          ? "You lent ${Money.format(netBalance)}"
          : "You are owed ${Money.format(netBalance)}";
      statusColor = FloxColors.owed;
    } else if (netBalance < 0) {
      statusText = selectedId != null
          ? "You borrowed ${Money.format(netBalance.abs())}"
          : "You owe ${Money.format(netBalance.abs())}";
      statusColor = FloxColors.owe;
    } else {
      statusText = selectedId != null ? "Settlement" : "Settled / Not involved";
      statusColor = Colors.white54;
    }

    final (icon, iconColor) = FloxColors.categoryFor(split.title);

    return GestureDetector(
      onTap: () => showSplitDetails(context, widget.repo, split),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [iconColor.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.04)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: iconColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconColor, iconColor.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          split.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        DateFormat('d MMM').format(split.date),
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Money.format(split.totalPaise),
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSplitModal(context),
          borderRadius: BorderRadius.circular(35),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  void _showAddSplitModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) => AddSplitScreen(
        repo: widget.repo,
        onClose: () => Navigator.pop(sheetContext),
        onError: widget.onError,
        onAddFriend: widget.onAddFriend,
      ),
    );
  }
}
