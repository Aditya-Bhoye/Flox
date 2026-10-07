import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/flox_repository.dart';

class SettingTab extends StatefulWidget {
  final FloxRepository repo;
  final void Function(Object error) onError;

  const SettingTab({super.key, required this.repo, required this.onError});

  @override
  State<SettingTab> createState() => _SettingTabState();
}

class _SettingTabState extends State<SettingTab> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      // AuthGate shows the login page once the session ends.
      await AuthService.signOut();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
      if (mounted) {
        setState(() => _signingOut = false);
        widget.onError(const FloxException("Couldn't sign out. Please try again."));
      }
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    try {
      await widget.repo.removeFriend(friend);
    } catch (e) {
      widget.onError(e);
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
                        ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
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

            // Friends Section
            _buildGlassCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                  if (widget.repo.friends.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text("No friends added yet.", style: GoogleFonts.inter(color: Colors.white54)),
                      ),
                    )
                  else
                    SizedBox(
                      height: 250, // Fixed height for scrollable area
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(children: widget.repo.friends.map(_buildFriendItem).toList()),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Sign Out Button
            GestureDetector(
              onTap: _signingOut ? null : _signOut,
              child: _buildGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                borderColor: Colors.redAccent.withValues(alpha: 0.4),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text(
                        "Sign Out",
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildFriendItem(Friend friend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(
              child: Text(
                friend.initial,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              friend.name,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
            tooltip: 'Remove (keeps past splits)',
            onPressed: () => _removeFriend(friend),
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
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
            shape: shape,
            borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(24) : null,
            border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
