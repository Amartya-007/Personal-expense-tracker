import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/expense_split_model.dart';
import '../models/khata_entry_model.dart';
import '../models/split_participant_model.dart';

class ExpenseSplitRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  ExpenseSplitRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Creates a new expense split record and its associated participant allocations.
  ///
  /// Preserves historical participant snapshots (name and phone).
  /// If [recordInKhataLedger] is true, records the corresponding peer debt in
  /// `khata_entries` so that the person's ledger balance accurately reflects what they owe.
  Future<ExpenseSplitModel> createSplit({
    required ExpenseSplitModel split,
    required List<SplitParticipantModel> participants,
    bool recordInKhataLedger = false,
    String? accountId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final splitId = split.id.isEmpty ? _uuid.v4() : split.id;

    final updatedSplit = split.copyWith(
      id: splitId,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('expense_splits', updatedSplit.toMap());

      for (final p in participants) {
        final participantId = p.id.isEmpty ? _uuid.v4() : p.id;
        final participant = p.copyWith(
          id: participantId,
          splitId: splitId,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert('split_participants', participant.toMap());

        // Optional synchronization with Khata peer ledger
        if (recordInKhataLedger && participant.personId != null) {
          if (updatedSplit.isUserPayer && !participant.isUser && !participant.isPayer) {
            // User paid for this person -> Person owes user (Lent)
            if (participant.allocatedAmount > 0) {
              final entry = KhataEntryModel(
                id: _uuid.v4(),
                personId: participant.personId!,
                type: KhataEntryType.lent,
                amount: participant.allocatedAmount,
                sign: 1,
                date: updatedSplit.date,
                notes: 'Split: ${updatedSplit.title}',
                accountId: accountId,
                isSettled: false,
                createdAt: now,
                updatedAt: now,
              );
              await txn.insert('khata_entries', entry.toMap());
            }
          } else if (!updatedSplit.isUserPayer &&
              participant.isUser &&
              updatedSplit.payerPersonId != null) {
            // Person paid for user -> User owes person (Borrowed)
            if (participant.allocatedAmount > 0) {
              final entry = KhataEntryModel(
                id: _uuid.v4(),
                personId: updatedSplit.payerPersonId!,
                type: KhataEntryType.borrowed,
                amount: participant.allocatedAmount,
                sign: -1,
                date: updatedSplit.date,
                notes: 'Split: ${updatedSplit.title}',
                accountId: accountId,
                isSettled: false,
                createdAt: now,
                updatedAt: now,
              );
              await txn.insert('khata_entries', entry.toMap());
            }
          }
        }
      }
    });

    await AppLogger.info(
      'Created expense split',
      category: LogCategory.database,
      details: 'id: $splitId, title: ${split.title}, total: ${split.totalAmount}',
    );

    return getSplitById(splitId).then((s) => s ?? updatedSplit);
  }

  /// Fetches splits filtered by optional [groupId] or [personId].
  Future<List<ExpenseSplitModel>> getSplits({
    String? groupId,
    String? personId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic> whereArgs = [];

    if (groupId != null) {
      where = 's.group_id = ?';
      whereArgs.add(groupId);
    } else if (personId != null) {
      where =
          's.id IN (SELECT split_id FROM split_participants WHERE person_id = ?)';
      whereArgs.add(personId);
    }

    final sql = '''
      SELECT 
        s.*,
        g.name AS group_name,
        p.name AS payer_name
      FROM expense_splits s
      LEFT JOIN expense_groups g ON s.group_id = g.id
      LEFT JOIN khata_people p ON s.payer_person_id = p.id
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY s.date DESC, s.created_at DESC
      LIMIT ? OFFSET ?
    ''';
    whereArgs.addAll([limit, offset]);

    final rows = await db.rawQuery(sql, whereArgs);
    final splits = <ExpenseSplitModel>[];

    for (final row in rows) {
      final splitId = row['id'] as String;
      final participantRows = await db.query(
        'split_participants',
        where: 'split_id = ?',
        whereArgs: [splitId],
        orderBy: 'is_payer DESC, allocated_amount DESC',
      );
      final participants =
          participantRows.map((pr) => SplitParticipantModel.fromMap(pr)).toList();

      splits.add(ExpenseSplitModel.fromMap(row, participants: participants));
    }

    return splits;
  }

  /// Gets a single split by [id] with all its participants.
  Future<ExpenseSplitModel?> getSplitById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        s.*,
        g.name AS group_name,
        p.name AS payer_name
      FROM expense_splits s
      LEFT JOIN expense_groups g ON s.group_id = g.id
      LEFT JOIN khata_people p ON s.payer_person_id = p.id
      WHERE s.id = ?
      LIMIT 1
    ''', [id]);

    if (rows.isEmpty) return null;

    final participantRows = await db.query(
      'split_participants',
      where: 'split_id = ?',
      whereArgs: [id],
      orderBy: 'is_payer DESC, allocated_amount DESC',
    );
    final participants =
        participantRows.map((pr) => SplitParticipantModel.fromMap(pr)).toList();

    return ExpenseSplitModel.fromMap(rows.first, participants: participants);
  }

  /// Updates an existing split and replaces its participant allocations.
  Future<void> updateSplit({
    required ExpenseSplitModel split,
    required List<SplitParticipantModel> participants,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'expense_splits',
        {
          'title': split.title.trim(),
          'total_amount': split.totalAmount,
          'payer_type': split.payerType,
          'payer_person_id': split.payerPersonId,
          'group_id': split.groupId,
          'split_mode': split.splitMode.toDbString(),
          'date': split.date.millisecondsSinceEpoch,
          'notes': split.notes?.trim().isEmpty == true ? null : split.notes?.trim(),
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [split.id],
      );

      // Re-insert participants
      await txn.delete(
        'split_participants',
        where: 'split_id = ?',
        whereArgs: [split.id],
      );

      for (final p in participants) {
        final participant = p.copyWith(
          id: p.id.isEmpty ? _uuid.v4() : p.id,
          splitId: split.id,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert('split_participants', participant.toMap());
      }
    });

    await AppLogger.info(
      'Updated expense split',
      category: LogCategory.database,
      details: 'id: ${split.id}',
    );
  }

  /// Deletes an expense split and its participants.
  Future<void> deleteSplit(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'expense_splits',
      where: 'id = ?',
      whereArgs: [id],
    );
    await AppLogger.info(
      'Deleted expense split',
      category: LogCategory.database,
      details: 'id: $id',
    );
  }

  /// Marks a specific participant as settled or unsettled.
  Future<void> setParticipantSettled(String participantId, bool settled) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'split_participants',
        {
          'is_settled': settled ? 1 : 0,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [participantId],
      );

      // Check if all non-payer participants in this split are settled
      final pRow = await txn.query(
        'split_participants',
        columns: ['split_id'],
        where: 'id = ?',
        whereArgs: [participantId],
      );
      if (pRow.isNotEmpty) {
        final splitId = pRow.first['split_id'] as String;
        final unsettled = await txn.query(
          'split_participants',
          where: 'split_id = ? AND is_settled = 0 AND is_payer = 0',
          whereArgs: [splitId],
        );
        await txn.update(
          'expense_splits',
          {
            'is_settled': unsettled.isEmpty ? 1 : 0,
            'updated_at': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [splitId],
        );
      }
    });
  }
}
