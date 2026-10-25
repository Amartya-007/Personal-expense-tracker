import 'log_category.dart';
import 'log_level.dart';

/// One stored diagnostic log entry.
class AppLogEntry {
  /// Database id; null until the entry has been stored.
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;

  /// Extra context that is safe to keep (counts, states, masked ids).
  final String? details;

  /// The error/exception text, when the entry records a failure.
  final String? error;
  final String? stackTrace;

  const AppLogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details,
    this.error,
    this.stackTrace,
  });

  /// True when there is technical information beyond the message.
  bool get hasTechnicalInfo =>
      (details?.isNotEmpty ?? false) ||
      (error?.isNotEmpty ?? false) ||
      (stackTrace?.isNotEmpty ?? false);

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'level': level.value,
    'category': category.value,
    'message': message,
    'details': details,
    'error': error,
    'stack_trace': stackTrace,
  };

  factory AppLogEntry.fromMap(Map<String, Object?> map) => AppLogEntry(
    id: map['id'] as int?,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (map['timestamp'] as num?)?.toInt() ?? 0,
    ),
    level: LogLevel.fromValue(map['level'] as String?),
    category: LogCategory.fromValue(map['category'] as String?),
    message: (map['message'] as String?) ?? '',
    details: map['details'] as String?,
    error: map['error'] as String?,
    stackTrace: map['stack_trace'] as String?,
  );

  /// JSON shape used by the log export. Empty optional fields are left out.
  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'level': level.value,
    'category': category.value,
    'message': message,
    if (details != null && details!.isNotEmpty) 'details': details,
    if (error != null && error!.isNotEmpty) 'error': error,
    if (stackTrace != null && stackTrace!.isNotEmpty) 'stackTrace': stackTrace,
  };

  /// Plain-text rendering for "copy details".
  String toDiagnosticText() {
    final b = StringBuffer()
      ..writeln('Time: ${timestamp.toIso8601String()}')
      ..writeln('Level: ${level.label}')
      ..writeln('Category: ${category.label}')
      ..writeln('Message: $message');
    if (details != null && details!.isNotEmpty) {
      b.writeln('\nDetails:\n$details');
    }
    if (error != null && error!.isNotEmpty) {
      b.writeln('\nError:\n$error');
    }
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      b.writeln('\nStack trace:\n$stackTrace');
    }
    return b.toString().trimRight();
  }
}
