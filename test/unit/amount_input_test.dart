import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/utils/amount_input.dart';

void main() {
  group('AmountInput.validateAmount', () {
    test('empty string is invalid', () {
      expect(AmountInput.validateAmount(''), 'Enter a valid amount.');
    });

    test('whitespace-only is invalid', () {
      expect(AmountInput.validateAmount('   '), 'Enter a valid amount.');
    });

    test('letters are invalid', () {
      expect(AmountInput.validateAmount('abc'), 'Enter a valid amount.');
    });

    test('scientific notation is invalid', () {
      expect(AmountInput.validateAmount('12e9'), 'Enter a valid amount.');
    });

    test('double minus is invalid', () {
      expect(AmountInput.validateAmount('--5'), 'Enter a valid amount.');
    });

    test('two decimal points is invalid', () {
      expect(AmountInput.validateAmount('1.2.3'), 'Enter a valid amount.');
    });

    test('more than two decimals is invalid', () {
      expect(AmountInput.validateAmount('10.999'), 'Enter a valid amount.');
    });

    test('over the cap reports the specific message', () {
      final msg = AmountInput.validateAmount('1000000000000');
      expect(msg, contains('cannot exceed'));
    });

    test('negative is invalid when negatives are disallowed', () {
      expect(AmountInput.validateAmount('-5'), 'Enter a valid amount.');
    });

    test('negative in range is valid when negatives are allowed', () {
      expect(AmountInput.validateAmount('-5', allowNegative: true), isNull);
    });

    test('zero is blocked by default', () {
      expect(
        AmountInput.validateAmount('0'),
        'Enter an amount greater than zero.',
      );
    });

    test('zero is allowed when allowZero is true', () {
      expect(AmountInput.validateAmount('0', allowZero: true), isNull);
    });

    test('a normal amount is valid', () {
      expect(AmountInput.validateAmount('1299.50'), isNull);
    });

    test('commas are stripped before validation', () {
      expect(AmountInput.validateAmount('1,299.50'), isNull);
    });
  });

  group('AmountInput.parseAmount', () {
    test('parses a valid amount', () {
      expect(AmountInput.parseAmount('1299.50'), 1299.50);
    });

    test('strips commas', () {
      expect(AmountInput.parseAmount('1,299.50'), 1299.50);
    });

    test('returns null for junk', () {
      expect(AmountInput.parseAmount('abc'), isNull);
    });

    test('returns null over the cap', () {
      expect(AmountInput.parseAmount('1000000000000'), isNull);
    });

    test('returns null for a negative by default', () {
      expect(AmountInput.parseAmount('-5'), isNull);
    });

    test('parses a negative when allowed', () {
      expect(AmountInput.parseAmount('-5', allowNegative: true), -5);
    });

    test('returns null for empty input', () {
      expect(AmountInput.parseAmount(''), isNull);
    });
  });
}
