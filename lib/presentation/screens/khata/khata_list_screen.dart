import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense_group_model.dart';
import '../../../data/models/khata_person_model.dart';
import '../../../data/repositories/khata_repository.dart';
import '../../providers/expense_group_providers.dart';
import '../../providers/khata_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/pressable.dart';
import 'create_edit_group_screen.dart';
import 'expense_split_screen.dart';
import 'group_detail_screen.dart';
import 'person_detail_screen.dart';
import 'widgets/add_person_sheet.dart';
import 'widgets/person_selector_sheet.dart';

class KhataListScreen extends ConsumerStatefulWidget {
  const KhataListScreen({super.key});

  @override
  ConsumerState<KhataListScreen> createState() => _KhataListScreenState();
}

class _KhataListScreenState extends ConsumerState<KhataListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(khataSearchQueryProvider.notifier).state = query;
    });
  }

  void _openAddPersonMenu() {
    AppHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.contacts_outlined, color: p.primary),
                  ),
                  title: Text('From Device Contacts', style: AppText.bodyStrong(p.ink)),
                  subtitle: Text('Pick someone from your address book', style: AppText.caption(p.muted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    PersonSelectorSheet.show(context, multiSelect: false, title: 'Select Contact');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.surface2,
                    child: Icon(Icons.edit_note_rounded, color: p.ink),
                  ),
                  title: Text('Add Manually', style: AppText.bodyStrong(p.ink)),
                  subtitle: Text('Enter name and phone without contact access', style: AppText.caption(p.muted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    AddPersonSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final summaryAsync = ref.watch(khataSummaryProvider);
    final peopleAsync = ref.watch(khataPeopleListProvider);
    final groupsAsync = ref.watch(expenseGroupListProvider);
    final currentFilter = ref.watch(khataFilterProvider);

    final isGroupsTab = _tabController.index == 1;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        title: Text('Khata & Groups', style: AppText.title(p.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_split_rounded),
            tooltip: 'Split Expense',
            onPressed: () => AppRoutes.push(context, const ExpenseSplitScreen()),
          ),
          IconButton(
            icon: Icon(isGroupsTab ? Icons.group_add_outlined : Icons.person_add_outlined),
            tooltip: isGroupsTab ? 'Create Group' : 'Add Person',
            onPressed: () {
              if (isGroupsTab) {
                AppRoutes.push(context, const CreateEditGroupScreen());
              } else {
                _openAddPersonMenu();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: p.primary,
          unselectedLabelColor: p.muted,
          indicatorColor: p.primary,
          tabs: const [
            Tab(text: 'People Ledger'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: People Ledger ─────────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(khataSummaryProvider);
              ref.invalidate(khataPeopleListProvider);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                MediaQuery.of(context).padding.bottom + 90,
              ),
              children: [
                // Overall summary card
                FadeSlideIn(
                  child: summaryAsync.when(
                    data: (summary) => _KhataOverviewCard(summary: summary),
                    loading: () => const _KhataOverviewSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Search bar
                FadeSlideIn(
                  index: 1,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: AppText.body(p.ink),
                    decoration: appFieldDecoration(
                      p,
                      hint: 'Search people by name or phone...',
                    ).copyWith(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Filter chips
                FadeSlideIn(
                  index: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(context, 'All', 'all', currentFilter),
                        const SizedBox(width: 8),
                        _filterChip(context, "You'll Get", 'receivable', currentFilter),
                        const SizedBox(width: 8),
                        _filterChip(context, "You'll Give", 'payable', currentFilter),
                        const SizedBox(width: 8),
                        _filterChip(context, 'Settled', 'settled', currentFilter),
                        const SizedBox(width: 8),
                        _filterChip(context, 'Archived', 'archived', currentFilter),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // People list
                peopleAsync.when(
                  data: (people) {
                    if (people.isEmpty) {
                      return EmptyState(
                        compact: true,
                        emoji: '👥',
                        title: currentFilter == 'archived'
                            ? 'No archived people'
                            : (_searchController.text.isNotEmpty
                                ? 'No matching people found'
                                : 'No Khata records yet'),
                        message: _searchController.text.isNotEmpty
                            ? 'Try searching with a different name or phone number.'
                            : 'Add friends, roommates, or family members to track money lent or borrowed.',
                        actionLabel: currentFilter != 'archived' && _searchController.text.isEmpty
                            ? 'Add First Person'
                            : null,
                        onAction: _openAddPersonMenu,
                      );
                    }

                    return Column(
                      children: people.map((person) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PersonTile(person: person),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading people: $err'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab 2: Groups ────────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expenseGroupListProvider);
            },
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      EmptyState(
                        compact: true,
                        emoji: '👥',
                        title: 'No groups created yet',
                        message:
                            'Create groups like Roommates, Goa Trip, or Office Lunch to easily split expenses repeatedly.',
                        actionLabel: 'Create First Group',
                        onAction: () => AppRoutes.push(
                          context,
                          const CreateEditGroupScreen(),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    MediaQuery.of(context).padding.bottom + 90,
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final group = groups[i];
                    return _GroupTile(group: group);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading groups: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        icon: Icon(isGroupsTab ? Icons.group_add_rounded : Icons.person_add_rounded),
        label: Text(isGroupsTab ? 'Create Group' : 'Add Person'),
        onPressed: () {
          if (isGroupsTab) {
            AppRoutes.push(context, const CreateEditGroupScreen());
          } else {
            _openAddPersonMenu();
          }
        },
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    String value,
    String current,
  ) {
    final p = context.palette;
    final isSelected = current == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: p.primary.withValues(alpha: 0.15),
      labelStyle: AppText.caption(isSelected ? p.primary : p.muted).copyWith(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) {
        AppHaptics.select();
        ref.read(khataFilterProvider.notifier).state = value;
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ExpenseGroupModel group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Pressable(
      onTap: () {
        AppRoutes.push(context, GroupDetailScreen(groupId: group.id));
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                group.icon ?? '👥',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          style: AppText.bodyStrong(p.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (group.isArchived) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: p.surface2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Archived',
                            style: AppText.caption(p.muted).copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.description ?? '${group.memberCount} members',
                    style: AppText.caption(p.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${group.memberCount} members',
                style: AppText.caption(p.primary).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _KhataOverviewCard extends StatelessWidget {
  final KhataSummary summary;

  const _KhataOverviewCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "YOU'LL GET",
                          style: AppText.caption(p.muted).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(summary.totalReceivable),
                      style: AppText.title(p.primary).copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 42, color: p.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: p.expense,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "YOU'LL GIVE",
                          style: AppText.caption(p.muted).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(summary.totalPayable),
                      style: AppText.title(p.expense).copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Balance',
                  style: AppText.caption(p.muted).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${summary.netBalance >= 0 ? '+' : ''}${CurrencyFormatter.format(summary.netBalance)}',
                  style: AppText.body(summary.netBalance >= 0 ? p.primary : p.expense).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KhataOverviewSkeleton extends StatelessWidget {
  const _KhataOverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final KhataPersonModel person;

  const _PersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final Color statusColor;
    if (person.isReceivable) {
      statusColor = p.primary;
    } else if (person.isPayable) {
      statusColor = p.expense;
    } else {
      statusColor = p.muted;
    }

    final initial = person.name.isNotEmpty
        ? person.name.trim().characters.first.toUpperCase()
        : '?';

    return Pressable(
      onTap: () {
        AppRoutes.push(
          context,
          PersonDetailScreen(personId: person.id),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppText.title(statusColor).copyWith(fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),

            // Person details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(p.ink).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (person.isArchived) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: p.surface2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Archived',
                            style: AppText.caption(p.muted).copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    person.phone ??
                        (person.lastEntryDate != null
                            ? 'Active ${DateFormat('dd MMM').format(person.lastEntryDate!)}'
                            : 'No entries yet'),
                    style: AppText.caption(p.muted),
                  ),
                ],
              ),
            ),

            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  person.isSettled
                      ? 'Settled'
                      : CurrencyFormatter.format(person.absoluteBalance),
                  style: AppText.title(statusColor),
                ),
                const SizedBox(height: 2),
                Text(
                  person.balanceStatusLabel,
                  style: AppText.caption(statusColor).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
