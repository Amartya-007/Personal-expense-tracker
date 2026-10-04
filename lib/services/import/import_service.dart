import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/account_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../sms/duplicate_detector.dart';

class ImportErrorRow {
  final int rowIndex;
  final String message;

  ImportErrorRow({required this.rowIndex, required this.message});
}

class CsvPreviewResult {
  final int totalRows;
  final int validCount;
  final int duplicateCount;
  final int rejectedCount;
  final List<TransactionModel> validTransactions;
  final List<ImportErrorRow> errors;

  CsvPreviewResult({
    required this.totalRows,
    required this.validCount,
    required this.duplicateCount,
    required this.rejectedCount,
    required this.validTransactions,
    required this.errors,
  });
}

class JsonPreviewResult {
  final bool isValid;
  final String? version;
  final int accountCount;
  final int categoryCount;
  final int transactionCount;
  final int budgetCount;
  final int recurringCount;
  final String? errorMessage;

  JsonPreviewResult({
    required this.isValid,
    this.version,
    this.accountCount = 0,
    this.categoryCount = 0,
    this.transactionCount = 0,
    this.budgetCount = 0,
    this.recurringCount = 0,
    this.errorMessage,
  });
}

class ImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DuplicateDetector _duplicateDetector = DuplicateDetector();
  final Uuid _uuid = const Uuid();

  /// Previews a CSV file for import without writing any data to database.
  Future<CsvPreviewResult> previewCsvImport(File csvFile) async {
    try {
      final content = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty || rows.length < 2) {
        return CsvPreviewResult(
          totalRows: 0,
          validCount: 0,
          duplicateCount: 0,
          rejectedCount: 0,
          validTransactions: [],
          errors: [ImportErrorRow(rowIndex: 0, message: 'CSV file is empty or missing data rows.')],
        );
      }

      final db = await _dbHelper.database;
      final accountMaps = await db.query('accounts');
      final categoryMaps = await db.query('categories');

      final accounts = accountMaps.map((m) => AccountModel.fromMap(m)).toList();
      final categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();

      final defaultAcc = accounts.isNotEmpty ? accounts.first : null;
      final defaultCat = categories.isNotEmpty ? categories.first : null;

      final validTxs = <TransactionModel>[];
      final errors = <ImportErrorRow>[];
      int duplicateCount = 0;
      int rejectedCount = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        if (row.length < 4) {
          rejectedCount++;
          errors.add(ImportErrorRow(rowIndex: i + 1, message: 'Insufficient columns (expected at least Date, Type, Amount, Description).'));
          continue;
        }

        try {
          final dateStr = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
          final typeStr = row.length > 2 ? row[2]?.toString().toLowerCase().trim() ?? 'expense' : 'expense';
          final amountVal = double.tryParse(row[3]?.toString().replaceAll(',', '').trim() ?? '') ?? 0.0;
          final descStr = row.length > 4 ? row[4]?.toString().trim() ?? '' : 'Imported Expense';

          if (amountVal <= 0) {
            rejectedCount++;
            errors.add(ImportErrorRow(rowIndex: i + 1, message: 'Invalid or non-positive amount ($amountVal).'));
            continue;
          }

          if (descStr.isEmpty) {
            rejectedCount++;
            errors.add(ImportErrorRow(rowIndex: i + 1, message: 'Description cannot be empty.'));
            continue;
          }

          DateTime date = DateTime.now();
          if (dateStr.isNotEmpty) {
            try {
              date = DateTime.parse(dateStr);
            } catch (_) {
              final ms = int.tryParse(dateStr);
              if (ms != null) {
                date = DateTime.fromMillisecondsSinceEpoch(ms);
              }
            }
          }

          final type = (typeStr == 'income' || typeStr == 'transfer') ? typeStr : 'expense';
          final catName = row.length > 5 ? row[5]?.toString().trim() ?? '' : '';
          final pmStr = row.length > 6 ? row[6]?.toString().trim() ?? 'UPI' : 'UPI';
          final accName = row.length > 7 ? row[7]?.toString().trim() ?? '' : '';
          final noteStr = row.length > 9 ? row[9]?.toString().trim() : null;

          final matchedCat = categories.firstWhere(
            (c) => c.name.toLowerCase() == catName.toLowerCase(),
            orElse: () => defaultCat ?? CategoryModel(id: 'cat_general', name: 'General', icon: 'category', color: 0xFF9E9E9E, type: 'expense', createdAt: DateTime.now()),
          );

          final matchedAcc = accounts.firstWhere(
            (a) => a.name.toLowerCase() == accName.toLowerCase(),
            orElse: () => defaultAcc ?? AccountModel(id: 'acc_default', name: 'Default Account', currentBalance: 0, initialBalance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
          );

          final isDup = await _duplicateDetector.isDuplicate(
            amount: amountVal,
            date: date,
          );

          if (isDup) {
            duplicateCount++;
            continue;
          }

          final tx = TransactionModel(
            id: _uuid.v4(),
            type: type,
            amount: amountVal,
            description: descStr,
            categoryId: matchedCat.id,
            paymentMethod: pmStr.isNotEmpty ? pmStr : 'UPI',
            accountId: matchedAcc.id,
            date: date,
            note: noteStr,
            source: 'csv_import',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          validTxs.add(tx);
        } catch (e) {
          rejectedCount++;
          errors.add(ImportErrorRow(rowIndex: i + 1, message: 'Parse failure: $e'));
        }
      }

      return CsvPreviewResult(
        totalRows: rows.length - 1,
        validCount: validTxs.length,
        duplicateCount: duplicateCount,
        rejectedCount: rejectedCount,
        validTransactions: validTxs,
        errors: errors,
      );
    } catch (e, st) {
      await AppLogger.e('previewCsvImport failed', error: e, stackTrace: st);
      return CsvPreviewResult(
        totalRows: 0,
        validCount: 0,
        duplicateCount: 0,
        rejectedCount: 0,
        validTransactions: [],
        errors: [ImportErrorRow(rowIndex: 0, message: 'Could not read CSV file: $e')],
      );
    }
  }

  /// Executes CSV import inside an atomic SQLite transaction.
  Future<bool> executeCsvImport(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) return true;

    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        for (final tx in transactions) {
          await txn.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

          // Update account balance
          final mult = tx.type == 'income' ? 1 : -1;
          if (tx.paymentMethod != 'Cash') {
            await txn.rawUpdate(
              'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
              [mult * tx.amount, tx.accountId],
            );
          }
        }
      });
      await AppLogger.i('Successfully executed CSV import for ${transactions.length} transactions.');
      return true;
    } catch (e, st) {
      await AppLogger.e('executeCsvImport failed and rolled back', error: e, stackTrace: st);
      return false;
    }
  }

  /// Previews structured JSON application data for import.
  Future<JsonPreviewResult> previewJsonImport(File jsonFile) async {
    try {
      final text = await jsonFile.readAsString();
      final Map<String, dynamic> data = jsonDecode(text);

      final version = data['version']?.toString() ?? '1';
      final accounts = (data['accounts'] as List?)?.length ?? 0;
      final categories = (data['categories'] as List?)?.length ?? 0;
      final transactions = (data['transactions'] as List?)?.length ?? 0;
      final budgets = (data['budgets'] as List?)?.length ?? 0;
      final recurring = (data['recurring_payments'] as List?)?.length ?? 0;

      return JsonPreviewResult(
        isValid: true,
        version: version,
        accountCount: accounts,
        categoryCount: categories,
        transactionCount: transactions,
        budgetCount: budgets,
        recurringCount: recurring,
      );
    } catch (e) {
      return JsonPreviewResult(
        isValid: false,
        errorMessage: 'Invalid JSON data: $e',
      );
    }
  }

  /// Executes structured JSON application data import inside an atomic transaction.
  Future<bool> executeJsonImport(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        if (data['accounts'] is List) {
          for (final item in data['accounts']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('accounts', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['categories'] is List) {
          for (final item in data['categories']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('categories', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['tags'] is List) {
          for (final item in data['tags']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('tags', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['transactions'] is List) {
          for (final item in data['transactions']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('transactions', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['transaction_tags'] is List) {
          for (final item in data['transaction_tags']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('transaction_tags', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['budgets'] is List) {
          for (final item in data['budgets']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('budgets', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['recurring_payments'] is List) {
          for (final item in data['recurring_payments']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('recurring_payments', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }

        if (data['balance_adjustments'] is List) {
          for (final item in data['balance_adjustments']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('balance_adjustments', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      });

      await AppLogger.i('Successfully executed JSON import.');
      return true;
    } catch (e, st) {
      await AppLogger.e('executeJsonImport failed and rolled back', error: e, stackTrace: st);
      return false;
    }
  }
}
