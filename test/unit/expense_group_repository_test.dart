import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/repositories/expense_group_repository.dart';
import 'package:mykhata/data/repositories/khata_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;
  late DatabaseHelper dbHelper;
  late ExpenseGroupRepository groupRepo;
  late KhataRepository khataRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_group_repo_');
    final dbPath = p.join(tempDir!.path, 'test_group_repo.db');
    DatabaseHelper.setCustomDatabasePath(dbPath);

    dbHelper = DatabaseHelper.instance;
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

  group('ExpenseGroupRepository Tests', () {
    test('Create, retrieve, update, archive, and delete groups with members', () async {
      // 1. Create people first
      final p1 = await khataRepo.createPerson(name: 'Aarav', phone: '9876543210');
      final p2 = await khataRepo.createPerson(name: 'Diya', phone: '9123456789');

      expect(p1.id, isNotEmpty);
      expect(p2.id, isNotEmpty);

      // 2. Create group with members
      final created = await groupRepo.createGroup(
        name: 'Weekend Getaway',
        description: 'Road trip to Lonavala',
        icon: '🚗',
        color: '#0D9488',
        memberPersonIds: [p1.id, p2.id],
      );
      expect(created.name, equals('Weekend Getaway'));
      expect(created.memberCount, equals(2));
      final groupId = created.id;

      // 3. Retrieve group and verify members
      final fetched = await groupRepo.getGroupById(groupId);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Weekend Getaway'));
      expect(fetched.memberCount, equals(2));

      final members = await groupRepo.getGroupMembers(groupId);
      expect(members.length, equals(2));
      final names = members.map((m) => m.name).toSet();
      expect(names, containsAll(['Aarav', 'Diya']));

      // 4. Update group details
      await groupRepo.updateGroup(
        id: groupId,
        name: 'Monsoon Getaway',
        icon: '🌧️',
      );

      final reFetched = await groupRepo.getGroupById(groupId);
      expect(reFetched!.name, equals('Monsoon Getaway'));
      expect(reFetched.icon, equals('🌧️'));

      // 5. Add a third member and verify no duplicate addition
      final p3 = await khataRepo.createPerson(name: 'Karan');
      await groupRepo.addMembers(groupId, [p3.id]);

      var updatedMembers = await groupRepo.getGroupMembers(groupId);
      expect(updatedMembers.length, equals(3));

      // Attempt duplicate addition - should be safely ignored
      await groupRepo.addMembers(groupId, [p3.id]);
      updatedMembers = await groupRepo.getGroupMembers(groupId);
      expect(updatedMembers.length, equals(3));

      // 6. Remove a member
      await groupRepo.removeMember(groupId, p3.id);
      updatedMembers = await groupRepo.getGroupMembers(groupId);
      expect(updatedMembers.length, equals(2));

      // 7. Archive and restore group
      await groupRepo.archiveGroup(groupId);
      var activeGroups = await groupRepo.getGroups(includeArchived: false);
      expect(activeGroups.any((g) => g.id == groupId), isFalse);

      var allGroups = await groupRepo.getGroups(includeArchived: true);
      expect(allGroups.any((g) => g.id == groupId), isTrue);

      await groupRepo.restoreGroup(groupId);
      activeGroups = await groupRepo.getGroups(includeArchived: false);
      expect(activeGroups.any((g) => g.id == groupId), isTrue);

      // 8. Delete group and verify people are still intact
      await groupRepo.deleteGroup(groupId);
      final deleted = await groupRepo.getGroupById(groupId);
      expect(deleted, isNull);

      final personAarav = await khataRepo.getPersonById(p1.id);
      expect(personAarav, isNotNull);
      expect(personAarav!.name, equals('Aarav'));
    });
  });
}
