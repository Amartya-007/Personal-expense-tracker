import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import 'backup_service.dart';

/// Thrown when "delete all data" did not complete. [message] is safe to show
/// to the user and says whether anything was changed.
class DataResetException implements Exception {
  final String message;

  const DataResetException(this.message);

  @override
  String toString() => message;
}

class DataResetService {
  final BackupService _backupService;

  DataResetService({BackupService? backupService})
      : _backupService = backupService ?? BackupService();

  /// Deletes everything the user created and returns the app to a clean first
  /// run.
  ///
  /// 1. A complete backup is created and verified silently. If that fails,
  ///    nothing is deleted.
  /// 2. All database rows are removed in a single transaction (all or
  ///    nothing). If that fails, nothing is deleted.
  /// 3. Receipt image files are removed.
  /// 4. Personal preferences are reset and onboarding is shown again.
  ///
  /// Settings such as theme, biometric lock and the SMS/location switches are
  /// kept. Steps 3 and 4 run only after the data is gone and cannot undo it,
  /// so their failures are logged rather than thrown.
  Future<void> deleteAllData() async {
    // 1. Safety backup. No backup, no deletion.
    try {
      await _backupService.createSafetyBackup();
    } catch (e, stack) {
      await AppLogger.e(
        'Delete all data aborted: safety backup failed',
        error: e,
        stackTrace: stack,
      );
      throw const DataResetException(
        'Could not create the safety backup, so nothing was deleted.',
      );
    }

    // 2. Atomic database wipe.
    try {
      await DatabaseHelper.instance.deleteAllUserData();
    } catch (e, stack) {
      await AppLogger.e(
        'Delete all data failed; database left unchanged',
        error: e,
        stackTrace: stack,
      );
      throw const DataResetException(
        'Deleting failed, so your data was not changed.',
      );
    }

    // 3 and 4: the data is gone; finish cleaning up on a best-effort basis.
    await _deleteReceiptFiles();
    await _resetPersonalPreferences();
  }

  Future<void> _deleteReceiptFiles() async {
    try {
      Directory docsDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        docsDir = Directory.systemTemp;
      }
      final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
      if (await receiptsDir.exists()) {
        await receiptsDir.delete(recursive: true);
      }
    } catch (e, stack) {
      await AppLogger.e(
        'Could not remove receipt files after deleting all data',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _resetPersonalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefUserName);
      // Pointed at an account that no longer exists.
      await prefs.remove(AppConstants.prefDefaultUpiAccount);
      // Back to the first-run flow, which creates the first account.
      await prefs.setBool(AppConstants.prefIsOnboardingComplete, false);
    } catch (e, stack) {
      await AppLogger.e(
        'Could not reset preferences after deleting all data',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
