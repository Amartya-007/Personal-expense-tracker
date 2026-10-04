import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/services/sms/bank_parsers/axis_parser.dart';
import 'package:mykhata/services/sms/bank_parsers/boi_parser.dart';
import 'package:mykhata/services/sms/bank_parsers/generic_bank_parser.dart';

void main() {
  group('Bank SMS Parsers Tests', () {
    test('Axis Parser extracts Blinkit UPI transaction correctly', () {
      final parser = AxisSmsParser();
      const sender = 'AXISBK';
      const body = '''
INR 326.00 debited
A/c no. XX6281
04-10-26, 11:21:34
UPI/P2M/627719406029/Blinkit
Not you? SMS BLOCKUPI Cust ID to 919951860002
Axis Bank
''';

      expect(parser.canParse(sender, body), isTrue);

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 326.0);
      expect(result.direction, 'debit');
      expect(result.merchant, 'Blinkit');
      expect(result.accountRef, '6281');
      expect(result.referenceId, '627719406029');
      expect(result.bankName, 'Axis Bank');
    });

    test('Axis Parser extracts Atul Singh Yadav UPI transaction correctly', () {
      final parser = AxisSmsParser();
      const sender = 'AXISBK';
      const body = '''
INR 90.00 debited
A/c no. XX6281
02-10-26, 18:59:58
UPI/P2M/627507408195/Atul Singh Yadav
Not you? SMS BLOCKUPI Cust ID to 919951860002
Axis Bank
''';

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 90.0);
      expect(result.merchant, 'Atul Singh Yadav');
      expect(result.accountRef, '6281');
    });

    test('Axis Parser extracts RAKIB KHAN UPI transaction correctly', () {
      final parser = AxisSmsParser();
      const sender = 'AXISBK';
      const body = '''
INR 90.00 debited
A/c no. XX6281
03-10-26, 22:43:24
UPI/P2A/627639019290/RAKIB KHAN
Not you? SMS BLOCKUPI Cust ID to 919951860002
Axis Bank
''';

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 90.0);
      expect(result.merchant, 'RAKIB KHAN');
      expect(result.referenceId, '627639019290');
    });

    test('BOI Parser extracts UPI Credit transaction correctly', () {
      final parser = BoiSmsParser();
      const sender = 'VM-BOIIND';
      const body = 'BOI -  Rs.3000.00 Credited to your Ac XX1488 on 01-10-26 by UPI ref No.216968711576.Avl Bal 3920.20';

      expect(parser.canParse(sender, body), isTrue);

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 3000.0);
      expect(result.direction, 'credit');
      expect(result.accountRef, '1488');
      expect(result.referenceId, '216968711576');
    });

    test('BOI Parser extracts UPI Transfer Debit correctly', () {
      final parser = BoiSmsParser();
      const sender = 'VM-BOIIND';
      const body = 'Rs.3,000.00 debited A/cXX1488 and credited to AMARTYA VISHWAKARMA via UPI Ref No 627435363530 on 01Oct26. Call 18001031906, if not done by you. -BOI';

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 3000.0);
      expect(result.direction, 'debit');
      expect(result.accountRef, '1488');
      expect(result.merchant, 'AMARTYA VISHWAKARMA');
      expect(result.referenceId, '627435363530');
    });

    test('BOI Parser extracts Google Play Autopay Debit correctly', () {
      final parser = BoiSmsParser();
      const sender = 'BOI';
      const body = 'BOI UPI - Your account has been debited towards Google Play for 89.00 on 17/09/2026 (UPI Ref no 178666052606).';

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 89.0);
      expect(result.merchant, 'Google Play');
      expect(result.referenceId, '178666052606');
    });

    test('BOI Parser extracts Google Asia Pacific Mandate correctly', () {
      final parser = BoiSmsParser();
      const sender = 'BOI';
      const body = 'BOI UPI - Your upcoming Mandate is set for 30/09/2026 Your account will be debited with Rs.399.00 towards Google Asia Pacific Pte.Ltd for the 118f115e3339431ab20528df8af3cd29@ybl (UPI Ref - 153641316089). If Mandate is paused the execution for the same will not happen.';

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 399.0);
      expect(result.merchant, 'Google Asia Pacific Pte.Ltd');
      expect(result.referenceId, '153641316089');
    });

    test('Generic Parser extracts Airtel Wi-Fi payment notice correctly', () {
      final parser = GenericBankParser();
      const sender = 'AIRTEL';
      const body = 'Hi, a payment of Rs. 1059.64 is updated against your Airtel Wi-Fi 076118129452_wifi . To download your payment receipt or know more about your connection, visit Airtel Thanks App https://www.airtel.in/5/trnxsbb';

      expect(parser.canParse(sender, body), isTrue);

      final result = parser.parse(sender, body);
      expect(result, isNotNull);
      expect(result!.amount, 1059.64);
      expect(result.merchant, 'Airtel Wi-Fi');
    });
  });
}
