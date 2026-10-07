import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/ledger.dart';
import 'package:mobile_app/models/split.dart';

SplitItem split(List<DebtEntry> entries, {String? payerId}) => SplitItem(
      id: 'id',
      title: 't',
      totalPaise: entries.fold(0, (s, e) => s + e.amountPaise),
      payerId: payerId,
      date: DateTime(2026),
      entries: entries,
    );

int sum(List<DebtEntry> entries) => entries.fold(0, (s, e) => s + e.amountPaise);

void main() {
  group('equalSplit', () {
    test('you paid and are included: each friend owes you a share', () {
      final entries = Ledger.equalSplit(
        totalPaise: 30000,
        friendIds: ['a', 'b'],
        includeMe: true,
        payerId: null,
      );
      expect(entries.map((e) => (e.debtorId, e.creditorId, e.amountPaise)), [
        ('a', null, 10000),
        ('b', null, 10000),
      ]);
    });

    test('you paid for friends only: the whole amount is owed to you', () {
      final entries = Ledger.equalSplit(
        totalPaise: 10001,
        friendIds: ['a', 'b'],
        includeMe: false,
        payerId: null,
      );
      expect(sum(entries), 10001);
      expect(entries.every((e) => e.creditorId == null), isTrue);
    });

    test('a friend paid: you and the others owe that friend', () {
      final entries = Ledger.equalSplit(
        totalPaise: 30000,
        friendIds: ['a', 'b'],
        includeMe: true,
        payerId: 'a',
      );
      expect(entries.map((e) => (e.debtorId, e.creditorId)), [(null, 'a'), ('b', 'a')]);
      final balances = Ledger.netBalances([split(entries, payerId: 'a')]);
      // Only your own debt affects your balances.
      expect(balances, {'a': -10000});
    });

    test('uneven totals never lose a paisa', () {
      final entries = Ledger.equalSplit(
        totalPaise: 10000,
        friendIds: ['a', 'b'],
        includeMe: true,
        payerId: null,
      );
      // You keep the 34-paise share; friends owe 33.33 each.
      expect(entries.map((e) => e.amountPaise), [3333, 3333]);
    });
  });

  group('netBalances', () {
    test('friends with the same name stay separate because ids differ', () {
      final balances = Ledger.netBalances([
        split([const DebtEntry(debtorId: 'rahul-1', creditorId: null, amountPaise: 500)]),
        split([const DebtEntry(debtorId: null, creditorId: 'rahul-2', amountPaise: 200)]),
      ]);
      expect(balances, {'rahul-1': 500, 'rahul-2': -200});
      expect(Ledger.totalOwedToYou(balances), 500);
      expect(Ledger.totalYouOwe(balances), 200);
    });

    test('ignores debts between two friends', () {
      final balances = Ledger.netBalances([
        split([const DebtEntry(debtorId: 'a', creditorId: 'b', amountPaise: 500)]),
      ]);
      expect(balances, isEmpty);
    });
  });

  group('settlement', () {
    test('clears a debt a friend owes you', () {
      final entries = Ledger.settlement(friendId: 'a', balance: 5000, paise: 5000);
      final after = Ledger.netBalances([
        split([const DebtEntry(debtorId: 'a', creditorId: null, amountPaise: 5000)]),
        split(entries),
      ]);
      expect(after['a'], 0);
    });

    test('clears a debt you owe a friend', () {
      final entries = Ledger.settlement(friendId: 'a', balance: -5000, paise: 2000);
      expect(entries.single.debtorId, 'a');
      expect(entries.single.creditorId, isNull);
      expect(entries.single.amountPaise, 2000);
    });

    test('overpaying is capped so the balance never flips', () {
      final entries = Ledger.settlement(friendId: 'a', balance: 5000, paise: 9000);
      expect(entries.single.amountPaise, 5000);
    });

    test('nothing to settle yields no entries', () {
      expect(Ledger.settlement(friendId: 'a', balance: 0, paise: 100), isEmpty);
      expect(Ledger.settlement(friendId: 'a', balance: 100, paise: 0), isEmpty);
    });
  });

  group('splitByShares', () {
    test('you paid: everyone else owes you their share, your share is skipped', () {
      final entries = Ledger.splitByShares(
        shares: {null: 5000, 'a': 3000, 'b': 0},
        payerId: null,
      );
      expect(entries.map((e) => (e.debtorId, e.creditorId, e.amountPaise)), [('a', null, 3000)]);
    });

    test('a friend paid: you and the others owe that friend', () {
      final entries = Ledger.splitByShares(
        shares: {null: 4000, 'a': 1000, 'b': 2000},
        payerId: 'a',
      );
      expect(entries.map((e) => (e.debtorId, e.creditorId, e.amountPaise)), [
        (null, 'a', 4000),
        ('b', 'a', 2000),
      ]);
    });
  });

  test('SplitItem JSON round-trip', () {
    final original = SplitItem(
      id: 's1',
      title: 'Dinner',
      totalPaise: 12345,
      payerId: 'a',
      date: DateTime.utc(2026, 9, 26, 12),
      entries: const [DebtEntry(debtorId: null, creditorId: 'a', amountPaise: 6173)],
    );
    final copy = SplitItem.fromJson(original.toJson());
    expect(copy.id, 's1');
    expect(copy.totalPaise, 12345);
    expect(copy.payerId, 'a');
    expect(copy.date.toUtc(), original.date);
    expect(copy.entries.single.amountPaise, 6173);
    expect(copy.netWith('a'), -6173);
  });
}
