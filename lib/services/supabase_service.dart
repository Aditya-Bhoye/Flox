import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend.dart';
import '../models/split.dart';

/// Thin wrapper over the Supabase tables defined in `supabase/schema.sql`.
/// Row Level Security restricts every query to the signed-in user's rows.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  Future<List<Friend>> fetchFriends() async {
    final rows = await _client.from('friends').select().order('created_at');
    return rows.map<Friend>(Friend.fromJson).toList();
  }

  Future<Friend> addFriend({required String name, String? phone}) async {
    final row = await _client
        .from('friends')
        .insert({'name': name, 'phone': phone})
        .select()
        .single();
    return Friend.fromJson(row);
  }

  Future<void> setFriendArchived(String friendId, bool archived) async {
    await _client.from('friends').update({'archived': archived}).eq('id', friendId);
  }

  Future<List<SplitItem>> fetchSplits() async {
    final rows = await _client
        .from('split_items')
        .select('*, split_debts(*)')
        .order('created_at', ascending: false);
    return rows.map<SplitItem>(SplitItem.fromJson).toList();
  }

  /// Inserts a split and its debts in one transaction (see `create_split`).
  Future<String> createSplit({
    required String title,
    required int totalPaise,
    required String? payerId,
    required DateTime date,
    required List<DebtEntry> entries,
  }) async {
    final id = await _client.rpc('create_split', params: {
      'p_title': title,
      'p_total_paise': totalPaise,
      'p_payer_friend_id': payerId,
      'p_created_at': date.toUtc().toIso8601String(),
      'p_debts': entries.map((e) => e.toJson()).toList(),
    });
    return id as String;
  }
}
