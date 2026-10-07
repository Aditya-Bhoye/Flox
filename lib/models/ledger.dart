import 'money.dart';
import 'split.dart';

/// Pure balance calculations. Kept free of Flutter so they are easy to test.
class Ledger {
  Ledger._();

  /// Net balance per friend id. Positive = they owe you, negative = you owe them.
  static Map<String, int> netBalances(Iterable<SplitItem> splits) {
    final balances = <String, int>{};
    for (final split in splits) {
      for (final e in split.entries) {
        if (e.youOwe && e.creditorId != null) {
          balances.update(e.creditorId!, (v) => v - e.amountPaise, ifAbsent: () => -e.amountPaise);
        } else if (e.youAreOwed && e.debtorId != null) {
          balances.update(e.debtorId!, (v) => v + e.amountPaise, ifAbsent: () => e.amountPaise);
        }
      }
    }
    return balances;
  }

  /// Sum of what friends owe you.
  static int totalOwedToYou(Map<String, int> balances) =>
      balances.values.where((v) => v > 0).fold(0, (s, v) => s + v);

  /// Sum of what you owe friends.
  static int totalYouOwe(Map<String, int> balances) =>
      balances.values.where((v) => v < 0).fold(0, (s, v) => s - v);

  /// Debt entries that cancel [paise] of [balance] with one friend.
  /// [paise] is capped at the outstanding amount so a settlement never flips
  /// who owes whom. Returns an empty list when there is nothing to settle.
  static List<DebtEntry> settlement({
    required String friendId,
    required int balance,
    required int paise,
  }) {
    final amount = paise.clamp(0, balance.abs());
    if (amount == 0) return const [];
    return [
      balance > 0
          // They owe you: record that you "owe" them the amount they paid back.
          ? DebtEntry(debtorId: null, creditorId: friendId, amountPaise: amount)
          // You owe them: record that they "owe" you the amount you paid back.
          : DebtEntry(debtorId: friendId, creditorId: null, amountPaise: amount),
    ];
  }

  /// Debts where each participant owes [payerId] their share.
  /// Keys of [shares] are friend ids; null = you. Zero shares are skipped.
  static List<DebtEntry> splitByShares({
    required Map<String?, int> shares,
    required String? payerId,
  }) {
    return [
      for (final MapEntry(key: who, value: paise) in shares.entries)
        if (who != payerId && paise > 0)
          DebtEntry(debtorId: who, creditorId: payerId, amountPaise: paise),
    ];
  }

  /// Debts for an equal split of [totalPaise] across [friendIds], optionally
  /// including you. [payerId] is who paid: null = you.
  static List<DebtEntry> equalSplit({
    required int totalPaise,
    required List<String> friendIds,
    required bool includeMe,
    required String? payerId,
  }) {
    final participants = <String?>[if (includeMe) null, ...friendIds];
    final shares = Money.splitEvenly(totalPaise, participants.length);
    final entries = <DebtEntry>[];
    for (var i = 0; i < participants.length; i++) {
      final who = participants[i];
      if (who == payerId || shares[i] == 0) continue;
      entries.add(DebtEntry(debtorId: who, creditorId: payerId, amountPaise: shares[i]));
    }
    return entries;
  }
}
