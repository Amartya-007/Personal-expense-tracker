import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/constants/app_constants.dart';
import 'package:mykhata/core/logging/app_logger.dart';
import 'package:mykhata/core/logging/log_category.dart';
import 'package:mykhata/core/logging/log_entry.dart';
import 'package:mykhata/core/logging/log_level.dart';
import 'package:mykhata/core/logging/log_sink.dart';

class _MemorySink implements LogSink {
  final List<AppLogEntry> rows = [];
  final List<int> trims = [];
  Object? failWrites;
  Object? failTrim;

  @override
  Future<void> writeBatch(List<AppLogEntry> entries) async {
    await Future<void>.delayed(Duration.zero);
    if (failWrites != null) throw failWrites!;
    rows.addAll(entries);
  }

  @override
  Future<void> trim(int maxEntries) async {
    if (failTrim != null) throw failTrim!;
    trims.add(maxEntries);
  }
}

/// A sink that never finishes writing (a stuck database).
class _HangingSink implements LogSink {
  @override
  Future<void> writeBatch(List<AppLogEntry> entries) =>
      Completer<void>().future;

  @override
  Future<void> trim(int maxEntries) async {}
}

void main() {
  late _MemorySink sink;

  setUp(() {
    AppLogger.resetForTesting();
    AppLogger.echoToConsole = false;
    sink = _MemorySink();
    AppLogger.sink = sink;
  });

  tearDown(AppLogger.resetForTesting);

  group('AppLogger', () {
    test(
      'persists entries with level, category, message and details',
      () async {
        AppLogger.debug('d', category: LogCategory.database);
        AppLogger.info('i', category: LogCategory.backup, details: 'n=3');
        AppLogger.warning('w', category: LogCategory.sms);
        AppLogger.error('e', category: LogCategory.restore);
        await AppLogger.flush();

        expect(sink.rows.map((r) => r.level), [
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
        ]);
        expect(sink.rows[1].category, LogCategory.backup);
        expect(sink.rows[1].message, 'i');
        expect(sink.rows[1].details, 'n=3');
        expect(sink.rows.first.category, LogCategory.database);
        expect(sink.rows.every((r) => r.id == null), isTrue);
      },
    );

    test(
      'defaults to the app category and keeps entries in call order',
      () async {
        for (var i = 0; i < 120; i++) {
          AppLogger.info('m$i');
        }
        await AppLogger.flush();
        expect(sink.rows, hasLength(120)); // more than one write batch
        expect(sink.rows.map((r) => r.message), [
          for (var i = 0; i < 120; i++) 'm$i',
        ]);
        expect(sink.rows.first.category, LogCategory.app);
      },
    );

    test('error logging stores the error and stack trace separately', () async {
      final stack = StackTrace.current;
      AppLogger.error(
        'Database migration failed',
        category: LogCategory.database,
        error: StateError('disk full'),
        stackTrace: stack,
      );
      await AppLogger.flush();

      final e = sink.rows.single;
      expect(e.level, LogLevel.error);
      expect(e.error, contains('disk full'));
      expect(e.stackTrace, isNotNull);
      expect(e.stackTrace, isNotEmpty);
      expect(e.message, 'Database migration failed');
    });

    test(
      'calls return immediately even if the database never responds',
      () async {
        AppLogger.sink = _HangingSink();
        // Awaiting a log call (even inside a transaction) must not wait for the
        // write, or a stuck database would freeze the app.
        await AppLogger.info('x').timeout(const Duration(seconds: 1));
        await AppLogger.error(
          'y',
          error: 'boom',
        ).timeout(const Duration(seconds: 1));
      },
    );

    test(
      'a failing write never throws into the caller and later logs still work',
      () async {
        sink.failWrites = StateError('database is locked');
        AppLogger.error('first', error: Exception('x'));
        await AppLogger.flush(); // must complete normally
        expect(sink.rows, isEmpty);
        expect(AppLogger.pendingCount, 0);

        sink.failWrites = null;
        AppLogger.info('second');
        await AppLogger.flush();
        expect(sink.rows.single.message, 'second');
      },
    );

    test('a failing trim does not break logging', () async {
      sink.failTrim = StateError('trim failed');
      AppLogger.info('a');
      await AppLogger.flush();
      expect(sink.rows.single.message, 'a');
    });

    test(
      'a missing sink is safe: entries wait and are written once it exists',
      () async {
        AppLogger.sink = null;
        AppLogger.info('early');
        await AppLogger.flush();
        expect(AppLogger.pendingCount, 1);

        AppLogger.sink = sink;
        await AppLogger.flush();
        expect(sink.rows.single.message, 'early');
      },
    );

    test(
      'writes are held while the database is unavailable, then flushed',
      () async {
        AppLogger.holdWrites();
        AppLogger.info('during open');
        await AppLogger.flush();
        expect(sink.rows, isEmpty);
        expect(AppLogger.pendingCount, 1);

        AppLogger.releaseWrites();
        await AppLogger.flush();
        expect(sink.rows.single.message, 'during open');
      },
    );

    test('the in-memory queue is bounded', () {
      AppLogger.holdWrites();
      for (var i = 0; i < AppConstants.maxPendingLogs + 200; i++) {
        AppLogger.debug('d$i');
      }
      expect(AppLogger.pendingCount, AppConstants.maxPendingLogs);
    });

    test('retention is enforced with the configured limit', () async {
      AppLogger.info('a');
      await AppLogger.flush();
      expect(sink.trims, isNotEmpty);
      expect(sink.trims.first, AppConstants.maxLogEntries);
      expect(AppConstants.maxLogEntries, 5000);
    });

    test('an empty message is replaced, not stored blank', () async {
      AppLogger.info('   ');
      await AppLogger.flush();
      expect(sink.rows.single.message, '(no message)');
    });
  });

  group('AppLogger privacy', () {
    test('sensitive values never reach the sink', () async {
      AppLogger.info(
        'Paid from account 12345678901234 using card 4111 1111 1111 1111',
        category: LogCategory.transactions,
        details: 'password: hunter2, contact amar@example.com, spent ₹1,250.00',
      );
      AppLogger.error(
        'Import failed',
        category: LogCategory.importData,
        error: const FormatException('bad', '{"amount": 987654321}', 2),
      );
      AppLogger.error(
        'Request failed',
        error: Exception(
          'token=abcDEF123456 api_key: sk-live-9999 Bearer eyJhbGciOiJIUzI1NiJ9.payloadpayload.sig',
        ),
      );
      await AppLogger.flush();

      final stored = sink.rows
          .map((r) => '${r.message}|${r.details}|${r.error}|${r.stackTrace}')
          .join('\n');

      expect(stored, isNot(contains('12345678901234')));
      expect(stored, isNot(contains('4111 1111 1111 1111')));
      expect(stored, isNot(contains('hunter2')));
      expect(stored, isNot(contains('amar@example.com')));
      expect(stored, isNot(contains('1,250')));
      expect(stored, isNot(contains('987654321')));
      expect(stored, isNot(contains('abcDEF123456')));
      expect(stored, isNot(contains('sk-live-9999')));
      expect(stored, isNot(contains('payloadpayload')));
      expect(stored, contains('****1234'));
      expect(stored, contains('****1111'));
    });

    test('stored text is length-limited', () async {
      AppLogger.info(List.filled(2000, 'word').join(' '));
      await AppLogger.flush();
      expect(sink.rows.single.message.length, lessThan(600));
    });
  });
}
