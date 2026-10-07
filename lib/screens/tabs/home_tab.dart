import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/friend.dart';
import '../../models/ledger.dart';
import '../../models/money.dart';
import '../../services/flox_repository.dart';
import '../../widgets/flox_colors.dart';

class HomeTab extends StatelessWidget {
  final FloxRepository repo;
  final VoidCallback onAddFriend;
  final VoidCallback onSeeAll;

  const HomeTab({
    super.key,
    required this.repo,
    required this.onAddFriend,
    required this.onSeeAll,
  });

  Widget _buildFriendAvatar(Friend friend) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Text(
              friend.initial,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          friend.firstName,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// One side of the balance summary: what you are owed or what you owe.
  Widget _buildBalanceTile({required String label, required int paise, required Color color, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 14),
            Text(label.toUpperCase(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Money.format(paise),
                  style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required String date,
    required Color color,
  }) {
    // Plain translucent card: a per-row BackdropFilter is costly on low-end phones.
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owedToYou = Ledger.totalOwedToYou(repo.balances);
    final youOwe = Ledger.totalYouOwe(repo.balances);
    final net = owedToYou - youOwe;
    final friends = repo.friends;
    final recent = repo.splits.take(5).toList(); // splits are newest first

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Section
          Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 24.0, right: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${net < 0 ? '-' : ''}${Money.format(net.abs())}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'INR',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Friends row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onAddFriend,
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 30),
                            ),
                            const SizedBox(height: 8),
                            const Text("Add", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      if (friends.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text("No friends yet", style: TextStyle(color: Colors.white)),
                        )
                      else
                        ...friends.map((friend) => Padding(
                              padding: const EdgeInsets.only(right: 20.0),
                              child: _buildFriendAvatar(friend),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Bottom Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),

                  // Balance summary
                  Row(
                    children: [
                      _buildBalanceTile(label: 'You are owed', paise: owedToYou, color: FloxColors.owed, icon: Icons.south_west_rounded),
                      const SizedBox(width: 12),
                      _buildBalanceTile(label: 'You owe', paise: youOwe, color: FloxColors.owe, icon: Icons.north_east_rounded),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      TextButton(
                        onPressed: onSeeAll,
                        child: Text(
                          'See all',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (repo.loading && recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20.0),
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  else if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20.0),
                      child: Center(
                        child: Text("No recent activity", style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ),
                    )
                  else
                    ...recent.map((split) => _buildTransactionItem(
                          icon: Icons.receipt_long,
                          title: split.title,
                          subtitle: "Paid by ${repo.nameOf(split.payerId)}",
                          amount: Money.format(split.totalPaise),
                          date: DateFormat('dd MMM').format(split.date),
                          color: Colors.blueAccent,
                        )),

                  // Room for the navigation bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
