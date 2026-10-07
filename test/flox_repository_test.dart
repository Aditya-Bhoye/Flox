import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/friend.dart';
import 'package:mobile_app/models/split.dart';
import 'package:mobile_app/services/flox_repository.dart';
import 'package:mobile_app/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Supabase.
class FakeRemote implements SupabaseService {
  final friends = <Friend>[];
  final splits = <SplitItem>[];
  bool offline = false;
  int _nextId = 0;

  void _check() {
    if (offline) throw Exception('network down');
  }

  @override
  Future<List<Friend>> fetchFriends() async {
    _check();
    return [...friends];
  }

  @override
  Future<Friend> addFriend({required String name, String? phone}) async {
    _check();
    final f = Friend(id: 'f${_nextId++}', name: name, phone: phone);
    friends.add(f);
    return f;
  }

  @override
  Future<void> setFriendArchived(String friendId, bool archived) async {
    _check();
    final i = friends.indexWhere((f) => f.id == friendId);
    friends[i] = friends[i].copyWith(archived: archived);
  }

  @override
  Future<List<SplitItem>> fetchSplits() async {
    _check();
    return [...splits]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<String> createSplit({
    required String title,
    required int totalPaise,
    required String? payerId,
    required DateTime date,
    required List<DebtEntry> entries,
  }) async {
    _check();
    final id = 's${_nextId++}';
    splits.add(SplitItem(
        id: id, title: title, totalPaise: totalPaise, payerId: payerId, date: date, entries: entries));
    return id;
  }
}

void main() {
  late FakeRemote remote;

  setUp(() {
    remote = FakeRemote();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  FloxRepository repoFor(String userId) => FloxRepository(userId: userId, remote: remote);

  test('friends with the same phone are not duplicated', () async {
    final repo = repoFor('u1');
    await repo.load();
    final a = await repo.addFriend(name: 'Ravi', phone: '+91 98765 43210');
    final b = await repo.addFriend(name: 'Ravi K', phone: '098765-43210');
    expect(b.id, a.id);
    expect(remote.friends, hasLength(1));
  });

  test('two different people with the same name stay separate', () async {
    final repo = repoFor('u1');
    await repo.load();
    final a = await repo.addFriend(name: 'Rahul', phone: '1111111111');
    final b = await repo.addFriend(name: 'Rahul', phone: '2222222222');
    expect(a.id, isNot(b.id));
  });

  test('settling up more than owed is capped', () async {
    final repo = repoFor('u1');
    await repo.load();
    final ravi = await repo.addFriend(name: 'Ravi');
    await repo.addSplit(
      title: 'Lunch',
      totalPaise: 5000,
      payerId: null,
      entries: [DebtEntry(debtorId: ravi.id, creditorId: null, amountPaise: 5000)],
    );
    await repo.settleUp(ravi.id, 999999);
    expect(repo.balances[ravi.id], 0);
  });

  test('removed friends keep their history', () async {
    final repo = repoFor('u1');
    await repo.load();
    final ravi = await repo.addFriend(name: 'Ravi');
    await repo.addSplit(
      title: 'Lunch',
      totalPaise: 5000,
      payerId: null,
      entries: [DebtEntry(debtorId: ravi.id, creditorId: null, amountPaise: 5000)],
    );
    await repo.removeFriend(ravi);
    expect(repo.friends, isEmpty);
    expect(repo.nameOf(ravi.id), 'Ravi');
    expect(repo.balances[ravi.id], 5000);
  });

  test('cached data is shown offline and is per user', () async {
    final repo = repoFor('u1');
    await repo.load();
    await repo.addFriend(name: 'Ravi');

    remote.offline = true;
    final again = repoFor('u1');
    await again.load();
    expect(again.friends.map((f) => f.name), ['Ravi']);
    expect(again.syncError, isNotNull);

    final otherUser = repoFor('u2');
    await otherUser.load();
    expect(otherUser.friends, isEmpty);
  });

  test('sign-out wipes the local cache', () async {
    final repo = repoFor('u1');
    await repo.load();
    await repo.addFriend(name: 'Ravi');
    await FloxRepository.clearLocalData('u1');

    remote.offline = true;
    final again = repoFor('u1');
    await again.load();
    expect(again.friends, isEmpty);
  });

  test('failed saves throw a user-safe message', () async {
    final repo = repoFor('u1');
    await repo.load();
    remote.offline = true;
    expect(
      () => repo.addFriend(name: 'Ravi'),
      throwsA(isA<FloxException>().having((e) => e.message, 'message', isNot(contains('network')))),
    );
  });

  test('legacy local data is uploaded once and then deleted', () async {
    SharedPreferences.setMockInitialValues({
      'saved_splits_v2': [
        jsonEncode({
          'id': '1',
          'title': 'Dinner',
          'total_amount': 300.0,
          'payer_name': 'You',
          'created_at': '2025-01-01T10:00:00.000',
          'debt_entries': [
            {'debtor_name': 'Ravi', 'creditor_name': null, 'amount': 100.0},
            {'debtor_name': 'Asha', 'creditor_name': null, 'amount': 100.0},
          ],
        }),
        'not json',
      ],
    });

    final repo = repoFor('u1');
    await repo.load();

    expect(remote.splits, hasLength(1));
    expect(remote.splits.single.totalPaise, 30000);
    expect(remote.friends.map((f) => f.name), unorderedEquals(['Ravi', 'Asha']));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('saved_splits_v2'), isNull);

    // A second load does not upload again.
    await repoFor('u1').load();
    expect(remote.splits, hasLength(1));
  });

  test('legacy migration resumes after a network failure', () async {
    SharedPreferences.setMockInitialValues({
      'saved_splits_v2': [
        jsonEncode({
          'title': 'Taxi',
          'total_amount': 50,
          'payer_name': 'You',
          'created_at': '2025-01-01T10:00:00.000',
          'debt_entries': [
            {'debtor_name': 'Ravi', 'creditor_name': null, 'amount': 25},
          ],
        }),
      ],
    });
    remote.offline = true;
    await repoFor('u1').load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('saved_splits_v2'), hasLength(1));

    remote.offline = false;
    await repoFor('u1').load();
    expect(remote.splits, hasLength(1));
    expect(prefs.getStringList('saved_splits_v2'), isNull);
  });
}
