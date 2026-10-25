import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/constants/app_constants.dart';
import 'package:mykhata/core/logging/log_category.dart';
import 'package:mykhata/core/logging/log_entry.dart';
import 'package:mykhata/core/logging/log_export_document.dart';
import 'package:mykhata/core/logging/log_level.dart';

AppLogEntry _entry(
  String message, {
  LogLevel level = LogLevel.info,
  LogCategory category = LogCategory.app,
  DateTime? at,
  String? details,
  String? error,
  String? stackTrace,
}) => AppLogEntry(
  timestamp: at ?? DateTime.utc(2026, 10, 21, 9, 13, 5),
  level: level,
  category: category,
  message: message,
  details: details,
  error: error,
  stackTrace: stackTrace,
);

void main() {
  final exportedAt = DateTime.utc(2026, 10, 26, 12, 0, 0);

  Map<String, dynamic> build(List<AppLogEntry> logs) =>
      jsonDecode(LogExportDocument.build(logs, exportedAt: exportedAt))
          as Map<String, dynamic>;

  group('LogExportDocument', () {
    test('has the documented header and one object per log', () {
      final doc = build([
        _entry(
          'Database initialization failed',
          level: LogLevel.error,
          category: LogCategory.database,
          details: 'schema version 4',
          error: 'Bad state: disk full',
          stackTrace: '#0 main (file.dart:1:1)',
        ),
        _entry('Backup started', category: LogCategory.backup),
      ]);

      expect(doc['exportedAt'], '2026-10-26T12:00:00.000Z');
      expect(doc['appName'], AppConstants.appName);
      expect(doc['appVersion'], AppConstants.appVersion);
      expect(doc['logCount'], 2);

      final logs = doc['logs'] as List;
      expect(logs, hasLength(2));
      final first = logs.first as Map<String, dynamic>;
      expect(first['timestamp'], '2026-10-21T09:13:05.000Z');
      expect(first['level'], 'error');
      expect(first['category'], 'database');
      expect(first['message'], 'Database initialization failed');
      expect(first['details'], 'schema version 4');
      expect(first['error'], 'Bad state: disk full');
      expect(first['stackTrace'], '#0 main (file.dart:1:1)');
    });

    test('leaves out empty optional fields and keeps the given order', () {
      final doc = build([
        _entry('newest', at: DateTime.utc(2026, 10, 21, 10)),
        _entry('oldest', at: DateTime.utc(2026, 10, 21, 8)),
      ]);
      final logs = (doc['logs'] as List).cast<Map<String, dynamic>>();
      expect(logs.map((l) => l['message']), ['newest', 'oldest']);
      expect(logs.first.containsKey('details'), isFalse);
      expect(logs.first.containsKey('error'), isFalse);
      expect(logs.first.containsKey('stackTrace'), isFalse);
    });

    test('an empty log still produces a valid document', () {
      final doc = build(const []);
      expect(doc['logCount'], 0);
      expect(doc['logs'], isEmpty);
    });

    test(
      'is sanitised again: sensitive text in a stored row is not exported',
      () {
        final text = LogExportDocument.build([
          _entry(
            'Paid from 12345678901234',
            details: 'password: hunter2 amar@example.com ₹1,250.00',
            error: 'token=abcDEF123456',
          ),
        ], exportedAt: exportedAt);

        expect(text, isNot(contains('12345678901234')));
        expect(text, isNot(contains('hunter2')));
        expect(text, isNot(contains('amar@example.com')));
        expect(text, isNot(contains('1,250')));
        expect(text, isNot(contains('abcDEF123456')));
        expect(text, contains('****1234'));
      },
    );

    test('uses the supplied app version', () {
      final doc = jsonDecode(
        LogExportDocument.build(
          const [],
          exportedAt: exportedAt,
          appVersion: '9.9.9',
        ),
      ) as Map<String, dynamic>;
      expect(doc['appVersion'], '9.9.9');
    });
  });

  group('AppLogEntry', () {
    test('round-trips through its database map', () {
      final e = AppLogEntry(
        id: 7,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1760000000000),
        level: LogLevel.warning,
        category: LogCategory.sms,
        message: 'm',
        details: 'd',
        error: 'e',
        stackTrace: 's',
      );
      final back = AppLogEntry.fromMap(e.toMap());
      expect(back.id, 7);
      expect(back.timestamp, e.timestamp);
      expect(back.level, LogLevel.warning);
      expect(back.category, LogCategory.sms);
      expect(back.message, 'm');
      expect(back.details, 'd');
      expect(back.error, 'e');
      expect(back.stackTrace, 's');
    });

    test('unknown stored values fall back safely', () {
      final e = AppLogEntry.fromMap({
        'id': 1,
        'timestamp': 0,
        'level': 'WARN', // legacy upper-case value
        'category': 'something-new',
        'message': 'x',
      });
      expect(e.level, LogLevel.warning);
      expect(e.category, LogCategory.app);
    });

    test('copy text includes every technical section that is present', () {
      final text = _entry(
        'Boom',
        level: LogLevel.error,
        category: LogCategory.restore,
        details: 'step 2',
        error: 'Bad state',
        stackTrace: '#0 main',
      ).toDiagnosticText();
      expect(text, contains('Level: Error'));
      expect(text, contains('Category: Restore'));
      expect(text, contains('Message: Boom'));
      expect(text, contains('step 2'));
      expect(text, contains('Bad state'));
      expect(text, contains('#0 main'));
    });
  });
}
