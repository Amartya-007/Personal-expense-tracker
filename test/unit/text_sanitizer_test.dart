import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/utils/text_sanitizer.dart';

void main() {
  group('TextSanitizer.singleLine', () {
    test('trims leading and trailing whitespace', () {
      expect(TextSanitizer.singleLine('  hello  '), 'hello');
    });

    test('collapses internal whitespace runs to a single space', () {
      expect(TextSanitizer.singleLine('a    b\t\tc'), 'a b c');
    });

    test('strips newlines, replacing them with a space', () {
      expect(
        TextSanitizer.singleLine('line1\nline2\r\nline3'),
        'line1 line2 line3',
      );
    });

    test('empty stays empty', () {
      expect(TextSanitizer.singleLine(''), '');
    });

    test('whitespace-only collapses to empty', () {
      expect(TextSanitizer.singleLine('   \n\t  '), '');
    });
  });

  group('TextSanitizer.multiLine', () {
    test('trims the ends', () {
      expect(TextSanitizer.multiLine('  hello  '), 'hello');
    });

    test('keeps internal newlines', () {
      expect(TextSanitizer.multiLine('  line1\nline2  '), 'line1\nline2');
    });

    test('empty stays empty', () {
      expect(TextSanitizer.multiLine(''), '');
    });

    test('whitespace-only trims to empty', () {
      expect(TextSanitizer.multiLine('   \n   '), '');
    });
  });
}
