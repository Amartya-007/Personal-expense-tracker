import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class AppLogger {
  static Future<void> i(String message, {String? details}) async {
    if (kDebugMode) {
      print('[INFO] $message ${details != null ? "- $details" : ""}');
    }
    await _saveToDb('INFO', message, details);
  }

  static Future<void> w(String message, {String? details}) async {
    if (kDebugMode) {
      print('[WARN] $message ${details != null ? "- $details" : ""}');
    }
    await _saveToDb('WARN', message, details);
  }

  static Future<void> e(String message, {dynamic error, StackTrace? stackTrace}) async {
    final detailsStr = '${error ?? ""} \n${stackTrace ?? ""}';
    if (kDebugMode) {
      print('[ERROR] $message - $detailsStr');
    }
    await _saveToDb('ERROR', message, detailsStr);
  }

  static Future<void> _saveToDb(String level, String message, String? details) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_logs', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'level': level,
        'message': message,
        'details': details,
      });
    } catch (_) {
      // Avoid crash if logging fails
    }
  }
}
