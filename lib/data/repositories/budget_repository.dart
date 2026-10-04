import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/budget_model.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
    for (final map in maps) {
      final catId = map['category_id'] as String;
      final startDate = map['start_date'] as int;
      final endDate = map['end_date'] as int;

      // Aggregated spent amount query
      final spentRes = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE category_id = ?
          AND date >= ?
          AND date <= ?
          AND type = 'expense'
          AND deleted_at IS NULL
      ''', [catId, startDate, endDate]);

      final spentAmount = (spentRes.first['total'] as num?)?.toDouble() ?? 0.0;
      budgets.add(BudgetModel.fromMap(map, spentAmount: spentAmount));
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
