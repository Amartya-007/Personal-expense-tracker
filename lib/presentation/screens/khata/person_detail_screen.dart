import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/khata_entry_model.dart';
import '../../../data/models/khata_person_model.dart';
import '../../providers/khata_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/pressable.dart';
import 'widgets/add_person_sheet.dart';
import 'widgets/record_khata_entry_sheet.dart';
import 'widgets/settle_up_sheet.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  KhataEntryType? _typeFilter;

  Future<void> _confirmDeleteEntry(KhataEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Are you sure you want to delete this ${entry.type.label} of ${CurrencyFormatter.format(entry.amount)}?'
          '${entry.accountId != null ? ' The associated account balance adjustment will be automatically reversed.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.palette.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(khataControllerProvider.notifier)
          .deleteEntry(entry.id, widget.personId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Entry deleted' : 'Failed to delete entry',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePerson(KhataPersonModel person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${person.name}?'),
        content: const Text(
          'This will permanently delete this person and all their ledger history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.palette.expense),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(khataControllerProvider.notifier)
          .deletePerson(person.id);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete person')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final personAsync = ref.watch(khataPersonDetailProvider(widget.personId));
    final ledgerAsync = ref.watch(
      khataPersonLedgerProvider((
        personId: widget.personId,
        typeFilter: _typeFilter,
      )),
    );

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        title: personAsync.when(
          data: (person) => Text(person?.name ?? 'Person Detail'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Person Detail'),
        ),
        actions: [
          if (personAsync.value != null) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) async {
                final person = personAsync.value!;
                if (val == 'edit') {
                  AddPersonSheet.show(context, personToEdit: person);
                } else if (val == 'archive') {
                  await ref
                      .read(khataControllerProvider.notifier)
                      .setArchived(person.id, !person.isArchived);
                } else if (val == 'delete') {
                  _confirmDeletePerson(person);
                }
              },
              itemBuilder: (ctx) {
                final person = personAsync.value!;
                return [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          person.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(person.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 20, color: p.expense),
                        const SizedBox(width: 8),
                        Text('Delete Person',
                            style: TextStyle(color: p.expense)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
      body: personAsync.when(
        data: (person) {
          if (person == null) {
            return const Center(child: Text('Person not found'));
          }

          final isReceivable = person.isReceivable;
          final isPayable = person.isPayable;
          final isSettled = person.isSettled;

          final Color statusColor;
          if (isReceivable) {
            statusColor = p.primary;
          } else if (isPayable) {
            statusColor = p.expense;
          } else {
            statusColor = p.muted;
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + 120,
            ),
            children: [
              // Hero Balance Card
              FadeSlideIn(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.name,
                                style: AppText.title(p.ink).copyWith(fontSize: 20),
                              ),
                              if (person.phone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  person.phone!,
                                  style: AppText.caption(p.muted),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.surface2,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: p.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          person.isFromContact ? Icons.contacts_outlined : Icons.edit_note_rounded,
                                          size: 12,
                                          color: p.muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          person.isFromContact ? 'Device Contact' : 'Manual Entry',
                                          style: AppText.caption(p.muted).copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              person.balanceStatusLabel,
                              style: AppText.caption(statusColor).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSettled
                            ? 'All Settled'
                            : CurrencyFormatter.format(person.absoluteBalance),
                        style: AppText.display(statusColor).copyWith(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReceivable
                            ? '${person.name} owes you'
                            : isPayable
                                ? 'You owe ${person.name}'
                                : 'No outstanding dues',
                        style: AppText.caption(p.muted),
                      ),
                      if (person.notes != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: p.surface2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            person.notes!,
                            style: AppText.caption(p.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Buttons Row (Lend, Borrow, Settle)
              FadeSlideIn(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionSquareBtn(
                        label: 'Give (Lend)',
                        icon: Icons.north_east_rounded,
                        color: p.primary,
                        onTap: () => RecordKhataEntrySheet.show(
                          context,
                          person: person,
                          initialType: KhataEntryType.lent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionSquareBtn(
                        label: 'Got (Borrow)',
                        icon: Icons.south_west_rounded,
                        color: p.expense,
                        onTap: () => RecordKhataEntrySheet.show(
                          context,
                          person: person,
                          initialType: KhataEntryType.borrowed,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionSquareBtn(
                        label: 'Settle Up',
                        icon: Icons.done_all_rounded,
                        color: Colors.blueAccent,
                        disabled: isSettled,
                        onTap: () => SettleUpSheet.show(context, person: person),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Groups this person belongs to
              ref.watch(khataPersonGroupsProvider(widget.personId)).when(
                data: (groups) {
                  if (groups.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.groups_outlined, size: 16, color: p.primary),
                              const SizedBox(width: 6),
                              Text('Groups', style: AppText.caption(p.muted).copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: groups
                                .map((g) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(g, style: AppText.caption(p.ink)),
                                      backgroundColor: p.surface2,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Historical Splits Participation
              ref.watch(khataPersonSplitsProvider(widget.personId)).when(
                data: (splits) {
                  if (splits.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.call_split_rounded, size: 16, color: p.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Expense Splits (${splits.length})',
                                style: AppText.caption(p.muted).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final s in splits)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s['title'] as String? ?? 'Split',
                                      style: AppText.body(p.ink),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format((s['allocated_amount'] as num?)?.toDouble() ?? 0.0),
                                    style: AppText.bodyStrong(p.primary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', null),
                    const SizedBox(width: 6),
                    _filterChip('Lent', KhataEntryType.lent),
                    const SizedBox(width: 6),
                    _filterChip('Borrowed', KhataEntryType.borrowed),
                    const SizedBox(width: 6),
                    _filterChip('Repayments', KhataEntryType.repaymentReceived),
                    const SizedBox(width: 6),
                    _filterChip('Settlements', KhataEntryType.settlement),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Chronological Ledger Entries
              ledgerAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      compact: true,
                      emoji: '📖',
                      title: 'No ledger entries',
                      message: 'Record your first transaction above.',
                    );
                  }

                  return Column(
                    children: items.map((item) {
                      final e = item.entry;
                      final typeColor = e.type == KhataEntryType.lent ||
                              e.type == KhataEntryType.repaymentMade
                          ? p.primary
                          : (e.type == KhataEntryType.settlement
                              ? Colors.blueAccent
                              : p.expense);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  e.type == KhataEntryType.lent
                                      ? Icons.north_east_rounded
                                      : (e.type == KhataEntryType.borrowed
                                          ? Icons.south_west_rounded
                                          : (e.type == KhataEntryType.settlement
                                              ? Icons.done_all_rounded
                                              : Icons.sync_alt_rounded)),
                                  color: typeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.type.label,
                                      style: AppText.body(p.ink).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DateFormat('dd MMM yyyy').format(e.date)}'
                                      '${e.accountName != null ? ' · via ${e.accountName}' : ''}',
                                      style: AppText.caption(p.muted),
                                    ),
                                    if (e.notes != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        e.notes!,
                                        style: AppText.caption(p.ink)
                                            .copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(e.amount),
                                    style: AppText.title(typeColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.surface2,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Bal: ${item.runningBalance >= 0 ? '+' : ''}${CurrencyFormatter.format(item.runningBalance)}',
                                      style: AppText.caption(p.muted).copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: p.muted,
                                ),
                                onPressed: () => _confirmDeleteEntry(e),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading person: $e')),
      ),
    );
  }

  Widget _filterChip(String label, KhataEntryType? type) {
    final isSelected = _typeFilter == type;
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: p.primary.withValues(alpha: 0.15),
      labelStyle: AppText.caption(isSelected ? p.primary : p.muted).copyWith(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => setState(() => _typeFilter = type),
    );
  }
}

class _ActionSquareBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionSquareBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final effectiveColor = disabled ? p.muted : color;

    return Pressable(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? p.surface2 : effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? Colors.transparent : effectiveColor.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.caption(effectiveColor).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
