import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/split.dart';
import '../models/loan_application.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // --- Splits & Debt Entries ---

  /// Fetch all splits for the current user, including their debt entries
  static Future<List<SplitItem>> fetchSplits() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('splits')
        .select('*, debt_entries(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return response.map<SplitItem>((json) => SplitItem.fromJson(json)).toList();
  }

  /// Insert a new Split and its DebtEntries
  static Future<SplitItem> addSplit(SplitItem split) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    // Insert split
    final splitResponse = await _supabase.from('splits').insert({
      'user_id': userId,
      'title': split.title,
      'total_amount': split.totalAmount,
      'payer_name': split.payerName,
    }).select().single();

    final splitId = splitResponse['id'];

    // Insert debt entries
    if (split.entries.isNotEmpty) {
      final debtEntriesData = split.entries.map((e) => {
        'split_id': splitId,
        'debtor_name': e.debtorName,
        'creditor_name': e.creditorName,
        'amount': e.amount,
      }).toList();

      final entriesResponse = await _supabase.from('debt_entries').insert(debtEntriesData).select();
      splitResponse['debt_entries'] = entriesResponse;
    } else {
      splitResponse['debt_entries'] = [];
    }

    return SplitItem.fromJson(splitResponse);
  }

  // --- Loan Applications ---

  static Future<List<LoanApplication>> fetchLoanApplications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('loan_applications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return response.map<LoanApplication>((json) => LoanApplication.fromJson(json)).toList();
  }

  static Future<LoanApplication> submitLoanApplication(LoanApplication app) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    final response = await _supabase.from('loan_applications').insert({
      'user_id': userId,
      'cibil_score': app.cibilScore,
      'loan_term': app.loanTerm,
      'loan_amount': app.loanAmount,
      'income_annum': app.incomeAnnum,
      'bank_asset_value': app.bankAssetValue,
      'residential_assets_value': app.residentialAssetsValue,
    }).select().single();

    return LoanApplication.fromJson(response);
  }
}
