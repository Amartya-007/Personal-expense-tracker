import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
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
    await AppLogger.info('SMS added to review queue', category: LogCategory.sms, details: 'id ${item.id}');
  }

  Future<void> updateStatus(String id, String status) async {
    final db = await _dbHelper.database;
    await db.update(
      'sms_review_queue',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await AppLogger.info('Updated SMS review status for $id to $status', category: LogCategory.sms);
  }

  /// Lowercased with whitespace collapsed, so the same message read by the
  /// background receiver and by an inbox scan compares equal.
  static String normalizeSms(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _typeFor(String direction) =>
      direction == 'credit' ? 'income' : 'expense';

  /// Adds [item] to the review queue unless it is already there (in any
  /// state, so a dismissed message is not offered again) or already became a
  /// transaction. The check and the insert run in ONE database transaction,
  /// so two callers racing with the same message can never both insert it.
  ///
  /// Returns `false` when it was a duplicate.
  Future<bool> addToQueueIfNew(SmsReviewModel item) async {
    final db = await _dbHelper.database;
    final added = await db.transaction<bool>((txn) async {
      if (await _isAlreadyKnown(txn, item)) return false;
      await txn.insert('sms_review_queue', item.toMap());
      return true;
    });
    if (added) await AppLogger.info('Queued SMS ${item.id} for review', category: LogCategory.sms);
    return added;
  }

  Future<bool> _isAlreadyKnown(DatabaseExecutor db, SmsReviewModel item) async {
    final messageId = item.smsMessageId;
    final refId = item.referenceId;

    // 1. Same message id (queue or transactions).
    if (messageId != null && messageId.isNotEmpty) {
      final inQueue = await db.query(
        'sms_review_queue',
        columns: ['id'],
        where: 'sms_message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (inQueue.isNotEmpty) return true;
      final inTx = await db.query(
        'transactions',
        columns: ['id'],
        where: 'sms_message_id = ? AND deleted_at IS NULL',
        whereArgs: [messageId],
        limit: 1,
      );
      if (inTx.isNotEmpty) return true;
    }

    // 2. Same bank reference in the same direction. (A refund can reuse the
    //    original payment's reference, so direction must match.)
    if (refId != null && refId.isNotEmpty) {
      final inQueue = await db.query(
        'sms_review_queue',
        columns: ['id'],
        where: 'reference_id = ? AND direction = ?',
        whereArgs: [refId, item.direction],
        limit: 1,
      );
      if (inQueue.isNotEmpty) return true;
      final inTx = await db.query(
        'transactions',
        columns: ['id'],
        where: 'external_reference = ? AND type = ? AND deleted_at IS NULL',
        whereArgs: [refId, _typeFor(item.direction)],
        limit: 1,
      );
      if (inTx.isNotEmpty) return true;
    }

    // 3. Same text. The background receiver and an inbox scan give the same
    //    SMS different ids, so the text is the only thing they share.
    final sameAmount = await db.query(
      'sms_review_queue',
      columns: ['raw_sms'],
      where: 'amount = ?',
      whereArgs: [item.amount],
    );
    final key = normalizeSms(item.rawSms);
    for (final row in sameAmount) {
      if (normalizeSms(row['raw_sms'] as String) == key) return true;
    }

    // 4. The person already entered this by hand: same amount and type within
    //    10 minutes of a manual transaction. Transactions that came from an
    //    SMS are excluded, so two genuine payments of the same amount close
    //    together are not mistaken for one.
    final windowStart =
        item.date.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
    final windowEnd =
        item.date.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    final manual = await db.rawQuery(
      '''
      SELECT COUNT(*) FROM transactions
      WHERE amount = ? AND type = ? AND date >= ? AND date <= ?
        AND deleted_at IS NULL
        AND (sms_message_id IS NULL OR sms_message_id = '')
      ''',
      [item.amount, _typeFor(item.direction), windowStart, windowEnd],
    );
    return (Sqflite.firstIntValue(manual) ?? 0) > 0;
  }

  /// One-time clean-up for copies that were queued before the check above
  /// existed: among messages still waiting for review, keeps the earliest of
  /// each group of identical ones. Returns how many copies were removed.
  Future<int> collapseDuplicateDetected() async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        'sms_review_queue',
        columns: ['id', 'raw_sms', 'amount', 'direction', 'reference_id'],
        where: "status = 'detected'",
        orderBy: 'created_at ASC, id ASC',
      );
      final seen = <String>{};
      final extras = <String>[];
      for (final row in rows) {
        final ref = (row['reference_id'] as String?)?.trim() ?? '';
        final key = ref.isNotEmpty
            ? 'ref:$ref|${row['direction']}'
            : 'txt:${normalizeSms(row['raw_sms'] as String)}|${row['amount']}';
        if (!seen.add(key)) extras.add(row['id'] as String);
      }
      for (final id in extras) {
        await txn.delete('sms_review_queue', where: 'id = ?', whereArgs: [id]);
      }
      return extras.length;
    });
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
