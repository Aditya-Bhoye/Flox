import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavBar({super.key, required this.selectedIndex, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      _buildNavItem(Icons.home_rounded, 0, "Home"),
      _buildNavItem(Icons.calendar_today_rounded, 1, "Splitwise"),
      _buildNavItem(Icons.track_changes_rounded, 2, "Setting"),
    ];

    // Solid black bar; the selected tab is a white pill.
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0D),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: navItems,
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
        decoration: BoxDecoration(
          // Same decoration type both ways so the pill animates smoothly.
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.6), size: 28),
            ClipRect(
              // Ensure content is clipped during size animation to prevent overflow
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300), // Match container duration
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft, // Expand from left to right naturally
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(), // Prevent user scroll
                            child: ConstrainedBox(
                              // Constrain width to prevent infinite expansion
                              constraints: const BoxConstraints(maxWidth: 150), // Max reasonable width for label
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis, // Ensure ellipsis if somehow text is super long
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
