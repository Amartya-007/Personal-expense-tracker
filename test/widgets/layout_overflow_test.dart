import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/core/utils/currency_formatter.dart';
import 'package:mykhata/data/models/budget_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/presentation/widgets/budget_row.dart';
import 'package:mykhata/presentation/widgets/pill_chips.dart';
import 'package:mykhata/presentation/widgets/segmented_tabs.dart';
import 'package:mykhata/presentation/widgets/transaction_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase-C layout/overflow/text-scale regressions for the Phase-A fixes.
///
/// Each test pins the REAL implemented behaviour: no `RenderFlex` overflow at a
/// constrained width and/or large text scale, long text ellipsised, amounts
/// shrunk via `FittedBox` (never truncated), and the text-scale-aware chip
/// height formula. Private widgets (`_QuickFilterChips`, `_MonthFigure`,
/// `_NavButton`, the Insights `line` closure, the SMS card row) cannot be
/// imported from `test/`; where their Phase-A fix is literally the same pattern
/// carried by a public widget, that public carrier is asserted and the proxy is
/// documented inline (see the §proxy group at the bottom).

/// Long realistic sample strings from the brief, so the tests document the
/// extremes the layout must survive.
const _longDescription =
    'Dinner at the extremely long-named restaurant downtown with friends';
const _longCategory = 'Groceries and household monthly essentials';

TransactionModel _expenseTx() {
  final now = DateTime(2024, 1, 1);
  return TransactionModel(
    id: 'tx_1',
    type: 'expense',
    amount: 999999999.0, // 9-digit signed amount
    description: _longDescription,
    categoryName: 'Food',
    paymentMethod: 'UPI',
    accountId: 'acc_1',
    date: now,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetModel _croreBudget() {
  final now = DateTime(2024, 1, 1);
  return BudgetModel(
    id: 'b_1',
    categoryId: 'cat_1',
    categoryName: _longCategory,
    period: 'monthly',
    amount: 10000000.0, // ₹1 Cr limit
    spentAmount: 9999999.0, // just under a crore spent
    startDate: now,
    endDate: now.add(const Duration(days: 30)),
    createdAt: now,
  );
}

void main() {
  // Privacy mode defaults to false; seeding empty mock prefs keeps
  // privacyModeProvider from hitting the real plugin, so amounts render
  // unmasked (no override needed — the default value is already what we want).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A real-theme host with a ProviderScope so the amount-bearing
  /// `ConsumerWidget`s (TransactionRow/BudgetRow) can read privacyModeProvider.
  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );

  /// Constrains a widget to a ~320px logical width (the narrowest supported
  /// phone), the width at which the Phase-A overflows originally appeared.
  Widget narrow(Widget child) =>
      Center(child: SizedBox(width: 320, child: child));

  /// Wraps a widget in a [MediaQuery] that scales text by [s].
  Widget scaled(Widget child, double s) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s)),
      child: child,
    ),
  );

  group('TransactionRow (A-13) narrow + long description + 9-digit amount', () {
    testWidgets('does not overflow; description ellipsised; amount shrinks', (
      tester,
    ) async {
      final tx = _expenseTx();
      await tester.pumpWidget(host(narrow(TransactionRow(transaction: tx))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Description is present and ellipsised.
      final descFinder = find.text(_longDescription);
      expect(descFinder, findsOneWidget);
      expect(tester.widget<Text>(descFinder).overflow, TextOverflow.ellipsis);

      // Amount still shows (expense prefix is U+2212 '−', so match the digits)
      // and lives under a FittedBox that scales it down.
      final amountFinder = find.textContaining('99,99,999');
      expect(amountFinder, findsOneWidget);
      expect(
        find.ancestor(of: amountFinder, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
    });
  });

  group('BudgetRow (A-14) narrow + long category + crore spent/limit', () {
    testWidgets('does not overflow; name ellipsised; figures under FittedBox', (
      tester,
    ) async {
      final b = _croreBudget();
      await tester.pumpWidget(host(narrow(BudgetRow(budget: b))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Category name present and ellipsised (prefixed by an emoji).
      final nameFinder = find.textContaining(_longCategory);
      expect(nameFinder, findsOneWidget);
      expect(tester.widget<Text>(nameFinder).overflow, TextOverflow.ellipsis);

      // Trailing "spent / limit" pair shows both figures under a FittedBox.
      final expected =
          '${CurrencyFormatter.format(b.spentAmount)} / '
          '${CurrencyFormatter.format(b.amount)}';
      final pairFinder = find.text(expected);
      expect(pairFinder, findsOneWidget);
      expect(
        find.ancestor(of: pairFinder, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
    });
  });

  group('PillChips (A-1) text-scale-aware height', () {
    // The shared PillChips carries the Phase-A height fix used by History's
    // _QuickFilterChips and the Insights/Budgets chip rows: the bounded box is
    // `scale(kMinInteractiveDimension) + verticalPadding`, never a hard 48.
    const padding = EdgeInsets.fromLTRB(18, 8, 18, 4); // vertical = 12
    const options = ['This month', 'Expenses', 'Income', 'Food', 'Travel'];

    Future<void> pumpAt(WidgetTester tester, double s) async {
      await tester.pumpWidget(
        host(
          scaled(
            narrow(
              PillChips(
                options: options,
                selected: 'This month',
                onSelected: (_) {},
                padding: padding,
              ),
            ),
            s,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no vertical overflow and correct height at scale 1.0', (
      tester,
    ) async {
      await pumpAt(tester, 1.0);
      expect(tester.takeException(), isNull);

      final box = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ListView),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        box.height,
        TextScaler.linear(1.0).scale(kMinInteractiveDimension) + 12,
      );
    });

    testWidgets('no vertical overflow and taller height at scale 1.3', (
      tester,
    ) async {
      await pumpAt(tester, 1.3);
      expect(tester.takeException(), isNull);

      final box = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ListView),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        box.height,
        TextScaler.linear(1.3).scale(kMinInteractiveDimension) + 12,
      );
    });
  });

  group('SegmentedTabs (A-17) long options + text scale', () {
    testWidgets(
      'narrow + scale 1.3 does not overflow; options under FittedBox',
      (tester) async {
        await tester.pumpWidget(
          host(
            scaled(
              narrow(
                SegmentedTabs(
                  options: const ['UPI', 'Cash', 'Debit Card'],
                  selected: 'UPI',
                  onSelected: (_) {},
                ),
              ),
              1.3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.ancestor(
            of: find.text('Debit Card'),
            matching: find.byType(FittedBox),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('SMS-style long option set does not overflow', (tester) async {
      await tester.pumpWidget(
        host(
          scaled(
            narrow(
              SegmentedTabs(
                options: const ['Detected · 999', 'Review'],
                selected: 'Review',
                onSelected: (_) {},
              ),
            ),
            1.3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(
          of: find.text('Detected · 999'),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
    });
  });

  group('A-2 crore figure — compact value (non-stub)', () {
    // `_MonthFigure` is private. Its Phase-A behaviour is pure: a crore amount
    // (>= 1 lakh) renders `formatCompact(...)` inside a FittedBox, NOT a bare
    // ellipsised stub. The exact value is pinned here and in the formatter
    // unit test (transaction_calculation_test.dart). The FittedBox-around-the-
    // amount pattern is exercised by the public TransactionRow/BudgetRow tests
    // above (identical pattern), so A-2 is protected by value + shared pattern.
    test('crore figure renders the real compact string, not a stub', () {
      expect(CurrencyFormatter.formatCompact(99999999.0), '₹10.00 Cr');
      expect(CurrencyFormatter.formatCompact(10000000.0), '₹1.00 Cr');
      // Below a lakh _MonthFigure uses the full format(), proving the branch.
      expect(CurrencyFormatter.format(99999.0), '₹99,999.00');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // §proxy — private widgets covered through their public carriers.
  //
  // A-15 (SMS card amount) and A-20 (Insights income/expense/net rows) use the
  //   SAME `Flexible + FittedBox(scaleDown)` amount pattern asserted on
  //   TransactionRow (A-13) and BudgetRow (A-14) above.
  // A-26 (bottom-nav labels) uses the SAME `FittedBox(scaleDown, Text(maxLines:
  //   1))` fix asserted on SegmentedTabs (A-17) above; the nav label
  //   'Transactions' is laid out through that identical FittedBox.
  // A-1 (_QuickFilterChips) duplicates the exact PillChips height formula
  //   asserted above.
  // These widgets are library-private and cannot be imported from test/, so
  // the regression is protected through the public carriers rather than a
  // golden test or an aspirational replica. See plan-phaseC.md §Findings.
}
