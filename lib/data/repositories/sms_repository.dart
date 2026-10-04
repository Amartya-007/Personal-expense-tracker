import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/sms_review_model.dart';

class SmsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<SmsReviewModel>> getQueueByStatus(String status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'sms_review_queue',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'date DESC',
    );
    return maps.map((m) => SmsReviewModel.fromMap(m)).toList();
  }

  Future<void> addToQueue(SmsReviewModel item) async {
    final db = await _dbHelper.database;
    await db.insert('sms_review_queue', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await AppLogger.i('Added SMS to review queue: ${item.merchant} - ₹${item.amount}');
  }

  Future<void> updateStatus(String id, String status) async {
    final db = await _dbHelper.database;
    await db.update(
      'sms_review_queue',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await AppLogger.i('Updated SMS review status for $id to $status');
  }

  Future<bool> isPossibleDuplicate(String? refId, String? smsMessageId, double amount, DateTime date) async {
    final db = await _dbHelper.database;

    if (refId != null && refId.isNotEmpty) {
      final res = await db.query('transactions', where: 'external_reference = ? AND deleted_at IS NULL', whereArgs: [refId]);
      if (res.isNotEmpty) return true;
    }

    if (smsMessageId != null && smsMessageId.isNotEmpty) {
      final res = await db.query('transactions', where: 'sms_message_id = ? AND deleted_at IS NULL', whereArgs: [smsMessageId]);
      if (res.isNotEmpty) return true;
    }

    // Check same amount within 10 minute window
    final windowStart = date.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
    final windowEnd = date.add(const Duration(minutes: 10)).millisecondsSinceEpoch;

    final res = await db.rawQuery('''
      SELECT COUNT(*) FROM transactions
      WHERE amount = ? AND date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [amount, windowStart, windowEnd]);

    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }
}
