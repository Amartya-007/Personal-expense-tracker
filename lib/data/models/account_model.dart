class AccountModel {
  final String id;
  final String name;
  final double currentBalance;
  final double initialBalance;
  final bool isActive;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountModel({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.initialBalance,
    this.isActive = true,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  AccountModel copyWith({
    String? id,
    String? name,
    double? currentBalance,
    double? initialBalance,
    bool? isActive,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      currentBalance: currentBalance ?? this.currentBalance,
      initialBalance: initialBalance ?? this.initialBalance,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'current_balance': currentBalance,
      'initial_balance': initialBalance,
      'is_active': isActive ? 1 : 0,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as String,
      name: map['name'] as String,
      currentBalance: (map['current_balance'] as num).toDouble(),
      initialBalance: (map['initial_balance'] as num).toDouble(),
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isPrimary: ((map['is_primary'] as int?) ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }
}
