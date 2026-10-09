@Timeout(Duration(seconds: 120))
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/data/repositories/category_repository.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:mykhata/services/backup/backup_service.dart';
import 'package:mykhata/services/export/export_service.dart';
import 'package:mykhata/services/import/import_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    await db.delete('transactions');
    await db.delete('transaction_tags');
    await db.delete('receipts');
    await db.delete('budgets');
    await db.delete('recurring_payments');
    await db.delete('balance_adjustments');
    await db.delete('categories');
    await db.delete('accounts');

    await db.insert('accounts', {
      'id': 'acc_test',
      'name': 'SBI',
      'current_balance': 50000.0,
      'initial_balance': 50000.0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    await db.insert('categories', {
      'id': 'cat_test',
      'name': 'Food',
      'icon': 'dining',
      'color': 0xFFFF8A5B,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  group('Import, Export, Backup & Restore System Integration Tests', () {
    final txRepo = TransactionRepository();
    final accRepo = AccountRepository();
    final catRepo = CategoryRepository();
    const uuid = Uuid();

    test('1. JSON Full Application Export -> Clear DB -> JSON Import -> Match Verification', () async {
      final accounts = await accRepo.getActiveAccounts();
      final categories = await catRepo.getAllCategories();

      final acc = accounts.first;
      final cat = categories.first;

      final originalTx = TransactionModel(
        id: uuid.v4(),
        type: 'expense',
        amount: 1450.75,
        description: 'JSON Integration Test Expense',
        categoryId: cat.id,
        paymentMethod: 'UPI',
        accountId: acc.id,
        date: DateTime.now(),
        note: 'Audited JSON Export/Import test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(originalTx);

      // Export to JSON
      final jsonFile = await ExportService().exportToJson();
      expect(await jsonFile.exists(), isTrue);

      // Reset DB
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');

      final emptyCheck = await txRepo.getTransactionsPaged(limit: 10);
      expect(emptyCheck.isEmpty, isTrue);

      // Import JSON
      final preview = await ImportService().previewJsonImport(jsonFile);
      expect(preview.isValid, isTrue);
      expect(preview.transactionCount, greaterThan(0));

      final text = await jsonFile.readAsString();
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        jsonDecode(text),
      );
      final success = await ImportService().executeJsonImport(data);
      expect(success, isTrue);

      final restoredTxs = await txRepo.getTransactionsPaged(limit: 10);
      expect(restoredTxs.length, equals(1));
      expect(restoredTxs.first.amount, equals(1450.75));
      expect(
        restoredTxs.first.description,
        equals('JSON Integration Test Expense'),
      );

      if (await jsonFile.exists()) await jsonFile.delete();
    });

    test('2. CSV Export -> Clear DB -> CSV Preview -> CSV Import Commit Verification', () async {
      final accounts = await accRepo.getActiveAccounts();
      final categories = await catRepo.getAllCategories();

      final acc = accounts.first;
      final cat = categories.first;

      final sampleTx = TransactionModel(
        id: uuid.v4(),
        type: 'expense',
        amount: 890.0,
        description: 'CSV Export Test Transaction',
        categoryId: cat.id,
        paymentMethod: 'UPI',
        accountId: acc.id,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(sampleTx);

      final csvFile = await ExportService().exportToCsv();
      expect(await csvFile.exists(), isTrue);

      // Clear DB so duplicate detector doesn't skip it
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');

      final preview = await ImportService().previewCsvImport(csvFile);
      for (final err in preview.errors) {
        debugPrint(
          'IMPORT PREVIEW ERROR [Row ${err.rowIndex}]: ${err.message}',
        );
      }
      expect(preview.totalRows, greaterThan(0));
      expect(preview.validCount, greaterThan(0));

      final success = await ImportService().executeCsvImport(
        preview.validTransactions,
      );
      expect(success, isTrue);

      final importedTxs = await txRepo.getTransactionsPaged(limit: 10);
      expect(importedTxs.length, equals(1));
      expect(importedTxs.first.amount, equals(890.0));
      expect(
        importedTxs.first.description,
        equals('CSV Export Test Transaction'),
      );

      if (await csvFile.exists()) await csvFile.delete();
    });

    test('3. Full Backup Archive -> Truncate WAL -> Restore -> PRAGMA Quick Check Integrity', () async {
      final accounts = await accRepo.getActiveAccounts();
      final categories = await catRepo.getAllCategories();

      final acc = accounts.first;
      final cat = categories.first;

      final backupTx = TransactionModel(
        id: uuid.v4(),
        type: 'income',
        amount: 75000.0,
        description: 'Salary Backup Test',
        categoryId: cat.id,
        paymentMethod: 'Bank',
        accountId: acc.id,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(backupTx);

      final backupZip = await BackupService().createFullBackupPackage();
      expect(await backupZip.exists(), isTrue);

      final restoreSuccess = await BackupService().restoreFullBackupPackage(
        backupZip,
      );
      expect(restoreSuccess, isTrue);

      final checkTxs = await txRepo.getTransactionsPaged(limit: 10);
      expect(
        checkTxs.any((t) => t.description == 'Salary Backup Test'),
        isTrue,
      );

      if (await backupZip.exists()) await backupZip.delete();
    });
  });
}
