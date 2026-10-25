import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<List<({String keyword, String categoryId})>> getCategoryRules() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'category_rules',
      orderBy: 'LENGTH(keyword) DESC',
    );
    return maps
        .map(
          (m) => (
            keyword: (m['keyword'] as String).toLowerCase(),
            categoryId: m['category_id'] as String,
          ),
        )
        .toList();
  }

  Future<void> createCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.insert('categories', category.toMap());
    await AppLogger.info(
      'Category created',
      category: LogCategory.settings,
      details: 'id ${category.id}',
    );
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await AppLogger.info(
      'Category updated',
      category: LogCategory.settings,
      details: 'id ${category.id}',
    );
  }

  Future<void> deleteCategory(
    String categoryId, {
    String? replacementCategoryId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final txCount =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM transactions WHERE category_id = ? AND deleted_at IS NULL',
              [categoryId],
            ),
          ) ??
          0;

      if (txCount > 0) {
        if (replacementCategoryId == null) {
          throw Exception(
            'Cannot delete category with $txCount active transactions without selecting a replacement category.',
          );
        }
        await txn.update(
          'transactions',
          {'category_id': replacementCategoryId},
          where: 'category_id = ?',
          whereArgs: [categoryId],
        );
      }

      await txn.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    });
    await AppLogger.info(
      'Deleted category $categoryId',
      category: LogCategory.settings,
    );
  }
}
