import 'bank_parser_interface.dart';

class AxisSmsParser implements BankParserInterface {
  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();
    return s.contains('AXIS') || b.contains('AXIS BANK') || b.contains('BLOCKUPI');
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
    if (clean.toUpperCase().contains('CREDITED') || clean.toUpperCase().contains('RECEIVED')) {
      direction = 'credit';
    }

    final amountRegex = RegExp(r'(?:INR|Rs\.?|₹)\s*([\d\.]+)');
    final match = amountRegex.firstMatch(clean);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1) ?? '') ?? 0.0;
    if (amount <= 0) return null;

    final accRegex = RegExp(r'(?:A/c|ACC|CARD)\s*(?:no\.?)?\s*X*(\d+)', caseSensitive: false);
    final accMatch = accRegex.firstMatch(clean);
    final accountRef = accMatch?.group(1);

    String? merchant;
    String? refId;

    // Axis UPI pattern: "UPI/P2M/627719406029/Blinkit" or "UPI/P2A/627639019290/RAKIB KHAN"
    final axisUpiRegex = RegExp(r'UPI/P2[MA]/(\d+)/([A-Za-z0-9 _@\.\-]+)', caseSensitive: false);
    final upiMatch = axisUpiRegex.firstMatch(clean);
    if (upiMatch != null) {
      refId = upiMatch.group(1);
      merchant = upiMatch.group(2)?.trim();
    } else {
      final atRegex = RegExp(r'(?:at|to|vpa)\s+([A-Za-z0-9 _@\.\-]+?)(?:\.|\s+on|\s+ref|\s+avail|\$|\n|\r)', caseSensitive: false);
      final mMatch = atRegex.firstMatch(clean);
      if (mMatch != null) {
        merchant = mMatch.group(1)?.trim();
      }

      final refRegex = RegExp(r'(?:Ref|UPI|Txn)\s*NO?\s*:?\s*([A-Za-z0-9]{6,})', caseSensitive: false);
      final refMatch = refRegex.firstMatch(clean);
      refId = refMatch?.group(1);
    }

    return ExtractedSmsData(
      amount: amount,
      direction: direction,
      merchant: merchant ?? 'Axis Transaction',
      bankName: 'Axis Bank',
      accountRef: accountRef,
      referenceId: refId,
      status: status,
    );
  }
}
