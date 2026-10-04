import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../providers/transaction_providers.dart';

class SmsReviewScreen extends ConsumerWidget {
  const SmsReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(smsQueueStatusTabProvider);
    final smsQueueAsync = ref.watch(smsQueueProvider(activeTab));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Review Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Scan Inbox',
            onPressed: () async {
              // BUG FIX: capture messenger before await so context stays valid.
              final messenger = ScaffoldMessenger.of(context);
              try {
                final count = await ref
                    .read(smsQueueProvider(activeTab).notifier)
                    .scanInbox();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Scanned inbox. Found $count new transactions.',
                    ),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Scan failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Detected')),
                    selected: activeTab == 'detected',
                    onSelected: (val) {
                      if (val) {
                        ref.read(smsQueueStatusTabProvider.notifier).state =
                            'detected';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Added')),
                    selected: activeTab == 'added',
                    onSelected: (val) {
                      if (val) {
                        ref.read(smsQueueStatusTabProvider.notifier).state =
                            'added';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Ignored')),
                    selected: activeTab == 'ignored',
                    onSelected: (val) {
                      if (val) {
                        ref.read(smsQueueStatusTabProvider.notifier).state =
                            'ignored';
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: smsQueueAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No SMS messages in this tab.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final sms = items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    sms.merchant ?? 'Bank Transaction',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(sms.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: sms.isDebit
                                        ? AppColors.expense
                                        : AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bank: ${sms.bankName ?? 'Unknown'} (${sms.accountRef ?? 'Card'})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sms.rawSms,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (activeTab == 'detected')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        await ref
                                            .read(
                                              smsQueueProvider(activeTab)
                                                  .notifier,
                                            )
                                            .updateStatus(sms.id, 'ignored');
                                      } catch (_) {}
                                    },
                                    child: const Text(
                                      'Ignore',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final accounts =
                                          ref.read(accountListProvider).value ??
                                          [];
                                      if (accounts.isEmpty) return;

                                      // BUG FIX: capture ScaffoldMessenger before awaits so the
                                      // context remains valid in a ConsumerWidget (no mounted prop).
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );

                                      final tx = TransactionModel(
                                        id: const Uuid().v4(),
                                        type: sms.isDebit
                                            ? 'expense'
                                            : 'income',
                                        amount: sms.amount,
                                        description:
                                            sms.merchant ?? 'SMS Transaction',
                                        paymentMethod: 'UPI',
                                        accountId: accounts.first.id,
                                        date: sms.date,
                                        source: 'sms',
                                        smsMessageId: sms.smsMessageId,
                                        externalReference: sms.referenceId,
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      );

                                      try {
                                        await ref
                                            .read(
                                              transactionListProvider.notifier,
                                            )
                                            .createTransaction(tx);
                                        await ref
                                            .read(
                                              smsQueueProvider(activeTab)
                                                  .notifier,
                                            )
                                            .updateStatus(sms.id, 'added');
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Transaction added successfully.',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to add transaction: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Confirm & Add'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
