import 'receipt_model.dart';
import 'tag_model.dart';

class TransactionModel {
  final String id;
  final String type; // 'expense', 'income', 'transfer'
  final double amount;
  final String description; // What's it for?
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String paymentMethod; // UPI, Cash, Debit Card, etc.
  final String accountId;
  final String? accountName;
  final String? destinationAccountId;
  final String? destinationAccountName;
  final DateTime date;
  final String? note;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String source; // 'manual', 'sms'
  final String status; // 'confirmed', 'pending'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? recurringPaymentId;
  final String? smsMessageId;
  final String? externalReference;
  final String? duplicateStatus;
  final List<TagModel> tags;
  final List<ReceiptModel> receipts;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.paymentMethod,
    required this.accountId,
    this.accountName,
    this.destinationAccountId,
    this.destinationAccountName,
    required this.date,
    this.note,
    this.latitude,
    this.longitude,
    this.locationName,
    this.source = 'manual',
    this.status = 'confirmed',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.recurringPaymentId,
    this.smsMessageId,
    this.externalReference,
    this.duplicateStatus,
    this.tags = const [],
    this.receipts = const [],
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';
  bool get isDeleted => deletedAt != null;

  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? description,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    int? categoryColor,
    String? paymentMethod,
    String? accountId,
    String? accountName,
    String? destinationAccountId,
    String? destinationAccountName,
    DateTime? date,
    String? note,
    double? latitude,
    double? longitude,
    String? locationName,
    String? source,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? recurringPaymentId,
    String? smsMessageId,
    String? externalReference,
    String? duplicateStatus,
    List<TagModel>? tags,
    List<ReceiptModel>? receipts,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      destinationAccountName:
          destinationAccountName ?? this.destinationAccountName,
      date: date ?? this.date,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      source: source ?? this.source,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      recurringPaymentId: recurringPaymentId ?? this.recurringPaymentId,
      smsMessageId: smsMessageId ?? this.smsMessageId,
      externalReference: externalReference ?? this.externalReference,
      duplicateStatus: duplicateStatus ?? this.duplicateStatus,
      tags: tags ?? this.tags,
      receipts: receipts ?? this.receipts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'category_id': categoryId,
      'payment_method': paymentMethod,
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'date': date.millisecondsSinceEpoch,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'source': source,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'recurring_payment_id': recurringPaymentId,
      'sms_message_id': smsMessageId,
      'external_reference': externalReference,
      'duplicate_status': duplicateStatus,
    };
  }

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    List<TagModel>? tags,
    List<ReceiptModel>? receipts,
  }) {
    return TransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] != null
          ? map['category_color'] as int
          : null,
      paymentMethod: map['payment_method'] as String,
      accountId: map['account_id'] as String,
      accountName: map['account_name'] as String?,
      destinationAccountId: map['destination_account_id'] as String?,
      destinationAccountName: map['destination_account_name'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt()),
      note: map['note'] as String?,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      locationName: map['location_name'] as String?,
      source: map['source'] as String? ?? 'manual',
      status: map['status'] as String? ?? 'confirmed',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['deleted_at'] as num).toInt(),
            )
          : null,
      recurringPaymentId: map['recurring_payment_id'] as String?,
      smsMessageId: map['sms_message_id'] as String?,
      externalReference: map['external_reference'] as String?,
      duplicateStatus: map['duplicate_status'] as String?,
      tags: tags ?? [],
      receipts: receipts ?? [],
    );
  }
}
