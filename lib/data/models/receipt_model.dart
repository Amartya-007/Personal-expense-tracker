class ReceiptModel {
  final String id;
  final String transactionId;
  final String filePath;
  final String thumbnailPath;
  final DateTime createdAt;

  ReceiptModel({
    required this.id,
    required this.transactionId,
    required this.filePath,
    required this.thumbnailPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'file_path': filePath,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ReceiptModel.fromMap(Map<String, dynamic> map) {
    return ReceiptModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      filePath: map['file_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
