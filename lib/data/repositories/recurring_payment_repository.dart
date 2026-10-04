import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/recurring_payment_model.dart';
import '../models/transaction_model.dart';
import 'transaction_repository.dart';

class RecurringPaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TransactionRepository _txRepo = TransactionRepository();
  final Uuid _uuid = const Uuid();

  Future<List<RecurringPaymentModel>> getAllRecurringPayments() async {
    final db = await _dbHelper.database;
    const sql = '''
      SELECT 
        r.*,
        c.name as category_name,
        a.name as account_name
      FROM recurring_payments r
      LEFT JOIN categories c ON r.category_id = c.id
      LEFT JOIN accounts a ON r.account_id = a.id
      ORDER BY r.next_due_date ASC
    ''';
    final maps = await db.rawQuery(sql);
    return maps.map((m) => RecurringPaymentModel.fromMap(m)).toList();
  }

  Future<void> createRecurringPayment(RecurringPaymentModel item) async {
    final db = await _dbHelper.database;
    await db.insert('recurring_payments', item.toMap());
    await AppLogger.i('Created recurring payment ${item.name}');
  }

  Future<void> updateRecurringPayment(RecurringPaymentModel item) async {
    final db = await _dbHelper.database;
    await db.update(
      'recurring_payments',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await AppLogger.i('Updated recurring payment ${item.name}');
  }

  Future<void> deleteRecurringPayment(String id) async {
    final db = await _dbHelper.database;
    await db.delete('recurring_payments', where: 'id = ?', whereArgs: [id]);
    await AppLogger.i('Completely deleted recurring payment rule $id');
  }

  Future<void> processPaymentAction(
    RecurringPaymentModel item,
    String action,
  ) async {
    final db = await _dbHelper.database;

    if (action == 'Paid') {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: _uuid.v4(),
        type: 'expense',
        amount: item.amount,
        description: item.name,
        categoryId: item.categoryId,
        paymentMethod: item.paymentMethod,
        accountId: item.accountId,
        date: now,
        note: 'Recurring payment auto-recorded',
        recurringPaymentId: item.id,
        createdAt: now,
        updatedAt: now,
      );
      await _txRepo.createTransaction(tx);

      final nextDate = _calculateNextDueDate(item.nextDueDate, item.frequency);
      await db.update(
        'recurring_payments',
        {'next_due_date': nextDate.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await AppLogger.i(
        'Marked recurring payment ${item.name} as Paid and advanced due date',
      );
    } else if (action == 'Later') {
      final nextDate = item.nextDueDate.add(const Duration(days: 1));
      await db.update(
        'recurring_payments',
        {'next_due_date': nextDate.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } else if (action == "Don't remind") {
      final nextDate = _calculateNextDueDate(item.nextDueDate, item.frequency);
      await db.update(
        'recurring_payments',
        {'next_due_date': nextDate.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } else if (action == 'Delete') {
      await deleteRecurringPayment(item.id);
    }
  }

  /// BUG FIX: clamp the day to the last valid day of the target month so that
  /// e.g. Jan 31 → Feb 28 (not Mar 3) and Jan 31 → Mar 31 on the next cycle.
  DateTime _calculateNextDueDate(DateTime current, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      case 'monthly':
      default:
        final nextMonth = current.month + 1;
        final year = current.year + (nextMonth > 12 ? 1 : 0);
        final month = nextMonth > 12 ? 1 : nextMonth;
        // Last day of the target month: DateTime(year, month+1, 0).day
        final lastDayOfMonth = DateTime(year, month + 1, 0).day;
        final day = current.day.clamp(1, lastDayOfMonth);
        return DateTime(year, month, day);
    }
  }
}
