import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/presentation/widgets/app_dropdown.dart';
import 'package:mykhata/presentation/widgets/app_sheets.dart';

/// Bug: choosing a category/tag/account from a picker made the keyboard pop
/// up again, because focus was handed back to the text field that had it
/// before the picker opened.
void main() {
  Widget host(Widget Function(BuildContext) body) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: Builder(builder: body)),
      );

  testWidgets('closing a sheet does not give focus back to the text field',
      (tester) async {
    final field = FocusNode();
    addTearDown(field.dispose);

    await tester.pumpWidget(
      host(
        (context) => Column(
          children: [
            TextField(focusNode: field),
            TextButton(
              onPressed: () => AppBottomSheet.show<void>(
                context,
                title: 'Pick',
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(field.hasFocus, isFalse, reason: 'opening a sheet drops focus');

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(field.hasFocus, isFalse, reason: 'closing must not restore focus');
  });

  testWidgets('choosing from a dropdown leaves the text fields unfocused',
      (tester) async {
    final field = FocusNode();
    addTearDown(field.dispose);
    String? chosen;

    await tester.pumpWidget(
      host(
        (context) => StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              TextField(focusNode: field),
              AppDropdown<String>(
                hint: 'Category',
                value: chosen,
                items: const ['Food', 'Travel'],
                labelOf: (s) => s,
                onChanged: (s) => setState(() => chosen = s),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();

    expect(chosen, 'Travel');
    expect(field.hasFocus, isFalse);
  });

  testWidgets('cancelling a delete confirmation does not refocus the field',
      (tester) async {
    final field = FocusNode();
    addTearDown(field.dispose);

    await tester.pumpWidget(
      host(
        (context) => Column(
          children: [
            TextField(focusNode: field),
            TextButton(
              onPressed: () => confirmDestructive(
                context,
                title: 'Delete?',
                message: 'Sure?',
              ),
              child: const Text('Ask'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(field.hasFocus, isFalse);
  });
}
