import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/expense_split_model.dart';
import 'package:mykhata/data/models/khata_entry_model.dart';
import 'package:mykhata/data/models/split_participant_model.dart';
import 'package:mykhata/data/repositories/expense_group_repository.dart';
import 'package:mykhata/data/repositories/expense_split_repository.dart';
import 'package:mykhata/data/repositories/khata_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;
  late DatabaseHelper dbHelper;
  late ExpenseSplitRepository splitRepo;
  late ExpenseGroupRepository groupRepo;
  late KhataRepository khataRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_split_repo_');
    final dbPath = p.join(tempDir!.path, 'test_split_repo.db');
    DatabaseHelper.setCustomDatabasePath(dbPath);

    dbHelper = DatabaseHelper.instance;
    splitRepo = ExpenseSplitRepository(dbHelper: dbHelper);
    groupRepo = ExpenseGroupRepository(dbHelper: dbHelper);
    khataRepo = KhataRepository(dbHelper: dbHelper);
  });

  tearDownAll(() async {
    await dbHelper.close();
    DatabaseHelper.setCustomDatabasePath(null);
    try {
      if (tempDir != null && await tempDir!.exists()) {
        await tempDir!.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('ExpenseSplitRepository Tests', () {
    test('Create split with ledger sync records Lent entries for peers', () async {
      // 1. Create a person
      final person = await khataRepo.createPerson(name: 'Rohan', phone: '9988776655');

      // 2. Create group
      final group = await groupRepo.createGroup(
        name: 'Office Lunch',
        memberPersonIds: [person.id],
      );

      // 3. User pays ₹500, split 50/50
      final split = ExpenseSplitModel(
        id: 'split-101',
        title: 'Team Lunch at Haldiram',
        totalAmount: 500.0,
        payerType: 'user',
        payerPersonId: null,
        date: DateTime.now(),
        splitMode: SplitMode.equal,
        groupId: group.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final participants = [
        SplitParticipantModel(
          id: 'sp-1',
          splitId: 'split-101',
          personId: null,
          isUser: true,
          isPayer: true,
          personName: 'You',
          allocatedAmount: 250.0,
          shareValue: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        SplitParticipantModel(
          id: 'sp-2',
          splitId: 'split-101',
          personId: person.id,
          isUser: false,
          isPayer: false,
          personName: person.name,
          personPhone: person.phone,
          allocatedAmount: 250.0,
          shareValue: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final created = await splitRepo.createSplit(
        split: split,
        participants: participants,
        recordInKhataLedger: true,
      );

      expect(created.id, equals('split-101'));
      expect(created.participants.length, equals(2));

      // Check that Khata ledger entry was created for Rohan (Lent ₹250)
      final ledger = await khataRepo.getLedgerEntries(person.id);
      expect(ledger.length, equals(1));
      expect(ledger.first.entry.amount, equals(250.0));
      expect(ledger.first.entry.type, equals(KhataEntryType.lent));

      // Query split by group
      final groupSplits = await splitRepo.getSplits(groupId: group.id);
      expect(groupSplits.length, equals(1));
      expect(groupSplits.first.title, equals('Team Lunch at Haldiram'));

      // Query split by person
      final personSplits = await splitRepo.getSplits(personId: person.id);
      expect(personSplits.length, equals(1));
      expect(personSplits.first.id, equals('split-101'));
    });

    test('Update split details and participants', () async {
      final fetched = await splitRepo.getSplitById('split-101');
      expect(fetched, isNotNull);

      final updatedSplit = fetched!.copyWith(
        title: 'Team Lunch & Sweets',
        totalAmount: 600.0,
      );

      final updatedParticipants = [
        fetched.participants[0].copyWith(allocatedAmount: 300.0),
        fetched.participants[1].copyWith(allocatedAmount: 300.0),
      ];

      await splitRepo.updateSplit(
        split: updatedSplit,
        participants: updatedParticipants,
      );

      final reFetched = await splitRepo.getSplitById('split-101');
      expect(reFetched!.title, equals('Team Lunch & Sweets'));
      expect(reFetched.totalAmount, equals(600.0));
      expect(reFetched.participants[0].allocatedAmount, equals(300.0));
    });

    test('Delete split removes split and participants', () async {
      await splitRepo.deleteSplit('split-101');
      final fetched = await splitRepo.getSplitById('split-101');
      expect(fetched, isNull);
    });
  });
}
