import 'bank_parser_interface.dart';

class HdfcSmsParser implements BankParserInterface {
  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();
    return s.contains('HDFC') || b.contains('HDFC BANK');
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

    final accRegex = RegExp(r'A/C\s*X*(\d+)|CARD\s*X*(\d+)');
    final accMatch = accRegex.firstMatch(clean.toUpperCase());
    final accountRef = accMatch != null ? (accMatch.group(1) ?? accMatch.group(2)) : null;

    String? merchant;
    final atRegex = RegExp(r'(?:to|at)\s+([A-Za-z0-9\s_@\.\-]+?)(?:\.|\s+on|\s+ref|\s+bal|\$|\n)');
    final mMatch = atRegex.firstMatch(clean);
    if (mMatch != null) {
      merchant = mMatch.group(1)?.trim();
    }

    return ExtractedSmsData(
      amount: amount,
      direction: direction,
      merchant: merchant ?? 'HDFC Transaction',
      bankName: 'HDFC',
      accountRef: accountRef,
      status: status,
    );
  }
}
