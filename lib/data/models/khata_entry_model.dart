enum KhataEntryType {
  lent,
  borrowed,
  repaymentReceived,
  repaymentMade,
  settlement;

  static KhataEntryType fromString(String val) {
    switch (val) {
      case 'lent':
        return KhataEntryType.lent;
      case 'borrowed':
        return KhataEntryType.borrowed;
      case 'repayment_received':
        return KhataEntryType.repaymentReceived;
      case 'repayment_made':
        return KhataEntryType.repaymentMade;
      case 'settlement':
        return KhataEntryType.settlement;
      default:
        throw ArgumentError('Unknown KhataEntryType: $val');
    }
  }

  String toDbString() {
    switch (this) {
      case KhataEntryType.lent:
        return 'lent';
      case KhataEntryType.borrowed:
        return 'borrowed';
      case KhataEntryType.repaymentReceived:
        return 'repayment_received';
      case KhataEntryType.repaymentMade:
        return 'repayment_made';
      case KhataEntryType.settlement:
        return 'settlement';
    }
  }

  String get label {
    switch (this) {
      case KhataEntryType.lent:
        return 'You Lent (Given)';
      case KhataEntryType.borrowed:
        return 'You Borrowed (Taken)';
      case KhataEntryType.repaymentReceived:
        return 'Repayment Received';
      case KhataEntryType.repaymentMade:
        return 'Repayment Made';
      case KhataEntryType.settlement:
        return 'Settlement';
    }
  }
}

class KhataEntryModel {
  final String id;
  final String personId;
  final KhataEntryType type;
  final double amount;
  /// Explicit sign (+1 or -1) representing the signed effect on the person's net balance.
  /// +1 increases receivable / reduces payable (You Lent, Repayment Made, Settlement of Debt).
  /// -1 decreases receivable / increases payable (You Borrowed, Repayment Received, Settlement of Credit).
  final int sign;
  final DateTime date;
  final String? notes;
  final DateTime? dueDate;
  final String? accountId;
  final String? accountName;
  final bool isSettled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KhataEntryModel({
    required this.id,
    required this.personId,
    required this.type,
    required this.amount,
    required this.sign,
    required this.date,
    this.notes,
    this.dueDate,
    this.accountId,
    this.accountName,
    this.isSettled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Signed effect on the person's net balance:
  /// Positive means the person owes you more.
  /// Negative means the person owes you less (or you owe them more).
  double get signedEffect => amount * sign;

  /// Human-readable description of how this impacts the relationship:
  bool get isReceivableIncrease => sign > 0;

  KhataEntryModel copyWith({
    String? id,
    String? personId,
    KhataEntryType? type,
    double? amount,
    int? sign,
    DateTime? date,
    String? notes,
    DateTime? dueDate,
    String? accountId,
    String? accountName,
    bool? isSettled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KhataEntryModel(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      sign: sign ?? this.sign,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'type': type.toDbString(),
      'amount': amount,
      'sign': sign,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'account_id': accountId,
      'is_settled': isSettled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory KhataEntryModel.fromMap(Map<String, dynamic> map) {
    return KhataEntryModel(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      type: KhataEntryType.fromString(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      sign: (map['sign'] as num?)?.toInt() ?? 1,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      notes: map['notes'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      accountId: map['account_id'] as String?,
      accountName: map['account_name'] as String?,
      isSettled: (map['is_settled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
