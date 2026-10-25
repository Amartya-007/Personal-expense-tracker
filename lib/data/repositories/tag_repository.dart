import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/tag_model.dart';

class TagRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<TagModel>> getAllTags() async {
    final db = await _dbHelper.database;
    final maps = await db.query('tags', orderBy: 'name ASC');
    return maps.map((m) => TagModel.fromMap(m)).toList();
  }

  Future<void> createTag(TagModel tag) async {
    final db = await _dbHelper.database;
    await db.insert('tags', tag.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    await AppLogger.info('Tag created', category: LogCategory.settings, details: 'id ${tag.id}');
  }

  Future<void> deleteTag(String id) async {
    final db = await _dbHelper.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
    await AppLogger.info('Deleted tag $id', category: LogCategory.settings);
  }
}
