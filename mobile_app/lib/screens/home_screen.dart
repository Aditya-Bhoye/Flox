import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/screens/tabs/home_tab.dart';
import 'package:mobile_app/screens/tabs/loan_approval_tab.dart';
import 'package:mobile_app/screens/tabs/splitwise_tab.dart';
import 'package:mobile_app/screens/tabs/setting_tab.dart';
import 'package:mobile_app/widgets/custom_bottom_nav_bar.dart';
import 'package:mobile_app/models/split.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  
  // Lifted state for contacts
  List<Contact> _contacts = [];
  
  // Lifted state for splits
  final List<SplitItem> _splits = [];
  
  // Lifted state for Splitwise Drill-Down
  String? _selectedFriendName;

  // Feature Toggles State
  bool _isLoanApprovalEnabled = true;
  bool _isSplitwiseEnabled = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadSavedContacts();
    _loadSavedSplits();
  }

  // ── Persistence helpers ──

  static const _kContactIdsKey = 'saved_friend_ids';

  Future<void> _loadSavedContacts() async {
    if (!await Permission.contacts.request().isGranted) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kContactIdsKey) ?? [];
    if (ids.isEmpty) return;
    final loaded = <Contact>[];
    for (final id in ids) {
      try {
        final c = await FlutterContacts.getContact(id);
        if (c != null) loaded.add(c);
      } catch (_) {}
    }
    if (loaded.isNotEmpty && mounted) {
      setState(() => _contacts = loaded);
    }
  }

  Future<void> _saveContactIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kContactIdsKey, _contacts.map((c) => c.id).toList());
  }

  static const _kSplitsKey = 'saved_splits_v2';

  Future<void> _loadSavedSplits() async {
    final prefs = await SharedPreferences.getInstance();
    final splitsJsonList = prefs.getStringList(_kSplitsKey) ?? [];
    if (splitsJsonList.isEmpty) return;

    final loaded = <SplitItem>[];
    for (final jsonStr in splitsJsonList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        loaded.add(SplitItem.fromJson(map));
      } catch (e) {
        debugPrint("Error parsing split: $e");
      }
    }
    
    // Sort splits by date descending (newest first)
    loaded.sort((a, b) => b.date.compareTo(a.date));

    if (loaded.isNotEmpty && mounted) {
      setState(() => _splits.addAll(loaded));
    }
  }

  Future<void> _saveSplits() async {
    final prefs = await SharedPreferences.getInstance();
    final splitsJsonList = _splits.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_kSplitsKey, splitsJsonList);
  }

  void _removeContact(Contact contact) {
    setState(() => _contacts.removeWhere((c) => c.id == contact.id));
    _saveContactIds();
  }

  Future<void> _pickContact() async {
    if (await Permission.contacts.request().isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final fullContact = await FlutterContacts.getContact(contact.id);
        if (fullContact != null) {
          setState(() {
            if (!_contacts.any((c) => c.id == fullContact.id)) {
              _contacts.add(fullContact);
            }
          });
          _saveContactIds(); // persist immediately
        }
      }
    }
  }

  void _addSplit(SplitItem split) {
    setState(() {
      _splits.insert(0, split); // Add new splits to the top
    });
    _saveSplits();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onToggleFeature(bool isLoanApproval, bool value) {
    setState(() {
      if (isLoanApproval) {
        // Prevent disabling both
        if (!value && !_isSplitwiseEnabled) return;
        _isLoanApprovalEnabled = value;
      } else {
        // Prevent disabling both
        if (!value && !_isLoanApprovalEnabled) return;
        _isSplitwiseEnabled = value;
      }
      
      // If the current tab became disabled, go home
      _selectedIndex = 0;
    });
    // Return to home page to avoid breaking the index state
    _pageController.jumpToPage(0);
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, // Light icons for dark bg
        leadingWidth: 80, // Allow more width for the leading widget with padding
        leading: Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: _selectedIndex == 2 && _selectedFriendName != null 
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFriendName = null;
                  });
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
              )
            : Stack(
                clipBehavior: Clip.none, // Allow badge to overflow if needed, though positioned inside here
                alignment: Alignment.center,
                children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Glassy background
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black, // Dark icon as per reference
                  size: 30,
                ),
              ),
              // Red Dot Badge
              Positioned(
                top: 12,
                right: 14, // Adjusted for centering within the larger container
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 550), // Slower, premium transition
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
            _getAppTitle(),
            key: ValueKey<int>(_selectedIndex),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22, // Slightly larger
              fontWeight: FontWeight.w900, // Matching the balance font weight
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // Profile Icon (Far Right)
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: CircleAvatar(
              radius: 26,
              backgroundImage: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] != null
                  ? NetworkImage(Supabase.instance.client.auth.currentUser!.userMetadata!['avatar_url'])
                  : const NetworkImage('https://i.pravatar.cc/300?img=12'), // Fallback if no avatar
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Base Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                colors: [
                  Color(0xFFE0EEFF), // Top: Whitish Blue
                  Color(0xFF0066FF), // Vibrant Blue
                  Color(0xFF001040), // Navy Blue
                  Color(0xFF7C4DFF), // Purple
                  Color(0xFFE0EEFF), // Bottom: Whitish Blue
                ],
                tileMode: TileMode.clamp,
              ),
            ),
          ),
          
          // Navy Circle Element
          OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: const Alignment(0.0, -0.5), // Position here directly
            child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 2.0, // 2x width
                  height: MediaQuery.of(context).size.width * 2.0, 
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFF000A12),
                        Colors.transparent,
                      ],
                      stops: [0.3, 1.0], // Adjusted stops for better gradient distribution at large scale
                    ),
                  ),
                ),
              ),
            ),
          
          // Vignette Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5, // Extend beyond corners
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3), // Subtle darkening
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),

          // Page View to slide content
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _buildPages(),
          ),

          // Custom Bottom Navigation Bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CustomBottomNavBar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemTapped,
                showLoanApproval: _isLoanApprovalEnabled,
                showSplitwise: _isSplitwiseEnabled,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppTitle() {
    List<String> titles = ["Home"];
    if (_isLoanApprovalEnabled) titles.add("Loan Approval");
    if (_isSplitwiseEnabled) titles.add("Splitwise");
    titles.add("Setting");
    
    if (_selectedIndex >= 0 && _selectedIndex < titles.length) {
      return titles[_selectedIndex];
    }
    return "Home";
  }

  List<Widget> _buildPages() {
    List<Widget> pages = [];
    
    // Always add Home
    pages.add(HomeTab(
      contacts: _contacts,
      splits: _splits,
      onAddContact: _pickContact,
    ));

    if (_isLoanApprovalEnabled) {
      pages.add(const LoanApprovalTab());
    }

    if (_isSplitwiseEnabled) {
      pages.add(SplitwiseTab(
        contacts: _contacts,
        splits: _splits,
        onAddSplit: _addSplit,
        onRemoveContact: _removeContact,
        selectedFriendName: _selectedFriendName,
        onFriendSelected: (name, balance) {
          setState(() {
            _selectedFriendName = name;
          });
        },
      ));
    }

    // Always add Settings
    pages.add(SettingTab(
      isLoanApprovalEnabled: _isLoanApprovalEnabled,
      isSplitwiseEnabled: _isSplitwiseEnabled,
      onToggleFeature: _onToggleFeature,
      contacts: _contacts,
      onRemoveContact: _removeContact,
    ));

    return pages;
  }
}
