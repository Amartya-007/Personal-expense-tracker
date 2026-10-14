import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/presentation/widgets/empty_state.dart';

/// The empty Transactions list renders the shared [EmptyState] with a single
/// primary action. This verifies that exact component (title + tappable
/// action) without standing up the whole screen and its providers.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  testWidgets('EmptyState shows its title and a working primary action', (
    tester,
  ) async {
    var tapped = 0;

    await tester.pumpWidget(
      host(
        EmptyState(
          emoji: '🧾',
          title: 'No transactions yet',
          message: 'Add your first expense to get started.',
          actionLabel: 'Add expense',
          onAction: () => tapped++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);

    await tester.tap(find.text('Add expense'));
    await tester.pump();
    expect(tapped, 1);
  });
}
