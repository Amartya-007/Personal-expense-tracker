class KhataPersonModel {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final String? contactId;
  final String? lookupKey;
  final String source; // 'manual' or 'contact'
  final bool isArchived;
  final double netBalance;
  final DateTime? lastEntryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KhataPersonModel({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    this.contactId,
    this.lookupKey,
    this.source = 'manual',
    this.isArchived = false,
    this.netBalance = 0.0,
    this.lastEntryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Accounting conventions:
  /// Positive balance (> 0.009) -> Person owes the user ("You'll Get" / Receivable)
  /// Negative balance (< -0.009) -> User owes the person ("You'll Give" / Payable)
  /// Near-zero balance (-0.009 <= balance <= 0.009) -> Settled
  bool get isReceivable => netBalance > 0.009;
  bool get isPayable => netBalance < -0.009;
  bool get isSettled => !isReceivable && !isPayable;
  bool get isFromContact => source == 'contact';

  /// Absolute value for display with signed label
  double get absoluteBalance => netBalance.abs();

  String get balanceStatusLabel {
    if (isReceivable) return "You'll Get";
    if (isPayable) return "You'll Give";
    return 'Settled';
  }

  KhataPersonModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    String? contactId,
    String? lookupKey,
    String? source,
    bool? isArchived,
    double? netBalance,
    DateTime? lastEntryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KhataPersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      contactId: contactId ?? this.contactId,
      lookupKey: lookupKey ?? this.lookupKey,
      source: source ?? this.source,
      isArchived: isArchived ?? this.isArchived,
      netBalance: netBalance ?? this.netBalance,
      lastEntryDate: lastEntryDate ?? this.lastEntryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'contact_id': contactId,
      'lookup_key': lookupKey,
      'source': source,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory KhataPersonModel.fromMap(Map<String, dynamic> map, {double netBalance = 0.0, DateTime? lastEntryDate}) {
    return KhataPersonModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
      contactId: map['contact_id'] as String?,
      lookupKey: map['lookup_key'] as String?,
      source: (map['source'] as String?) ?? 'manual',
      isArchived: (map['is_archived'] as int?) == 1,
      netBalance: (map['net_balance'] as num?)?.toDouble() ?? netBalance,
      lastEntryDate: map['last_entry_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_entry_date'] as int)
          : lastEntryDate,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
