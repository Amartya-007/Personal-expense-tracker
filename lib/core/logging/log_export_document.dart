import 'dart:convert';

import '../constants/app_constants.dart';
import 'log_entry.dart';
import 'log_sanitizer.dart';

/// Builds the JSON document written by the log export.
class LogExportDocument {
  LogExportDocument._();

  /// Entries are sanitised again here, so a row that reached the table by
  /// another route (for example a backup restored from another version) still
  /// cannot export sensitive text.
  static String build(
    List<AppLogEntry> logs, {
    required DateTime exportedAt,
    String appVersion = AppConstants.appVersion,
  }) {
    final document = <String, Object?>{
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appName': AppConstants.appName,
      'appVersion': appVersion,
      'logCount': logs.length,
      'logs': [for (final e in logs) _clean(e).toJson()],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  static AppLogEntry _clean(AppLogEntry e) => AppLogEntry(
    id: e.id,
    timestamp: e.timestamp,
    level: e.level,
    category: e.category,
    message: LogSanitizer.sanitize(
      e.message,
      maxLength: LogSanitizer.maxMessageLength,
    ),
    details: LogSanitizer.sanitizeNullable(
      e.details,
      maxLength: LogSanitizer.maxDetailsLength,
    ),
    error: LogSanitizer.sanitizeNullable(
      e.error,
      maxLength: LogSanitizer.maxErrorLength,
    ),
    stackTrace: LogSanitizer.sanitizeNullable(
      e.stackTrace,
      maxLength: LogSanitizer.maxStackTraceLength,
    ),
  );
}
