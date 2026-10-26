import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense_group_model.dart';
import '../../providers/expense_group_providers.dart';
import '../../providers/expense_split_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import 'create_edit_group_screen.dart';
import 'expense_split_screen.dart';
import 'person_detail_screen.dart';
import 'widgets/person_selector_sheet.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteGroup(ExpenseGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${group.name}"?'),
        content: const Text(
          'This will permanently delete the group. Existing transactions, people, and historical expense split records will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.palette.expense),
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(expenseGroupControllerProvider.notifier)
          .deleteGroup(group.id);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete group')),
          );
        }
      }
    }
  }

  Future<void> _addMembers(ExpenseGroupModel group) async {
    final existingIds = group.members.map((m) => m.id).toSet();
    final selected = await PersonSelectorSheet.show(
      context,
      initialSelected: group.members,
      multiSelect: true,
      title: 'Add Members to ${group.name}',
    );

    if (selected != null && mounted) {
      final newIds = selected.map((p) => p.id).where((id) => !existingIds.contains(id)).toList();
      if (newIds.isNotEmpty) {
        await ref
            .read(expenseGroupControllerProvider.notifier)
            .addMembers(group.id, newIds);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final groupAsync = ref.watch(expenseGroupDetailProvider(widget.groupId));
    final splitsAsync = ref.watch(
      expenseSplitListProvider((groupId: widget.groupId, personId: null)),
    );

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return Scaffold(
            backgroundColor: p.background,
            appBar: AppBar(backgroundColor: p.background),
            body: const Center(child: Text('Group not found')),
          );
        }

        return Scaffold(
          backgroundColor: p.background,
          appBar: AppBar(
            backgroundColor: p.background,
            elevation: 0,
            title: Text(group.name, style: AppText.title(p.ink)),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) async {
                  if (val == 'edit') {
                    AppRoutes.push(
                      context,
                      CreateEditGroupScreen(groupToEdit: group),
                    );
                  } else if (val == 'add_members') {
                    _addMembers(group);
                  } else if (val == 'archive') {
                    if (group.isArchived) {
                      await ref
                          .read(expenseGroupControllerProvider.notifier)
                          .restoreGroup(group.id);
                    } else {
                      await ref
                          .read(expenseGroupControllerProvider.notifier)
                          .archiveGroup(group.id);
                    }
                  } else if (val == 'delete') {
                    _confirmDeleteGroup(group);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Edit Group'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_members',
                    child: Row(
                      children: [
                        Icon(Icons.person_add_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Add Members'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          group.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(group.isArchived ? 'Restore Group' : 'Archive Group'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 20, color: p.expense),
                        const SizedBox(width: 10),
                        Text('Delete Group',
                            style: TextStyle(color: p.expense)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Group Hero Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          group.icon ?? '👥',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.name, style: AppText.title(p.ink)),
                            if (group.description != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                group.description!,
                                style: AppText.caption(p.muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${group.members.length} members',
                              style: AppText.caption(p.primary)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: p.primary,
                unselectedLabelColor: p.muted,
                indicatorColor: p.primary,
                tabs: [
                  Tab(text: 'Members (${group.members.length})'),
                  const Tab(text: 'Expense Splits'),
                ],
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Members
                    group.members.isEmpty
                        ? Center(
                            child: EmptyState(
                              emoji: '👥',
                              title: 'No members in this group',
                              message: 'Add friends from contacts or saved people',
                              actionLabel: 'Add Members',
                              onAction: () => _addMembers(group),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: group.members.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final member = group.members[i];
                              return Pressable(
                                onTap: () => AppRoutes.push(
                                  context,
                                  PersonDetailScreen(personId: member.id),
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            p.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          member.name.isNotEmpty
                                              ? member.name[0].toUpperCase()
                                              : '?',
                                          style: AppText.bodyStrong(p.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(member.name,
                                                style: AppText.bodyStrong(p.ink)),
                                            if (member.phone != null)
                                              Text(member.phone!,
                                                  style: AppText.caption(p.muted)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline,
                                            size: 20),
                                        color: p.muted,
                                        tooltip: 'Remove from group',
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  expenseGroupControllerProvider
                                                      .notifier)
                                              .removeMember(group.id, member.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    // Tab 2: Splits History
                    splitsAsync.when(
                      data: (splits) {
                        if (splits.isEmpty) {
                          return Center(
                            child: EmptyState(
                              emoji: '🧾',
                              title: 'No split expenses yet',
                              message:
                                  'Split a bill with this group to track who owes what.',
                              actionLabel: 'Split an Expense',
                              onAction: () {
                                AppRoutes.push(
                                  context,
                                  ExpenseSplitScreen(preselectedGroup: group),
                                );
                              },
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: splits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final split = splits[i];
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(split.title,
                                            style: AppText.bodyStrong(p.ink)),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(split.totalAmount),
                                        style: AppText.amount(p.primary, size: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Paid by: ${split.isUserPayer ? 'You' : (split.payerName ?? 'Someone')}',
                                        style: AppText.caption(p.muted),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(split.date),
                                        style: AppText.caption(p.muted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: split.participants.map((part) {
                                      return Chip(
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${part.isUser ? 'You' : part.personName}: ${CurrencyFormatter.format(part.allocatedAmount)}',
                                          style: AppText.caption(p.ink),
                                        ),
                                        backgroundColor: part.isSettled
                                            ? p.income.withValues(alpha: 0.12)
                                            : p.surface2,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ],
                ),
              ),

              // Bottom Split action
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                child: PrimaryButton(
                  label: 'Split an Expense with Group',
                  icon: Icons.call_split_rounded,
                  onPressed: () {
                    AppRoutes.push(
                      context,
                      ExpenseSplitScreen(preselectedGroup: group),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: p.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: p.background,
        body: Center(child: Text('Error loading group: $e')),
      ),
    );
  }
}
