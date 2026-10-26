import 'split_participant_model.dart';

enum SplitMode {
  equal,
  custom,
  percentage,
  shares;

  static SplitMode fromString(String val) {
    switch (val.toLowerCase()) {
      case 'equal':
        return SplitMode.equal;
      case 'custom':
        return SplitMode.custom;
      case 'percentage':
        return SplitMode.percentage;
      case 'shares':
        return SplitMode.shares;
      default:
        return SplitMode.equal;
    }
  }

  String toDbString() {
    switch (this) {
      case SplitMode.equal:
        return 'equal';
      case SplitMode.custom:
        return 'custom';
      case SplitMode.percentage:
        return 'percentage';
      case SplitMode.shares:
        return 'shares';
    }
  }

  String get label {
    switch (this) {
      case SplitMode.equal:
        return 'Equally (=)';
      case SplitMode.custom:
        return 'Custom (₹)';
      case SplitMode.percentage:
        return 'Percentage (%)';
      case SplitMode.shares:
        return 'Shares (÷)';
    }
  }
}

class ExpenseSplitModel {
  final String id;
  final String title;
  final double totalAmount;
  final String payerType; // 'user' or 'person'
  final String? payerPersonId;
  final String? payerName;
  final String? groupId;
  final String? groupName;
  final SplitMode splitMode;
  final DateTime date;
  final String? transactionId;
  final String? notes;
  final bool isSettled;
  final List<SplitParticipantModel> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseSplitModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    this.payerType = 'user',
    this.payerPersonId,
    this.payerName,
    this.groupId,
    this.groupName,
    this.splitMode = SplitMode.equal,
    required this.date,
    this.transactionId,
    this.notes,
    this.isSettled = false,
    this.participants = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUserPayer => payerType == 'user' || payerPersonId == null;

  double get totalAllocated =>
      participants.fold<double>(0.0, (sum, p) => sum + p.allocatedAmount);

  double get remainingAmount => totalAmount - totalAllocated;

  bool get isAllocationExact => remainingAmount.abs() < 0.009;

  SplitParticipantModel? get payerParticipant {
    for (final p in participants) {
      if (p.isPayer) return p;
    }
    return null;
  }

  ExpenseSplitModel copyWith({
    String? id,
    String? title,
    double? totalAmount,
    String? payerType,
    String? payerPersonId,
    String? payerName,
    String? groupId,
    String? groupName,
    SplitMode? splitMode,
    DateTime? date,
    String? transactionId,
    String? notes,
    bool? isSettled,
    List<SplitParticipantModel>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseSplitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      payerType: payerType ?? this.payerType,
      payerPersonId: payerPersonId ?? this.payerPersonId,
      payerName: payerName ?? this.payerName,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      splitMode: splitMode ?? this.splitMode,
      date: date ?? this.date,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      isSettled: isSettled ?? this.isSettled,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'total_amount': totalAmount,
      'payer_type': payerType,
      'payer_person_id': payerPersonId,
      'group_id': groupId,
      'split_mode': splitMode.toDbString(),
      'date': date.millisecondsSinceEpoch,
      'transaction_id': transactionId,
      'notes': notes,
      'is_settled': isSettled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ExpenseSplitModel.fromMap(
    Map<String, dynamic> map, {
    List<SplitParticipantModel> participants = const [],
    String? payerName,
    String? groupName,
  }) {
    return ExpenseSplitModel(
      id: map['id'] as String,
      title: map['title'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      payerType: (map['payer_type'] as String?) ?? 'user',
      payerPersonId: map['payer_person_id'] as String?,
      payerName: payerName ?? map['payer_name'] as String?,
      groupId: map['group_id'] as String?,
      groupName: groupName ?? map['group_name'] as String?,
      splitMode: SplitMode.fromString((map['split_mode'] as String?) ?? 'equal'),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      transactionId: map['transaction_id'] as String?,
      notes: map['notes'] as String?,
      isSettled: (map['is_settled'] as int?) == 1,
      participants: participants,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
