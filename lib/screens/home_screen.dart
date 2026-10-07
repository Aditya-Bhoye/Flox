import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/screens/tabs/home_tab.dart';
import 'package:mobile_app/screens/tabs/splitwise/splitwise_tab.dart';
import 'package:mobile_app/screens/tabs/setting_tab.dart';
import 'package:mobile_app/services/flox_repository.dart';
import 'package:mobile_app/services/supabase_service.dart';
import 'package:mobile_app/widgets/app_background.dart';
import 'package:mobile_app/widgets/custom_bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userId});

  final String userId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _titles = ["Home", "Splits", "Settings"];
  static const _splitwiseIndex = 1;

  int _selectedIndex = 0;
  late final PageController _pageController;
  late final FloxRepository _repo;
  String? _lastShownSyncError;

  // Splitwise drill-down: the friend whose history is open.
  String? _selectedFriendId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _repo = FloxRepository(
      userId: widget.userId,
      remote: SupabaseService(Supabase.instance.client),
    )..addListener(_onRepoChanged);
    _repo.load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _repo.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    final error = _repo.syncError;
    if (error != null && error != _lastShownSyncError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    _lastShownSyncError = error;
  }

  void _showError(Object e) {
    if (!mounted) return;
    final message = e is FloxException ? e.message : 'Something went wrong.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  /// Contacts permission is requested only when the user taps "Add".
  /// Returns the added friend, or null if cancelled or it failed.
  Future<Friend?> _pickContact() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) return null;
      final picked = await FlutterContacts.openExternalPick();
      if (picked == null) return null;
      final contact = await FlutterContacts.getContact(picked.id) ?? picked;
      return await _repo.addFriend(
        name: contact.displayName,
        phone: contact.phones.isNotEmpty ? contact.phones.first.number : null,
      );
    } catch (e) {
      _showError(e);
      return null;
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] as String?;
    final showBack = _selectedIndex == _splitwiseIndex && _selectedFriendId != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, // Light icons for dark bg
        automaticallyImplyLeading: false,
        leadingWidth: showBack ? 80 : null,
        leading: showBack
            ? Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFriendId = null),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          // Keep the section name pinned left while it animates.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          switchInCurve: Curves.easeOutQuint,
          switchOutCurve: Curves.easeInQuint,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isEntering = child.key == ValueKey<int>(_selectedIndex);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isEntering ? const Offset(0.0, 0.4) : const Offset(0.0, -0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _titles[_selectedIndex],
            key: ValueKey<int>(_selectedIndex),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: false,
        titleSpacing: showBack ? 8 : 24,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black54) : null,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          ListenableBuilder(
            listenable: _repo,
            builder: (context, _) => PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                HomeTab(
                  repo: _repo,
                  onAddFriend: () => _pickContact(),
                  onSeeAll: () => _onItemTapped(_splitwiseIndex),
                ),
                SplitwiseTab(
                  repo: _repo,
                  selectedFriendId: _selectedFriendId,
                  onFriendSelected: (id) => setState(() => _selectedFriendId = id),
                  onError: _showError,
                  onAddFriend: _pickContact,
                ),
                SettingTab(repo: _repo, onError: _showError),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CustomBottomNavBar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemTapped,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
