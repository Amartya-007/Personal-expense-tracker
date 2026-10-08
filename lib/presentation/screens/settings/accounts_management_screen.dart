import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../providers/account_providers.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/list_widgets.dart';

class AccountsManagementScreen extends ConsumerWidget {
  const AccountsManagementScreen({super.key});

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final makePrimary = ValueNotifier<bool>(false);
    final values = await showFieldsSheet(
      context,
      title: 'Add account',
      submitLabel: 'Add account',
      switchLabel: 'Use as primary account',
      switchValue: makePrimary,
      fields: const [
        FieldSpec(
          label: 'Account name',
          hint: 'e.g. HDFC Savings',
          required: true,
        ),
        FieldSpec(label: 'Current balance (₹)', numeric: true, initial: '0'),
      ],
    );
    final primary = makePrimary.value;
    if (values == null || !context.mounted) return;

    final balance = double.tryParse(values[1]) ?? 0.0;
    final now = DateTime.now();
    try {
      await ref.read(accountListProvider.notifier).createAccount(
            AccountModel(
              id: const Uuid().v4(),
              name: values[0],
              currentBalance: balance,
              initialBalance: balance,
              isPrimary: primary,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not add the account: $e');
    }
  }

  Future<void> _togglePrimary(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    final notifier = ref.read(accountListProvider.notifier);
    try {
      if (account.isPrimary) {
        await notifier.clearPrimaryAccount();
      } else {
        await notifier.setPrimaryAccount(account.id);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Could not change the primary account: $e');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
    int accountCount,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (accountCount <= 1) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Keep at least one account to record transactions.'),
        ),
      );
      return;
    }

    final ok = await confirmDestructive(
      context,
      title: 'Remove ${account.name}?',
      message: account.isPrimary
          ? 'The account is hidden from your lists and existing transactions are kept. It is your primary account, so you will have no primary account until you pick another.'
          : 'The account is hidden from your lists. Existing transactions are kept.',
      confirmLabel: 'Remove',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(accountListProvider.notifier).deleteAccount(account.id);
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not remove the account: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final accountsAsync = ref.watch(accountListProvider);
    final count = accountsAsync.value?.length ?? 0;

    return ManagementScaffold<AccountModel>(
      title: 'Bank accounts',
      items: accountsAsync,
      emptyEmoji: '🏦',
      emptyTitle: 'No accounts yet',
      emptyMessage: 'Add a bank account or wallet to start tracking balances.',
      addLabel: 'Add account',
      onAdd: () => _add(context, ref),
      rowBuilder: (context, acc) => ListRowTile(
        emoji: acc.isPrimary ? '⭐' : '🏦',
        title: acc.name,
        subtitle: acc.isPrimary
            ? 'Primary · ${CurrencyFormatter.format(acc.currentBalance)}'
            : CurrencyFormatter.format(acc.currentBalance),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: acc.isPrimary
                  ? 'Primary account (tap to unset)'
                  : 'Set as primary account',
              icon: Icon(
                acc.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                color: acc.isPrimary ? p.primary : p.muted,
              ),
              onPressed: () => _togglePrimary(context, ref, acc),
            ),
            IconButton(
              tooltip: 'Remove account',
              icon: Icon(Icons.delete_outline_rounded, color: p.expense),
              onPressed: () => _delete(context, ref, acc, count),
            ),
          ],
        ),
      ),
    );
  }
}
