import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

void main() {
  group('Money.format', () {
    test('renders whole and fractional amounts to two decimal places', () {
      expect(const Money.fromCents(0).format(), '£0.00');
      expect(const Money.fromCents(5).format(), '£0.05');
      expect(const Money.fromCents(50).format(), '£0.50');
      expect(const Money.fromCents(700).format(), '£7.00');
      expect(const Money.fromCents(1250).format(), '£12.50');
    });

    test('groups thousands', () {
      expect(const Money.fromCents(99999).format(), '£999.99');
      expect(const Money.fromCents(100000).format(), '£1,000.00');
      expect(const Money.fromCents(123456).format(), '£1,234.56');
      expect(const Money.fromCents(123456789).format(), '£1,234,567.89');
    });

    test('carries the sign in front of the symbol', () {
      expect(const Money.fromCents(-1250).format(), '-£12.50');
      expect(const Money.fromCents(-5).format(), '-£0.05');
    });

    test('honours the venue currency rather than the device locale', () {
      expect(const Money.fromCents(1250).format(symbol: '€'), '€12.50');
      expect(const Money.fromCents(1250).format(symbol: r'$'), r'$12.50');
    });
  });

  group('Money.toEditingString', () {
    test('omits symbol and grouping so the caret is not fought', () {
      expect(const Money.fromCents(1250).toEditingString(), '12.50');
      expect(const Money.fromCents(123456).toEditingString(), '1234.56');
      expect(const Money.fromCents(0).toEditingString(), '0.00');
      expect(const Money.fromCents(-750).toEditingString(), '-7.50');
    });
  });

  group('Money.tryParse', () {
    test('accepts the shapes a manager actually types', () {
      expect(Money.tryParse('12.50'), const Money.fromCents(1250));
      expect(Money.tryParse('12'), const Money.fromCents(1200));
      expect(Money.tryParse('12.5'), const Money.fromCents(1250));
      expect(Money.tryParse('.5'), const Money.fromCents(50));
      expect(Money.tryParse('0.05'), const Money.fromCents(5));
      expect(Money.tryParse('  7.20  '), const Money.fromCents(720));
    });

    test('accepts a comma decimal separator', () {
      expect(Money.tryParse('12,50'), const Money.fromCents(1250));
    });

    test('accepts a leading currency mark', () {
      expect(Money.tryParse('£12.50'), const Money.fromCents(1250));
      expect(Money.tryParse('€ 12.50'), const Money.fromCents(1250));
    });

    test('rejects more than two decimals instead of rounding silently', () {
      expect(Money.tryParse('12.999'), isNull);
      expect(Money.tryParse('0.001'), isNull);
    });

    test('accepts a trailing point, as typed on the way to the pence', () {
      expect(Money.tryParse('7.'), const Money.fromCents(700));
      expect(Money.tryParse('12,'), const Money.fromCents(1200));
      expect(Money.tryParse('.'), isNull);
    });

    test('rejects junk', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('12.50.50'), isNull);
      expect(Money.tryParse('1 2.50'), isNull);
      expect(Money.tryParse('12-'), isNull);
      expect(Money.tryParse('.'), isNull);
      expect(Money.tryParse('12£'), isNull);
    });

    test('rejects amounts beyond the ceiling the rules also enforce', () {
      expect(Money.tryParse('1000000.00'), const Money.fromCents(100000000));
      expect(Money.tryParse('1000000.01'), isNull);
      expect(Money.tryParse('99999999999999'), isNull);
    });

    test('accepts a grouped amount, in either convention', () {
      expect(Money.tryParse('1,234.50'), const Money.fromCents(123450));
      expect(Money.tryParse('1.234,50'), const Money.fromCents(123450));
      expect(Money.tryParse('£123,456.78'), const Money.fromCents(12345678));
      expect(Money.tryParse('1,234'), const Money.fromCents(123400));
    });

    test('round-trips a negative, sign before the symbol', () {
      expect(Money.tryParse('-£12.50'), const Money.fromCents(-1250));
      expect(
        Money.tryParse(const Money.fromCents(-1250).format()),
        const Money.fromCents(-1250),
      );
    });

    test('round-trips through the displayed representation', () {
      for (final cents in [0, 5, 99, 720, 123450, 12345678, 100000000]) {
        final money = Money.fromCents(cents);
        expect(
          Money.tryParse(money.format()),
          money,
          reason: 'format() produced ${money.format()}',
        );
        expect(Money.tryParse(money.format(symbol: '€')), money);
      }
    });

    test('rejects an interior space rather than guessing', () {
      expect(Money.tryParse('1 2.50'), isNull);
      expect(Money.tryParse('1 234,50'), isNull);
    });

    test('rejects grouping where grouping does not go', () {
      expect(Money.tryParse('1,2.50'), isNull);
      expect(Money.tryParse('1.23,45'), isNull);
      expect(Money.tryParse('1,,234.5'), isNull);
      expect(Money.tryParse('1234,567.00'), isNull);
      expect(Money.tryParse('1,23,456'), isNull);
      expect(Money.tryParse('1,5,0'), isNull);
      expect(Money.tryParse('1.234.50'), isNull);
      expect(Money.tryParse('0,999'), isNull);
      expect(Money.tryParse('00,500'), isNull);
    });

    test('still accepts grouping that is in the right places', () {
      expect(Money.tryParse('123,456.78'), const Money.fromCents(12345678));
      expect(Money.tryParse('123.456,78'), const Money.fromCents(12345678));
      expect(Money.tryParse('-1,234.50'), const Money.fromCents(-123450));
      expect(Money.tryParse('12,999'), const Money.fromCents(1299900));
    });

    test('round-trips through the editing representation', () {
      for (final cents in [0, 5, 99, 100, 1250, 123456, 100000000]) {
        final money = Money.fromCents(cents);
        expect(Money.tryParse(money.toEditingString()), money);
      }
    });
  });

  group('Money arithmetic', () {
    test('adds, subtracts and multiplies without leaving the integers', () {
      expect(
        const Money.fromCents(720) + const Money.fromCents(680),
        const Money.fromCents(1400),
      );
      expect(
        const Money.fromCents(1400) - const Money.fromCents(680),
        const Money.fromCents(720),
      );
      expect(const Money.fromCents(720) * 3, const Money.fromCents(2160));
      expect(const Money.fromCents(720) * 0, Money.zero);
    });

    test('the classic float failure does not happen here', () {
      final sum = const Money.fromCents(10) + const Money.fromCents(20);
      expect(sum, const Money.fromCents(30));
      expect(sum.format(), '£0.30');
    });

    test('compares and sorts by value', () {
      final amounts = [
        const Money.fromCents(1250),
        const Money.fromCents(320),
        const Money.fromCents(720),
      ]..sort();
      expect(amounts.map((m) => m.cents), [320, 720, 1250]);
      expect(
        const Money.fromCents(320).compareTo(const Money.fromCents(720)),
        isNegative,
      );
      expect(
        const Money.fromCents(720).compareTo(const Money.fromCents(720)),
        isZero,
      );
    });

    test('reports zero and sign', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money.fromCents(1).isZero, isFalse);
      expect(const Money.fromCents(-1).isNegative, isTrue);
      expect(Money.zero.isNegative, isFalse);
    });

    test(
      'value equality, so two amounts of the same size are the same money',
      () {
        expect(const Money.fromCents(1250), const Money.fromCents(1250));
        expect(
          const Money.fromCents(1250).hashCode,
          const Money.fromCents(1250).hashCode,
        );
        expect(
          const Money.fromCents(1250) == const Money.fromCents(1251),
          isFalse,
        );
      },
    );
  });
}
