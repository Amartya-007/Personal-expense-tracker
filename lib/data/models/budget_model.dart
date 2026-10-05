class BudgetModel {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String period; // 'weekly', 'monthly', 'yearly', 'custom'
  final double amount;
  final double spentAmount; // Joined calculation
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.period,
    required this.amount,
    this.spentAmount = 0.0,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  double get remainingAmount =>
      (amount - spentAmount).clamp(0.0, double.infinity);
  double get percentage =>
      amount > 0 ? (spentAmount / amount).clamp(0.0, 1.0) : 0.0;

  /// Unclamped spent / limit (1.3 means 130% of the limit).
  double get usedRatio => amount > 0 ? spentAmount / amount : 0.0;

  /// How far past the limit spending is (0 when within budget).
  double get overAmount =>
      (spentAmount - amount).clamp(0.0, double.infinity);

  BudgetModel copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    int? categoryColor,
    String? period,
    double? amount,
    double? spentAmount,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      period: period ?? this.period,
      amount: amount ?? this.amount,
      spentAmount: spentAmount ?? this.spentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'period': period,
      'amount': amount,
      'start_date': startDate.millisecondsSinceEpoch,
      'end_date': endDate.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BudgetModel.fromMap(
    Map<String, dynamic> map, {
    double spentAmount = 0.0,
  }) {
    return BudgetModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] != null
          ? map['category_color'] as int
          : null,
      period: map['period'] as String,
      amount: (map['amount'] as num).toDouble(),
      spentAmount: spentAmount,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        (map['start_date'] as num).toInt(),
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        (map['end_date'] as num).toInt(),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
