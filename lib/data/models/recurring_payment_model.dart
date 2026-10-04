class RecurringPaymentModel {
  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final String? categoryName;
  final String accountId;
  final String? accountName;
  final String paymentMethod;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime nextDueDate;
  final bool isActive;
  final String? note;
  final DateTime createdAt;

  RecurringPaymentModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    this.categoryName,
    required this.accountId,
    this.accountName,
    required this.paymentMethod,
    required this.frequency,
    required this.nextDueDate,
    this.isActive = true,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'payment_method': paymentMethod,
      'frequency': frequency,
      'next_due_date': nextDueDate.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RecurringPaymentModel.fromMap(Map<String, dynamic> map) {
    return RecurringPaymentModel(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      accountId: map['account_id'] as String,
      accountName: map['account_name'] as String?,
      paymentMethod: map['payment_method'] as String,
      frequency: map['frequency'] as String,
      nextDueDate: DateTime.fromMillisecondsSinceEpoch(
        (map['next_due_date'] as num).toInt(),
      ),
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
