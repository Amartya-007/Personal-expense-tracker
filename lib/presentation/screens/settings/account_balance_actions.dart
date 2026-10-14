import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_input.dart';
import '../../../data/models/account_model.dart';
import '../../providers/home_controller.dart';
import '../../widgets/app_sheets.dart';

/// Shared "Edit balance" flow used by both Home's hero account chips and the
/// Accounts management screen, so both record the SAME adjustment through
/// [homeControllerProvider.updateAccountBalance] (never a silent set) and show
/// identical messaging. The adjustment math stays inside the controller — this
/// helper only drives the sheet and the feedback.
Future<void> editAccountBalance(
  BuildContext context,
  WidgetRef ref,
  AccountModel account,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final values = await showFieldsSheet(
    context,
    title: 'Edit ${account.name} balance',
    submitLabel: 'Save balance',
    fields: [
      FieldSpec(
        label: 'Balance (₹)',
        numeric: true,
        required: true,
        allowNegative: true,
        maxValue: kMaxAmount,
        initial: account.currentBalance.toStringAsFixed(2),
      ),
    ],
  );
  if (values == null) return;

  // The field already blocked invalid/over-cap input inline; this parse is a
  // defensive guard that keeps the existing "enter a valid amount" fallback.
  final newBalance = AmountInput.parseAmount(values[0], allowNegative: true);
  if (newBalance == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Enter a valid amount.')),
    );
    return;
  }

  final success = await ref
      .read(homeControllerProvider.notifier)
      .updateAccountBalance(account.id, newBalance);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        success
            ? 'Adjustment recorded for ${account.name}'
            : 'Could not update ${account.name} balance',
      ),
    ),
  );
}
