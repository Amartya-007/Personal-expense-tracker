import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';

class DevDataGenerator {
  static final Uuid _uuid = const Uuid();
  static final Random _rnd = Random();

  static const List<String> _descriptions = [
    'Swiggy Momos',
    'Zomato Pizza',
    'Amazon Shopping',
    'Uber Ride',
    'Mobile Recharge',
    'Electricity Bill',
    'Grocery Supermarket',
    'Coffee Cafe',
    'Bookstore Purchase',
    'Screen Protector',
    'Petrol Pump',
    'Pharmacy Medicines',
    'Movie Ticket',
    'Restaurant Dinner',
    'Freelance Payment',
    'Salary Credit',
    'Gym Subscription',
  ];

  static const List<String> _paymentMethods = ['UPI', 'Cash', 'Debit Card'];

  static Future<void> seedLargeDataset(int count) async {
    // BUG FIX: wrap in try/catch so a DB error is surfaced rather than silently
    // leaving the generator in a half-finished state.
    try {
      final db = await DatabaseHelper.instance.database;

      final accs = await db.query('accounts');
      if (accs.isEmpty) return;
      final accId = accs.first['id'] as String;

      // BUG FIX: query real category IDs from the DB instead of using hardcoded
      // string literals. Hardcoded IDs cause FK constraint failures when the
      // category was never seeded or uses a different ID scheme.
      final catRows = await db.query('categories', columns: ['id']);
      if (catRows.isEmpty) return;
      final catIds = catRows.map((r) => r['id'] as String).toList();

      final now = DateTime.now().millisecondsSinceEpoch;
      const batchSize = 1000;

      await AppLogger.i(
        'Starting dev data generator for $count transactions...',
      );

      for (int i = 0; i < count; i += batchSize) {
        await db.transaction((txn) async {
          final currentBatchCount = min(batchSize, count - i);
          for (int j = 0; j < currentBatchCount; j++) {
            final txId = _uuid.v4();
            final amount = (_rnd.nextInt(5000) + 10).toDouble();
            final desc = _descriptions[_rnd.nextInt(_descriptions.length)];
            final catId = catIds[_rnd.nextInt(catIds.length)];
            final pm = _paymentMethods[_rnd.nextInt(_paymentMethods.length)];
            final dateMs = now - _rnd.nextInt(365 * 24 * 3600 * 1000);

            await txn.insert('transactions', {
              'id': txId,
              'type': 'expense',
              'amount': amount,
              'description': desc,
              'category_id': catId,
              'payment_method': pm,
              'account_id': accId,
              'date': dateMs,
              'source': 'manual',
              'status': 'confirmed',
              'created_at': now,
              'updated_at': now,
            });
          }
        });
      }

      await AppLogger.i('Seeded $count transactions successfully.');
    } catch (e, st) {
      await AppLogger.e('seedLargeDataset failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
