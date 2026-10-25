import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/budget_model.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Calendar-aligned window for a budget's current period: weekly is
  /// Monday to Sunday, monthly the calendar month, yearly the calendar year.
  /// Custom budgets keep their stored range.
  static ({DateTime start, DateTime end}) currentWindow(
    String period,
    DateTime storedStart,
    DateTime storedEnd, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    switch (period) {
      case 'weekly':
        final monday = DateTime(n.year, n.month, n.day - (n.weekday - 1));
        return (
          start: monday,
          end: DateTime(
            monday.year,
            monday.month,
            monday.day + 6,
            23,
            59,
            59,
            999,
          ),
        );
      case 'monthly':
        return (
          start: DateTime(n.year, n.month, 1),
          end: DateTime(n.year, n.month + 1, 0, 23, 59, 59, 999),
        );
      case 'yearly':
        return (
          start: DateTime(n.year, 1, 1),
          end: DateTime(n.year, 12, 31, 23, 59, 59, 999),
        );
      default:
        return (start: storedStart, end: storedEnd);
    }
  }

  Future<List<BudgetModel>> getActiveBudgets() async {
    final db = await _dbHelper.database;
    final sql = '''
      SELECT 
        b.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color
      FROM budgets b
      INNER JOIN categories c ON b.category_id = c.id
      ORDER BY b.created_at DESC
    ''';
    final maps = await db.rawQuery(sql);
    if (maps.isEmpty) return [];

    final now = DateTime.now();
    final items =
        <
          ({Map<String, dynamic> map, ({DateTime start, DateTime end}) window})
        >[];
    for (final map in maps) {
      final period = (map['period'] as String?) ?? 'monthly';
      final storedStart = DateTime.fromMillisecondsSinceEpoch(
        map['start_date'] as int,
      );
      final storedEnd = DateTime.fromMillisecondsSinceEpoch(
        map['end_date'] as int,
      );
      final window = currentWindow(period, storedStart, storedEnd, now: now);
      items.add((map: map, window: window));
    }

    final spentAmounts = await Future.wait([
      for (final item in items)
        _calculateCategorySpent(
          db,
          item.map['category_id'] as String,
          item.window.start.millisecondsSinceEpoch,
          item.window.end.millisecondsSinceEpoch,
        ),
    ]);

    final budgets = <BudgetModel>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final spentAmount = spentAmounts[i];
      budgets.add(
        BudgetModel.fromMap(
          item.map,
          spentAmount: spentAmount,
        ).copyWith(startDate: item.window.start, endDate: item.window.end),
      );
    }

    return budgets;
  }

  Future<double> _calculateCategorySpent(
    DatabaseExecutor db,
    String categoryId,
    int startMs,
    int endMs,
  ) async {
    final res = await db.rawQuery(
      '''
      SELECT SUM(amt) as total FROM (
        SELECT amount as amt FROM transactions
        WHERE category_id = ?
          AND id NOT IN (SELECT transaction_id FROM transaction_splits)
          AND date >= ? AND date <= ?
          AND type = 'expense' AND deleted_at IS NULL
        UNION ALL
        SELECT s.amount as amt FROM transaction_splits s
        INNER JOIN transactions t ON s.transaction_id = t.id
        WHERE s.category_id = ?
          AND t.date >= ? AND t.date <= ?
          AND t.type = 'expense' AND t.deleted_at IS NULL
      )
    ''',
      [categoryId, startMs, endMs, categoryId, startMs, endMs],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> createBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    await db.insert('budgets', budget.toMap());
    await AppLogger.info(
      'Budget created',
      category: LogCategory.budgets,
      details: 'id ${budget.id}, period ${budget.period}',
    );
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
    await AppLogger.info(
      'Updated budget ${budget.id}',
      category: LogCategory.budgets,
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await _dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    await AppLogger.info('Deleted budget $id', category: LogCategory.budgets);
  }
}
