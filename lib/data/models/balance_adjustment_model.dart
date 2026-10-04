class BalanceAdjustmentModel {
  final String id;
  final String accountId;
  final double previousBalance;
  final double newBalance;
  final double adjustmentAmount;
  final String? reason;
  final DateTime createdAt;

  BalanceAdjustmentModel({
    required this.id,
    required this.accountId,
    required this.previousBalance,
    required this.newBalance,
    required this.adjustmentAmount,
    this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'previous_balance': previousBalance,
      'new_balance': newBalance,
      'adjustment_amount': adjustmentAmount,
      'reason': reason,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BalanceAdjustmentModel.fromMap(Map<String, dynamic> map) {
    return BalanceAdjustmentModel(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      previousBalance: (map['previous_balance'] as num).toDouble(),
      newBalance: (map['new_balance'] as num).toDouble(),
      adjustmentAmount: (map['adjustment_amount'] as num).toDouble(),
      reason: map['reason'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
