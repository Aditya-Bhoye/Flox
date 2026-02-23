/// A single debt relationship created by a split.
class DebtEntry {
  final String? id;
  
  /// Person who owes (null = "You")
  final String? debtorName;

  /// Person who is owed (null = "You")
  final String? creditorName;

  final double amount;

  const DebtEntry({
    this.id,
    required this.debtorName,
    required this.creditorName,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'debtor_name': debtorName,
    'creditor_name': creditorName,
    'amount': amount,
  };

  factory DebtEntry.fromJson(Map<String, dynamic> json) => DebtEntry(
    id: json['id'] as String?,
    debtorName: json['debtor_name'] as String?,
    creditorName: json['creditor_name'] as String?,
    amount: (json['amount'] as num).toDouble(),
  );

  /// Human‑readable label, e.g. "Ravi owes You" or "You owe Ravi"
  String get label {
    final debtor = debtorName ?? 'You';
    final creditor = creditorName ?? 'You';
    return '$debtor owes $creditor';
  }

  /// True when "You" are the creditor (money comes to you)
  bool get youAreOwed => creditorName == null;

  /// True when "You" are the debtor (money leaves you)
  bool get youOwe => debtorName == null;
}

/// The top‑level record for one expense entry.
class SplitItem {
  final String? id;
  final String? userId;
  final String title;
  final double totalAmount;
  final String payerName;
  final DateTime date;

  /// Flat list of who owes whom
  final List<DebtEntry> entries;

  SplitItem({
    this.id,
    this.userId,
    required this.title,
    required this.totalAmount,
    required this.payerName,
    required this.date,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (userId != null) 'user_id': userId,
    'title': title,
    'total_amount': totalAmount,
    'payer_name': payerName,
    'created_at': date.toIso8601String(),
    // Supabase can accept nested inserts if the relationship is configured correctly.
    'debt_entries': entries.map((e) => e.toJson()).toList(),
  };

  factory SplitItem.fromJson(Map<String, dynamic> json) => SplitItem(
    id: json['id'] as String?,
    userId: json['user_id'] as String?,
    title: json['title'] as String,
    totalAmount: (json['total_amount'] as num).toDouble(),
    payerName: json['payer_name'] as String? ?? 'You', // Gracefully handle old data
    date: DateTime.parse((json['created_at'] ?? json['date']) as String), // Fallback for old local data
    entries: (json['debt_entries'] as List<dynamic>?)
        ?.map((e) => DebtEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [], // Default to empty list if missing
  );

  // ── Convenience aggregates used by the balance card ──

  /// Net amount "You are owed" across all entries
  double get totalOwedToYou =>
      entries.where((e) => e.youAreOwed).fold(0, (s, e) => s + e.amount);

  /// Net amount "You owe" across all entries
  double get totalYouOwe =>
      entries.where((e) => e.youOwe).fold(0, (s, e) => s + e.amount);

  // ── Legacy compat fields (used by old _buildSplitItem) ──
  // Kept so nothing else breaks while we migrate.
  @Deprecated('Use entries instead')
  SplitType get type => totalYouOwe > 0 ? SplitType.owe : SplitType.owed;

  @Deprecated('Use entries instead')
  double get amount => totalYouOwe > 0 ? totalYouOwe : totalOwedToYou;

  @Deprecated('Use entries instead')
  dynamic get otherPerson => null;
}

/// Legacy enum – kept so existing references don't break.
enum SplitType { owe, owed }
