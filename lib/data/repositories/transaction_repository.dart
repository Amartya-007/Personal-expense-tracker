import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/receipt_model.dart';
import '../models/tag_model.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<TransactionModel>> getTransactionsPaged({
    int limit = 30,
    int offset = 0,
    DateTime? cursorDate,
    String? cursorId,
    String? type,
    String? accountId,
    String? categoryId,
    String? paymentMethod,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['t.deleted_at IS NULL'];
    final whereArgs = <dynamic>[];

    if (cursorDate != null && cursorId != null) {
      whereClauses.add('(t.date < ? OR (t.date = ? AND t.id < ?))');
      whereArgs.add(cursorDate.millisecondsSinceEpoch);
      whereArgs.add(cursorDate.millisecondsSinceEpoch);
      whereArgs.add(cursorId);
    }

    if (type != null && type.isNotEmpty) {
      whereClauses.add('t.type = ?');
      whereArgs.add(type);
    }

    if (accountId != null && accountId.isNotEmpty) {
      whereClauses.add('(t.account_id = ? OR t.destination_account_id = ?)');
      whereArgs.add(accountId);
      whereArgs.add(accountId);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('t.category_id = ?');
      whereArgs.add(categoryId);
    }

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      whereClauses.add('t.payment_method = ?');
      whereArgs.add(paymentMethod);
    }

    if (startDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final cleanQuery = searchQuery.trim();
      try {
        final ftsRes = await db.rawQuery(
          'SELECT id FROM transactions_fts WHERE transactions_fts MATCH ?',
          ['$cleanQuery*'],
        );
        if (ftsRes.isNotEmpty) {
          final ftsIds = ftsRes.map((r) => r['id'] as String).toList();
          final placeholders = List.filled(ftsIds.length, '?').join(',');
          whereClauses.add('t.id IN ($placeholders)');
          whereArgs.addAll(ftsIds);
        } else {
          final term = '%$cleanQuery%';
          whereClauses.add(
            '(t.description LIKE ? OR t.note LIKE ? OR t.payment_method LIKE ? OR c.name LIKE ?)',
          );
          whereArgs.addAll([term, term, term, term]);
        }
      } catch (_) {
        final term = '%$cleanQuery%';
        whereClauses.add(
          '(t.description LIKE ? OR t.note LIKE ? OR t.payment_method LIKE ? OR c.name LIKE ?)',
        );
        whereArgs.addAll([term, term, term, term]);
      }
    }

    final whereSql = whereClauses.join(' AND ');
    final useOffset = cursorDate == null || cursorId == null;
    final sql =
        '''
      SELECT 
        t.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        a.name as account_name,
        da.name as destination_account_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts da ON t.destination_account_id = da.id
      WHERE $whereSql
      ORDER BY t.date DESC, t.id DESC
      LIMIT ? ${useOffset ? 'OFFSET ?' : ''}
    ''';

    whereArgs.add(limit);
    if (useOffset) whereArgs.add(offset);

    final maps = await db.rawQuery(sql, whereArgs);
    final list = <TransactionModel>[];
    for (final map in maps) {
      final txId = map['id'] as String;
      final tags = await _getTagsForTransaction(db, txId);
      final receipts = await _getReceiptsForTransaction(db, txId);
      list.add(TransactionModel.fromMap(map, tags: tags, receipts: receipts));
    }
    return list;
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    const sql =
        '''
      SELECT 
        t.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        a.name as account_name,
        da.name as destination_account_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts da ON t.destination_account_id = da.id
      WHERE t.id = ?
    ''';
    final maps = await db.rawQuery(sql, [id]);
    if (maps.isEmpty) return null;

    final tags = await _getTagsForTransaction(db, id);
    final receipts = await _getReceiptsForTransaction(db, id);
    return TransactionModel.fromMap(maps.first, tags: tags, receipts: receipts);
  }

  Future<void> createTransaction(TransactionModel tx) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', tx.toMap());
      await _applyBalanceImpact(txn, tx, isReversal: false);

      for (final tag in tx.tags) {
        final cleanName = tag.name.trim();
        if (cleanName.isEmpty) continue;

        final existing = await txn.query(
          'tags',
          where: 'LOWER(name) = LOWER(?)',
          whereArgs: [cleanName],
        );

        String tagId;
        if (existing.isNotEmpty) {
          tagId = existing.first['id'] as String;
        } else {
          tagId = tag.id;
          await txn.insert(
            'tags',
            {'id': tagId, 'name': cleanName},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn.insert('transaction_tags', {
          'transaction_id': tx.id,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final receipt in tx.receipts) {
        final fixedReceipt = ReceiptModel(
          id: receipt.id,
          transactionId: tx.id,
          filePath: receipt.filePath,
          thumbnailPath: receipt.thumbnailPath,
          createdAt: receipt.createdAt,
        );
        await txn.insert(
          'receipts',
          fixedReceipt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    if (tx.categoryId != null && tx.description.trim().isNotEmpty) {
      await learnCategoryRule(tx.description.trim(), tx.categoryId!);
    }

    await AppLogger.i('Created transaction: ${tx.description} (₹${tx.amount})');
  }

  Future<void> updateTransaction(TransactionModel newTx) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldTxMap = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [newTx.id],
      );
      if (oldTxMap.isNotEmpty) {
        final oldTx = TransactionModel.fromMap(oldTxMap.first);
        await _applyBalanceImpact(txn, oldTx, isReversal: true);
      }

      await _applyBalanceImpact(txn, newTx, isReversal: false);

      await txn.update(
        'transactions',
        newTx.toMap(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );

      await txn.delete(
        'transaction_tags',
        where: 'transaction_id = ?',
        whereArgs: [newTx.id],
      );
      for (final tag in newTx.tags) {
        final cleanName = tag.name.trim();
        if (cleanName.isEmpty) continue;

        final existing = await txn.query(
          'tags',
          where: 'LOWER(name) = LOWER(?)',
          whereArgs: [cleanName],
        );

        String tagId;
        if (existing.isNotEmpty) {
          tagId = existing.first['id'] as String;
        } else {
          tagId = tag.id;
          await txn.insert(
            'tags',
            {'id': tagId, 'name': cleanName},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn.insert('transaction_tags', {
          'transaction_id': newTx.id,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.delete(
        'receipts',
        where: 'transaction_id = ?',
        whereArgs: [newTx.id],
      );
      for (final receipt in newTx.receipts) {
        final fixedReceipt = ReceiptModel(
          id: receipt.id,
          transactionId: newTx.id,
          filePath: receipt.filePath,
          thumbnailPath: receipt.thumbnailPath,
          createdAt: receipt.createdAt,
        );
        await txn.insert(
          'receipts',
          fixedReceipt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await AppLogger.i('Updated transaction ${newTx.id}');
  }

  Future<void> softDeleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final maps = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return;

      final tx = TransactionModel.fromMap(maps.first);
      if (tx.deletedAt == null) {
        await _applyBalanceImpact(txn, tx, isReversal: true);
      }

      await txn.update(
        'transactions',
        {
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await AppLogger.i('Soft-deleted transaction $id');
  }

  Future<void> restoreTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final maps = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return;

      final tx = TransactionModel.fromMap(maps.first);
      await _applyBalanceImpact(txn, tx, isReversal: false);

      await txn.update(
        'transactions',
        {
          'deleted_at': null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await AppLogger.i('Restored transaction $id');
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final maps = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        final tx = TransactionModel.fromMap(maps.first);
        if (tx.deletedAt == null) {
          await _applyBalanceImpact(txn, tx, isReversal: true);
        }
      }

      final receiptMaps = await txn.query(
        'receipts',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      for (final rMap in receiptMaps) {
        final receipt = ReceiptModel.fromMap(rMap);
        try {
          final imgFile = File(receipt.filePath);
          if (await imgFile.exists()) await imgFile.delete();
          final thumbFile = File(receipt.thumbnailPath);
          if (await thumbFile.exists()) await thumbFile.delete();
        } catch (_) {}
      }

      await txn.delete(
        'receipts',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'transaction_tags',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
    await AppLogger.i(
      'Permanently deleted transaction $id and cleaned up receipts',
    );
  }

  Future<List<TransactionModel>> getSoftDeletedTransactions() async {
    final db = await _dbHelper.database;
    const sql =
        '''
      SELECT 
        t.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        a.name as account_name,
        da.name as destination_account_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts da ON t.destination_account_id = da.id
      WHERE t.deleted_at IS NOT NULL
      ORDER BY t.deleted_at DESC
    ''';
    final maps = await db.rawQuery(sql);
    final list = <TransactionModel>[];
    for (final map in maps) {
      final txId = map['id'] as String;
      final tags = await _getTagsForTransaction(db, txId);
      final receipts = await _getReceiptsForTransaction(db, txId);
      list.add(TransactionModel.fromMap(map, tags: tags, receipts: receipts));
    }
    return list;
  }

  Future<void> learnCategoryRule(String keyword, String categoryId) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('category_rules', {
        'id': _uuid.v4(),
        'keyword': keyword.toLowerCase(),
        'category_id': categoryId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<List<TagModel>> _getTagsForTransaction(
    DatabaseExecutor db,
    String txId,
  ) async {
    const sql =
        '''
      SELECT tag_id FROM transaction_tags WHERE transaction_id = ?
    ''';
    final maps = await db.rawQuery(sql, [txId]);
    if (maps.isEmpty) return [];

    final tagIds = maps.map((m) => m['tag_id'] as String).toList();
    final placeholders = List.filled(tagIds.length, '?').join(',');
    final tagMaps = await db.rawQuery(
      'SELECT * FROM tags WHERE id IN ($placeholders)',
      tagIds,
    );
    return tagMaps.map((m) => TagModel.fromMap(m)).toList();
  }

  Future<List<ReceiptModel>> _getReceiptsForTransaction(
    DatabaseExecutor db,
    String txId,
  ) async {
    const sql = '''
      SELECT * FROM receipts WHERE transaction_id = ?
    ''';
    final maps = await db.rawQuery(sql, [txId]);
    return maps.map((m) => ReceiptModel.fromMap(m)).toList();
  }

  Future<void> _applyBalanceImpact(
    DatabaseExecutor txn,
    TransactionModel tx, {
    bool isReversal = false,
  }) async {
    final mult = isReversal ? -1 : 1;

    if (tx.type == 'expense') {
      if (tx.paymentMethod != 'Cash') {
        final accMap = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );
        if (accMap.isNotEmpty) {
          final current = (accMap.first['current_balance'] as num).toDouble();
          final updated = current - (tx.amount * mult);
          await txn.update(
            'accounts',
            {
              'current_balance': updated,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [tx.accountId],
          );
        }
      }
    } else if (tx.type == 'income') {
      final accMap = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [tx.accountId],
      );
      if (accMap.isNotEmpty) {
        final current = (accMap.first['current_balance'] as num).toDouble();
        final updated = current + (tx.amount * mult);
        await txn.update(
          'accounts',
          {
            'current_balance': updated,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );
      }
    } else if (tx.type == 'transfer') {
      final fromAccMap = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [tx.accountId],
      );
      if (fromAccMap.isNotEmpty) {
        final current = (fromAccMap.first['current_balance'] as num).toDouble();
        final updated = current - (tx.amount * mult);
        await txn.update(
          'accounts',
          {
            'current_balance': updated,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );
      }

      if (tx.destinationAccountId != null) {
        final toAccMap = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [tx.destinationAccountId],
        );
        if (toAccMap.isNotEmpty) {
          final current = (toAccMap.first['current_balance'] as num).toDouble();
          final updated = current + (tx.amount * mult);
          await txn.update(
            'accounts',
            {
              'current_balance': updated,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [tx.destinationAccountId],
          );
        }
      }
    }
  }
}
