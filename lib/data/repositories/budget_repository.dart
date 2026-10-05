import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
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
          end: DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59, 999),
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

    final budgets = <BudgetModel>[];
    final now = DateTime.now();
    for (final map in maps) {
      final catId = map['category_id'] as String;
      final period = (map['period'] as String?) ?? 'monthly';
      final storedStart = DateTime.fromMillisecondsSinceEpoch(
        map['start_date'] as int,
      );
      final storedEnd = DateTime.fromMillisecondsSinceEpoch(
        map['end_date'] as int,
      );

      // Budgets roll over: measure spending in the *current* period window
      // rather than the dates the budget was created with.
      final window = currentWindow(period, storedStart, storedEnd, now: now);

      // Aggregated spent amount query
      final spentRes = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE category_id = ?
          AND date >= ?
          AND date <= ?
          AND type = 'expense'
          AND deleted_at IS NULL
      ''', [
        catId,
        window.start.millisecondsSinceEpoch,
        window.end.millisecondsSinceEpoch,
      ]);

      final spentAmount = (spentRes.first['total'] as num?)?.toDouble() ?? 0.0;
      budgets.add(
        BudgetModel.fromMap(map, spentAmount: spentAmount).copyWith(
          startDate: window.start,
          endDate: window.end,
        ),
      );
    }

    return budgets;
  }

  Future<void> createBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    await db.insert('budgets', budget.toMap());
    await AppLogger.i('Created budget for ${budget.categoryId}');
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
    await AppLogger.i('Updated budget ${budget.id}');
  }

  Future<void> deleteBudget(String id) async {
    final db = await _dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    await AppLogger.i('Deleted budget $id');
  }
}
