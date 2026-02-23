import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/split.dart';

class HomeTab extends StatefulWidget {
  final List<Contact> contacts;
  final List<SplitItem> splits;
  final VoidCallback onAddContact;

  const HomeTab({
    super.key,
    required this.contacts,
    required this.splits,
    required this.onAddContact,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {

  Widget _buildContactAvatar(Contact contact) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            image: (contact.photo != null)
                ? DecorationImage(
                    image: MemoryImage(contact.photo!),
                    fit: BoxFit.cover,
                  )
                : null,
            color: (contact.photo == null) ? Colors.grey.withOpacity(0.3) : null,
          ),
          child: (contact.photo == null)
              ? Center(
                  child: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName.substring(0, 1).toUpperCase()
                        : "?",
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          contact.displayName.split(" ").first,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCreditCard({
    required Color color,
    required String cardNumber,
    required String expiryDate,
    required String cardHolder,
    required bool isFront,
  }) {
    return CustomPaint(
      painter: CardShadowPainter(), // Custom shadow for the shape
      child: ClipPath(
        clipper: CardShapeClipper(),
        child: Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: color,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use `Stack` or `Row` aligned to top
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Chip Icon
                   CustomPaint(
                     size: const Size(40, 30),
                     painter: ChipPainter(),
                   ),
                   // Visa Logo Text
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
                // Card Number
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
                // Bottom Row: Name and Expiry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card Holder Name',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardHolder,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Expiry Date',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expiryDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                   const Spacer(), // Push content up if not front
              ]
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Amount & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total actual split debt/owe
    double totalBalance = 0.0;
    for (var split in widget.splits) {
      totalBalance += split.totalOwedToYou; // Using the existing getter
    }
    
    final fmtBalance = NumberFormat.currency(symbol: "₹ ", decimalDigits: 2).format(totalBalance);

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
                // Total Balance Label
                Text(
                  'Total Splits',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18, // Increased size
                    fontWeight: FontWeight.w900, // Extra Bold
                  ),
                ),
                const SizedBox(height: 8),
                
                // Balance Row
                Row(
                  children: [
                    Text(
                      fmtBalance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48, // Increased font size
                        fontWeight: FontWeight.w900, // Extra bold
                        letterSpacing: -1.0, // Tighter spacing for large text
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'INR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),

                // Contacts / Send Money Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Add Button
                      GestureDetector(
                        onTap: widget.onAddContact,
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 30),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Add",
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      // Dynamic Contacts List
                       if (widget.contacts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text("No contacts", style: TextStyle(color: Colors.white)),
                        )
                      else
                        ...widget.contacts.map((contact) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 20.0),
                            child: _buildContactAvatar(contact),
                          );
                        }),
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
                  
                  // Credit Cards Stack
                  SizedBox(
                    height: 340, // Height for the stack
                    child: Stack(
                      children: [
                        // Card 3 (Back - Top)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF1E1E1E),
                            cardNumber: '', // Hidden
                            expiryDate: '',
                            cardHolder: '',
                            isFront: false,
                          ),
                        ),
                        // Card 2 (Middle)
                        Positioned(
                          top: 55,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF4285F4), // Vibrant Blue
                            cardNumber: '', // Hidden
                            expiryDate: '',
                            cardHolder: '',
                            isFront: false,
                          ),
                        ),
                        // Card 1 (Front - Bottom)
                        Positioned(
                          top: 110,
                          left: 0,
                          right: 0,
                          child: _buildCreditCard(
                            color: const Color(0xFF0F1115), // Deep Black
                            cardNumber: '**** **** **** 2345',
                            expiryDate: '02/30',
                            cardHolder: Supabase.instance.client.auth.currentUser?.userMetadata?['name'] ?? 'Unknown User',
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Increased size
                          fontWeight: FontWeight.w900, // Extra Bold
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'See all',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Transactions List
                  if (widget.splits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20.0),
                      child: Center(
                        child: Text(
                          "No recent activity",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...widget.splits.reversed.take(5).map((split) {
                      final fmt = NumberFormat.currency(symbol: "₹", decimalDigits: 0);
                      
                      // Map SplitItem properties to the UI
                      return _buildTransactionItem(
                        icon: Icons.receipt_long, // Generic receipt icon for splits
                        title: split.title,
                        subtitle: "Paid by ${split.payerName}",
                        amount: fmt.format(split.totalAmount),
                        date: DateFormat('dd MMM').format(split.date),
                        color: Colors.blueAccent, // You can make this dynamic if desired
                      );
                    }).toList(),

                  // Add extra padding at the bottom for navigation bar
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
    canvas.drawShadow(path, Colors.black.withOpacity(0.5), 10.0, true);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFE0C489)
      ..style = PaintingStyle.fill;

    final RRect rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    
    canvas.drawRRect(rRect, paint);

    // Add lines for chip detail
    final Paint linePaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
    
    // Draw dummy lines
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), linePaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), linePaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), linePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
