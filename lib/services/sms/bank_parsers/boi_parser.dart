import 'bank_parser_interface.dart';

class BoiSmsParser implements BankParserInterface {
  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();
    return s.contains('BOI') || b.contains('BANK OF INDIA') || b.contains('BOI');
  }

  @override
  ExtractedSmsData? parse(String sender, String body) {
    final clean = body.replaceAll(',', '');

    String status = 'SUCCESS';
    if (clean.toUpperCase().contains('FAILED') || clean.toUpperCase().contains('DECLINED')) {
      status = 'FAILED';
    } else if (clean.toUpperCase().contains('REVERSED')) {
      status = 'REVERSED';
    }

    String direction = 'debit';
    if (clean.toUpperCase().contains('CREDITED TO YOUR AC') || clean.toUpperCase().contains('CREDITED TO YOUR A/C') || clean.toUpperCase().contains('RECEIVED')) {
      direction = 'credit';
    }

    final currencyAmountRegex = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d\.]+)');
    final fallbackAmountRegex = RegExp(r'for\s+([\d\.]+)');

    final match = currencyAmountRegex.firstMatch(clean) ?? fallbackAmountRegex.firstMatch(clean);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1) ?? '') ?? 0.0;
    if (amount <= 0) return null;

    final accRegex = RegExp(r'(?:A/C|ACC|AC)\s*X*(\d+)', caseSensitive: false);
    final accMatch = accRegex.firstMatch(clean);
    final accountRef = accMatch?.group(1);

    String? merchant;
    final towardsRegex = RegExp(r'towards\s+([A-Za-z0-9 _@\.\-]+?)(?:\s+for\b|\s+on\b|\n|\r|$)', caseSensitive: false);
    final creditedToRegex = RegExp(r'credited to\s+([A-Za-z0-9 _@\.\-]+?)(?:\s+via\b|\s+on\b|\s+ref\b|\n|\r|$)', caseSensitive: false);
    final atRegex = RegExp(r'(?:at|to|via|info:)\s+([A-Za-z0-9 _@\.\-]+?)(?:\s+on\b|\s+ref\b|\s+avail\b|\$|\n|\r)', caseSensitive: false);

    final towardsMatch = towardsRegex.firstMatch(clean);
    final creditedToMatch = creditedToRegex.firstMatch(clean);
    final atMatch = atRegex.firstMatch(clean);

    if (towardsMatch != null) {
      merchant = towardsMatch.group(1)?.trim();
    } else if (creditedToMatch != null) {
      merchant = creditedToMatch.group(1)?.trim();
    } else if (atMatch != null) {
      merchant = atMatch.group(1)?.trim();
    }

    final refRegex = RegExp(r'(?:Ref|UPI|Txn)\s*(?:no\.?|Ref|-)?\s*:?\s*([A-Za-z0-9]{6,})', caseSensitive: false);
    final refMatch = refRegex.firstMatch(clean);
    final refId = refMatch?.group(1);

    return ExtractedSmsData(
      amount: amount,
      direction: direction,
      merchant: merchant ?? 'BOI Transaction',
      bankName: 'BOI',
      accountRef: accountRef,
      referenceId: refId,
      status: status,
    );
  }
}
