import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/sms_review_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/async_section.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sms_permission_help.dart';

class SmsReviewScreen extends ConsumerStatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  ConsumerState<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends ConsumerState<SmsReviewScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from Android Settings: re-check the permission and pick up
  /// anything that arrived while the user was there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(smsPermissionProvider);
    }
  }

  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    final tab = ref.read(smsQueueStatusTabProvider);
    try {
      final count = await ref.read(smsQueueProvider(tab).notifier).scanInbox();
      ref.invalidate(smsPermissionProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Scanned inbox. Found $count new transactions.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  void _showHelp() => showSmsPermissionHelp(context, onPaste: _showPasteSheet);

  Future<void> _showPasteSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await AppBottomSheet.show<String>(
      context,
      title: 'Paste bank messages',
      builder: (_) => const _PasteForm(),
    );
    if (text == null || text.trim().isEmpty) return;

    final tab = ref.read(smsQueueStatusTabProvider);
    final r = await ref.read(smsQueueProvider(tab).notifier).addPasted(text);

    final parts = <String>[
      if (r.added > 0) '${r.added} added to review',
      if (r.duplicate > 0) '${r.duplicate} already there',
      if (r.unrecognized > 0) '${r.unrecognized} not recognised as a bank message',
    ];
    messenger.showSnackBar(
      SnackBar(content: Text(parts.isEmpty ? 'Nothing to add.' : parts.join(' · '))),
    );
    if (r.added > 0) {
      ref.read(smsQueueStatusTabProvider.notifier).state = 'detected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activeTab = ref.watch(smsQueueStatusTabProvider);
    final queueAsync = ref.watch(smsQueueProvider(activeTab));
    final hasPermission = ref.watch(smsPermissionProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_rounded),
            tooltip: 'Paste messages',
            onPressed: _showPasteSheet,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Scan inbox',
            onPressed: _scan,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: p.primary,
        onRefresh: () => ref.read(smsQueueProvider(activeTab).notifier).loadQueue(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            if (!hasPermission) ...[
              FadeSlideIn(
                child: AppCard(
                  onTap: _showHelp,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('🔒', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SMS access is off', style: AppText.bodyStrong(p.ink)),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to fix it, or paste messages by hand.',
                              style: AppText.caption(p.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'detected', label: Text('Detected')),
                ButtonSegment(value: 'added', label: Text('Added')),
                ButtonSegment(value: 'ignored', label: Text('Ignored')),
              ],
              selected: {activeTab},
              onSelectionChanged: (s) =>
                  ref.read(smsQueueStatusTabProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 16),
            AsyncSection<List<SmsReviewModel>>(
              value: queueAsync,
              skeletonHeight: 160,
              errorLabel: 'Could not load messages',
              onRetry: () =>
                  ref.read(smsQueueProvider(activeTab).notifier).loadQueue(),
              builder: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    compact: true,
                    emoji: activeTab == 'detected' ? '📭' : '🗂',
                    title: 'No messages here',
                    message: activeTab == 'detected'
                        ? 'New bank messages show up automatically. You can also paste one.'
                        : 'Nothing in this list yet.',
                    actionLabel: activeTab == 'detected' ? 'Paste a message' : null,
                    onAction: activeTab == 'detected' ? _showPasteSheet : null,
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FadeSlideIn(
                          key: ValueKey(items[i].id),
                          index: i,
                          child: _SmsCard(sms: items[i], tab: activeTab),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsCard extends ConsumerWidget {
  final SmsReviewModel sms;
  final String tab;

  const _SmsCard({required this.sms, required this.tab});

  /// Best-effort match of the SMS bank to one of the user's accounts, so
  /// money isn't always booked against the first account.
  AccountModel? _match(List<AccountModel> accounts) {
    final bank = (sms.bankName ?? '').toLowerCase().trim();
    if (bank.isEmpty) return null;
    for (final a in accounts) {
      final name = a.name.toLowerCase();
      if (name.contains(bank) || (name.length >= 3 && bank.contains(name))) {
        return a;
      }
    }
    return null;
  }

  Future<void> _pickAccount(
    BuildContext context,
    WidgetRef ref,
    List<AccountModel> accounts,
  ) {
    return AppBottomSheet.show<void>(
      context,
      title: 'Add to account',
      builder: (ctx) => SettingsGroup(
        children: [
          for (final a in accounts)
            ListRowTile(
              emoji: '🏦',
              title: a.name,
              subtitle: CurrencyFormatter.format(a.currentBalance),
              onTap: () {
                ref.read(smsAccountChoiceProvider(sms.id).notifier).state = a.id;
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    AccountModel? account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (account == null) {
      // This used to return silently.
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a bank account first (Settings → Accounts).')),
      );
      return;
    }

    final tx = TransactionModel(
      id: const Uuid().v4(),
      type: sms.isDebit ? 'expense' : 'income',
      amount: sms.amount,
      description: sms.merchant ?? 'SMS Transaction',
      paymentMethod: 'UPI',
      accountId: account.id,
      date: sms.date,
      source: 'sms',
      smsMessageId: sms.smsMessageId,
      externalReference: sms.referenceId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(transactionListProvider.notifier).createTransaction(tx);
      await ref.read(smsQueueProvider(tab).notifier).updateStatus(sms.id, 'added');
      messenger.showSnackBar(
        SnackBar(content: Text('Added to ${account.name}.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to add transaction: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final accounts = ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final chosenId = ref.watch(smsAccountChoiceProvider(sms.id));
    AccountModel? account;
    for (final a in accounts) {
      if (a.id == chosenId) account = a;
    }
    account ??= _match(accounts) ?? (accounts.isEmpty ? null : accounts.first);

    final amountColor = sms.isDebit ? p.expense : p.income;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sms.merchant ?? 'Bank transaction',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(p.ink),
                ),
              ),
              Text(
                '${sms.isDebit ? '−' : '+'}${CurrencyFormatter.format(sms.amount)}',
                style: AppText.bodyStrong(amountColor),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${sms.bankName ?? 'Unknown bank'} · ${sms.accountRef ?? 'card'}',
            style: AppText.caption(p.muted),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(sms.rawSms, style: AppText.caption(p.muted).copyWith(fontSize: 11)),
          ),
          if (tab == 'detected') ...[
            const SizedBox(height: 12),
            if (accounts.length > 1)
              Pressable(
                onTap: () => _pickAccount(context, ref, accounts),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_rounded, size: 16, color: p.muted),
                    const SizedBox(width: 6),
                    Text('Add to ', style: AppText.caption(p.muted)),
                    Text(account?.name ?? '—', style: AppText.caption(p.primary).copyWith(fontWeight: FontWeight.w700)),
                    Icon(Icons.expand_more_rounded, size: 16, color: p.primary),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(smsQueueProvider(tab).notifier).updateStatus(sms.id, 'ignored');
                    } catch (_) {}
                  },
                  style: TextButton.styleFrom(foregroundColor: p.muted),
                  child: const Text('Ignore'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirm & add',
                    onPressed: () => _confirm(context, ref, account),
                  ),
                ),
              ],
            ),
          ] else if (tab == 'ignored') ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  try {
                    await ref.read(smsQueueProvider(tab).notifier).updateStatus(sms.id, 'detected');
                  } catch (_) {}
                },
                child: const Text('Move back to detected'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasteForm extends StatefulWidget {
  const _PasteForm();

  @override
  State<_PasteForm> createState() => _PasteFormState();
}

class _PasteFormState extends State<_PasteForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    setState(() => _controller.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Copy a bank SMS from your messages app and paste it here. This needs no SMS permission. Separate several messages with a blank line.',
          style: AppText.caption(p.muted).copyWith(fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Rs 450.00 debited from A/c XX1234 on 05-Oct…',
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text('Paste from clipboard'),
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Add to review',
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    );
  }
}
