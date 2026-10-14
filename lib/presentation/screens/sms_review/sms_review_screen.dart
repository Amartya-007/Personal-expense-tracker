import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/sms_review_model.dart';
import '../../../data/models/transaction_model.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../../providers/account_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/async_section.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_tabs.dart';
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
        SnackBar(
          content: Text('Scanned inbox. Found $count new transactions.'),
        ),
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
      if (r.unrecognized > 0)
        '${r.unrecognized} not recognised as a bank message',
    ];
    messenger.showSnackBar(
      SnackBar(
        content: Text(parts.isEmpty ? 'Nothing to add.' : parts.join(' · ')),
      ),
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
    final waiting = ref.watch(smsQueueProvider('detected')).value?.length ?? 0;
    final hasPermission = ref.watch(smsPermissionProvider).value ?? true;

    const tabs = [
      ('detected', 'Detected'),
      ('added', 'Added'),
      ('ignored', 'Ignored'),
    ];
    final labels = [
      for (final t in tabs)
        t.$1 == 'detected' && waiting > 0 ? '${t.$2} · $waiting' : t.$2,
    ];
    final activeIndex = tabs.indexWhere((t) => t.$1 == activeTab);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text('SMS review', style: AppText.title(p.ink))),
      body: RefreshIndicator(
        color: p.primary,
        onRefresh: () =>
            ref.read(smsQueueProvider(activeTab).notifier).loadQueue(),
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.secondary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🔒', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMS access is off',
                              style: AppText.bodyStrong(p.ink),
                            ),
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

            // The two ways to bring messages in, visible instead of hidden in
            // the app bar.
            FadeSlideIn(
              index: 1,
              child: Row(
                children: [
                  _ToolButton(
                    icon: Icons.sync_rounded,
                    label: 'Scan inbox',
                    onTap: _scan,
                  ),
                  const SizedBox(width: 10),
                  _ToolButton(
                    icon: Icons.content_paste_rounded,
                    label: 'Paste message',
                    onTap: _showPasteSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SegmentedTabs(
              options: labels,
              selected: labels[activeIndex < 0 ? 0 : activeIndex],
              onSelected: (label) {
                final i = labels.indexOf(label);
                if (i >= 0) {
                  ref.read(smsQueueStatusTabProvider.notifier).state =
                      tabs[i].$1;
                }
              },
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
                    emoji: activeTab == 'detected' ? '📭' : '🗂',
                    title: activeTab == 'detected'
                        ? 'All caught up'
                        : 'Nothing here yet',
                    message: activeTab == 'detected'
                        ? 'New bank messages show up here automatically. You can also scan your inbox or paste one.'
                        : 'Messages you ${activeTab == 'added' ? 'add' : 'ignore'} will be listed here.',
                    actionLabel: activeTab == 'detected'
                        ? 'Paste a message'
                        : null,
                    onAction: activeTab == 'detected' ? _showPasteSheet : null,
                  );
                }
                return _MessageList(items: items, tab: activeTab);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Scan / Paste button.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: kMinInteractiveDimension,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
            boxShadow: p.shadowSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: p.primary),
              const SizedBox(width: 8),
              Text(label, style: AppText.bodyStrong(p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Messages grouped under day headings, with a one-line summary on top of the
/// "Detected" list.
class _MessageList extends ConsumerWidget {
  final List<SmsReviewModel> items;
  final String tab;

  const _MessageList({required this.items, required this.tab});

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
  }

  /// Directly books one transaction per confidently-matched detected message
  /// (never opens the form — see plan D3). Guards re-entry with
  /// [smsBatchProcessingProvider] so taps during the run are ignored.
  Future<void> _addAll(
    BuildContext context,
    WidgetRef ref,
    List<SmsReviewModel> matched,
    List<AccountModel> accounts,
  ) async {
    if (ref.read(smsBatchProcessingProvider)) return;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(smsBatchProcessingProvider.notifier).state = true;
    var added = 0;
    try {
      final txNotifier = ref.read(transactionListProvider.notifier);
      final repo = ref.read(smsRepositoryProvider);
      for (final sms in matched) {
        final account = smsBestMatchAccount(sms, accounts);
        if (account == null) continue;
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
        await txNotifier.createTransaction(tx);
        await repo.updateStatus(sms.id, 'added');
        added++;
      }
      // Reload the queue once, after the whole batch.
      await ref.read(smsQueueProvider(tab).notifier).loadQueue();
      AppHaptics.success();
      messenger.showSnackBar(
        SnackBar(content: Text('Added $added transactions.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to add transactions: $e')),
      );
    } finally {
      ref.read(smsBatchProcessingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);

    final spent = items
        .where((m) => m.isDebit)
        .fold<double>(0, (a, m) => a + m.amount);
    final received = items
        .where((m) => !m.isDebit)
        .fold<double>(0, (a, m) => a + m.amount);

    final accounts =
        ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final matched = tab == 'detected'
        ? items.where((m) => smsBestMatchAccount(m, accounts) != null).toList()
        : const <SmsReviewModel>[];
    final processing = ref.watch(smsBatchProcessingProvider);

    final children = <Widget>[];
    if (tab == 'detected') {
      children.add(
        FadeSlideIn(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TO REVIEW', style: AppText.overline(p.muted)),
                          const SizedBox(height: 4),
                          Text(
                            '${items.length} ${items.length == 1 ? 'message' : 'messages'}',
                            style: AppText.title(p.ink),
                          ),
                        ],
                      ),
                    ),
                    _Total(
                      label: 'Spent',
                      value: CurrencyFormatter.format(
                        spent,
                        isMasked: isMasked,
                      ),
                      color: p.expense,
                    ),
                    const SizedBox(width: 18),
                    _Total(
                      label: 'Received',
                      value: CurrencyFormatter.format(
                        received,
                        isMasked: isMasked,
                      ),
                      color: p.income,
                    ),
                  ],
                ),
                if (matched.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Add all ${matched.length}',
                      loading: processing,
                      onPressed: () => _addAll(context, ref, matched, accounts),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 6));
    }

    String? lastDay;
    for (var i = 0; i < items.length; i++) {
      final day = _dayLabel(items[i].date);
      if (day != lastDay) {
        lastDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
            child: Text(day.toUpperCase(), style: AppText.overline(p.muted)),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeSlideIn(
            key: ValueKey(items[i].id),
            index: i,
            child: _SmsCard(sms: items[i], tab: tab),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Total({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: AppText.caption(p.muted)),
        const SizedBox(height: 2),
        Text(value, style: AppText.amount(color, size: 14)),
      ],
    );
  }
}

class _SmsCard extends ConsumerStatefulWidget {
  final SmsReviewModel sms;
  final String tab;

  const _SmsCard({required this.sms, required this.tab});

  @override
  ConsumerState<_SmsCard> createState() => _SmsCardState();
}

class _SmsCardState extends ConsumerState<_SmsCard> {
  bool _busy = false;
  bool _showOriginal = false;

  SmsReviewModel get sms => widget.sms;

  /// Best-effort match of the SMS bank to one of the user's accounts, so
  /// money isn't always booked against the first account. Delegates to the
  /// shared [smsBestMatchAccount] so the card and the batch action agree.
  AccountModel? _match(List<AccountModel> accounts) =>
      smsBestMatchAccount(sms, accounts);

  Future<void> _setStatus(String status) async {
    try {
      await ref
          .read(smsQueueProvider(widget.tab).notifier)
          .updateStatus(sms.id, status);
    } catch (_) {}
  }

  Future<void> _confirm(AccountModel? account) async {
    // A second tap while the first is still opening the form used to push it
    // twice.
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    if (account == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add a bank account first (Settings → Accounts).'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      // Route the single confirm through the shared add form so the user can
      // review/edit before saving. The SMS is only marked 'added' once the
      // form reports a successful save (pop with a truthy result).
      final saved = await AppRoutes.pushModal<bool>(
        context,
        AddTransactionScreen(
          smsPrefill: SmsPrefill(
            type: sms.isDebit ? 'expense' : 'income',
            amount: sms.amount,
            description: sms.merchant,
            paymentMethod: 'UPI',
            date: sms.date,
            accountId: account.id,
            smsMessageId: sms.smsMessageId,
            externalReference: sms.referenceId,
          ),
        ),
      );
      if (saved == true) {
        await ref
            .read(smsQueueProvider(widget.tab).notifier)
            .updateStatus(sms.id, 'added');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);
    final accounts =
        ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final chosenId = ref.watch(smsAccountChoiceProvider(sms.id));
    AccountModel? account;
    for (final a in accounts) {
      if (a.id == chosenId) account = a;
    }
    account ??= _match(accounts) ?? (accounts.isEmpty ? null : accounts.first);

    final amountColor = sms.isDebit ? p.expense : p.income;
    final sign = sms.isDebit ? '−' : '+';

    return AppCard(
      elevation: CardElevation.low,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  sms.isDebit
                      ? Icons.north_east_rounded
                      : Icons.south_west_rounded,
                  color: amountColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sms.merchant ?? 'Bank transaction',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sms.bankName ?? 'Unknown bank'} · ${sms.accountRef ?? 'card'} · ${DateFormat('h:mm a').format(sms.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$sign${CurrencyFormatter.format(sms.amount, isMasked: isMasked)}',
                style: AppText.amount(amountColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showOriginal ? 'Hide message' : 'View original message',
                    style: AppText.caption(p.primary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Icon(
                    _showOriginal
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: p.primary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            child: _showOriginal
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sms.rawSms,
                      style: AppText.caption(p.muted).copyWith(fontSize: 11.5),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (widget.tab == 'detected') ...[
            const SizedBox(height: 14),
            if (accounts.length > 1) ...[
              AppDropdown<AccountModel>(
                label: 'Add to account',
                value: account,
                items: accounts,
                keyOf: (a) => a.id,
                labelOf: (a) => a.name,
                subtitleOf: (a) => CurrencyFormatter.format(
                  a.currentBalance,
                  isMasked: isMasked,
                ),
                emojiOf: (a) => a.isPrimary ? '⭐' : '🏦',
                onChanged: (a) =>
                    ref.read(smsAccountChoiceProvider(sms.id).notifier).state =
                        a.id,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _setStatus('ignored'),
                  style: TextButton.styleFrom(
                    foregroundColor: p.muted,
                    minimumSize: const Size(0, kMinInteractiveDimension),
                  ),
                  child: const Text('Ignore'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirm & add',
                    loading: _busy,
                    onPressed: () => _confirm(account),
                  ),
                ),
              ],
            ),
          ] else if (widget.tab == 'ignored') ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _setStatus('detected'),
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
