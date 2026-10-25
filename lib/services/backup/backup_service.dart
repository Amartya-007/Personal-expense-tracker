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
import '../../core/logging/log_category.dart';

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
    AppLogger.info('Backup started', category: LogCategory.backup);
    try {
      final docsDir = await _getDocsDirectory();
      final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));

      final db = await DatabaseHelper.instance.database;
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}

      final zipPrepDir = Directory(
        p.join(
          docsDir.path,
          'zip_prep_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      if (await zipPrepDir.exists()) await zipPrepDir.delete(recursive: true);
      await zipPrepDir.create(recursive: true);

      // Use SQLite VACUUM INTO to safely export active DB (supports both file and in-memory databases)
      final stagedDb = File(p.join(zipPrepDir.path, AppConstants.dbFileName));
      await db.execute('VACUUM INTO ?', [stagedDb.path]);

      if (!await stagedDb.exists()) {
        throw Exception(
          'Failed to generate backup database snapshot via VACUUM INTO',
        );
      }

      final dbChecksum = await _computeFileSha256(stagedDb);

      // Collect table row counts for manifest
      final txCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM transactions'),
          ) ??
          0;
      final accCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM accounts'),
          ) ??
          0;
      final catCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM categories'),
          ) ??
          0;

      int receiptFileCount = 0;
      if (await receiptsDir.exists()) {
        receiptFileCount = await receiptsDir
            .list(recursive: true)
            .where((e) => e is File)
            .length;
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
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );

      // 2. Add DB
      final dbBytes = await stagedDb.readAsBytes();
      archive.addFile(
        ArchiveFile(AppConstants.dbFileName, dbBytes.length, dbBytes),
      );

      // 3. Add receipts
      if (await receiptsDir.exists()) {
        await for (final entity in receiptsDir.list(recursive: true)) {
          if (entity is File) {
            final relPath = p.relative(entity.path, from: receiptsDir.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(
              ArchiveFile('receipts/$relPath', bytes.length, bytes),
            );
          }
        }
      }

      final encoder = ZipEncoder();
      final encoded = encoder.encode(archive);

      final backupFileName =
          'MyKhata_Backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipPath = p.join(docsDir.path, backupFileName);
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(encoded);

      if (await zipPrepDir.exists()) await zipPrepDir.delete(recursive: true);

      await AppLogger.info(
        'Backup archive created',
        category: LogCategory.backup,
        details: '$receiptFileCount receipts included',
      );
      return zipFile;
    } catch (e, stack) {
      await AppLogger.error(
        'Backup creation failed',
        error: e,
        stackTrace: stack,
        category: LogCategory.backup,
      );
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

    final manifest = jsonDecode(
      utf8.decode(manifestEntry.content as List<int>),
    ) as Map<String, dynamic>;
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

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save MyKhata backup',
        fileName: p.basename(zipFile.path),
        type: FileType.any,
        bytes: await zipFile.readAsBytes(),
      );

      if (savedUri == null) {
        await AppLogger.info(
          'Backup export cancelled by the user',
          category: LogCategory.backup,
        );
        return null;
      }
      await AppLogger.info(
        'Backup exported to a user-selected location',
        category: LogCategory.backup,
      );
      // file_picker 13 returns a Uri; keep a file-system path when the scheme
      // is `file`, otherwise hand back the Uri string (e.g. Android SAF
      // `content://` targets) for display.
      return savedUri.isScheme('file')
          ? savedUri.toFilePath()
          : savedUri.toString();
    } catch (e, stack) {
      await AppLogger.error(
        'Backup export failed',
        error: e,
        stackTrace: stack,
        category: LogCategory.backup,
      );
      rethrow;
    } finally {
      // The copy in app storage was only a staging file; the user now has
      // their own copy (or cancelled).
      try {
        if (await zipFile.exists()) await zipFile.delete();
      } catch (_) {}
    }
  }

  /// Creates a complete backup silently, in private app storage
  /// (`safety_backups/`), and verifies it. Used right before destructive
  /// operations. There is no dialog and no user step.
  ///
  /// Throws if the backup cannot be created or fails verification, so the
  /// caller can abort instead of proceeding without a safety net. Safety
  /// backups are never pruned automatically: after "delete all data" a newer
  /// (empty) backup must not replace the only copy of the real data.
  Future<File> createSafetyBackup() async {
    final created = await createFullBackupPackage();
    try {
      await verifyBackupArchive(created);

      final docsDir = await _getDocsDirectory();
      final dir = Directory(p.join(docsDir.path, 'safety_backups'));
      await dir.create(recursive: true);

      final target = File(
        p.join(
          dir.path,
          'MyKhata_PreDelete_${DateTime.now().millisecondsSinceEpoch}.zip',
        ),
      );
      await created.copy(target.path);
      if (!await target.exists() || await target.length() == 0) {
        throw Exception('The safety backup could not be stored.');
      }

      await created.delete();
      await AppLogger.info(
        'Created safety backup before a destructive operation',
        category: LogCategory.backup,
      );
      return target;
    } catch (_) {
      // Leave nothing half-made behind.
      try {
        if (await created.exists()) await created.delete();
      } catch (_) {}
      rethrow;
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
    AppLogger.info('Restore started', category: LogCategory.restore);
    final docsDir = await _getDocsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory(p.join(docsDir.path, 'restore_temp_$timestamp'));
    final safetyDir = Directory(
      p.join(docsDir.path, 'restore_safety_$timestamp'),
    );

    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true);

      // Stage 1: Extract zip archive to tempDir
      final bytes = await zipFile.readAsBytes();
      if (bytes.isEmpty) {
        await AppLogger.warning(
          'Restore rejected: Backup archive is empty.',
          category: LogCategory.restore,
        );
        return false;
      }

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

      // Stage 2: Validate manifest and staged DB checksum
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        await AppLogger.warning(
          'Restore rejected: manifest.json missing in backup archive.',
          category: LogCategory.restore,
        );
        return false;
      }

      final manifestStr = await manifestFile.readAsString();
      final Map<String, dynamic> manifest = jsonDecode(manifestStr);

      final stagedDbFile = File(p.join(tempDir.path, AppConstants.dbFileName));
      if (!await stagedDbFile.exists()) {
        await AppLogger.warning(
          'Restore rejected: ${AppConstants.dbFileName} missing in backup package.',
          category: LogCategory.restore,
        );
        return false;
      }

      final expectedChecksum = manifest['dbChecksum'] as String?;
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final actualChecksum = await _computeFileSha256(stagedDbFile);
        if (actualChecksum != expectedChecksum) {
          await AppLogger.warning(
            'Restore rejected: database checksum mismatch',
            category: LogCategory.restore,
          );
          return false;
        }
      }

      // Stage 3: Validate staged DB with PRAGMA quick_check
      Database? testDb;
      try {
        testDb = await openDatabase(stagedDbFile.path, readOnly: true);
        final checkRes = await testDb.rawQuery('PRAGMA quick_check');
        if (checkRes.isEmpty || checkRes.first.values.first != 'ok') {
          await testDb.close();
          await AppLogger.warning(
            'Restore rejected: SQLite PRAGMA quick_check failed.',
            category: LogCategory.restore,
          );
          return false;
        }
        await testDb.close();
        testDb = null;
      } catch (e) {
        if (testDb != null && testDb.isOpen) await testDb.close();
        await AppLogger.warning(
          'Restore rejected: staged database integrity check failed',
          category: LogCategory.restore,
          error: e,
        );
        return false;
      }

      // Stage 4: Create safety backup of current active database & receipts
      if (await safetyDir.exists()) await safetyDir.delete(recursive: true);
      await safetyDir.create(recursive: true);

      final activeDb = await DatabaseHelper.instance.database;
      final activeDbPath = activeDb.path;

      if (activeDbPath != ':memory:') {
        // Truncate active WAL before copying safety backup
        try {
          await activeDb.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (_) {}

        final activeDbFile = File(activeDbPath);
        if (await activeDbFile.exists()) {
          await activeDbFile.copy(
            p.join(safetyDir.path, AppConstants.dbFileName),
          );
        }

        final activeReceiptsDir = Directory(p.join(docsDir.path, 'receipts'));
        if (await activeReceiptsDir.exists()) {
          final safetyReceiptsDir = Directory(
            p.join(safetyDir.path, 'receipts'),
          );
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

        // Stage 5: Replace active database
        // Close DatabaseHelper connection and sqflite factory handle
        await DatabaseHelper.instance.close();
        try {
          await databaseFactory.deleteDatabase(activeDbPath);
        } catch (_) {}

        // Remove/truncate active WAL and SHM sidecars
        final walFile = File('$activeDbPath-wal');
        final shmFile = File('$activeDbPath-shm');
        if (await walFile.exists()) {
          try {
            await walFile.delete();
          } catch (_) {
            await walFile.writeAsBytes([], flush: true);
          }
        }
        if (await shmFile.exists()) {
          try {
            await shmFile.delete();
          } catch (_) {
            await shmFile.writeAsBytes([], flush: true);
          }
        }

        // Replace database file on disk
        final activeFile = File(activeDbPath);
        try {
          if (await activeFile.exists()) {
            await activeFile.delete();
          }
          await stagedDbFile.copy(activeDbPath);
        } catch (_) {
          await activeFile.writeAsBytes(
            await stagedDbFile.readAsBytes(),
            flush: true,
          );
        }

        // Replace receipts
        final stagedReceipts = Directory(p.join(tempDir.path, 'receipts'));
        if (await stagedReceipts.exists()) {
          if (!await activeReceiptsDir.exists()) {
            await activeReceiptsDir.create(recursive: true);
          }
          await for (final entity in stagedReceipts.list(recursive: true)) {
            if (entity is File) {
              final relativePath = p.relative(
                entity.path,
                from: stagedReceipts.path,
              );
              final targetPath = p.join(activeReceiptsDir.path, relativePath);
              final targetFile = File(targetPath);
              await targetFile.parent.create(recursive: true);
              await entity.copy(targetPath);
            }
          }
        }

        // Reopen database and verify restored database works
        final restoredDb = await DatabaseHelper.instance.database;
        final checkRes = await restoredDb.rawQuery('PRAGMA quick_check');
        if (checkRes.isEmpty || checkRes.first.values.first != 'ok') {
          throw Exception('Restored database failed quick_check verification');
        }
      }

      await AppLogger.info(
        'Backup restored successfully',
        category: LogCategory.restore,
      );
      return true;
    } catch (e, stack) {
      await AppLogger.error(
        'Backup restore failed, attempting rollback',
        error: e,
        stackTrace: stack,
        category: LogCategory.restore,
      );
      // Rollback from safety backup
      try {
        final docsDir = await _getDocsDirectory();
        final safetyDbFile = File(
          p.join(safetyDir.path, AppConstants.dbFileName),
        );
        final activeDbPath =
            DatabaseHelper.customDatabasePath ??
            p.join(docsDir.path, AppConstants.dbFileName);

        if (await safetyDbFile.exists() && activeDbPath != ':memory:') {
          await DatabaseHelper.instance.close();
          try {
            await databaseFactory.deleteDatabase(activeDbPath);
          } catch (_) {}

          final walFile = File('$activeDbPath-wal');
          final shmFile = File('$activeDbPath-shm');
          if (await walFile.exists()) {
            try {
              await walFile.delete();
            } catch (_) {
              await walFile.writeAsBytes([], flush: true);
            }
          }
          if (await shmFile.exists()) {
            try {
              await shmFile.delete();
            } catch (_) {
              await shmFile.writeAsBytes([], flush: true);
            }
          }

          final activeFile = File(activeDbPath);
          try {
            if (await activeFile.exists()) await activeFile.delete();
            await safetyDbFile.copy(activeDbPath);
          } catch (_) {
            await activeFile.writeAsBytes(
              await safetyDbFile.readAsBytes(),
              flush: true,
            );
          }

          await DatabaseHelper.instance.database;
        }
      } catch (rollbackErr) {
        await AppLogger.error(
          'Rollback failed',
          error: rollbackErr,
          category: LogCategory.restore,
        );
      }
      return false;
    } finally {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
      try {
        if (await safetyDir.exists()) await safetyDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
