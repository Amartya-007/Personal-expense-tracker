import 'bank_parser_interface.dart';

class GenericBankParser implements BankParserInterface {
  @override
  bool canParse(String sender, String body) {
    final b = body.toUpperCase();
    return b.contains('DEBITED') || b.contains('CREDITED') || b.contains('SPENT') || b.contains('PAID') || b.contains('PAYMENT OF');
  }

  @override
  ExtractedSmsData? parse(String sender, String body) {
    final clean = body.replaceAll(',', '');

    String status = 'SUCCESS';
    if (clean.toUpperCase().contains('FAILED') || clean.toUpperCase().contains('DECLINED')) {
      status = 'FAILED';
    }

    String direction = 'debit';
    if (clean.toUpperCase().contains('CREDITED') || clean.toUpperCase().contains('RECEIVED')) {
      direction = 'credit';
    }

    final amountRegex = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d\.]+)');
    final match = amountRegex.firstMatch(clean);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1) ?? '') ?? 0.0;
    if (amount <= 0) return null;

    final accRegex = RegExp(r'(?:A/C|ACC|CARD)\s*(?:no\.?)?\s*X*(\d+)', caseSensitive: false);
    final accMatch = accRegex.firstMatch(clean);
    final accountRef = accMatch?.group(1);

    String? merchant;
    final againstRegex = RegExp(r'against\s+your\s+([A-Za-z0-9\s_\.-]+?)(?:\s+\d|\.|\$|\n)', caseSensitive: false);
    final atRegex = RegExp(r'(?:at|to|vpa)\s+([A-Za-z0-9\s_@\.\-]+?)(?:\.|\s+on|\s+ref|\s+avail|\$|\n)', caseSensitive: false);

    final againstMatch = againstRegex.firstMatch(clean);
    final atMatch = atRegex.firstMatch(clean);

    if (againstMatch != null) {
      merchant = againstMatch.group(1)?.trim();
    } else if (atMatch != null) {
      merchant = atMatch.group(1)?.trim();
    }

    return ExtractedSmsData(
      amount: amount,
      direction: direction,
      merchant: merchant ?? (sender.isNotEmpty ? sender : 'Utility/Bank Payment'),
      bankName: sender.isNotEmpty ? sender.toUpperCase() : 'Bank',
      accountRef: accountRef,
      status: status,
    );
  }
}
