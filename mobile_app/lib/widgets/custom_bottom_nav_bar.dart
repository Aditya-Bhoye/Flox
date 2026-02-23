import 'dart:ui';
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool showLoanApproval;
  final bool showSplitwise;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.showLoanApproval = true,
    this.showSplitwise = true,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamically build the list of nav items and their corresponding target index
    List<Widget> navItems = [];
    int currentIndex = 0;

    // Home is always index 0
    navItems.add(_buildNavItem(Icons.home_rounded, currentIndex++, "Home"));

    if (showLoanApproval) {
      navItems.add(_buildNavItem(Icons.check_circle_outline_rounded, currentIndex++, "Loan Approval"));
    }

    if (showSplitwise) {
      navItems.add(_buildNavItem(Icons.calendar_today_rounded, currentIndex++, "Splitwise"));
    }

    // Setting is always the last index
    navItems.add(_buildNavItem(Icons.track_changes_rounded, currentIndex++, "Setting"));

    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 40, // Prevent overflow beyond screen width
          ),
          height: 80,
          // Removed fixed width to allow expansion
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: navItems,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 550), // Slower, smoother transition
        curve: Curves.easeOutQuint, // Super smooth "butter" curve
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30), // Pill shape
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              )
            : BoxDecoration( // Use same decoration type for smooth interpolation
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(50), 
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              size: 28,
            ),
            ClipRect( // Ensure content is clipped during size animation to prevent overflow
              child: AnimatedSize(
                duration: const Duration(milliseconds: 550), // Match container duration
                curve: Curves.easeOutQuint,
                alignment: Alignment.centerLeft, // Expand from left to right naturally
                child: SizedBox(
                  width: isSelected ? null : 0, 
                  child: isSelected 
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(), // Prevent user scroll
                          child: ConstrainedBox( // Constrain width to prevent infinite expansion
                            constraints: const BoxConstraints(maxWidth: 150), // Max reasonable width for label
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis, // Ensure ellipsis if somehow text is super long
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
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
