class SplitParticipantModel {
  final String id;
  final String splitId;
  final String? personId;
  final bool isPayer;
  final bool isUser;
  final String personName;
  final String? personPhone;
  final double shareValue; // percentage, shares weight, or custom amount
  final double allocatedAmount; // in currency units (Rupees)
  final bool isSettled;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SplitParticipantModel({
    required this.id,
    required this.splitId,
    this.personId,
    this.isPayer = false,
    this.isUser = false,
    required this.personName,
    this.personPhone,
    required this.shareValue,
    required this.allocatedAmount,
    this.isSettled = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  SplitParticipantModel copyWith({
    String? id,
    String? splitId,
    String? personId,
    bool? isPayer,
    bool? isUser,
    String? personName,
    String? personPhone,
    double? shareValue,
    double? allocatedAmount,
    bool? isSettled,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SplitParticipantModel(
      id: id ?? this.id,
      splitId: splitId ?? this.splitId,
      personId: personId ?? this.personId,
      isPayer: isPayer ?? this.isPayer,
      isUser: isUser ?? this.isUser,
      personName: personName ?? this.personName,
      personPhone: personPhone ?? this.personPhone,
      shareValue: shareValue ?? this.shareValue,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      isSettled: isSettled ?? this.isSettled,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'split_id': splitId,
      'person_id': personId,
      'is_payer': isPayer ? 1 : 0,
      'is_user': isUser ? 1 : 0,
      'person_name': personName,
      'person_phone': personPhone,
      'share_value': shareValue,
      'allocated_amount': allocatedAmount,
      'is_settled': isSettled ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SplitParticipantModel.fromMap(Map<String, dynamic> map) {
    return SplitParticipantModel(
      id: map['id'] as String,
      splitId: map['split_id'] as String,
      personId: map['person_id'] as String?,
      isPayer: (map['is_payer'] as int?) == 1,
      isUser: (map['is_user'] as int?) == 1,
      personName: map['person_name'] as String,
      personPhone: map['person_phone'] as String?,
      shareValue: (map['share_value'] as num).toDouble(),
      allocatedAmount: (map['allocated_amount'] as num).toDouble(),
      isSettled: (map['is_settled'] as int?) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
