class LoanApplication {
  final String? id;
  final String? userId;
  final int cibilScore;
  final int loanTerm;
  final int loanAmount;
  final int incomeAnnum;
  final int bankAssetValue;
  final int residentialAssetsValue;
  final DateTime? createdAt;

  LoanApplication({
    this.id,
    this.userId,
    required this.cibilScore,
    required this.loanTerm,
    required this.loanAmount,
    required this.incomeAnnum,
    required this.bankAssetValue,
    required this.residentialAssetsValue,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'cibil_score': cibilScore,
      'loan_term': loanTerm,
      'loan_amount': loanAmount,
      'income_annum': incomeAnnum,
      'bank_asset_value': bankAssetValue,
      'residential_assets_value': residentialAssetsValue,
    };
  }

  factory LoanApplication.fromJson(Map<String, dynamic> json) {
    return LoanApplication(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      cibilScore: json['cibil_score'] as int,
      loanTerm: json['loan_term'] as int,
      loanAmount: (json['loan_amount'] as num).toInt(),
      incomeAnnum: (json['income_annum'] as num).toInt(),
      bankAssetValue: (json['bank_asset_value'] as num).toInt(),
      residentialAssetsValue: (json['residential_assets_value'] as num).toInt(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
