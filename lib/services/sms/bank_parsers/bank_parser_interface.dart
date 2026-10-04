class ExtractedSmsData {
  final double amount;
  final String direction; // 'debit', 'credit'
  final String? merchant;
  final String bankName;
  final String? accountRef;
  final String? referenceId;
  final String status; // 'SUCCESS', 'FAILED', 'REVERSED', 'PENDING'

  ExtractedSmsData({
    required this.amount,
    required this.direction,
    this.merchant,
    required this.bankName,
    this.accountRef,
    this.referenceId,
    this.status = 'SUCCESS',
  });
}

abstract class BankParserInterface {
  bool canParse(String sender, String body);
  ExtractedSmsData? parse(String sender, String body);
}
