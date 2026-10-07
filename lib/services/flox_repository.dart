import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/friend.dart';
import '../models/ledger.dart';
import '../models/money.dart';
import '../models/split.dart';
import 'supabase_service.dart';

/// A failure with a message that is safe to show to the user.
class FloxException implements Exception {
  const FloxException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Single source of truth for the signed-in user's friends and splits.
///
/// Supabase is authoritative. An encrypted per-user cache (Keystore/Keychain
/// via flutter_secure_storage) makes the app open instantly and readable
/// offline. The cache is deleted on sign-out.
class FloxRepository extends ChangeNotifier {
  FloxRepository({
    required this.userId,
    required SupabaseService remote,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  })  : _remote = remote,
        _storage = storage;

  final String userId;
  final SupabaseService _remote;
  final FlutterSecureStorage _storage;

  List<Friend> _friends = [];
  List<SplitItem> _splits = [];
  Map<String, int> _balances = {};
  bool _loading = true;
  String? _syncError;

  // Pre-Supabase versions stored data unencrypted and not per user.
  static const _legacySplitsKey = 'saved_splits_v2';
  static const _legacyFriendIdsKey = 'saved_friend_ids';

  static String _cacheKey(String userId) => 'flox_cache_v1_$userId';

  /// All friends, including archived ones (needed to show old history).
  List<Friend> get allFriends => List.unmodifiable(_friends);

  /// Friends shown in pickers and lists.
  List<Friend> get friends => _friends.where((f) => !f.archived).toList();

  /// Newest first.
  List<SplitItem> get splits => List.unmodifiable(_splits);

  /// Net balance per friend id; positive = they owe you.
  Map<String, int> get balances => _balances;

  bool get loading => _loading;

  /// Set when the last sync with Supabase failed; cached data is still shown.
  String? get syncError => _syncError;

  Friend? friendById(String? id) {
    if (id == null) return null;
    for (final f in _friends) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Display name for a debt party: null id = "You".
  String nameOf(String? friendId) =>
      friendId == null ? 'You' : (friendById(friendId)?.name ?? 'Removed friend');

  // ─── Loading ──────────────────────────────────────────────────────────────

  Future<void> load() async {
    await _readCache();
    await refresh();
  }

  Future<void> refresh() async {
    try {
      await _migrateLegacyData();
      final results = await Future.wait([_remote.fetchFriends(), _remote.fetchSplits()]);
      _friends = results[0] as List<Friend>;
      _splits = results[1] as List<SplitItem>;
      _syncError = null;
      await _writeCache();
    } catch (e, st) {
      debugPrint('Flox sync failed: $e\n$st');
      _syncError = "Couldn't reach the server. Showing saved data.";
    } finally {
      _loading = false;
      _recompute();
    }
  }

  // ─── Friends ──────────────────────────────────────────────────────────────

  /// Adds a friend, reusing an existing one with the same phone number.
  Future<Friend> addFriend({required String name, String? phone}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FloxException('This contact has no name.');
    final cleanPhone = _normalizePhone(phone);

    if (cleanPhone != null) {
      for (final f in _friends) {
        if (_normalizePhone(f.phone) == cleanPhone) {
          if (f.archived) await _setArchived(f, false);
          return friendById(f.id)!;
        }
      }
    }

    final friend = await _guard(() => _remote.addFriend(name: cleanName, phone: cleanPhone));
    _friends = [..._friends, friend];
    await _writeCache();
    _recompute();
    return friend;
  }

  /// Hides a friend from lists. Their past splits and balance are kept.
  Future<void> removeFriend(Friend friend) => _setArchived(friend, true);

  Future<void> _setArchived(Friend friend, bool archived) async {
    await _guard(() => _remote.setFriendArchived(friend.id, archived));
    _friends = [
      for (final f in _friends) f.id == friend.id ? f.copyWith(archived: archived) : f,
    ];
    await _writeCache();
    _recompute();
  }

  // ─── Splits ───────────────────────────────────────────────────────────────

  Future<SplitItem> addSplit({
    required String title,
    required int totalPaise,
    required String? payerId,
    required List<DebtEntry> entries,
  }) async {
    final date = DateTime.now();
    final id = await _guard(() => _remote.createSplit(
          title: title,
          totalPaise: totalPaise,
          payerId: payerId,
          date: date,
          entries: entries,
        ));
    final split = SplitItem(
      id: id,
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      date: date,
      entries: entries,
    );
    _splits = [split, ..._splits];
    await _writeCache();
    _recompute();
    return split;
  }

  /// Records a repayment with [friendId]. The amount is capped at what is owed.
  Future<void> settleUp(String friendId, int paise) async {
    final balance = _balances[friendId] ?? 0;
    final entries = Ledger.settlement(friendId: friendId, balance: balance, paise: paise);
    if (entries.isEmpty) return;
    await addSplit(
      title: 'Settlement with ${nameOf(friendId)}',
      totalPaise: entries.first.amountPaise,
      // The person who owed is the one paying.
      payerId: balance > 0 ? friendId : null,
      entries: entries,
    );
  }

  // ─── Sign-out ─────────────────────────────────────────────────────────────

  /// Removes everything this app stored on the device for [userId].
  static Future<void> clearLocalData(
    String userId, {
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) async {
    await storage.delete(key: _cacheKey(userId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacySplitsKey);
    await prefs.remove(_legacyFriendIdsKey);
  }

  // ─── Internals ────────────────────────────────────────────────────────────

  void _recompute() {
    _balances = Ledger.netBalances(_splits);
    notifyListeners();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e, st) {
      // The server answered, so this is not a connection problem.
      debugPrint('Flox request failed: $e\n$st');
      throw const FloxException("Couldn't save: the server rejected it. Please try again later.");
    } catch (e, st) {
      debugPrint('Flox request failed: $e\n$st');
      throw const FloxException("Couldn't save. Check your connection and try again.");
    }
  }

  Future<void> _readCache() async {
    try {
      final raw = await _storage.read(key: _cacheKey(userId));
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _friends = (json['friends'] as List).map((e) => Friend.fromJson(e as Map<String, dynamic>)).toList();
      _splits = (json['splits'] as List).map((e) => SplitItem.fromJson(e as Map<String, dynamic>)).toList();
      _recompute();
    } catch (e) {
      debugPrint('Ignoring unreadable cache: $e');
    }
  }

  Future<void> _writeCache() async {
    try {
      await _storage.write(
        key: _cacheKey(userId),
        value: jsonEncode({
          'friends': _friends.map((f) => f.toJson()).toList(),
          'splits': _splits.map((s) => s.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('Could not write cache: $e');
    }
  }

  static String? _normalizePhone(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    // Compare on the last 10 digits so "+91 98…" matches "098…".
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Uploads data saved by older app versions (names, rupee doubles) once,
  /// then deletes it. Each split is removed from the legacy list right after
  /// it is uploaded, so an interrupted migration resumes without duplicates.
  Future<void> _migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    final legacySplits = prefs.getStringList(_legacySplitsKey) ?? const [];
    final legacyContactIds = prefs.getStringList(_legacyFriendIdsKey) ?? const [];
    if (legacySplits.isEmpty && legacyContactIds.isEmpty) return;

    final existing = await _remote.fetchFriends();
    final byName = {for (final f in existing) f.name: f};

    Future<String> friendIdFor(String name, {String? phone}) async {
      final known = byName[name];
      if (known != null) return known.id;
      final created = await _remote.addFriend(name: name, phone: _normalizePhone(phone));
      byName[name] = created;
      return created.id;
    }

    // Friends picked from contacts; only readable if permission was already given.
    if (legacyContactIds.isNotEmpty) {
      if (await Permission.contacts.status.isGranted) {
        for (final id in legacyContactIds) {
          try {
            final c = await FlutterContacts.getContact(id);
            if (c != null && c.displayName.trim().isNotEmpty) {
              await friendIdFor(c.displayName.trim(),
                  phone: c.phones.isNotEmpty ? c.phones.first.number : null);
            }
          } catch (e) {
            debugPrint('Skipping legacy contact $id: $e');
          }
        }
      }
      await prefs.remove(_legacyFriendIdsKey);
    }

    final remaining = [...legacySplits];
    for (final raw in legacySplits) {
      final legacy = _LegacySplit.tryParse(raw);
      if (legacy == null) {
        debugPrint('Dropping unreadable legacy split');
      } else {
        // Network errors propagate and leave the rest for the next launch.
        final entries = <DebtEntry>[
          for (final d in legacy.debts)
            DebtEntry(
              debtorId: d.debtor == null ? null : await friendIdFor(d.debtor!),
              creditorId: d.creditor == null ? null : await friendIdFor(d.creditor!),
              amountPaise: d.paise,
            ),
        ];
        await _remote.createSplit(
          title: legacy.title,
          totalPaise: legacy.totalPaise,
          payerId: legacy.payer == null ? null : await friendIdFor(legacy.payer!),
          date: legacy.date,
          entries: entries,
        );
      }
      remaining.remove(raw);
      await prefs.setStringList(_legacySplitsKey, remaining);
    }
    await prefs.remove(_legacySplitsKey);
  }
}

/// A split as stored by app versions before the Supabase migration.
class _LegacySplit {
  _LegacySplit(this.title, this.totalPaise, this.payer, this.date, this.debts);

  final String title;
  final int totalPaise;
  final String? payer; // null = You
  final DateTime date;
  final List<({String? debtor, String? creditor, int paise})> debts;

  static _LegacySplit? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final debts = <({String? debtor, String? creditor, int paise})>[];
      for (final e in (json['debt_entries'] as List<dynamic>? ?? const [])) {
        final m = e as Map<String, dynamic>;
        final debtor = m['debtor_name'] as String?;
        final creditor = m['creditor_name'] as String?;
        final paise = Money.fromRupees(m['amount'] as num);
        if (paise <= 0 || debtor == creditor) continue;
        debts.add((debtor: debtor, creditor: creditor, paise: paise));
      }
      final title = (json['title'] as String? ?? '').trim();
      final payer = json['payer_name'] as String? ?? 'You';
      return _LegacySplit(
        title.isEmpty ? 'Expense' : title,
        Money.fromRupees(json['total_amount'] as num? ?? 0),
        payer == 'You' ? null : payer,
        DateTime.tryParse((json['created_at'] ?? json['date'] ?? '') as String) ?? DateTime.now(),
        debts,
      );
    } catch (_) {
      return null;
    }
  }
}
