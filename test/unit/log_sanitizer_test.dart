import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/logging/log_sanitizer.dart';

void main() {
  String clean(String s) => LogSanitizer.sanitize(s);

  group('LogSanitizer.sanitize', () {
    test('masks long account / card numbers down to the last four digits', () {
      expect(clean('Account 12345678901234 failed'), 'Account ****1234 failed');
      expect(clean('card 4111 1111 1111 1111'), 'card ****1111');
      expect(clean('card 4111-1111-1111-1111'), 'card ****1111');
    });

    test('redacts passwords, PINs, OTPs and tokens given as key/value', () {
      expect(clean('password: hunter2 ok'), 'password: [redacted] ok');
      expect(clean('otp=482913'), 'otp=[redacted]');
      final json = clean('{"token": "abc123secret"}');
      expect(json, isNot(contains('abc123secret')));
      expect(json, contains('[redacted]'));
      expect(clean('Bearer abc.DEF-123'), 'Bearer [redacted]');
    });

    test('redacts API keys / long unbroken secrets', () {
      final key = 'sk_live_${'A1b2C3d4' * 6}';
      expect(clean('using $key now'), isNot(contains(key)));
    });

    test('redacts emails, UPI ids, phone numbers and rupee amounts', () {
      expect(clean('mail amar@example.com'), isNot(contains('amar@')));
      expect(clean('pay amar@oksbi now'), isNot(contains('amar@')));
      expect(clean('call +91 98765 43210'), contains('[phone]'));
      expect(clean('spent ₹1,234.50 on food'), 'spent [amount] on food');
      expect(clean('Rs. 500 debited'), '[amount] debited');
    });

    test('removes bound SQL arguments that exception text can carry', () {
      final out = clean(
        'DatabaseException(constraint failed) sql INSERT INTO t args [x1, Momos, 120.0]',
      );
      expect(out, isNot(contains('Momos')));
      expect(out, contains('args [redacted]'));
    });

    test('keeps harmless diagnostics readable', () {
      const ok = '120 messages processed, 7 skipped at 2026-10-21 09:13:00';
      expect(clean(ok), ok);
      const uuid = 'id 3f2b8c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e';
      expect(clean(uuid), uuid);
      expect(clean('Account ****1234 updated'), 'Account ****1234 updated');
    });

    test('truncates over-long text and says so', () {
      final long = List.filled(100, 'word').join(' ');
      final out = LogSanitizer.sanitize(long, maxLength: 100);
      expect(out.length, lessThan(long.length));
      expect(out, endsWith('[truncated ${long.length - 100} chars]'));
    });
  });

  group('LogSanitizer helpers', () {
    test('maskIdentifier keeps only the last four digits', () {
      expect(LogSanitizer.maskIdentifier('12345678901234'), '****1234');
      expect(LogSanitizer.maskIdentifier('1234 5678 9012'), '****9012');
      expect(LogSanitizer.maskIdentifier('12'), '****');
      expect(LogSanitizer.maskIdentifier(null), '****');
    });

    test('describeError drops the source text a FormatException carries', () {
      final e = FormatException('Unexpected character', '{"amount": 5000}', 3);
      final text = LogSanitizer.describeError(e);
      expect(text, 'FormatException: Unexpected character (at offset 3)');
      expect(text, isNot(contains('5000')));
    });

    test('sanitizeNullable returns null for null or blank input', () {
      expect(LogSanitizer.sanitizeNullable(null, maxLength: 10), isNull);
      expect(LogSanitizer.sanitizeNullable('   ', maxLength: 10), isNull);
      expect(LogSanitizer.sanitizeNullable('ok', maxLength: 10), 'ok');
    });
  });
}
