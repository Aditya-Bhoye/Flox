import 'package:intl/intl.dart';

/// Money is stored as whole paise (1 ₹ = 100 paise) so sums never drift.
class Money {
  Money._();

  static final _whole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _exact = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// "₹1,250" when there are no paise, otherwise "₹1,250.50".
  static String format(int paise) {
    final rupees = paise / 100;
    return paise % 100 == 0 ? _whole.format(rupees) : _exact.format(rupees);
  }

  /// Parses user input such as "12", "12.5" or "12.50" into paise.
  /// Returns null for invalid input or more than two decimals.
  static int? parse(String input) {
    final text = input.trim();
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{0,2}))?$').firstMatch(text);
    if (match == null) return null;
    final rupees = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return rupees * 100 + int.parse(fraction);
  }

  /// Plain editable text for an amount: "1250" or "1250.50".
  static String toInput(int paise) {
    final rupees = paise ~/ 100;
    final rest = paise % 100;
    return rest == 0 ? '$rupees' : '$rupees.${rest.toString().padLeft(2, '0')}';
  }

  /// Converts a legacy rupee double into paise.
  static int fromRupees(num rupees) => (rupees * 100).round();

  /// Splits [totalPaise] into [parts] shares that add up exactly to the total.
  /// The first `total % parts` shares get one extra paisa.
  static List<int> splitEvenly(int totalPaise, int parts) {
    if (parts <= 0) return const [];
    final base = totalPaise ~/ parts;
    final remainder = totalPaise % parts;
    return List.generate(parts, (i) => base + (i < remainder ? 1 : 0));
  }
}
