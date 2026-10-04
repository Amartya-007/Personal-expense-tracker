class SmsReviewModel {
  final String id;
  final String rawSms;
  final String sender;
  final double amount;
  final String direction; // 'debit', 'credit'
  final String? merchant;
  final String? bankName;
  final String? accountRef;
  final DateTime date;
  final String status; // 'detected', 'added', 'ignored'
  final String? referenceId;
  final String? smsMessageId;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime createdAt;

  SmsReviewModel({
    required this.id,
    required this.rawSms,
    required this.sender,
    required this.amount,
    required this.direction,
    this.merchant,
    this.bankName,
    this.accountRef,
    required this.date,
    this.status = 'detected',
    this.referenceId,
    this.smsMessageId,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
  });

  bool get isDebit => direction == 'debit';
  bool get isCredit => direction == 'credit';

  SmsReviewModel copyWith({
    String? id,
    String? rawSms,
    String? sender,
    double? amount,
    String? direction,
    String? merchant,
    String? bankName,
    String? accountRef,
    DateTime? date,
    String? status,
    String? referenceId,
    String? smsMessageId,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? createdAt,
  }) {
    return SmsReviewModel(
      id: id ?? this.id,
      rawSms: rawSms ?? this.rawSms,
      sender: sender ?? this.sender,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      merchant: merchant ?? this.merchant,
      bankName: bankName ?? this.bankName,
      accountRef: accountRef ?? this.accountRef,
      date: date ?? this.date,
      status: status ?? this.status,
      referenceId: referenceId ?? this.referenceId,
      smsMessageId: smsMessageId ?? this.smsMessageId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_sms': rawSms,
      'sender': sender,
      'amount': amount,
      'direction': direction,
      'merchant': merchant,
      'bank_name': bankName,
      'account_ref': accountRef,
      'date': date.millisecondsSinceEpoch,
      'status': status,
      'reference_id': referenceId,
      'sms_message_id': smsMessageId,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SmsReviewModel.fromMap(Map<String, dynamic> map) {
    return SmsReviewModel(
      id: map['id'] as String,
      rawSms: map['raw_sms'] as String,
      sender: map['sender'] as String,
      amount: (map['amount'] as num).toDouble(),
      direction: map['direction'] as String,
      merchant: map['merchant'] as String?,
      bankName: map['bank_name'] as String?,
      accountRef: map['account_ref'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt()),
      status: map['status'] as String? ?? 'detected',
      referenceId: map['reference_id'] as String?,
      smsMessageId: map['sms_message_id'] as String?,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      locationName: map['location_name'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
