import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/khata_entry_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/data/repositories/khata_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;
  late KhataRepository repo;
  late AccountRepository accountRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_khata_repo_');
    DatabaseHelper.setCustomDatabasePath(p.join(tempDir!.path, 'khata_test.db'));

    repo = KhataRepository();
    accountRepo = AccountRepository();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setCustomDatabasePath(null);
    try {
      if (tempDir != null && await tempDir!.exists()) {
        await tempDir!.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('KhataRepository Integration Tests', () {
    test('Create, search, update, archive, and delete people', () async {
      final p1 = await repo.createPerson(
        name: 'Rahul Sharma',
        phone: '9876543210',
        notes: 'Roommate',
      );
      expect(p1.id, isNotEmpty);
      expect(p1.name, equals('Rahul Sharma'));
      expect(p1.phone, equals('9876543210'));

      // Empty name validation
      expect(
        () => repo.createPerson(name: '   '),
        throwsA(isA<ArgumentError>()),
      );

      // Search
      final searchResults = await repo.getPeople(searchQuery: 'Rahul');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.id, equals(p1.id));

      // Update
      final updated = p1.copyWith(notes: 'Ex-Roommate');
      await repo.updatePerson(updated);
      final fetched = await repo.getPersonById(p1.id);
      expect(fetched?.notes, equals('Ex-Roommate'));

      // Archive & Unarchive
      await repo.setArchived(p1.id, true);
      final activeList = await repo.getPeople(includeArchived: false);
      expect(activeList.any((p) => p.id == p1.id), isFalse);

      final archivedList = await repo.getPeople(includeArchived: true);
      expect(archivedList.any((p) => p.id == p1.id), isTrue);

      await repo.setArchived(p1.id, false);
      final restoredList = await repo.getPeople(includeArchived: false);
      expect(restoredList.any((p) => p.id == p1.id), isTrue);
    });

    test('Add lending and repayment entries without account association', () async {
      final person = await repo.createPerson(name: 'Sneha Patel');

      // 1. Lent ₹1,500
      await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.lent,
        amount: 1500.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        notes: 'Concert ticket advance',
      );

      var pFetched = await repo.getPersonById(person.id);
      expect(pFetched?.netBalance, equals(1500.0));
      expect(pFetched?.isReceivable, isTrue);

      // 2. Repayment received ₹500
      await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.repaymentReceived,
        amount: 500.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'UPI partial transfer',
      );

      pFetched = await repo.getPersonById(person.id);
      expect(pFetched?.netBalance, equals(1000.0));

      // 3. Ledger items verify chronological order and running balances
      final ledger = await repo.getLedgerEntries(person.id);
      expect(ledger.length, equals(2));
      // Displayed reverse chronological:
      expect(ledger.first.entry.amount, equals(500.0));
      expect(ledger.first.runningBalance, equals(1000.0));
      expect(ledger.last.entry.amount, equals(1500.0));
      expect(ledger.last.runningBalance, equals(1500.0));
    });

    test('Full and partial settlements update balance to zero correctly', () async {
      final person = await repo.createPerson(name: 'Vikram Mehta');

      // User borrowed ₹600 from Vikram
      await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.borrowed,
        amount: 600.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
      );

      var pFetched = await repo.getPersonById(person.id);
      expect(pFetched?.netBalance, equals(-600.0));
      expect(pFetched?.isPayable, isTrue);

      // Partial settlement of ₹200
      await repo.settlePerson(
        person.id,
        amount: 200.0,
        notes: 'Cash payment',
      );

      pFetched = await repo.getPersonById(person.id);
      expect(pFetched?.netBalance, equals(-400.0));

      // Full settlement of remaining ₹400
      await repo.settlePerson(
        person.id,
        amount: 400.0,
        notes: 'Cleared full balance',
      );

      pFetched = await repo.getPersonById(person.id);
      expect(pFetched?.netBalance, equals(0.0));
      expect(pFetched?.isSettled, isTrue);
      expect(pFetched?.balanceStatusLabel, equals('Settled'));
    });

    test('Atomic account integration: balance updates and reconcile without drift', () async {
      final now = DateTime.now();
      // Setup a test bank account with ₹10,000 balance
      final acc = AccountModel(
        id: 'acc-test-bank',
        name: 'HDFC Savings',
        currentBalance: 10000.0,
        initialBalance: 10000.0,
        createdAt: now,
        updatedAt: now,
      );
      final db = await DatabaseHelper.instance.database;
      await db.insert('accounts', acc.toMap());

      final person = await repo.createPerson(name: 'Karan Johar');

      // User lends ₹2,000 to Karan paid from HDFC Savings
      final lentEntry = await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.lent,
        amount: 2000.0,
        date: now,
        accountId: acc.id,
        notes: 'Short term loan',
      );

      // Verify account balance decreased by ₹2,000 -> ₹8,000
      var accRow = await db.query('accounts', where: 'id = ?', whereArgs: [acc.id]);
      expect((accRow.first['current_balance'] as num).toDouble(), equals(8000.0));

      // Verify reconcileAccount passes with zero drift!
      var rec = await accountRepo.reconcileAccount(acc.id);
      expect(rec.isMatch, isTrue);
      expect(rec.actualBalance, equals(8000.0));
      expect(rec.expectedBalance, equals(8000.0));

      // Karan repays ₹2,000 back into HDFC Savings
      await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.repaymentReceived,
        amount: 2000.0,
        date: now,
        accountId: acc.id,
      );

      // Verify account balance increased back to ₹10,000
      accRow = await db.query('accounts', where: 'id = ?', whereArgs: [acc.id]);
      expect((accRow.first['current_balance'] as num).toDouble(), equals(10000.0));

      rec = await accountRepo.reconcileAccount(acc.id);
      expect(rec.isMatch, isTrue);
      expect(rec.actualBalance, equals(10000.0));

      // Deleting entry reverses the balance adjustment atomically
      await repo.deleteEntry(lentEntry.id);
      // lentEntry reduced balance by 2000, deleting it increases it by 2000 -> 12000
      accRow = await db.query('accounts', where: 'id = ?', whereArgs: [acc.id]);
      expect((accRow.first['current_balance'] as num).toDouble(), equals(12000.0));

      rec = await accountRepo.reconcileAccount(acc.id);
      expect(rec.isMatch, isTrue);
    });

    test('Overall KhataSummary aggregates receivables and payables correctly', () async {
      final summary = await repo.getSummary();
      expect(summary.activePeopleCount, greaterThan(0));
      expect(summary.totalReceivable, greaterThanOrEqualTo(0.0));
      expect(summary.totalPayable, greaterThanOrEqualTo(0.0));
      expect(
        summary.netBalance,
        equals(((summary.totalReceivable - summary.totalPayable) * 100).round() / 100),
      );
    });
  });
}
