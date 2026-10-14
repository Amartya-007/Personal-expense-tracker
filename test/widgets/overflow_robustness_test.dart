import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_text.dart';
import 'package:mykhata/core/utils/currency_formatter.dart';
import 'package:mykhata/presentation/widgets/pill_chips.dart';

/// Phase-A layout-robustness smoke tests for the two CRITICAL/HIGH hotspots.
///
/// A-1: the shared [PillChips] horizontal row previously boxed its
/// kMinInteractiveDimension-tall chips in a kMinInteractiveDimension SizedBox,
/// overflowing the bottom (worse at larger text scale). It now sizes the box
/// to the chip height + list padding, scaled with the system text size.
///
/// A-2: the Home "This Month" figures render a crore amount through a
/// FittedBox(scaleDown) in a ~1/3-of-card slot so the value stays readable and
/// never RenderFlex-overflows its box.
///
/// These are intentionally minimal: pump a MaterialApp (so `context.palette`
/// resolves off the theme brightness), fix a phone-sized surface, and assert
/// `tester.takeException()` is null at text scale 1.0 and 1.3.
void main() {
  Widget host({required Widget child, double textScale = 1.0}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Center(child: child),
      ),
    ),
  );

  Future<void> setPhoneSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('A-1 PillChips row does not overflow', () {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('at text scale $scale', (tester) async {
        await setPhoneSurface(tester);
        await tester.pumpWidget(
          host(
            textScale: scale,
            child: PillChips(
              options: const [
                'This month',
                'Expenses',
                'Income',
                'Groceries',
                'Rent',
              ],
              selected: 'Expenses',
              onSelected: (_) {},
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('A-2 Home month figure renders a crore value without overflow', () {
    // Mirror of the _MonthFigure amount: a FittedBox(scaleDown) amount in a
    // narrow (~1/3-of-card) slot. ₹1,00,00,000 formats compact as "₹1.00 Cr".
    Widget monthFigure(double amount) => SizedBox(
      width: 100,
      child: Builder(
        builder: (context) {
          final text = amount >= 100000
              ? CurrencyFormatter.formatCompact(amount)
              : CurrencyFormatter.format(amount);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: AppText.amount(const Color(0xFF000000), size: 16),
            ),
          );
        },
      ),
    );

    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('at text scale $scale', (tester) async {
        await setPhoneSurface(tester);
        await tester.pumpWidget(
          host(
            textScale: scale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                monthFigure(99999999), // ₹9.99 Cr-ish, largest realistic
                monthFigure(10000000), // ₹1.00 Cr
                monthFigure(20000), // ₹20,000 (normal, stays full)
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
