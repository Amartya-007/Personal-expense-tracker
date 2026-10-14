import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/presentation/screens/add_transaction/add_transaction_screen.dart';

/// Guards the consistent, type-specific success copy shown after a save. The
/// same mapping backs both the manual add flow and the single SMS confirm.
void main() {
  test('success copy is type-specific and consistent', () {
    expect(kAddTransactionSuccessMessages['expense'], 'Expense added');
    expect(kAddTransactionSuccessMessages['income'], 'Income added');
    expect(kAddTransactionSuccessMessages['transfer'], 'Transfer saved');
  });

  test('editing an existing transaction reuses the "Changes saved" copy', () {
    expect(kAddTransactionEditedMessage, 'Changes saved');
  });
}
