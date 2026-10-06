@Timeout(Duration(seconds: 120))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/services/backup/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    await DatabaseHelper.instance.database;
  });

  group('Backup export verification', () {
    test('a fresh backup passes verification and can be restored', () async {
      final service = BackupService();
      final zip = await service.createFullBackupPackage();

      await service.verifyBackupArchive(zip); // must not throw
      expect(await service.restoreFullBackupPackage(zip), isTrue);

      await zip.delete();
    });

    test('a truncated backup fails verification', () async {
      final service = BackupService();
      final zip = await service.createFullBackupPackage();
      final bytes = await zip.readAsBytes();

      final broken = File('${zip.path}.broken');
      await broken.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

      await expectLater(service.verifyBackupArchive(broken), throwsA(anything));

      await broken.delete();
      await zip.delete();
    });

    test('an empty file fails verification', () async {
      final service = BackupService();
      final empty = File(
        '${Directory.systemTemp.path}/mykhata_empty_${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      await empty.writeAsBytes(<int>[]);

      await expectLater(service.verifyBackupArchive(empty), throwsA(anything));

      await empty.delete();
    });

    test('describeSavedLocation makes Android document paths readable', () {
      expect(
        BackupService.describeSavedLocation(
          '/document/primary:Download/MyKhata_Backup_1.zip',
        ),
        'Internal storage/Download/MyKhata_Backup_1.zip',
      );
      expect(
        BackupService.describeSavedLocation('/storage/emulated/0/x.zip'),
        '/storage/emulated/0/x.zip',
      );
    });
  });
}
