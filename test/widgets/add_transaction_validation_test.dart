import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/category_model.dart';
import 'package:mykhata/data/models/tag_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/presentation/providers/account_providers.dart';
import 'package:mykhata/presentation/providers/category_providers.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart';
import 'package:mykhata/presentation/providers/tag_providers.dart';
import 'package:mykhata/presentation/screens/add_transaction/add_transaction_screen.dart';
import 'package:mykhata/presentation/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase-C regressions for the add-transaction inline validation (B-1a / T-1):
/// a blocked Save surfaces an inline `errorText` under the offending field
/// (not just a Snackbar), and never pops/saves. The four cases all `return`
/// inside `_saveTransaction` BEFORE any `accountListProvider`/notifier read, so
/// no DB layer is touched (the seeded providers below are never mutated).

/// Seeds [privacyModeProvider] (a `BoolPrefNotifier`) to a fixed value without
/// reading SharedPreferences. `_load()` runs async against the mock prefs
/// seeded in setUp and resolves to the same `false`, so state never flips.
class _FixedBool extends BoolPrefNotifier {
  _FixedBool(bool value) : super('test_privacy_mode', defaultValue: value);
}

/// Seeds [accountListProvider] without opening the account repository/DB:
/// [loadAccounts] is overridden to a no-op, so the constructor's load call does
/// nothing and the seeded data stands.
class _SeededAccounts extends AccountListNotifier {
  _SeededAccounts(List<AccountModel> accounts) : super(AccountRepository()) {
    state = AsyncValue.data(accounts);
  }

  @override
  Future<void> loadAccounts() async {
    // No DB: the constructor already seeded [state].
  }
}

CategoryModel _food() => CategoryModel(
  id: 'cat_food',
  name: 'Food',
  icon: '🍔',
  color: 0xFF000000,
  type: 'expense',
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  // Keep the (unused-at-save) prefs-backed providers off the real plugin.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // A tall surface so the whole collapsed form (including the Save button at
  // the bottom) fits without scrolling. Reset after each test.
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app() => ProviderScope(
    overrides: [
      privacyModeProvider.overrideWith((ref) => _FixedBool(false)),
      accountListProvider.overrideWith((ref) => _SeededAccounts(const [])),
      expenseCategoriesProvider.overrideWith((ref) async => [_food()]),
      incomeCategoriesProvider.overrideWith(
        (ref) async => const <CategoryModel>[],
      ),
      tagsListProvider.overrideWith((ref) async => const <TagModel>[]),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AddTransactionScreen(initialType: 'expense'),
    ),
  );

  // The amount field is the first TextField on the screen (the 44px amount
  // input), the description field the second.
  Finder amountField() => find.byType(TextField).first;
  Finder saveButton() => find.widgetWithText(PrimaryButton, 'Save expense');

  Future<void> pumpScreen(WidgetTester tester) async {
    await setTallSurface(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  testWidgets('(B-1a) empty amount → inline error, no save, no snackbar', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapSave(tester);

    expect(find.text('Enter a valid amount.'), findsOneWidget);
    expect(find.byType(AddTransactionScreen), findsOneWidget); // did not pop
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('(B-1a) zero amount → "greater than zero" inline error', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(amountField(), '0');
    await tapSave(tester);

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('(B-1a) unparseable amount "." → inline "valid amount" error', (
    tester,
  ) async {
    // The field's formatters block most junk ('abc', '12e9') on input; a bare
    // '.' passes the char filter but fails parse, exercising the save-boundary
    // validator backstop.
    await pumpScreen(tester);

    await tester.enterText(amountField(), '.');
    await tapSave(tester);

    expect(find.text('Enter a valid amount.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('(T-1) valid amount + empty description → description error', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(amountField(), '250');
    // Leave description empty.
    await tapSave(tester);

    expect(find.text('Enter a value.'), findsOneWidget);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('(live) errors appear and clear while typing, without Save', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Zero is flagged immediately — no Save tap.
    await tester.enterText(amountField(), '0');
    await tester.pump();
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

    // Fixing the value clears the message right away.
    await tester.enterText(amountField(), '250');
    await tester.pump();
    expect(find.text('Enter an amount greater than zero.'), findsNothing);
    expect(find.text('Enter a valid amount.'), findsNothing);

    // Emptying the field after typing is flagged live too.
    await tester.enterText(amountField(), '');
    await tester.pump();
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });
}
