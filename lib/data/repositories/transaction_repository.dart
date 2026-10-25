import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/receipt_model.dart';
import '../models/tag_model.dart';
import '../models/transaction_model.dart';
import '../models/transaction_split_model.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  ({String whereSql, List<dynamic> whereArgs}) _buildWhereClause({
    String? type,
    String? accountId,
    List<String>? accountIds,
    String? categoryId,
    List<String>? categoryIds,
    String? paymentMethod,
    List<String>? paymentMethods,
    List<String>? tagIds,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    bool? hasReceipt,
    bool? isRecurring,
    bool? hasNote,
    bool? hasLocation,
    String? searchQuery,
  }) {
    final whereClauses = <String>['t.deleted_at IS NULL'];
    final whereArgs = <dynamic>[];

    // Transaction Type
    if (type != null && type.isNotEmpty && type.toLowerCase() != 'all') {
      whereClauses.add('t.type = ?');
      whereArgs.add(type.toLowerCase());
    }

    // Categories (merge single categoryId into list if provided)
    final effectiveCatIds = <String>{
      if (categoryId != null && categoryId.isNotEmpty) categoryId,
      if (categoryIds != null) ...categoryIds.where((id) => id.isNotEmpty),
    }.toList();

    if (effectiveCatIds.isNotEmpty) {
      final hasUncategorized = effectiveCatIds.contains('uncategorized');
      final regularCatIds = effectiveCatIds
          .where((id) => id != 'uncategorized')
          .toList();

      final catClauses = <String>[];
      if (hasUncategorized) {
        catClauses.add('t.category_id IS NULL');
      }
      if (regularCatIds.isNotEmpty) {
        final placeholders = List.filled(regularCatIds.length, '?').join(',');
        catClauses.add('t.category_id IN ($placeholders)');
        whereArgs.addAll(regularCatIds);
        catClauses.add(
          't.id IN (SELECT transaction_id FROM transaction_splits WHERE category_id IN ($placeholders))',
        );
        whereArgs.addAll(regularCatIds);
      }
      whereClauses.add('(${catClauses.join(' OR ')})');
    }

    // Tags
    if (tagIds != null && tagIds.isNotEmpty) {
      final cleanTagIds = tagIds.where((id) => id.isNotEmpty).toList();
      if (cleanTagIds.isNotEmpty) {
        final placeholders = List.filled(cleanTagIds.length, '?').join(',');
        whereClauses.add(
          't.id IN (SELECT transaction_id FROM transaction_tags WHERE tag_id IN ($placeholders))',
        );
        whereArgs.addAll(cleanTagIds);
      }
    }

    // Accounts (merge single accountId into list if provided)
    final effectiveAccIds = <String>{
      if (accountId != null && accountId.isNotEmpty) accountId,
      if (accountIds != null) ...accountIds.where((id) => id.isNotEmpty),
    }.toList();

    if (effectiveAccIds.isNotEmpty) {
      final hasPrimary = effectiveAccIds.contains('primary');
      final regularAccIds = effectiveAccIds
          .where((id) => id != 'primary')
          .toList();

      final accClauses = <String>[];
      if (hasPrimary) {
        accClauses.add('a.is_primary = 1 OR da.is_primary = 1');
      }
      if (regularAccIds.isNotEmpty) {
        final placeholders = List.filled(regularAccIds.length, '?').join(',');
        accClauses.add('t.account_id IN ($placeholders)');
        whereArgs.addAll(regularAccIds);
        accClauses.add('t.destination_account_id IN ($placeholders)');
        whereArgs.addAll(regularAccIds);
      }
      whereClauses.add('(${accClauses.join(' OR ')})');
    }

    // Payment Methods (merge single paymentMethod into list if provided)
    final effectivePayments = <String>{
      if (paymentMethod != null && paymentMethod.isNotEmpty) paymentMethod,
      if (paymentMethods != null) ...paymentMethods.where((m) => m.isNotEmpty),
    }.where((m) => m.toLowerCase() != 'all').toList();

    if (effectivePayments.isNotEmpty) {
      final placeholders = List.filled(effectivePayments.length, '?').join(',');
      whereClauses.add('t.payment_method IN ($placeholders)');
      whereArgs.addAll(effectivePayments);
    }

    // Date Range
    if (startDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // Amount Range
    if (minAmount != null) {
      whereClauses.add('t.amount >= ?');
      whereArgs.add(minAmount);
    }
    if (maxAmount != null) {
      whereClauses.add('t.amount <= ?');
      whereArgs.add(maxAmount);
    }

    // Receipt presence
    if (hasReceipt != null) {
      if (hasReceipt) {
        whereClauses.add(
          'EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = t.id)',
        );
      } else {
        whereClauses.add(
          'NOT EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = t.id)',
        );
      }
    }

    // Recurring presence
    if (isRecurring != null) {
      if (isRecurring) {
        whereClauses.add(
          '(t.recurring_payment_id IS NOT NULL AND TRIM(t.recurring_payment_id) != "")',
        );
      } else {
        whereClauses.add(
          '(t.recurring_payment_id IS NULL OR TRIM(t.recurring_payment_id) = "")',
        );
      }
    }

    // Note presence
    if (hasNote != null) {
      if (hasNote) {
        whereClauses.add('(t.note IS NOT NULL AND TRIM(t.note) != "")');
      } else {
        whereClauses.add('(t.note IS NULL OR TRIM(t.note) = "")');
      }
    }

    // Location presence
    if (hasLocation != null) {
      if (hasLocation) {
        whereClauses.add(
          '(t.location_name IS NOT NULL AND TRIM(t.location_name) != "")',
        );
      } else {
        whereClauses.add(
          '(t.location_name IS NULL OR TRIM(t.location_name) = "")',
        );
      }
    }

    // Universal Search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim();
      final term = '%$query%';

      final searchClauses = <String>[
        't.description LIKE ?',
        't.note LIKE ?',
        't.payment_method LIKE ?',
        't.location_name LIKE ?',
        'c.name LIKE ?',
        'a.name LIKE ?',
        'da.name LIKE ?',
        't.id IN (SELECT tt.transaction_id FROM transaction_tags tt JOIN tags tg ON tt.tag_id = tg.id WHERE tg.name LIKE ?)',
        't.id IN (SELECT ts.transaction_id FROM transaction_splits ts LEFT JOIN categories sc ON ts.category_id = sc.id WHERE ts.note LIKE ? OR sc.name LIKE ?)',
      ];
      whereArgs.addAll([
        term,
        term,
        term,
        term,
        term,
        term,
        term,
        term,
        term,
        term,
      ]);

      // Check numeric query / amount match
      final cleanedNumStr = query.replaceAll(RegExp(r'[^\d.]'), '');
      final parsedNum = double.tryParse(cleanedNumStr);
      if (parsedNum != null && parsedNum > 0) {
        final lowerQuery = query.toLowerCase();
        if (lowerQuery.contains('above') ||
            lowerQuery.contains('more than') ||
            lowerQuery.startsWith('>')) {
          searchClauses.add('t.amount > ?');
          whereArgs.add(parsedNum);
        } else if (lowerQuery.contains('below') ||
            lowerQuery.contains('less than') ||
            lowerQuery.startsWith('<')) {
          searchClauses.add('t.amount < ?');
          whereArgs.add(parsedNum);
        } else {
          searchClauses.add('t.amount = ?');
          whereArgs.add(parsedNum);
          searchClauses.add('CAST(t.amount AS TEXT) LIKE ?');
          whereArgs.add('%$cleanedNumStr%');
        }
      }

      // Check year match like '2026'
      if (RegExp(r'^\d{4}$').hasMatch(query)) {
        searchClauses.add(
          "strftime('%Y', t.date / 1000, 'unixepoch', 'localtime') = ?",
        );
        whereArgs.add(query);
      }

      whereClauses.add('(${searchClauses.join(' OR ')})');
    }

    return (whereSql: whereClauses.join(' AND '), whereArgs: whereArgs);
  }

  Future<List<TransactionModel>> getTransactionsPaged({
    int limit = 30,
    int offset = 0,
    DateTime? cursorDate,
    String? cursorId,
    String? type,
    String? accountId,
    List<String>? accountIds,
    String? categoryId,
    List<String>? categoryIds,
    String? paymentMethod,
    List<String>? paymentMethods,
    List<String>? tagIds,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    bool? hasReceipt,
    bool? isRecurring,
    bool? hasNote,
    bool? hasLocation,
    String sortBy = 'dateDesc',
  }) async {
    final db = await _dbHelper.database;
    final (:whereSql, :whereArgs) = _buildWhereClause(
      type: type,
      accountId: accountId,
      accountIds: accountIds,
      categoryId: categoryId,
      categoryIds: categoryIds,
      paymentMethod: paymentMethod,
      paymentMethods: paymentMethods,
      tagIds: tagIds,
      startDate: startDate,
      endDate: endDate,
      minAmount: minAmount,
      maxAmount: maxAmount,
      hasReceipt: hasReceipt,
      isRecurring: isRecurring,
      hasNote: hasNote,
      hasLocation: hasLocation,
      searchQuery: searchQuery,
    );

    final finalWhereClauses = <String>[whereSql];
    final finalWhereArgs = List<dynamic>.from(whereArgs);

    if (cursorDate != null && cursorId != null && sortBy == 'dateDesc') {
      finalWhereClauses.add('(t.date < ? OR (t.date = ? AND t.id < ?))');
      finalWhereArgs.add(cursorDate.millisecondsSinceEpoch);
      finalWhereArgs.add(cursorDate.millisecondsSinceEpoch);
      finalWhereArgs.add(cursorId);
    }

    String orderBySql;
    switch (sortBy) {
      case 'dateAsc':
        orderBySql = 't.date ASC, t.id ASC';
        break;
      case 'amountDesc':
        orderBySql = 't.amount DESC, t.date DESC, t.id DESC';
        break;
      case 'amountAsc':
        orderBySql = 't.amount ASC, t.date DESC, t.id DESC';
        break;
      case 'titleAsc':
        orderBySql = 'LOWER(t.description) ASC, t.date DESC, t.id DESC';
        break;
      case 'titleDesc':
        orderBySql = 'LOWER(t.description) DESC, t.date DESC, t.id DESC';
        break;
      case 'dateDesc':
      default:
        orderBySql = 't.date DESC, t.id DESC';
        break;
    }

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
      WHERE ${finalWhereClauses.join(' AND ')}
      ORDER BY $orderBySql
      LIMIT ? OFFSET ?
    ''';

    finalWhereArgs.add(limit);
    finalWhereArgs.add(offset);

    final maps = await db.rawQuery(sql, finalWhereArgs);
    if (maps.isEmpty) return [];

    final txIds = maps.map((m) => m['id'] as String).toList();
    final batchResults = await Future.wait([
      _getBatchTags(db, txIds),
      _getBatchReceipts(db, txIds),
      _getBatchSplits(db, txIds),
    ]);
    final batchTags = batchResults[0] as Map<String, List<TagModel>>;
    final batchReceipts = batchResults[1] as Map<String, List<ReceiptModel>>;
    final batchSplits =
        batchResults[2] as Map<String, List<TransactionSplitModel>>;

    final list = <TransactionModel>[];
    for (final map in maps) {
      final txId = map['id'] as String;
      final tags = batchTags[txId] ?? const [];
      final receipts = batchReceipts[txId] ?? const [];
      final splits = batchSplits[txId] ?? const [];
      list.add(
        TransactionModel.fromMap(
          map,
          tags: tags,
          receipts: receipts,
          splits: splits,
        ),
      );
    }
    return list;
  }

  Future<({int count, double totalExpense, double totalIncome})>
  getFilteredSummary({
    String? type,
    String? accountId,
    List<String>? accountIds,
    String? categoryId,
    List<String>? categoryIds,
    String? paymentMethod,
    List<String>? paymentMethods,
    List<String>? tagIds,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    bool? hasReceipt,
    bool? isRecurring,
    bool? hasNote,
    bool? hasLocation,
    String? searchQuery,
  }) async {
    final db = await _dbHelper.database;
    final (:whereSql, :whereArgs) = _buildWhereClause(
      type: type,
      accountId: accountId,
      accountIds: accountIds,
      categoryId: categoryId,
      categoryIds: categoryIds,
      paymentMethod: paymentMethod,
      paymentMethods: paymentMethods,
      tagIds: tagIds,
      startDate: startDate,
      endDate: endDate,
      minAmount: minAmount,
      maxAmount: maxAmount,
      hasReceipt: hasReceipt,
      isRecurring: isRecurring,
      hasNote: hasNote,
      hasLocation: hasLocation,
      searchQuery: searchQuery,
    );

    final sql =
        '''
      SELECT 
        COUNT(*) as total_count,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as total_expense,
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) as total_income
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts da ON t.destination_account_id = da.id
      WHERE $whereSql
    ''';

    final res = await db.rawQuery(sql, whereArgs);
    if (res.isEmpty) {
      return (count: 0, totalExpense: 0.0, totalIncome: 0.0);
    }
    final row = res.first;
    return (
      count: (row['total_count'] as num? ?? 0).toInt(),
      totalExpense: (row['total_expense'] as num? ?? 0.0).toDouble(),
      totalIncome: (row['total_income'] as num? ?? 0.0).toDouble(),
    );
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    const sql = '''
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
    final splits = await _getSplitsForTransaction(db, id);
    return TransactionModel.fromMap(
      maps.first,
      tags: tags,
      receipts: receipts,
      splits: splits,
    );
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
          await txn.insert('tags', {
            'id': tagId,
            'name': cleanName,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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

      for (final split in tx.splits) {
        await txn.insert('transaction_splits', {
          'id': split.id.isEmpty ? _uuid.v4() : split.id,
          'transaction_id': tx.id,
          'category_id': split.categoryId,
          'amount': split.amount,
          'note': split.note,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    if (tx.categoryId != null && tx.description.trim().isNotEmpty) {
      await learnCategoryRule(tx.description.trim(), tx.categoryId!);
    }

    await AppLogger.info(
      'Transaction created',
      category: LogCategory.transactions,
      details: 'id ${tx.id}, type ${tx.type}',
    );
  }

  Future<void> updateTransaction(TransactionModel newTx) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldTxMap = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [newTx.id],
      );
      // A soft-deleted transaction's effect was already reversed when it was
      // deleted, so reversing it again (or applying a still-deleted one)
      // would move the balance for a transaction that no longer counts.
      if (oldTxMap.isNotEmpty) {
        final oldTx = TransactionModel.fromMap(oldTxMap.first);
        if (oldTx.deletedAt == null) {
          await _applyBalanceImpact(txn, oldTx, isReversal: true);
        }
      }

      if (newTx.deletedAt == null) {
        await _applyBalanceImpact(txn, newTx, isReversal: false);
      }

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
          await txn.insert('tags', {
            'id': tagId,
            'name': cleanName,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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

      await txn.delete(
        'transaction_splits',
        where: 'transaction_id = ?',
        whereArgs: [newTx.id],
      );
      for (final split in newTx.splits) {
        await txn.insert('transaction_splits', {
          'id': split.id.isEmpty ? _uuid.v4() : split.id,
          'transaction_id': newTx.id,
          'category_id': split.categoryId,
          'amount': split.amount,
          'note': split.note,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await AppLogger.info(
      'Updated transaction ${newTx.id}',
      category: LogCategory.transactions,
    );
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
    await AppLogger.info(
      'Soft-deleted transaction $id',
      category: LogCategory.transactions,
    );
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
      // Only a deleted transaction has had its effect reversed. Restoring one
      // that is already active (a double tap, or Undo after restoring from
      // Recently Deleted) must not apply it a second time.
      if (tx.deletedAt == null) return;
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
    await AppLogger.info(
      'Restored transaction $id',
      category: LogCategory.transactions,
    );
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
      await txn.delete(
        'transaction_splits',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
    await AppLogger.info(
      'Permanently deleted transaction $id and cleaned up receipts and splits',
      category: LogCategory.transactions,
    );
  }

  Future<List<TransactionModel>> getSoftDeletedTransactions() async {
    final db = await _dbHelper.database;
    const sql = '''
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
    if (maps.isEmpty) return [];

    final txIds = maps.map((m) => m['id'] as String).toList();
    final batchResults = await Future.wait([
      _getBatchTags(db, txIds),
      _getBatchReceipts(db, txIds),
      _getBatchSplits(db, txIds),
    ]);
    final batchTags = batchResults[0] as Map<String, List<TagModel>>;
    final batchReceipts = batchResults[1] as Map<String, List<ReceiptModel>>;
    final batchSplits =
        batchResults[2] as Map<String, List<TransactionSplitModel>>;

    final list = <TransactionModel>[];
    for (final map in maps) {
      final txId = map['id'] as String;
      final tags = batchTags[txId] ?? const [];
      final receipts = batchReceipts[txId] ?? const [];
      final splits = batchSplits[txId] ?? const [];
      list.add(
        TransactionModel.fromMap(
          map,
          tags: tags,
          receipts: receipts,
          splits: splits,
        ),
      );
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

  Future<Map<String, List<TagModel>>> _getBatchTags(
    DatabaseExecutor db,
    List<String> txIds,
  ) async {
    if (txIds.isEmpty) return {};
    const chunkSize = 200;
    final result = <String, List<TagModel>>{};

    for (var i = 0; i < txIds.length; i += chunkSize) {
      final chunk = txIds.sublist(
        i,
        i + chunkSize > txIds.length ? txIds.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final sql =
          '''
        SELECT tt.transaction_id, tg.*
        FROM transaction_tags tt
        JOIN tags tg ON tt.tag_id = tg.id
        WHERE tt.transaction_id IN ($placeholders)
      ''';
      final maps = await db.rawQuery(sql, chunk);
      for (final m in maps) {
        final txId = m['transaction_id'] as String;
        result.putIfAbsent(txId, () => []).add(TagModel.fromMap(m));
      }
    }
    return result;
  }

  Future<Map<String, List<ReceiptModel>>> _getBatchReceipts(
    DatabaseExecutor db,
    List<String> txIds,
  ) async {
    if (txIds.isEmpty) return {};
    const chunkSize = 200;
    final result = <String, List<ReceiptModel>>{};

    for (var i = 0; i < txIds.length; i += chunkSize) {
      final chunk = txIds.sublist(
        i,
        i + chunkSize > txIds.length ? txIds.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final sql =
          '''
        SELECT * FROM receipts WHERE transaction_id IN ($placeholders)
      ''';
      final maps = await db.rawQuery(sql, chunk);
      for (final m in maps) {
        final txId = m['transaction_id'] as String;
        result.putIfAbsent(txId, () => []).add(ReceiptModel.fromMap(m));
      }
    }
    return result;
  }

  Future<Map<String, List<TransactionSplitModel>>> _getBatchSplits(
    DatabaseExecutor db,
    List<String> txIds,
  ) async {
    if (txIds.isEmpty) return {};
    const chunkSize = 200;
    final result = <String, List<TransactionSplitModel>>{};

    for (var i = 0; i < txIds.length; i += chunkSize) {
      final chunk = txIds.sublist(
        i,
        i + chunkSize > txIds.length ? txIds.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final sql =
          '''
        SELECT s.*, c.name as category_name
        FROM transaction_splits s
        LEFT JOIN categories c ON s.category_id = c.id
        WHERE s.transaction_id IN ($placeholders)
      ''';
      final maps = await db.rawQuery(sql, chunk);
      for (final m in maps) {
        final txId = m['transaction_id'] as String;
        result
            .putIfAbsent(txId, () => [])
            .add(TransactionSplitModel.fromMap(m));
      }
    }
    return result;
  }

  Future<List<TagModel>> _getTagsForTransaction(
    DatabaseExecutor db,
    String txId,
  ) async {
    const sql = '''
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

  Future<List<TransactionSplitModel>> _getSplitsForTransaction(
    DatabaseExecutor db,
    String txId,
  ) async {
    const sql = '''
      SELECT s.*, c.name as category_name
      FROM transaction_splits s
      LEFT JOIN categories c ON s.category_id = c.id
      WHERE s.transaction_id = ?
    ''';
    final maps = await db.rawQuery(sql, [txId]);
    return maps.map((m) => TransactionSplitModel.fromMap(m)).toList();
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
