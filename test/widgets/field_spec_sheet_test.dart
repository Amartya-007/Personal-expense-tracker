import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/presentation/widgets/app_sheets.dart';

/// Phase-C regressions for the extended [FieldSpec] sheet (Part-B validation
/// rendering). Each case asserts the REAL strings produced by `_FieldsForm`
/// and `AmountInput.validateAmount` — inline `errorText`, Flutter's default
/// `<current>/<max>` counter, and value preservation across a sibling error.
///
/// The sheet is opened through a host button, matching keyboard_focus_test.dart.
void main() {
  Widget host(void Function(BuildContext) onOpen) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onOpen(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(
    WidgetTester tester, {
    required List<FieldSpec> fields,
    String submitLabel = 'Save',
  }) async {
    await tester.pumpWidget(
      host(
        (context) => showFieldsSheet(
          context,
          title: 'Edit',
          fields: fields,
          submitLabel: submitLabel,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder submitButton(String label) =>
      find.widgetWithText(ElevatedButton, label);

  testWidgets('(B-3a) empty required field shows inline error, blocks submit', (
    tester,
  ) async {
    await openSheet(
      tester,
      fields: const [
        FieldSpec(
          label: 'Name',
          required: true,
          maxLength: 40,
          showCounter: true,
        ),
      ],
    );

    await tester.tap(submitButton('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsOneWidget);
    // Sheet stays open (submit blocked) — the Save button is still shown.
    expect(submitButton('Save'), findsOneWidget);
  });

  testWidgets('(B-3b) over-cap amount shows the exact cap message inline', (
    tester,
  ) async {
    await openSheet(
      tester,
      fields: const [FieldSpec(label: 'Limit', numeric: true, required: true)],
    );

    await tester.enterText(find.byType(TextField), '1000000000000');
    await tester.tap(submitButton('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Amount cannot exceed ₹9,99,99,99,99,999.'),
      findsOneWidget,
    );
  });

  testWidgets('(B-3c) maxLength counter renders and the value is capped at 40', (
    tester,
  ) async {
    await openSheet(
      tester,
      fields: const [
        FieldSpec(label: 'Name', maxLength: 40, showCounter: true),
      ],
    );

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.text('3/40'), findsOneWidget);

    // A 50-char string is capped by LengthLimitingTextInputFormatter(40); the
    // counter can never read past 40/40, which is the observable proof the cap
    // held (the private controller is unreadable from here).
    await tester.enterText(find.byType(TextField), 'a' * 50);
    await tester.pump();
    expect(find.text('40/40'), findsOneWidget);
  });

  testWidgets('(B-3d) one invalid field keeps the other field\'s value', (
    tester,
  ) async {
    await openSheet(
      tester,
      fields: const [
        FieldSpec(label: 'Name', required: true, maxLength: 40),
        FieldSpec(label: 'Amount', numeric: true, required: true),
      ],
    );

    // Valid name first, invalid (empty) amount second — _submit stops at the
    // first failure, which is the second field.
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Savings');
    await tester.pump();
    await tester.tap(submitButton('Save'));
    await tester.pumpAndSettle();

    // The Amount field errors…
    expect(find.text('This field is required.'), findsOneWidget);
    // …while the Name field keeps its value (controller not reset on a
    // sibling-field error).
    expect(find.text('Savings'), findsOneWidget);
  });

  testWidgets('(§10) a showCounter field renders and updates its counter', (
    tester,
  ) async {
    await openSheet(
      tester,
      fields: const [
        FieldSpec(label: 'Account name', maxLength: 40, showCounter: true),
      ],
    );

    expect(find.text('0/40'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My Savings'); // 10 chars
    await tester.pump();
    expect(find.text('10/40'), findsOneWidget);
  });
}
