/// A single debt relationship created by a split: [debtorId] owes [creditorId].
/// A null id means "You" (the signed-in user).
class DebtEntry {
  final String? debtorId;
  final String? creditorId;
  final int amountPaise;

  const DebtEntry({
    required this.debtorId,
    required this.creditorId,
    required this.amountPaise,
  });

  /// True when "You" are the creditor (money comes to you).
  bool get youAreOwed => creditorId == null;

  /// True when "You" are the debtor (money leaves you).
  bool get youOwe => debtorId == null;

  bool involves(String friendId) => debtorId == friendId || creditorId == friendId;

  Map<String, dynamic> toJson() => {
        'debtor_friend_id': debtorId,
        'creditor_friend_id': creditorId,
        'amount_paise': amountPaise,
      };

  factory DebtEntry.fromJson(Map<String, dynamic> json) => DebtEntry(
        debtorId: json['debtor_friend_id'] as String?,
        creditorId: json['creditor_friend_id'] as String?,
        amountPaise: (json['amount_paise'] as num).toInt(),
      );
}

/// One expense or settlement.
class SplitItem {
  final String id;
  final String title;
  final int totalPaise;

  /// Friend who paid; null = "You".
  final String? payerId;
  final DateTime date;
  final List<DebtEntry> entries;

  const SplitItem({
    required this.id,
    required this.title,
    required this.totalPaise,
    required this.payerId,
    required this.date,
    required this.entries,
  });

  /// Amount friends owe you in this split.
  int get owedToYouPaise =>
      entries.where((e) => e.youAreOwed).fold(0, (s, e) => s + e.amountPaise);

  /// Amount you owe friends in this split.
  int get youOwePaise =>
      entries.where((e) => e.youOwe).fold(0, (s, e) => s + e.amountPaise);

  /// Net effect on you with one friend: positive = they owe you.
  int netWith(String friendId) {
    var net = 0;
    for (final e in entries) {
      if (e.youOwe && e.creditorId == friendId) net -= e.amountPaise;
      if (e.youAreOwed && e.debtorId == friendId) net += e.amountPaise;
    }
    return net;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'total_paise': totalPaise,
        'payer_friend_id': payerId,
        'created_at': date.toUtc().toIso8601String(),
        'split_debts': entries.map((e) => e.toJson()).toList(),
      };

  factory SplitItem.fromJson(Map<String, dynamic> json) => SplitItem(
        id: json['id'] as String,
        title: json['title'] as String,
        totalPaise: (json['total_paise'] as num).toInt(),
        payerId: json['payer_friend_id'] as String?,
        date: DateTime.parse(json['created_at'] as String).toLocal(),
        entries: (json['split_debts'] as List<dynamic>? ?? const [])
            .map((e) => DebtEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
