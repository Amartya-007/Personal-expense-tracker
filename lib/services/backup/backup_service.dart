import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';

class BackupService {
  Future<Directory> _getDocsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Computes SHA-256 hash of a file for integrity verification.
  Future<String> _computeFileSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Creates a complete restorable snapshot archive containing SQLite database,
  /// receipt files, and manifest metadata.
  Future<File> createFullBackupPackage() async {
    try {
      final docsDir = await _getDocsDirectory();
      final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));

      final db = await DatabaseHelper.instance.database;
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}

      final zipPrepDir = Directory(p.join(docsDir.path, 'zip_prep_${DateTime.now().millisecondsSinceEpoch}'));
      if (await zipPrepDir.exists()) await zipPrepDir.delete(recursive: true);
      await zipPrepDir.create(recursive: true);

      // Use SQLite VACUUM INTO to safely export active DB (supports both file and in-memory databases)
      final stagedDb = File(p.join(zipPrepDir.path, AppConstants.dbFileName));
      await db.execute('VACUUM INTO ?', [stagedDb.path]);

      if (!await stagedDb.exists()) {
        throw Exception('Failed to generate backup database snapshot via VACUUM INTO');
      }

      final dbChecksum = await _computeFileSha256(stagedDb);

      // Collect table row counts for manifest
      final txCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
      final accCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accounts')) ?? 0;
      final catCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;

      int receiptFileCount = 0;
      if (await receiptsDir.exists()) {
        receiptFileCount = await receiptsDir.list(recursive: true).where((e) => e is File).length;
      }

      final archive = Archive();

      // 1. Add manifest
      final manifest = {
        'version': AppConstants.backupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'appName': AppConstants.appName,
        'dbChecksum': dbChecksum,
        'counts': {
          'transactions': txCount,
          'accounts': accCount,
          'categories': catCount,
        },
        'receiptCount': receiptFileCount,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // 2. Add DB
      final dbBytes = await stagedDb.readAsBytes();
      archive.addFile(ArchiveFile(AppConstants.dbFileName, dbBytes.length, dbBytes));

      // 3. Add receipts
      if (await receiptsDir.exists()) {
        await for (final entity in receiptsDir.list(recursive: true)) {
          if (entity is File) {
            final relPath = p.relative(entity.path, from: receiptsDir.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile('receipts/$relPath', bytes.length, bytes));
          }
        }
      }

      final encoder = ZipEncoder();
      final encoded = encoder.encode(archive);
      if (encoded == null) throw Exception('Failed to encode zip archive');

      final backupFileName = 'MyKhata_Backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipPath = p.join(docsDir.path, backupFileName);
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(encoded);

      if (await zipPrepDir.exists()) await zipPrepDir.delete(recursive: true);

      await AppLogger.i('Created full backup archive at $zipPath');
      return zipFile;
    } catch (e, stack) {
      await AppLogger.e('Backup creation failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Confirms a backup ZIP is complete and readable: it must contain the
  /// manifest and the database, and the database must match the checksum
  /// recorded in the manifest. Throws if anything is wrong.
  Future<void> verifyBackupArchive(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    if (bytes.isEmpty) throw Exception('The backup file is empty.');

    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestEntry;
    ArchiveFile? dbEntry;
    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.name == 'manifest.json') manifestEntry = file;
      if (file.name == AppConstants.dbFileName) dbEntry = file;
    }
    if (manifestEntry == null || dbEntry == null) {
      throw Exception('The backup is missing its manifest or database.');
    }

    final manifest =
        jsonDecode(utf8.decode(manifestEntry.content as List<int>))
            as Map<String, dynamic>;
    final expectedChecksum = manifest['dbChecksum'] as String?;
    if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
      final actual = sha256.convert(dbEntry.content as List<int>).toString();
      if (actual != expectedChecksum) {
        throw Exception('The backup database failed its integrity check.');
      }
    }
  }

  /// Creates a backup and lets the user save it somewhere they can find it
  /// (Downloads, Drive, an SD card...) through Android's system "save file"
  /// dialog (Storage Access Framework). No storage permission is needed.
  ///
  /// Returns where the file was saved, or `null` if the user cancelled the
  /// dialog. Throws if the backup could not be created, verified or saved.
  ///
  /// The ZIP is exactly what [createFullBackupPackage] produces, so
  /// [restoreFullBackupPackage] restores it unchanged.
  Future<String?> exportBackupForUser() async {
    final zipFile = await createFullBackupPackage();
    try {
      // Never hand the user a backup that cannot be restored.
      await verifyBackupArchive(zipFile);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save MyKhata backup',
        fileName: p.basename(zipFile.path),
        type: FileType.any,
        bytes: await zipFile.readAsBytes(),
      );

      if (savedPath == null) {
        await AppLogger.i('Backup export cancelled by the user');
        return null;
      }
      await AppLogger.i('Backup exported to a user-selected location');
      return savedPath;
    } catch (e, stack) {
      await AppLogger.e('Backup export failed', error: e, stackTrace: stack);
      rethrow;
    } finally {
      // The copy in app storage was only a staging file; the user now has
      // their own copy (or cancelled).
      try {
        if (await zipFile.exists()) await zipFile.delete();
      } catch (_) {}
    }
  }

  /// A readable location for the path returned by [exportBackupForUser].
  /// Android returns a document path such as `/document/primary:Download/x.zip`.
  static String describeSavedLocation(String savedPath) {
    final match = RegExp(r'primary:(.+)$').firstMatch(savedPath);
    if (match != null) return 'Internal storage/${match.group(1)}';
    return savedPath;
  }

  /// Restores a full backup with 5-stage safety, integrity validation, and automatic rollback.
  Future<bool> restoreFullBackupPackage(File zipFile) async {
    final docsDir = await _getDocsDirectory();
    final tempDir = Directory(p.join(docsDir.path, 'restore_temp'));
    final safetyDir = Directory(p.join(docsDir.path, 'restore_safety'));

    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true);

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final baseName = file.name;
          final outFile = File(p.join(tempDir.path, baseName));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        await AppLogger.w('Restore rejected: manifest.json missing in backup archive.');
        await tempDir.delete(recursive: true);
        return false;
      }

      final manifestStr = await manifestFile.readAsString();
      final Map<String, dynamic> manifest = jsonDecode(manifestStr);

      final stagedDbFile = File(p.join(tempDir.path, AppConstants.dbFileName));
      if (!await stagedDbFile.exists()) {
        await AppLogger.w('Restore rejected: ${AppConstants.dbFileName} missing in backup package.');
        await tempDir.delete(recursive: true);
        return false;
      }

      final expectedChecksum = manifest['dbChecksum'] as String?;
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final actualChecksum = await _computeFileSha256(stagedDbFile);
        if (actualChecksum != expectedChecksum) {
          await AppLogger.w('Restore rejected: Database checksum mismatch (expected $expectedChecksum, got $actualChecksum).');
          await tempDir.delete(recursive: true);
          return false;
        }
      }

      Database? testDb;
      try {
        testDb = await openDatabase(stagedDbFile.path, readOnly: true);
        final checkRes = await testDb.rawQuery('PRAGMA quick_check');
        if (checkRes.isEmpty || checkRes.first.values.first != 'ok') {
          await testDb.close();
          await tempDir.delete(recursive: true);
          await AppLogger.w('Restore rejected: SQLite PRAGMA quick_check failed.');
          return false;
        }
        await testDb.close();
      } catch (e) {
        if (testDb != null && testDb.isOpen) await testDb.close();
        await tempDir.delete(recursive: true);
        await AppLogger.w('Restore rejected: staged DB failed to open: $e');
        return false;
      }

      if (await safetyDir.exists()) await safetyDir.delete(recursive: true);
      safetyDir.createSync(recursive: true);

      final db = await DatabaseHelper.instance.database;
      final activeDbPath = db.path;
      final activeDbFile = File(activeDbPath);
      if (await activeDbFile.exists() && activeDbPath != ':memory:') {
        await activeDbFile.copy(p.join(safetyDir.path, AppConstants.dbFileName));
      }

      final activeReceiptsDir = Directory(p.join(docsDir.path, 'receipts'));
      if (await activeReceiptsDir.exists()) {
        final safetyReceiptsDir = Directory(p.join(safetyDir.path, 'receipts'));
        await safetyReceiptsDir.create(recursive: true);
        await for (final entity in activeReceiptsDir.list(recursive: true)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: activeReceiptsDir.path);
            final target = File(p.join(safetyReceiptsDir.path, rel));
            await target.parent.create(recursive: true);
            await entity.copy(target.path);
          }
        }
      }

      await DatabaseHelper.instance.close();

      if (activeDbPath != ':memory:') {
        await stagedDbFile.copy(activeDbPath);
      } else {
        final activeDb = await DatabaseHelper.instance.database;
        await activeDb.execute('VACUUM INTO ?', [activeDbPath]);
      }

      final stagedReceipts = Directory(p.join(tempDir.path, 'receipts'));
      if (await stagedReceipts.exists()) {
        if (!await activeReceiptsDir.exists()) {
          await activeReceiptsDir.create(recursive: true);
        }

        await for (final entity in stagedReceipts.list(recursive: true)) {
          if (entity is File) {
            final relativePath = p.relative(entity.path, from: stagedReceipts.path);
            final targetPath = p.join(activeReceiptsDir.path, relativePath);
            final targetFile = File(targetPath);
            await targetFile.parent.create(recursive: true);
            await entity.copy(targetPath);
          }
        }
      }

      await tempDir.delete(recursive: true);
      if (await safetyDir.exists()) await safetyDir.delete(recursive: true);

      await AppLogger.i('Successfully restored full backup package from ${zipFile.path}');
      return true;
    } catch (e, stack) {
      try {
        final db = await DatabaseHelper.instance.database;
        final activeDbPath = db.path;
        final safetyDbFile = File(p.join(safetyDir.path, AppConstants.dbFileName));
        if (await safetyDbFile.exists() && activeDbPath != ':memory:') {
          await DatabaseHelper.instance.close();
          await safetyDbFile.copy(activeDbPath);
        }
      } catch (_) {}

      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await safetyDir.exists()) await safetyDir.delete(recursive: true);

      await AppLogger.e('Backup restore failed and rolled back safely', error: e, stackTrace: stack);
      return false;
    }
  }
}
