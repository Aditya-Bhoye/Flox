import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:mobile_app/models/split.dart';
import 'package:intl/intl.dart';

class SplitwiseTab extends StatefulWidget {
  final List<Contact> contacts;
  final List<SplitItem> splits;
  final Function(SplitItem) onAddSplit;
  final Function(Contact)? onRemoveContact;
  
  // Drill-down State
  final String? selectedFriendName;
  final Function(String?, double?) onFriendSelected;

  const SplitwiseTab({
    super.key, 
    this.contacts = const [],
    this.splits = const [],
    required this.onAddSplit,
    this.onRemoveContact,
    this.selectedFriendName,
    required this.onFriendSelected,
  });

  @override
  State<SplitwiseTab> createState() => _SplitwiseTabState();
}

class _SplitwiseTabState extends State<SplitwiseTab> {

  @override
  Widget build(BuildContext context) {
    // 1. Calculate net balances per friend
    final Map<String, double> netBalances = {};
    for (var split in widget.splits) {
      for (var entry in split.entries) {
        if (entry.youOwe) {
          final friend = entry.creditorName!;
          netBalances[friend] = (netBalances[friend] ?? 0) - entry.amount;
        } else if (entry.youAreOwed) {
          final friend = entry.debtorName!;
          netBalances[friend] = (netBalances[friend] ?? 0) + entry.amount;
        }
      }
    }

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
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final inDirection = widget.selectedFriendName != null 
                        ? const Offset(0.5, 0.0) // Slide from right to left
                        : const Offset(-0.5, 0.0); // Slide from left to right
                    
                    final offsetAnimation = Tween<Offset>(
                      begin: child.key == ValueKey(widget.selectedFriendName) ? inDirection : -inDirection,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
                    
                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    widget.selectedFriendName != null ? "${widget.selectedFriendName} History" : "Recent Activity",
                    key: ValueKey(widget.selectedFriendName), // Unique key forces the animated transition
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter, 
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final inDirection = widget.selectedFriendName != null 
                        ? const Offset(0.5, 0.0) // Slide from right to left
                        : const Offset(-0.5, 0.0); // Slide from left to right
                    
                    final offsetAnimation = Tween<Offset>(
                      begin: child.key == ValueKey(widget.selectedFriendName) ? inDirection : -inDirection,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
                    
                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey(widget.selectedFriendName ?? "all_splits"),
                    children: [
                      if (widget.splits.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Text(
                              "No splits yet",
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        ...widget.splits.where((split) {
                          if (widget.selectedFriendName == null) return true;
                          return split.entries.any((e) => e.debtorName == widget.selectedFriendName || e.creditorName == widget.selectedFriendName);
                        }).map((split) => _buildSplitItem(context, split)).toList(),
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

  Widget _buildTotalBalanceCard(Map<String, double> netBalances) {
    // 2. Aggregate final balances
    double youOwe = 0;
    double youAreOwed = 0;

    for (var balance in netBalances.values) {
      if (balance > 0) {
        youAreOwed += balance;
      } else if (balance < 0) {
        youOwe += balance.abs();
      }
    }

    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
         filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
         child: Container(
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
             color: Colors.white.withOpacity(0.12),
             borderRadius: BorderRadius.circular(30),
             border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
           ),
           child: Row(
             children: [
               Expanded(
                 child: _buildBalanceItem("you owe", currencyFormat.format(youOwe), Colors.redAccent),
               ),
               Container(
                 width: 1,
                 height: 50,
                 color: Colors.white.withOpacity(0.2),
               ),
               Expanded(
                 child: _buildBalanceItem("you are owed", currencyFormat.format(youAreOwed), Colors.greenAccent),
               ),
             ],
           ),
         ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, Map<String, double> netBalances) {
    if (widget.selectedFriendName != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        width: double.infinity,
        child: _buildSelectedFriendCard(context, netBalances),
      );
    } 

    // Display all friends that have been added
    final allFriends = widget.contacts.map((c) {
      final friendName = c.displayName;
      return MapEntry(friendName, netBalances[friendName] ?? 0.0);
    }).toList();

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
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Avatar Scroller
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: allFriends.map((entry) {
                final friendName = entry.key;
                final balance = entry.value;
                final contactColor = Colors.primaries[friendName.hashCode % Colors.primaries.length];

                return GestureDetector(
                  onTap: () {
                    widget.onFriendSelected(friendName, balance);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Column(
                      children: [
                        // The dormant shape morphs from here
                        Container( // Reverted to normal Container because AnimatedContainer requires the SAME widget instance to morph. We rely on the outer AnimatedSize now. 
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: contactColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: balance == 0 
                                  ? Colors.white.withOpacity(0.3)
                                  : (balance > 0 ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8)), 
                              width: 2
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friendName.split(" ").first,
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

  Widget _buildSelectedFriendCard(BuildContext context, Map<String, double> netBalances) {
    final friendName = widget.selectedFriendName!;
    double balance = netBalances[friendName] ?? 0;
    
    final contactColor = Colors.primaries[friendName.hashCode % Colors.primaries.length];
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // Morph properties
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24), // Morphs from 30
        border: Border.all(color: Colors.white.withOpacity(0.08)), // Morphs from thicker colored border
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
                    color: contactColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: balance > 0 ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
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
                if (balance.abs() > 0.01)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(balance.abs()),
                        style: GoogleFonts.inter(
                          color: balance > 0 ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                           _showSettleAmountDialog(context, friendName, balance);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Settle",
                                style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
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

  void _showSettleAmountDialog(BuildContext context, String friendName, double balance) {
    if (balance.abs() < 0.01) return;
    
    final TextEditingController amountController = TextEditingController(text: balance.abs().toStringAsFixed(0));
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ]
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
                  balance > 0 ? "$friendName owes you ${currencyFormat.format(balance)}" : "You owe $friendName ${currencyFormat.format(balance.abs())}",
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
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text("₹", style: GoogleFonts.inter(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "0",
                            hintStyle: TextStyle(color: Colors.white24),
                          ),
                          autofocus: true,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancel", style: GoogleFonts.inter(color: Colors.white54, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final double? enteredAmount = double.tryParse(amountController.text);
                          if (enteredAmount != null && enteredAmount > 0) {
                            // Close dialog
                            Navigator.pop(ctx);
                            // Process the payment
                            widget.onAddSplit(_generateSettlementSplit(friendName, balance > 0 ? enteredAmount : -enteredAmount));
                            // Reset View
                            widget.onFriendSelected(null, null);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text("Confirm", style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SplitItem _generateSettlementSplit(String friendName, double settleAmount) {
    if (settleAmount.abs() < 0.01) {
      // Return a dummy split or throw an error if settlement is not needed
      // For now, returning a split with 0 amount to avoid null.
      return SplitItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "No Settlement Needed with $friendName",
        totalAmount: 0,
        payerName: 'You',
        date: DateTime.now(),
        entries: [],
      );
    }

    final entries = <DebtEntry>[];

    if (settleAmount > 0) {
      // They owe me money. To settle it, I need a transaction where I owe *them*.
      entries.add(DebtEntry(
        debtorName: null, // "You"
        creditorName: friendName, 
        amount: settleAmount
      ));
    } else {
      // I owe them money. To settle it, I need a transaction where they owe *me*.
      entries.add(DebtEntry(
        debtorName: friendName, 
        creditorName: null, // "You"
        amount: settleAmount.abs()
      ));
    }

    final newSplit = SplitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Settlement with $friendName",
      totalAmount: settleAmount.abs(),
      payerName: settleAmount > 0 ? friendName : 'You', // The person who owes pays.
      date: DateTime.now(),
      entries: entries,
    );

    return newSplit;
  }

  Widget _buildBalanceItem(String label, String amount, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }


  Widget _buildSplitItem(BuildContext context, SplitItem split) {
    final fmt = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    double netBalance = 0;
    if (widget.selectedFriendName != null) {
      for (var entry in split.entries) {
         if (entry.debtorName == null && entry.creditorName == widget.selectedFriendName) {
           netBalance -= entry.amount; // You owe them
         } else if (entry.debtorName == widget.selectedFriendName && entry.creditorName == null) {
           netBalance += entry.amount; // They owe you
         }
      }
    } else {
      netBalance = split.totalOwedToYou - split.totalYouOwe;
    }

    String statusText;
    Color statusColor;

    if (netBalance > 0) {
      statusText = widget.selectedFriendName != null ? "You lent ${fmt.format(netBalance)}" : "You are owed ${fmt.format(netBalance)}";
      statusColor = Colors.greenAccent;
    } else if (netBalance < 0) {
      statusText = widget.selectedFriendName != null ? "You borrowed ${fmt.format(netBalance.abs())}" : "You owe ${fmt.format(netBalance.abs())}";
      statusColor = Colors.redAccent;
    } else {
      statusText = widget.selectedFriendName != null ? "Settlement" : "Settled / Not involved";
      statusColor = Colors.white54;
    }

    return GestureDetector(
      onTap: () => _showSplitDetails(context, split),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + date
            Row(
              children: [
                Expanded(
                  child: Text(
                    split.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  DateFormat('d MMM').format(split.date),
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total: ${fmt.format(split.totalAmount)}",
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.inter(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSplitDetails(BuildContext context, SplitItem split) {
    final fmt = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.only(top: 100),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  split.title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "${DateFormat('d MMM, yyyy • hh:mm a').format(split.date)}",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
              ),

              const SizedBox(height: 24),

              // Total Amount
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text("Total Expense", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text(
                      fmt.format(split.totalAmount),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Paid by ${split.payerName}",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text("DISTRIBUTION", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  shrinkWrap: true,
                  children: split.entries.map((entry) {
                    final isOwedToYou = entry.youAreOwed;
                    final isYouOwing = entry.youOwe;
                    final color = isOwedToYou ? Colors.greenAccent : (isYouOwing ? Colors.redAccent : Colors.white70);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isOwedToYou 
                                ? Icons.call_received_rounded 
                                : (isYouOwing ? Icons.arrow_outward_rounded : Icons.sync_alt_rounded),
                              color: color,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              entry.label,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            fmt.format(entry.amount),
                            style: GoogleFonts.inter(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSplitModal(context),
          borderRadius: BorderRadius.circular(35),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  void _showAddSplitModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return _UnifiedAddSplitScreen(
          contacts: widget.contacts,
          onAddSplit: widget.onAddSplit,
          onClose: () => Navigator.pop(context),
          onRemoveContact: widget.onRemoveContact,
        );
      },
    );
  }
}


// UNIFIED ADD SPLIT SCREEN (Revolut/Transfer Style)
class _UnifiedAddSplitScreen extends StatefulWidget {
  final List<Contact> contacts;
  final Function(SplitItem) onAddSplit;
  final VoidCallback onClose;
  final Function(Contact)? onRemoveContact;

  const _UnifiedAddSplitScreen({
    required this.contacts,
    required this.onAddSplit,
    required this.onClose,
    this.onRemoveContact,
  });

  @override
  State<_UnifiedAddSplitScreen> createState() => _UnifiedAddSplitScreenState();
}

class _UnifiedAddSplitScreenState extends State<_UnifiedAddSplitScreen> {

  List<Contact> _selectedFriends = [];
  bool _includeMe = true;
  bool _equallyDistributed = true;
  final Set<String> _paidFriends = {};

  // Amount entry screen state
  bool _showAmountEntry = false;
  String _totalAmount = "0";
  // For condition 3 (custom): per-friend amounts
  final Map<String, String> _customAmounts = {};
  String? _activeCustomFriendId; // which friend is being typed for

  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        setState(() => _isEditingTitle = false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _toggleFriend(Contact contact) {
    setState(() {
      if (_selectedFriends.any((c) => c.id == contact.id)) {
        _selectedFriends.removeWhere((c) => c.id == contact.id);
        _paidFriends.remove(contact.id);
        _customAmounts.remove(contact.id);
      } else {
        _selectedFriends.add(contact);
      }
    });
  }

  // ₹”€₹”€ Keypad input logic ₹”€₹”€
  void _onKeyTap(String key, {bool isCustom = false}) {
    setState(() {
      if (isCustom && _activeCustomFriendId != null) {
        String current = _customAmounts[_activeCustomFriendId!] ?? "0";
        _customAmounts[_activeCustomFriendId!] = _applyKey(current, key);
      } else {
        _totalAmount = _applyKey(_totalAmount, key);
      }
    });
  }

  String _applyKey(String current, String key) {
    if (key == 'del') {
      if (current.length <= 1) return "0";
      return current.substring(0, current.length - 1);
    }
    if (key == '.') {
      if (current.contains('.')) return current;
      return current + '.';
    }
    if (current == "0") return key;
    return current + key;
  }

  // ₹”€₹”€ Computed split amounts & Validation ₹”€₹”€
  bool get _canSave {
    if (_selectedFriends.isEmpty) return false;

    if (_equallyDistributed) {
      final total = double.tryParse(_totalAmount) ?? 0;
      if (total <= 0) return false;

      // Condition 1: Must select who paid
      if (_includeMe && _paidFriends.isEmpty) return false; 
    } else {
      // Condition 3: Custom split
      double assigned = 0;
      for (var f in _selectedFriends) {
        assigned += double.tryParse(_customAmounts[f.id] ?? "0") ?? 0;
      }
      if (assigned <= 0) return false;
    }
    return true;
  }

  void _saveSplit() {
    final title = _titleController.text.isEmpty ? "Add Expense" : _titleController.text;
    final date = DateTime.now();
    final entries = <DebtEntry>[];

    double computedTotal = 0;
    String payerName = 'You';

    if (_equallyDistributed) {
       computedTotal = double.tryParse(_totalAmount) ?? 0;
       final participantsCount = _includeMe ? (_selectedFriends.length + 1) : _selectedFriends.length;
       final each = computedTotal / participantsCount;
       
       if (!_includeMe) {
           // Condition 2: I Paid for Friends (Equal Split, Paid by Me)
           payerName = 'You';
           for (var f in _selectedFriends) {
             entries.add(DebtEntry(debtorName: f.displayName, creditorName: null, amount: each));
           }
       } else if (_paidFriends.isNotEmpty && !_paidFriends.contains('YOU')) {
           // Condition 1B: Equal Split, Paid by Friend
           final friendId = _paidFriends.first;
           final friend = _selectedFriends.firstWhere((c) => c.id == friendId);
           payerName = friend.displayName;
           
           // You owe the friend your share
           entries.add(DebtEntry(debtorName: null, creditorName: friend.displayName, amount: each));
           
           // Other friends owe the friend their share
           for (var f in _selectedFriends) {
             if (f.id != friendId) {
               entries.add(DebtEntry(debtorName: f.displayName, creditorName: friend.displayName, amount: each));
             }
           }
       } else {
           // Condition 1A: Equal Split, Paid by Me
           payerName = 'You';
           for (var f in _selectedFriends) {
             entries.add(DebtEntry(debtorName: f.displayName, creditorName: null, amount: each));
           }
       }
    } else {
      // Condition 3: I Owe (Unequal Split, Paid by Me)
      payerName = 'You';
      for (var f in _selectedFriends) {
         final amt = double.tryParse(_customAmounts[f.id] ?? "0") ?? 0;
         computedTotal += amt;
         if (amt > 0) {
           // You paid full amount. Amount is assigned to friends, meaning they owe you.
           entries.add(DebtEntry(debtorName: f.displayName, creditorName: null, amount: amt));
         }
      }
    }

    final newSplit = SplitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      totalAmount: computedTotal,
      payerName: payerName,
      date: date,
      entries: entries,
    );

    widget.onAddSplit(newSplit);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showAmountEntry) {
      return _buildAmountEntryScreen(context);
    }
    return _buildFriendSelectionScreen(context);
  }

  // ₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•
  // SCREEN 1: Friend Selection
  // ₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•
  bool _dropdownOpen = false; // controls the Select Friends dropdown

  Widget _buildFriendSelectionScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 60, bottom: 12),
              child: Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF1E1E1E), shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _isEditingTitle
                  ? TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      autofocus: true,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: "Add Expense",
                        hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 32, fontWeight: FontWeight.w900),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => setState(() => _isEditingTitle = false),
                    )
                  : InkWell(
                      onTap: () {
                        setState(() => _isEditingTitle = true);
                        _titleFocusNode.requestFocus();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _titleController.text.isEmpty ? "Add Expense" : _titleController.text,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 24),
                        ],
                      ),
                    ),
              ),
            ),

            const SizedBox(height: 24),



            // Include You toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Include You",
                        style: GoogleFonts.inter(
                          color: _equallyDistributed ? Colors.white : Colors.white30,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: _includeMe,
                        onChanged: _equallyDistributed ? (v) => setState(() => _includeMe = v) : null,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveThumbColor: Colors.white38,
                        inactiveTrackColor: Colors.white12,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Equally Distributed toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Equally Distributed",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: _equallyDistributed,
                        onChanged: (v) => setState(() {
                          _equallyDistributed = v;
                          if (!v) _includeMe = false;
                        }),
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveThumbColor: Colors.white38,
                        inactiveTrackColor: Colors.white12,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── SELECT FRIENDS button + inline dropdown ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Select Friends button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _dropdownOpen ? Colors.white54 : Colors.white12,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedFriends.isEmpty
                                        ? "Select Friends"
                                        : "${_selectedFriends.length} friend${_selectedFriends.length > 1 ? 's' : ''} selected",
                                      style: GoogleFonts.inter(
                                        color: _selectedFriends.isEmpty ? Colors.white54 : Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _dropdownOpen ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 22),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── INLINE glassmorphic dropdown (directly below button) ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _dropdownOpen
                        ? Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.09),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                  ),
                                  child: widget.contacts.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          "No friends added yet.\nAdd friends from the Home tab.",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                                        ),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: widget.contacts.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final contact = entry.value;
                                          final isSelected = _selectedFriends.any((c) => c.id == contact.id);
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (index > 0)
                                                Divider(color: Colors.white.withOpacity(0.07), height: 1, indent: 56),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() => _toggleFriend(contact));
                                                },
                                                behavior: HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      // Avatar
                                                      Container(
                                                        width: 38, height: 38,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.25) : Colors.white10,
                                                        ),
                                                        clipBehavior: Clip.antiAlias,
                                                        child: contact.photo != null
                                                          ? Image.memory(contact.photo!, fit: BoxFit.cover)
                                                          : Center(child: Text(
                                                              contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                                                              style: GoogleFonts.inter(
                                                                color: isSelected ? const Color(0xFF81C784) : Colors.white,
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            )),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Name
                                                      Expanded(
                                                        child: Text(
                                                          contact.displayName,
                                                          style: GoogleFonts.inter(
                                                            color: isSelected ? Colors.white : Colors.white70,
                                                            fontSize: 14,
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      // Checkmark circle on right
                                                      AnimatedContainer(
                                                        duration: const Duration(milliseconds: 200),
                                                        width: 26, height: 26,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: isSelected ? const Color(0xFF4CAF50) : Colors.white10,
                                                          border: Border.all(
                                                            color: isSelected ? const Color(0xFF4CAF50) : Colors.white24,
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        child: isSelected
                                                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                                          : null,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 16),

                    // ── SELECTED FRIEND CARDS ──
                    if (!_dropdownOpen && _selectedFriends.isNotEmpty) ...[
                      _buildSelectedFriendCard(id: 'YOU', name: 'You', isYou: true),
                      ..._selectedFriends.map((contact) => _buildSelectedFriendCard(
                        id: contact.id,
                        name: contact.displayName,
                        photo: contact.photo,
                        isYou: false,
                      )),
                    ],
                  ],
                ),
              ),
            ),

            // Action button (Confirm Friends or Enter Amount)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _dropdownOpen
                      ? () => setState(() => _dropdownOpen = false)
                      : (_selectedFriends.isEmpty ? null : () => setState(() => _showAmountEntry = true)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_dropdownOpen || _selectedFriends.isNotEmpty) ? Colors.white : Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: Text(
                    _dropdownOpen ? "Save" : "Enter Amount",
                    style: GoogleFonts.inter(
                      color: (_dropdownOpen || _selectedFriends.isNotEmpty) ? Colors.black : Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
  // ₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•₹•
  Widget _buildAmountEntryScreen(BuildContext context) {
    final isCustomSplit = !_equallyDistributed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 60, bottom: 12),
              child: Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF1E1E1E), shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: () => setState(() => _showAmountEntry = false),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // Top spacer / amount display area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isCustomSplit)
                    // Condition 3: glassmorphic friend cards with per-friend amounts
                    _buildCustomSplitFriendList()
                  else
                    // Conditions 1 & 2: large amount display
                    _buildEqualAmountDisplay(),
                  const SizedBox(height: 24),
                ],
              ),
            ),


            // Done / Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSave ? _saveSplit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSave ? Colors.white : Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Save",
                    style: GoogleFonts.inter(
                      color: _canSave ? Colors.black : Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Custom keypad
            _buildKeypad(isCustom: isCustomSplit),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ₹”€₹”€ Selected Friend Card (includes 'You') ₹”€₹”€
  Widget _buildSelectedFriendCard({
    required String id,
    required String name,
    Uint8List? photo,
    required bool isYou,
  }) {
    // Paid toggle is ONLY interactive during Condition 1 (Equally Distributed == true AND Include Me == true).
    bool canTogglePaid = _equallyDistributed && _includeMe;
    bool hasPaid;
    bool showPaidToggle;

    if (isYou) {
      if (!canTogglePaid) {
        hasPaid = true; // Forced ON for Cond 2 & 3
        showPaidToggle = true; 
      } else {
        hasPaid = _paidFriends.contains('YOU');
        showPaidToggle = true;
      }
    } else {
      if (!canTogglePaid) {
        hasPaid = false;
        showPaidToggle = false; 
      } else {
        hasPaid = _paidFriends.contains(id);
        showPaidToggle = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isYou ? Colors.blueAccent.withOpacity(0.2) : Colors.white12),
                  clipBehavior: Clip.antiAlias,
                  child: photo != null
                    ? Image.memory(photo, fit: BoxFit.cover)
                    : Center(child: Text(
                        isYou ? 'Y' : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                        style: GoogleFonts.inter(color: isYou ? Colors.blueAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      )),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (showPaidToggle)
                  GestureDetector(
                    onTap: () {
                      if (!canTogglePaid) return; 
                      setState(() {
                         if (isYou) {
                           _paidFriends.clear();
                           _paidFriends.add('YOU');
                         } else {
                           _paidFriends.clear();
                           _paidFriends.add(id);
                         }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: hasPaid ? Colors.green.withOpacity(0.20) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasPaid ? Colors.greenAccent.withOpacity(0.6) : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasPaid ? Icons.check_rounded : Icons.payments_outlined,
                            color: hasPaid ? Colors.greenAccent : Colors.white38,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasPaid ? "Paid" : "Paid?",
                            style: GoogleFonts.inter(
                              color: hasPaid ? Colors.greenAccent : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Icon(Icons.check_circle_rounded, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ₹”€₹”€ Equal split amount display ₹”€₹”€
  Widget _buildEqualAmountDisplay() {
    final total = double.tryParse(_totalAmount) ?? 0;
    final divisor = _includeMe ? _selectedFriends.length + 1 : _selectedFriends.length;
    final each = divisor > 0 ? total / divisor : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large amount input display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("₹", style: GoogleFonts.inter(color: Colors.white54, fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _totalAmount,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (total > 0 && _selectedFriends.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              (!_includeMe)
                ? "Each friend owes you -> ₹${each.toStringAsFixed(2)}"
                : _paidFriends.isEmpty 
                  ? "Select who paid"
                  : (_paidFriends.contains('YOU')
                      ? "Each friend owes you -> ₹${each.toStringAsFixed(2)}"
                      : "You owe -> ₹${each.toStringAsFixed(2)} to ${_selectedFriends.firstWhere((c) => c.id == _paidFriends.first).displayName}"),
              style: GoogleFonts.inter(
                color: (_includeMe && _paidFriends.isEmpty) ? Colors.orangeAccent : Colors.white38, 
                fontSize: 13
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ₹”€₹”€ Custom split: glassmorphic friend cards ₹”€₹”€
  Widget _buildCustomSplitFriendList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Set amount per person",
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ..._selectedFriends.map((contact) {
            final isActive = _activeCustomFriendId == contact.id;
            final amount = _customAmounts[contact.id] ?? "0";
            return GestureDetector(
              onTap: () => setState(() => _activeCustomFriendId = contact.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? Colors.white38 : Colors.white12,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
                            clipBehavior: Clip.antiAlias,
                            child: contact.photo != null
                              ? Image.memory(contact.photo!, fit: BoxFit.cover)
                              : Center(child: Text(
                                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              contact.displayName.split(' ').first,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                          // Amount on right
                          Text(
                            "₹$amount",
                            style: GoogleFonts.inter(
                              color: isActive ? Colors.white : Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 4),
                            Container(width: 2, height: 22, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ₹”€₹”€ Custom numeric keypad ₹”€₹”€
  Widget _buildKeypad({required bool isCustom}) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'del'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _onKeyTap(key, isCustom: isCustom),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: key == 'del' ? Colors.white10 : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: key == 'del'
                            ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22)
                            : Text(
                                key,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
} // end _UnifiedAddSplitScreenState
