import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/log_entry.dart';
import '../../core/logging/log_filter.dart';
import '../../core/logging/log_sink.dart';

/// SQLite access for the local diagnostic log (`app_logs`).
///
/// This class must never call `AppLogger`: it is the logger's own sink, so
/// logging from here would feed back into itself.
class LogRepository implements LogSink {
  // Resolved lazily: this is created while DatabaseHelper itself is being
  // constructed.
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Stores [entries] in one transaction, in order.
  @override
  Future<void> writeBatch(List<AppLogEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('app_logs', entry.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<void> insert(AppLogEntry entry) => writeBatch([entry]);

  /// Newest first. The filter is applied in SQL and only one page is read.
  Future<List<AppLogEntry>> getLogs({
    LogFilter filter = const LogFilter(),
    int limit = AppConstants.logPageSize,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = _where(filter);
    final rows = await db.query(
      'app_logs',
      where: where.clause,
      whereArgs: where.args,
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AppLogEntry.fromMap).toList();
  }

  Future<int> count({LogFilter filter = const LogFilter()}) async {
    final db = await _db;
    final where = _where(filter);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM app_logs'
      '${where.clause == null ? '' : ' WHERE ${where.clause}'}',
      where.args,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<AppLogEntry?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'app_logs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : AppLogEntry.fromMap(rows.first);
  }

  /// Returns how many rows were removed (0 or 1).
  Future<int> deleteById(int id) async {
    final db = await _db;
    return db.delete('app_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Removes every log. Returns how many were removed.
  Future<int> clearAll() async {
    final db = await _db;
    return db.delete('app_logs');
  }

  /// Retention: keeps the newest [maxEntries] rows. The cut point is found
  /// through the primary key, so this stays cheap on a full table.
  @override
  Future<void> trim([int maxEntries = AppConstants.maxLogEntries]) async {
    final db = await _db;
    await db.rawDelete(
      'DELETE FROM app_logs WHERE id <= '
      '(SELECT id FROM app_logs ORDER BY id DESC LIMIT 1 OFFSET ?)',
      [maxEntries],
    );
  }

  ({String? clause, List<Object?> args}) _where(LogFilter filter) {
    final clauses = <String>[];
    final args = <Object?>[];

    final level = filter.level;
    if (level != null) {
      clauses.add('level = ?');
      args.add(level.value);
    }
    final category = filter.category;
    if (category != null) {
      clauses.add('category = ?');
      args.add(category.value);
    }
    final query = filter.normalizedQuery;
    if (query != null) {
      final like = '%${_escapeLike(query)}%';
      clauses.add(
        "(message LIKE ? ESCAPE '\\' OR category LIKE ? ESCAPE '\\')",
      );
      args
        ..add(like)
        ..add(like);
    }

    return (clause: clauses.isEmpty ? null : clauses.join(' AND '), args: args);
  }

  /// Makes `%`, `_` and `\` in the search text match themselves.
  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
