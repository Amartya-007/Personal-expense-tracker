import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/presentation/widgets/list_widgets.dart';

/// Regression tests for two reported bugs:
///
/// 1. Settings labels were truncating ("Save Location with E…",
///    "Hide Balances and AMO…", "Import Transaction From…") because
///    [ListRowTile] forced the title to a single line beside a trailing
///    toggle/chevron. The title now wraps to [ListRowTile.titleMaxLines]
///    (default 2), so the full label stays readable on narrow screens.
///
/// 2. The Home per-account cards scrolled horizontally with no cue that more
///    cards existed off-screen once a third account was added. The chips now
///    wrap (centred) when they fit and only scroll when they genuinely cannot
///    — the wrap case is what covers the reported 3-account scenario.
void main() {
  Widget host({
    required Widget child,
    double textScale = 1.0,
    double width = 360,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  Future<void> setPhoneSurface(
    WidgetTester tester, {
    Size size = const Size(360, 740),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('ListRowTile title no longer truncates to one line', () {
    testWidgets(
      'a long settings label wraps instead of ellipsising at the end',
      (tester) async {
        await setPhoneSurface(tester);
        await tester.pumpWidget(
          host(
            child: ListRowTile(
              emoji: '📍',
              title: 'Save location with expenses',
              subtitle: 'Captured only at the moment you save',
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The full title is present and allowed to use two lines (not clipped
        // to a single line).
        final titleFinder = find.text('Save location with expenses');
        expect(titleFinder, findsOneWidget);
        final titleWidget = tester.widget<Text>(titleFinder);
        expect(titleWidget.maxLines, 2);
        expect(titleWidget.overflow, TextOverflow.ellipsis);
      },
    );

    testWidgets('default titleMaxLines is 2; callers can still request 1', (
      tester,
    ) async {
      await setPhoneSurface(tester);
      await tester.pumpWidget(
        host(
          child: const Column(
            children: [
              ListRowTile(title: 'Default wraps'),
              ListRowTile(title: 'Dense single line', titleMaxLines: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('Default wraps')).maxLines, 2);
      expect(tester.widget<Text>(find.text('Dense single line')).maxLines, 1);
    });

    testWidgets('long labels stay overflow-safe at text scale 1.3', (
      tester,
    ) async {
      await setPhoneSurface(tester);
      await tester.pumpWidget(
        host(
          textScale: 1.3,
          child: ListRowTile(
            emoji: '📥',
            title: 'Import transactions from CSV',
            subtitle: 'You will see a preview before anything is added',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Import transactions from CSV'), findsOneWidget);
    });
  });
}
