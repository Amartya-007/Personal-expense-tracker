import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/presentation/providers/account_providers.dart';
import 'package:mykhata/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mykhata/presentation/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget coverage for the rebuilt 8-step onboarding flow:
/// every step renders, the account-step Continue is gated on an account
/// existing, and the done step names the created accounts (and the optional
/// user name).

/// Seeds [accountListProvider] without touching the DB (its [loadAccounts] is
/// a no-op so the constructor's load does nothing).
class _SeededAccounts extends AccountListNotifier {
  _SeededAccounts() : super(AccountRepository()) {
    state = const AsyncValue.data(<AccountModel>[]);
  }

  @override
  Future<void> loadAccounts() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app() => ProviderScope(
    overrides: [accountListProvider.overrideWith((ref) => _SeededAccounts())],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OnboardingScreen(),
    ),
  );

  // Illustrations animate indefinitely (orbit/float/scan/ring), so
  // pumpAndSettle would time out. Pump a fixed span long enough for step
  // transitions and entrance staggers to finish instead.
  Future<void> stabilise(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await setTallSurface(tester);
    await tester.pumpWidget(app());
    await stabilise(tester);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(PrimaryButton, label));
    await stabilise(tester);
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await stabilise(tester);
  }

  Future<void> enterFirstField(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await stabilise(tester);
  }

  Finder continueButton() => find.widgetWithText(PrimaryButton, 'Continue');

  testWidgets('welcome step renders the brand and get-started CTA', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(find.text('MyKhata'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Get started'), findsOneWidget);
  });

  testWidgets('each of the 8 steps renders without exception', (tester) async {
    await pumpOnboarding(tester);

    // 0 welcome
    expect(find.text('MyKhata'), findsOneWidget);
    await tapButton(tester, 'Get started');

    // 1 sms
    expect(find.text('Bank messages, sorted for you'), findsOneWidget);
    await tapButton(tester, 'Next');

    // 2 receipt
    expect(find.text('Keep receipts with the expense'), findsOneWidget);
    await tapButton(tester, 'Next');

    // 3 budget
    expect(find.text('Budgets that tell you early'), findsOneWidget);
    await tapButton(tester, 'Next');

    // 4 add first account
    expect(find.text('Add your first bank account'), findsOneWidget);
    await enterFirstField(tester, 'SBI');
    await tapButton(tester, 'Continue');

    // 5 permissions — avoid real permission plugins by tapping "Not now".
    expect(find.text('A few permissions'), findsOneWidget);
    await tapText(tester, 'Not now');

    // 6 security — avoid the biometric plugin by tapping "Maybe later".
    expect(find.text('Lock it down'), findsOneWidget);
    await tapText(tester, 'Maybe later');

    // 7 done
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Open MyKhata'), findsOneWidget);
  });

  testWidgets('account step Continue is disabled until an account exists', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tapButton(tester, 'Get started');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');

    expect(find.text('Add your first bank account'), findsOneWidget);

    // Disabled: PrimaryButton.onPressed is null.
    PrimaryButton button = tester.widget(continueButton());
    expect(button.onPressed, isNull);

    // Typing a name enables it live.
    await enterFirstField(tester, 'SBI');
    button = tester.widget(continueButton());
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'adding another account shows a chip and keeps Continue enabled',
    (tester) async {
      await pumpOnboarding(tester);
      await tapButton(tester, 'Get started');
      await tapButton(tester, 'Next');
      await tapButton(tester, 'Next');
      await tapButton(tester, 'Next');

      await enterFirstField(tester, 'SBI');
      await tapText(tester, 'Add another bank account');

      // The queued account is now shown; the name field was cleared.
      expect(find.text('SBI'), findsOneWidget);
      final PrimaryButton button = tester.widget(continueButton());
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('done step names the created accounts', (tester) async {
    await pumpOnboarding(tester);
    await tapButton(tester, 'Get started');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');

    // Queue two accounts.
    await enterFirstField(tester, 'SBI');
    await tapText(tester, 'Add another bank account');
    await enterFirstField(tester, 'HDFC');

    await tapButton(tester, 'Continue');
    await tapText(tester, 'Not now');
    await tapText(tester, 'Maybe later');

    expect(find.textContaining('SBI and HDFC ready to track.'), findsOneWidget);
  });

  testWidgets('optional name on welcome personalises the done title', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await enterFirstField(tester, 'Asha');
    await tapButton(tester, 'Get started');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Next');

    await enterFirstField(tester, 'SBI');
    await tapButton(tester, 'Continue');
    await tapText(tester, 'Not now');
    await tapText(tester, 'Maybe later');

    expect(find.text("You're all set, Asha"), findsOneWidget);
  });
}
