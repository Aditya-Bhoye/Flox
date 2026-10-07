import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/money.dart';

void main() {
  group('Money.parse', () {
    test('parses whole rupees and paise', () {
      expect(Money.parse('12'), 1200);
      expect(Money.parse('12.5'), 1250);
      expect(Money.parse('12.05'), 1205);
      expect(Money.parse('12.'), 1200);
      expect(Money.parse(' 0.99 '), 99);
    });

    test('rejects invalid input', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('1.234'), isNull);
      expect(Money.parse('-5'), isNull);
      expect(Money.parse('1234567890'), isNull);
    });
  });

  test('toInput round-trips through parse', () {
    for (final paise in [0, 5, 100, 1250, 99999]) {
      expect(Money.parse(Money.toInput(paise)), paise);
    }
  });

  test('format drops .00 but keeps real paise', () {
    expect(Money.format(125000), '₹1,250');
    expect(Money.format(125050), '₹1,250.50');
  });

  group('Money.splitEvenly', () {
    test('shares always add up to the total', () {
      for (final total in [0, 1, 100, 10000, 10001, 99999]) {
        for (var parts = 1; parts <= 7; parts++) {
          final shares = Money.splitEvenly(total, parts);
          expect(shares.length, parts);
          expect(shares.reduce((a, b) => a + b), total);
          expect(shares.reduce((a, b) => a > b ? a : b) - shares.reduce((a, b) => a < b ? a : b),
              lessThanOrEqualTo(1));
        }
      }
    });

    test('₹100 three ways is 33.34 + 33.33 + 33.33', () {
      expect(Money.splitEvenly(10000, 3), [3334, 3333, 3333]);
    });

    test('zero parts gives no shares', () {
      expect(Money.splitEvenly(100, 0), isEmpty);
    });
  });
}
