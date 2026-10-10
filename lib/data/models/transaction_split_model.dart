class TransactionSplitModel {
  final String id;
  final String transactionId;
  final String categoryId;
  final String? categoryName;
  final double amount;
  final String? note;

  TransactionSplitModel({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    this.categoryName,
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
    };
  }

  factory TransactionSplitModel.fromMap(Map<String, dynamic> map) {
    return TransactionSplitModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
