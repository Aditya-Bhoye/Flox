import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friend.dart';
import '../../models/ledger.dart';
import '../../models/money.dart';
import '../../services/flox_repository.dart';

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

  /// Showcase credit card. Only the front card shows the number, holder and expiry.
  Widget _buildCreditCard({
    required Color color,
    required String cardNumber,
    required String expiryDate,
    required String cardHolder,
    required bool isFront,
  }) {
    TextStyle label() => TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10);
    const value = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500);

    return CustomPaint(
      painter: CardShadowPainter(),
      child: ClipPath(
        clipper: CardShapeClipper(),
        child: Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          color: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomPaint(size: const Size(40, 30), painter: ChipPainter()),
                  const Text(
                    'VISA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              if (isFront) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    cardNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Holder Name', style: label()),
                          const SizedBox(height: 4),
                          Text(cardHolder, style: value, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Expiry Date', style: label()),
                        const SizedBox(height: 4),
                        Text(expiryDate, style: value),
                      ],
                    ),
                  ],
                ),
              ] else
                const Spacer(),
            ],
          ),
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
    final holder = Supabase.instance.client.auth.currentUser?.userMetadata?['name'] as String? ?? 'You';

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

                  // Card stack
                  SizedBox(
                    height: 340,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF1E1E1E),
                            cardNumber: '',
                            expiryDate: '',
                            cardHolder: '',
                            isFront: false,
                          ),
                        ),
                        Positioned(
                          top: 55,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF4285F4),
                            cardNumber: '',
                            expiryDate: '',
                            cardHolder: '',
                            isFront: false,
                          ),
                        ),
                        Positioned(
                          top: 110,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF0F1115),
                            cardNumber: '**** **** **** 2345',
                            expiryDate: '02/30',
                            cardHolder: holder,
                            isFront: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

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

class CardShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    const double cornerRadius = 24.0;
    const double notchDepth = 15.0; // Depth of the notch
    const double notchWidth = 120.0; // Width of the notch top
    final double notchStart = (size.width - notchWidth) / 2;
    final double notchEnd = (size.width + notchWidth) / 2;

    // Start from top-left corner
    path.moveTo(0, cornerRadius);
    
    // Top-left corner
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Line to notch start
    path.lineTo(notchStart - 15, 0);

    // Curve down into notch
    path.cubicTo(
      notchStart, 0, 
      notchStart, notchDepth, 
      notchStart + 15, notchDepth
    );

    // Notch bottom line
    path.lineTo(notchEnd - 15, notchDepth);

    // Curve up from notch
    path.cubicTo(
      notchEnd, notchDepth, 
      notchEnd, 0, 
      notchEnd + 15, 0
    );

    // Line to top-right corner
    path.lineTo(size.width - cornerRadius, 0);

    // Top-right corner
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Right side
    path.lineTo(size.width, size.height - cornerRadius);

    // Bottom-right corner
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);

    // Bottom side
    path.lineTo(cornerRadius, size.height);

    // Bottom-left corner
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // Close path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CardShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = CardShapeClipper().getClip(size);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 10.0, true);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0C489)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)),
      paint,
    );

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), linePaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), linePaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), linePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
