import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/constants/app_constants.dart';
import 'package:mykhata/core/logging/log_category.dart';
import 'package:mykhata/core/logging/log_entry.dart';
import 'package:mykhata/core/logging/log_filter.dart';
import 'package:mykhata/core/logging/log_level.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/data/repositories/log_repository.dart';
import 'package:mykhata/presentation/providers/log_providers.dart';
import 'package:mykhata/presentation/screens/settings/logs_screen.dart';
import 'package:mykhata/presentation/widgets/app_card.dart';
import 'package:mykhata/presentation/widgets/log_level_badge.dart';
import 'package:mykhata/presentation/widgets/pill_chips.dart';

/// In-memory stand-in for the SQLite log repository. It applies the same
/// filter, ordering and paging rules, so the screen is exercised end to end
/// without a database.
class _FakeLogRepository extends LogRepository {
  _FakeLogRepository(List<AppLogEntry> seed) : store = [...seed];

  final List<AppLogEntry> store;
  Object? failReads;
  int clearCalls = 0;

  List<AppLogEntry> _matching(LogFilter f) {
    final q = f.normalizedQuery?.toLowerCase();
    final list = store
        .where(
          (e) =>
              (f.level == null || e.level == f.level) &&
              (f.category == null || e.category == f.category) &&
              (q == null ||
                  e.message.toLowerCase().contains(q) ||
                  e.category.value.contains(q)),
        )
        .toList();
    list.sort((a, b) {
      final c = b.timestamp.compareTo(a.timestamp);
      return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return list;
  }

  @override
  Future<List<AppLogEntry>> getLogs({
    LogFilter filter = const LogFilter(),
    int limit = AppConstants.logPageSize,
    int offset = 0,
  }) async {
    if (failReads != null) throw failReads!;
    return _matching(filter).skip(offset).take(limit).toList();
  }

  @override
  Future<int> count({LogFilter filter = const LogFilter()}) async =>
      _matching(filter).length;

  @override
  Future<int> clearAll() async {
    clearCalls++;
    final n = store.length;
    store.clear();
    return n;
  }
}

AppLogEntry _entry(
  int id,
  String message, {
  LogLevel level = LogLevel.info,
  LogCategory category = LogCategory.app,
  int minute = 0,
  String? details,
  String? error,
  String? stackTrace,
}) => AppLogEntry(
  id: id,
  timestamp: DateTime(2026, 10, 21, 9, minute),
  level: level,
  category: category,
  message: message,
  details: details,
  error: error,
  stackTrace: stackTrace,
);

void main() {
  Future<void> tallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(WidgetTester tester, _FakeLogRepository repo) async {
    await tallSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LogsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
  }

  group('Logs screen', () {
    testWidgets('shows a proper empty state when there are no logs', (
      tester,
    ) async {
      await pumpScreen(tester, _FakeLogRepository(const []));

      expect(find.text('No logs yet'), findsOneWidget);
      expect(find.textContaining('will appear here'), findsOneWidget);
      expect(find.byType(LogLevelBadge), findsNothing);
    });

    testWidgets('lists logs newest first with level, category and message', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _FakeLogRepository([
          _entry(1, 'Oldest entry', minute: 1),
          _entry(
            2,
            'Newest entry',
            minute: 30,
            level: LogLevel.error,
            category: LogCategory.backup,
          ),
          _entry(3, 'Middle entry', minute: 15, level: LogLevel.warning),
        ]),
      );

      final newest = tester.getTopLeft(find.text('Newest entry')).dy;
      final middle = tester.getTopLeft(find.text('Middle entry')).dy;
      final oldest = tester.getTopLeft(find.text('Oldest entry')).dy;
      expect(newest, lessThan(middle));
      expect(middle, lessThan(oldest));

      expect(find.byType(LogLevelBadge), findsNWidgets(3));
      expect(find.text('3 logs'), findsOneWidget);
      // The row of the newest entry shows its category.
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.text('Backup'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a log shows every technical detail and can copy it', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpScreen(
        tester,
        _FakeLogRepository([
          _entry(
            1,
            'Database migration failed',
            level: LogLevel.error,
            category: LogCategory.database,
            details: 'v3 to v4',
            error: 'Bad state: disk full',
            stackTrace: '#0 migrate (database_migrations.dart:10:3)',
          ),
        ]),
      );

      await tester.tap(find.text('Database migration failed'));
      await tester.pumpAndSettle();

      expect(find.text('Log details'), findsOneWidget);
      expect(find.text('v3 to v4'), findsOneWidget);
      expect(find.text('Bad state: disk full'), findsOneWidget);
      expect(
        find.text('#0 migrate (database_migrations.dart:10:3)'),
        findsOneWidget,
      );
      // Full timestamp (the AM/PM separator varies by platform locale data).
      expect(find.textContaining('21 Oct 2026'), findsOneWidget);

      await tester.tap(find.text('Copy details'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      expect(copied, contains('Database migration failed'));
      expect(copied, contains('Bad state: disk full'));
      expect(copied, contains('#0 migrate'));
      expect(find.text('Log details copied'), findsOneWidget);
    });

    testWidgets('filters by level', (tester) async {
      await pumpScreen(
        tester,
        _FakeLogRepository([
          _entry(1, 'An info entry', minute: 1),
          _entry(2, 'A warning entry', minute: 2, level: LogLevel.warning),
          _entry(3, 'An error entry', minute: 3, level: LogLevel.error),
        ]),
      );

      await tester.tap(find.widgetWithText(PillChip, 'Warning'));
      await tester.pumpAndSettle();

      expect(find.text('A warning entry'), findsOneWidget);
      expect(find.text('An info entry'), findsNothing);
      expect(find.text('An error entry'), findsNothing);
      expect(find.text('1 log'), findsOneWidget);

      await tester.tap(find.widgetWithText(PillChip, 'All').first);
      await tester.pumpAndSettle();
      expect(find.byType(LogLevelBadge), findsNWidgets(3));
    });

    testWidgets('filters by category', (tester) async {
      await pumpScreen(
        tester,
        _FakeLogRepository([
          _entry(1, 'Opened', minute: 1, category: LogCategory.database),
          _entry(2, 'Backed up', minute: 2, category: LogCategory.backup),
        ]),
      );

      await tester.tap(find.widgetWithText(PillChip, 'Database'));
      await tester.pumpAndSettle();

      expect(find.text('Opened'), findsOneWidget);
      expect(find.text('Backed up'), findsNothing);
    });

    testWidgets('search narrows the list, and no results offers to clear', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _FakeLogRepository([
          _entry(1, 'Backup started', minute: 1),
          _entry(2, 'SMS scan completed', minute: 2),
        ]),
      );

      await tester.enterText(find.byType(TextField), 'backup');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Backup started'), findsOneWidget);
      expect(find.text('SMS scan completed'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No matching logs'), findsOneWidget);
      expect(find.text('No logs yet'), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Backup started'), findsOneWidget);
      expect(find.text('SMS scan completed'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('clearing all logs asks first, then shows the empty state', (
      tester,
    ) async {
      final repo = _FakeLogRepository([
        _entry(1, 'First entry', minute: 1),
        _entry(2, 'Second entry', minute: 2),
      ]);
      await pumpScreen(tester, repo);

      // Cancel: nothing is deleted.
      await openMenu(tester);
      await tester.tap(find.text('Clear all logs'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all logs?'), findsOneWidget);
      expect(find.textContaining('permanently removes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.clearCalls, 0);
      expect(find.text('First entry'), findsOneWidget);

      // Confirm: logs are removed and the list refreshes to the empty state.
      await openMenu(tester);
      await tester.tap(find.text('Clear all logs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear logs'));
      await tester.pumpAndSettle();

      expect(repo.clearCalls, 1);
      expect(find.text('No logs yet'), findsOneWidget);
      expect(find.text('First entry'), findsNothing);
      expect(find.text('Logs cleared'), findsOneWidget);
    });

    testWidgets('the menu offers export and clear, disabled with no logs', (
      tester,
    ) async {
      await pumpScreen(tester, _FakeLogRepository(const []));
      await openMenu(tester);

      PopupMenuItem<Object?> item(String label) => tester.widget(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      expect(item('Export logs').enabled, isFalse);
      expect(item('Clear all logs').enabled, isFalse);
    });

    testWidgets('a read failure shows an error state that can be retried', (
      tester,
    ) async {
      final repo = _FakeLogRepository([_entry(1, 'Recovered entry')])
        ..failReads = StateError('db locked');
      await pumpScreen(tester, repo);

      expect(find.text('Could not load logs'), findsOneWidget);
      // The raw error text is not shown to the user.
      expect(find.textContaining('db locked'), findsNothing);

      repo.failReads = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered entry'), findsOneWidget);
    });

    testWidgets('loads further pages as the list is scrolled', (tester) async {
      final base = DateTime(2026, 10, 21);
      final repo = _FakeLogRepository([
        for (var i = 0; i < 120; i++)
          AppLogEntry(
            id: i + 1,
            timestamp: base.add(Duration(minutes: i)),
            level: LogLevel.info,
            category: LogCategory.app,
            message: 'Entry $i',
          ),
      ]);
      await pumpScreen(tester, repo);

      expect(find.text('120 logs'), findsOneWidget);
      expect(find.text('Entry 0'), findsNothing); // beyond the first page

      for (var i = 0; i < 14; i++) {
        await tester.drag(
          find.byType(RefreshIndicator),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Entry 0'), findsOneWidget);
    });
  });
}
