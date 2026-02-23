import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mobile_app/screens/auth/login_page.dart';

class SettingTab extends StatefulWidget {
  final bool isLoanApprovalEnabled;
  final bool isSplitwiseEnabled;
  final Function(bool isLoanApproval, bool value) onToggleFeature;
  final List<Contact> contacts;
  final Function(Contact) onRemoveContact;

  const SettingTab({
    super.key,
    required this.isLoanApprovalEnabled,
    required this.isSplitwiseEnabled,
    required this.onToggleFeature,
    required this.contacts,
    required this.onRemoveContact,
  });

  @override
  State<SettingTab> createState() => _SettingTabState();
}

class _SettingTabState extends State<SettingTab> {
  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current User Data
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final name = metadata?['name'] as String? ?? 'User';
    final avatarUrl = metadata?['avatar_url'] as String?;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Section 
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl), 
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null 
                      ? const Icon(Icons.person, size: 40, color: Colors.white) 
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),

            // Feature Toggles (Loan Approval / Splitwise)
            Column(
              children: [
                _buildSwitchOption(
                  title: "Loan Approval",
                  value: widget.isLoanApprovalEnabled,
                  onChanged: (v) => widget.onToggleFeature(true, v),
                ),
                const SizedBox(height: 12),
                _buildSwitchOption(
                  title: "Splitwise",
                  value: widget.isSplitwiseEnabled,
                  onChanged: (v) => widget.onToggleFeature(false, v),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Friends Section
            _buildGlassCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.white.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: Colors.white70),
                      const SizedBox(width: 12),
                      Text(
                        "Friends",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.contacts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No friends added yet.",
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 250, // Fixed height for scrollable area
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: widget.contacts.map((contact) => _buildFriendItem(contact)).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Sign Out Button
            GestureDetector(
              onTap: () => _signOut(context),
              child: _buildGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                borderColor: Colors.redAccent.withOpacity(0.4),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text(
                        "Sign Out",
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 120), // Bottom padding for Nav Bar
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      backgroundColor: Colors.white.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF4CAF50),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Contact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              contact.displayName,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
            onPressed: () => widget.onRemoveContact(contact),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    Color? borderColor,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return ClipRRect(
      borderRadius: shape == BoxShape.circle ? BorderRadius.circular(9999) : BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.08),
            shape: shape,
            borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(24) : null,
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

