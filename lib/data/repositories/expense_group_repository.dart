import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/expense_group_model.dart';
import '../models/khata_person_model.dart';

class ExpenseGroupRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  ExpenseGroupRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Creates a new group and optionally associates initial members.
  Future<ExpenseGroupModel> createGroup({
    required String name,
    String? description,
    String? icon,
    String? color,
    List<String> memberPersonIds = const [],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final groupId = _uuid.v4();

    final group = ExpenseGroupModel(
      id: groupId,
      name: trimmedName,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      icon: icon,
      color: color,
      isArchived: false,
      memberCount: memberPersonIds.toSet().length,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('expense_groups', group.toMap());

      final uniqueIds = memberPersonIds.toSet();
      for (final personId in uniqueIds) {
        await txn.insert(
          'group_members',
          {
            'id': _uuid.v4(),
            'group_id': groupId,
            'person_id': personId,
            'created_at': now.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });

    await AppLogger.info(
      'Created expense group',
      category: LogCategory.database,
      details: 'name: ${group.name}, id: ${group.id}',
    );

    return getGroupById(groupId).then((g) => g ?? group);
  }

  /// Updates group details and optionally syncs group membership.
  Future<void> updateGroup({
    required String id,
    required String name,
    String? description,
    String? icon,
    String? color,
    List<String>? memberPersonIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'expense_groups',
        {
          'name': trimmedName,
          'description':
              description?.trim().isEmpty == true ? null : description?.trim(),
          'icon': icon,
          'color': color,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (memberPersonIds != null) {
        // Remove members not in the new list
        final uniqueIds = memberPersonIds.toSet();
        if (uniqueIds.isEmpty) {
          await txn.delete(
            'group_members',
            where: 'group_id = ?',
            whereArgs: [id],
          );
        } else {
          final placeholders = List.filled(uniqueIds.length, '?').join(',');
          await txn.delete(
            'group_members',
            where:
                'group_id = ? AND person_id NOT IN ($placeholders)',
            whereArgs: [id, ...uniqueIds],
          );
          for (final personId in uniqueIds) {
            await txn.insert(
              'group_members',
              {
                'id': _uuid.v4(),
                'group_id': id,
                'person_id': personId,
                'created_at': now.millisecondsSinceEpoch,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });

    await AppLogger.info(
      'Updated expense group',
      category: LogCategory.database,
      details: 'id: $id, name: $trimmedName',
    );
  }

  /// Fetches all expense groups with their member counts.
  Future<List<ExpenseGroupModel>> getGroups({
    bool includeArchived = false,
  }) async {
    final db = await _dbHelper.database;
    final where = includeArchived ? null : 'g.is_archived = 0';

    final rows = await db.rawQuery('''
      SELECT 
        g.*,
        COUNT(m.person_id) AS member_count
      FROM expense_groups g
      LEFT JOIN group_members m ON g.id = m.group_id
      ${where != null ? 'WHERE $where' : ''}
      GROUP BY g.id
      ORDER BY g.updated_at DESC, g.name ASC
    ''');

    return rows.map((r) => ExpenseGroupModel.fromMap(r)).toList();
  }

  /// Gets a single group by ID including its populated members list.
  Future<ExpenseGroupModel?> getGroupById(String id) async {
    final db = await _dbHelper.database;
    final groupRows = await db.query(
      'expense_groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (groupRows.isEmpty) return null;

    final members = await getGroupMembers(id);
    return ExpenseGroupModel.fromMap(
      groupRows.first,
      memberCount: members.length,
      members: members,
    );
  }

  /// Gets the list of [KhataPersonModel] members belonging to [groupId].
  Future<List<KhataPersonModel>> getGroupMembers(String groupId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        p.*,
        COALESCE(SUM(e.amount * e.sign), 0.0) AS net_balance,
        MAX(e.date) AS last_entry_date
      FROM group_members m
      JOIN khata_people p ON m.person_id = p.id
      LEFT JOIN khata_entries e ON p.id = e.person_id
      WHERE m.group_id = ? AND p.is_archived = 0
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE ASC
    ''', [groupId]);

    return rows.map((r) => KhataPersonModel.fromMap(r)).toList();
  }

  /// Adds members to a group without removing existing ones.
  Future<void> addMembers(String groupId, List<String> personIds) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (final personId in personIds.toSet()) {
        await txn.insert(
          'group_members',
          {
            'id': _uuid.v4(),
            'group_id': groupId,
            'person_id': personId,
            'created_at': now.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.update(
        'expense_groups',
        {'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [groupId],
      );
    });
  }

  /// Removes a person from a group.
  ///
  /// Historical expense splits referencing this person or group are completely preserved.
  Future<void> removeMember(String groupId, String personId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'group_members',
      where: 'group_id = ? AND person_id = ?',
      whereArgs: [groupId, personId],
    );
  }

  /// Archives a group.
  Future<void> archiveGroup(String groupId) async {
    final db = await _dbHelper.database;
    await db.update(
      'expense_groups',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  /// Restores an archived group.
  Future<void> restoreGroup(String groupId) async {
    final db = await _dbHelper.database;
    await db.update(
      'expense_groups',
      {
        'is_archived': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  /// Deletes a group permanently.
  ///
  /// Existing splits and transactions are preserved (foreign key sets group_id to null).
  Future<void> deleteGroup(String groupId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'expense_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
    await AppLogger.info(
      'Deleted expense group',
      category: LogCategory.database,
      details: 'id: $groupId',
    );
  }
}
