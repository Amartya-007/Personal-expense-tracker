import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/expense_group_model.dart';
import 'package:mykhata/presentation/providers/account_providers.dart';
import 'package:mykhata/presentation/providers/expense_group_providers.dart';
import 'package:mykhata/presentation/screens/khata/expense_split_screen.dart';

class _MockAccountListNotifier extends StateNotifier<AsyncValue<List<AccountModel>>>
    implements AccountListNotifier {
  _MockAccountListNotifier(List<AccountModel> accounts)
      : super(AsyncValue.data(accounts));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ExpenseSplitScreen renders on 360px screen with no overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockGroup = ExpenseGroupModel(
      id: 'g1',
      name: 'Goa Weekend Roadtrip 2026',
      icon: '🏖️',
      description: 'Trip split',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockAccount = AccountModel(
      id: 'a1',
      name: 'HDFC Salary Primary Account',
      currentBalance: 50000.0,
      initialBalance: 50000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseGroupListProvider.overrideWith((ref) => [mockGroup]),
          accountListProvider
              .overrideWith((ref) => _MockAccountListNotifier([mockAccount])),
        ],
        child: const MaterialApp(
          home: ExpenseSplitScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no RenderFlex overflow exception
    expect(tester.takeException(), isNull);
    expect(find.text('Split Expense'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('Who Paid?'), findsOneWidget);
  });

  testWidgets('ExpenseSplitScreen renders on narrow 320px screen with no overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockGroup = ExpenseGroupModel(
      id: 'g1',
      name: 'Very Long Group Name That Could Cause RenderFlex Overflow On Tiny Screens',
      icon: '🏖️',
      description: 'Trip split',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockAccount = AccountModel(
      id: 'a1',
      name: 'Very Long Account Name For Savings And Investments Checking',
      currentBalance: 50000.0,
      initialBalance: 50000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseGroupListProvider.overrideWith((ref) => [mockGroup]),
          accountListProvider
              .overrideWith((ref) => _MockAccountListNotifier([mockAccount])),
        ],
        child: const MaterialApp(
          home: ExpenseSplitScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify zero overflow exceptions even on narrowest phone width with very long names
    expect(tester.takeException(), isNull);
  });
}
