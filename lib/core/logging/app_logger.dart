import 'dart:async';
import 'dart:collection';

import '../constants/app_constants.dart';
import 'log_category.dart';
import 'log_entry.dart';
import 'log_level.dart';
import 'log_sanitizer.dart';
import 'log_sink.dart';

/// Central, local-only diagnostic logger.
///
/// * Calls return immediately: entries are sanitised, queued in memory and
///   written to the database in batches in the background. A caller may
///   `await` a log call (even inside a database transaction) without
///   waiting for, or deadlocking on, the database.
/// * Logging can never throw into the app. If a write fails, the entries are
///   dropped.
/// * Nothing leaves the device.
///
/// Never pass passwords, tokens, card or account numbers, SMS text, or whole
/// transaction objects. Use [LogSanitizer.maskIdentifier] for references.
class AppLogger {
  AppLogger._();

  /// Where entries are stored. Registered by `DatabaseHelper`; until a sink
  /// exists, entries wait in memory.
  static LogSink? sink;

  /// Echo entries to the console (debug aid). Tests turn this off.
  static bool echoToConsole = true;

  static final Queue<AppLogEntry> _pending = Queue<AppLogEntry>();
  static Future<void>? _draining;
  static bool _held = false;
  static int _writtenSinceTrim = 0;
  static bool _trimmedOnce = false;

  // Bumped by [resetForTesting] so a drain left over from a previous test
  // run cannot touch the next one's queue.
  static int _epoch = 0;

  static Future<void> debug(
    String message, {
    LogCategory category = LogCategory.app,
    String? details,
  }) => _log(LogLevel.debug, message, category, details, null, null);

  static Future<void> info(
    String message, {
    LogCategory category = LogCategory.app,
    String? details,
  }) => _log(LogLevel.info, message, category, details, null, null);

  static Future<void> warning(
    String message, {
    LogCategory category = LogCategory.app,
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.warning, message, category, details, error, stackTrace);

  static Future<void> error(
    String message, {
    LogCategory category = LogCategory.app,
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.error, message, category, details, error, stackTrace);

  static Future<void> _log(
    LogLevel level,
    String message,
    LogCategory category,
    String? details,
    Object? error,
    StackTrace? stackTrace,
  ) {
    try {
      final cleanMessage = LogSanitizer.sanitize(
        message,
        maxLength: LogSanitizer.maxMessageLength,
      );
      final entry = AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: cleanMessage.trim().isEmpty ? '(no message)' : cleanMessage,
        details: LogSanitizer.sanitizeNullable(
          details,
          maxLength: LogSanitizer.maxDetailsLength,
        ),
        error: error == null
            ? null
            : LogSanitizer.sanitizeNullable(
                LogSanitizer.describeError(error),
                maxLength: LogSanitizer.maxErrorLength,
              ),
        stackTrace: LogSanitizer.sanitizeNullable(
          stackTrace?.toString(),
          maxLength: LogSanitizer.maxStackTraceLength,
        ),
      );
      _echo(entry);
      _pending.addLast(entry);
      while (_pending.length > AppConstants.maxPendingLogs) {
        _pending.removeFirst();
      }
      _scheduleDrain();
    } catch (_) {
      // Logging must never break the app.
    }
    return Future<void>.value();
  }

  static void _echo(AppLogEntry e) {
    if (!echoToConsole) return;
    assert(() {
      // ignore: avoid_print
      print(
        '[${e.level.label.toUpperCase()}][${e.category.label}] ${e.message}'
        '${e.error != null ? ' - ${e.error}' : ''}',
      );
      return true;
    }());
  }

  /// Stops writing to the database (it is opening, closing or being
  /// replaced). Entries keep queueing in memory meanwhile.
  static void holdWrites() => _held = true;

  /// Resumes writing and flushes what queued up meanwhile.
  static void releaseWrites() {
    _held = false;
    // On the event queue, so the caller finishes publishing the open database
    // before the first write asks for it.
    if (_pending.isNotEmpty) Timer.run(_scheduleDrain);
  }

  /// Completes when everything queued so far has been written (or dropped).
  /// Returns at once while writes are held or no sink is registered. Do not
  /// await this inside a database transaction.
  static Future<void> flush({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Future<void> run() async {
      while (!_held &&
          sink != null &&
          (_pending.isNotEmpty || _draining != null)) {
        final running = _draining;
        if (running != null) {
          await running;
        } else {
          _scheduleDrain();
          if (_draining == null) break;
        }
      }
    }

    try {
      await run().timeout(timeout);
    } catch (_) {
      // A stuck or failing write must not block the caller.
    }
  }

  static void _scheduleDrain() {
    if (_held || sink == null || _draining != null || _pending.isEmpty) return;
    final epoch = _epoch;
    final run = Future<void>(() => _runDrain(epoch));
    _draining = run;
    run.whenComplete(() {
      if (identical(_draining, run)) _draining = null;
      if (_pending.isNotEmpty) _scheduleDrain();
    });
  }

  static Future<void> _runDrain(int epoch) async {
    while (epoch == _epoch && _pending.isNotEmpty && !_held) {
      final target = sink;
      if (target == null) return;

      final batch = <AppLogEntry>[];
      while (_pending.isNotEmpty &&
          batch.length < AppConstants.logWriteBatchSize) {
        batch.add(_pending.removeFirst());
      }

      try {
        await target.writeBatch(batch);
        _writtenSinceTrim += batch.length;
      } catch (_) {
        // Dropped: diagnostics are not worth failing, or retrying forever.
      }

      if (!_trimmedOnce || _writtenSinceTrim >= AppConstants.logTrimInterval) {
        _trimmedOnce = true;
        _writtenSinceTrim = 0;
        try {
          await target.trim(AppConstants.maxLogEntries);
        } catch (_) {}
      }
    }
  }

  /// Number of entries waiting to be written (tests / diagnostics).
  static int get pendingCount => _pending.length;

  /// Restores the initial state. For tests.
  static void resetForTesting() {
    _epoch++;
    sink = null;
    echoToConsole = true;
    _pending.clear();
    _draining = null;
    _held = false;
    _writtenSinceTrim = 0;
    _trimmedOnce = false;
  }
}
