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

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final values = await showFieldsSheet(
      context,
      title: 'Add account',
      submitLabel: 'Add account',
      fields: const [
        FieldSpec(
          label: 'Account name',
          hint: 'e.g. HDFC Savings',
          required: true,
        ),
        FieldSpec(label: 'Current balance (₹)', numeric: true, initial: '0'),
      ],
    );
    if (values == null || !context.mounted) return;

    final balance = double.tryParse(values[1]) ?? 0.0;
    final now = DateTime.now();
    await ref.read(accountListProvider.notifier).createAccount(
          AccountModel(
            id: const Uuid().v4(),
            name: values[0],
            currentBalance: balance,
            initialBalance: balance,
            createdAt: now,
            updatedAt: now,
          ),
        );
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
      message:
          'The account is hidden from your lists. Existing transactions are kept.',
      confirmLabel: 'Remove',
    );
    if (!ok || !context.mounted) return;
    await ref.read(accountListProvider.notifier).deleteAccount(account.id);
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
        emoji: '🏦',
        title: acc.name,
        subtitle: CurrencyFormatter.format(acc.currentBalance),
        trailing: IconButton(
          tooltip: 'Remove account',
          icon: Icon(Icons.delete_outline_rounded, color: p.expense),
          onPressed: () => _delete(context, ref, acc, count),
        ),
      ),
    );
  }
}
