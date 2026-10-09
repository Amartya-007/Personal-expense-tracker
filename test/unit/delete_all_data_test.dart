@Timeout(Duration(seconds: 180))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/constants/app_constants.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/services/backup/backup_service.dart';
import 'package:mykhata/services/backup/data_reset_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A backup service whose safety backup always fails.
class _FailingBackupService extends BackupService {
  @override
  Future<File> createSafetyBackup() async => throw Exception('disk full');
}

Future<int> _count(Database db, String table, {String? where}) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
  );
  return rows.first['c'] as int;
}

/// One row (or more) of user data in every table the feature must clear.
Future<void> _seedUserData(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  await db.insert('accounts', {
    'id': 'acc_1',
    'name': 'SBI',
    'current_balance': 1000.0,
    'initial_balance': 1000.0,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('categories', {
    'id': 'cat_custom',
    'name': 'Custom',
    'icon': 'category',
    'color': 0xFF123456,
    'type': 'expense',
    'is_default': 0,
    'created_at': now,
  });
  await db.insert('category_rules', {
    'id': 'rule_custom',
    'keyword': 'customkeyword',
    'category_id': 'cat_custom',
    'created_at': now,
  });
  await db.insert('tags', {'id': 'tag_custom', 'name': 'Custom Tag'});
  await db.insert('transactions', {
    'id': 'tx_1',
    'type': 'expense',
    'amount': 250.0,
    'description': 'Lunch',
    'category_id': 'cat_custom',
    'payment_method': 'UPI',
    'account_id': 'acc_1',
    'date': now,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('transaction_tags', {
    'transaction_id': 'tx_1',
    'tag_id': 'tag_custom',
  });
  await db.insert('receipts', {
    'id': 'rcpt_1',
    'transaction_id': 'tx_1',
    'file_path': '/tmp/r.jpg',
    'thumbnail_path': '/tmp/t.jpg',
    'created_at': now,
  });
  await db.insert('budgets', {
    'id': 'bud_1',
    'category_id': 'cat_custom',
    'period': 'monthly',
    'amount': 5000.0,
    'start_date': now,
    'end_date': now,
    'created_at': now,
  });
  await db.insert('recurring_payments', {
    'id': 'rec_1',
    'name': 'Rent',
    'amount': 9000.0,
    'category_id': 'cat_custom',
    'account_id': 'acc_1',
    'payment_method': 'UPI',
    'frequency': 'monthly',
    'next_due_date': now,
    'created_at': now,
  });
  await db.insert('sms_review_queue', {
    'id': 'sms_1',
    'raw_sms': 'Rs 100 debited',
    'sender': 'BANK',
    'amount': 100.0,
    'direction': 'debit',
    'date': now,
    'created_at': now,
  });
  await db.insert('balance_adjustments', {
    'id': 'adj_1',
    'account_id': 'acc_1',
    'previous_balance': 900.0,
    'new_balance': 1000.0,
    'adjustment_amount': 100.0,
    'created_at': now,
  });
  await db.insert('app_logs', {
    'timestamp': now,
    'level': 'INFO',
    'message': 'seeded test log',
  });
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Start from a pristine, freshly seeded database.
    await DatabaseHelper.instance.close();
    String dbPath;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docsDir.path, AppConstants.dbFileName);
    } catch (_) {
      dbPath = p.join(Directory.systemTemp.path, AppConstants.dbFileName);
    }
    await databaseFactory.deleteDatabase(dbPath);
    await DatabaseHelper.instance.database;
    SharedPreferences.setMockInitialValues({});
  });

  group('DatabaseHelper.deleteAllUserData', () {
    test('removes user data from every table', () async {
      final db = await DatabaseHelper.instance.database;
      await _seedUserData(db);

      await DatabaseHelper.instance.deleteAllUserData();

      for (final table in [
        'transactions',
        'transaction_tags',
        'receipts',
        'budgets',
        'recurring_payments',
        'sms_review_queue',
        'balance_adjustments',
        'accounts',
        'app_logs',
      ]) {
        expect(await _count(db, table), 0, reason: '$table should be empty');
      }
      expect(await _count(db, 'categories', where: "id = 'cat_custom'"), 0);
      expect(await _count(db, 'tags', where: "id = 'tag_custom'"), 0);
      expect(await _count(db, 'category_rules', where: "id = 'rule_custom'"), 0);
    });

    test('keeps default categories and restores removed default tags/rules', () async {
      final db = await DatabaseHelper.instance.database;
      final defaultCategories = await _count(db, 'categories', where: 'is_default = 1');
      final tagsBefore = await _count(db, 'tags');
      final rulesBefore = await _count(db, 'category_rules');
      expect(defaultCategories, greaterThan(0));

      await _seedUserData(db);
      // The user deleted a default tag and a default rule.
      await db.delete('tags', where: "id = 'tag_tea'");
      await db.delete('category_rules', where: "id = 'rule_momos'");

      await DatabaseHelper.instance.deleteAllUserData();

      expect(await _count(db, 'categories', where: 'is_default = 1'), defaultCategories);
      expect(await _count(db, 'categories', where: 'is_default = 0'), 0);
      expect(await _count(db, 'tags'), tagsBefore);
      expect(await _count(db, 'tags', where: "id = 'tag_tea'"), 1);
      expect(await _count(db, 'category_rules'), rulesBefore);
      expect(await _count(db, 'category_rules', where: "id = 'rule_momos'"), 1);
    });

    test('is atomic: if any step fails, nothing is deleted', () async {
      final db = await DatabaseHelper.instance.database;
      await _seedUserData(db);

      // Make a late step (budgets) fail, after transactions were already
      // deleted inside the same database transaction.
      await db.execute('''
        CREATE TRIGGER block_budget_delete BEFORE DELETE ON budgets
        BEGIN SELECT RAISE(ABORT, 'blocked for test'); END;
      ''');

      await expectLater(
        DatabaseHelper.instance.deleteAllUserData(),
        throwsA(anything),
      );

      // Everything is still there.
      expect(await _count(db, 'transactions'), 1);
      expect(await _count(db, 'accounts'), 1);
      expect(await _count(db, 'budgets'), 1);
      expect(await _count(db, 'receipts'), 1);
      expect(await _count(db, 'categories', where: "id = 'cat_custom'"), 1);

      await db.execute('DROP TRIGGER block_budget_delete');
    });
  });

  group('DataResetService', () {
    test('deletes nothing when the safety backup fails', () async {
      final db = await DatabaseHelper.instance.database;
      await _seedUserData(db);

      await expectLater(
        DataResetService(backupService: _FailingBackupService()).deleteAllData(),
        throwsA(isA<DataResetException>()),
      );

      expect(await _count(db, 'transactions'), 1);
      expect(await _count(db, 'accounts'), 1);
    });

    test('creates a verified safety backup, deletes everything, resets personal prefs', () async {
      final db = await DatabaseHelper.instance.database;
      await _seedUserData(db);

      SharedPreferences.setMockInitialValues({
        AppConstants.prefUserName: 'Amar',
        AppConstants.prefDefaultUpiAccount: 'acc_1',
        AppConstants.prefIsOnboardingComplete: true,
        AppConstants.prefThemeMode: 'dark',
        AppConstants.prefBiometricsEnabled: true,
      });

      final receiptsDir = Directory(p.join(Directory.systemTemp.path, 'receipts'));
      await receiptsDir.create(recursive: true);
      await File(p.join(receiptsDir.path, 'r.jpg')).writeAsBytes([1, 2, 3]);

      await DataResetService().deleteAllData();

      // Data gone.
      expect(await _count(db, 'transactions'), 0);
      expect(await _count(db, 'accounts'), 0);
      expect(await receiptsDir.exists(), isFalse);

      // A safety backup was kept, and it is a valid backup.
      final safetyDir = Directory(p.join(Directory.systemTemp.path, 'safety_backups'));
      expect(await safetyDir.exists(), isTrue);
      final backups = await safetyDir
          .list()
          .where((e) => e is File && e.path.endsWith('.zip'))
          .cast<File>()
          .toList();
      expect(backups, isNotEmpty);
      await BackupService().verifyBackupArchive(backups.last);

      // Personal preferences reset; configuration kept.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefUserName), isNull);
      expect(prefs.getString(AppConstants.prefDefaultUpiAccount), isNull);
      expect(prefs.getBool(AppConstants.prefIsOnboardingComplete), isFalse);
      expect(prefs.getString(AppConstants.prefThemeMode), 'dark');
      expect(prefs.getBool(AppConstants.prefBiometricsEnabled), isTrue);

      for (final f in backups) {
        await f.delete();
      }
    });
  });
}
