import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/logging/log_category.dart';
import '../../../core/logging/log_entry.dart';
import '../../../core/logging/log_level.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../../providers/log_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/log_detail_sheet.dart';
import '../../widgets/log_level_badge.dart';
import '../../widgets/pill_chips.dart';

enum _LogsMenu { export, clear }

/// Settings > Logs: the local diagnostic log (activity, warnings, errors).
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  static const String _all = 'All';

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(logListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref
          .read(logListProvider.notifier)
          .setQuery(TextSanitizer.singleLine(text));
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    ref.read(logListProvider.notifier).clearFilters();
  }

  Future<void> _export() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final saved = await ref.read(logExportServiceProvider).exportForUser();
      if (saved != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Logs exported')));
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export the logs')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clearAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Clear all logs?',
      message:
          'This permanently removes the diagnostic logs stored on this '
          'device. Your transactions, accounts and other data are not '
          'affected.',
      confirmLabel: 'Clear logs',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(logListProvider.notifier).clearAll();
      messenger.showSnackBar(const SnackBar(content: Text('Logs cleared')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not clear the logs')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(logListProvider);
    final notifier = ref.read(logListProvider.notifier);
    final filter = state.filter;
    final hasLogs = state.entries.isNotEmpty || filter.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<_LogsMenu>(
            tooltip: 'Log options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => switch (action) {
              _LogsMenu.export => _export(),
              _LogsMenu.clear => _clearAll(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _LogsMenu.export,
                enabled: hasLogs && !_exporting,
                child: const Text('Export logs'),
              ),
              PopupMenuItem(
                value: _LogsMenu.clear,
                enabled: hasLogs,
                child: const Text('Clear all logs'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _search,
              builder: (context, value, _) => TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                style: AppText.body(p.ink),
                decoration:
                    appFieldDecoration(
                      p,
                      hint: 'Search message or category...',
                    ).copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
                                notifier.setQuery(null);
                              },
                            )
                          : null,
                    ),
              ),
            ),
          ),
          PillChips(
            options: [_all, for (final l in LogLevel.values) l.label],
            selected: filter.level?.label ?? _all,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            onSelected: (label) => notifier.setLevel(
              LogLevel.values.where((l) => l.label == label).firstOrNull,
            ),
          ),
          PillChips(
            options: [_all, for (final c in LogCategory.values) c.label],
            selected: filter.category?.label ?? _all,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            onSelected: (label) => notifier.setCategory(
              LogCategory.values.where((c) => c.label == label).firstOrNull,
            ),
          ),
          Expanded(child: _buildBody(context, p, state)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppPalette p, LogListState state) {
    final notifier = ref.read(logListProvider.notifier);

    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.entries.isEmpty) {
      return EmptyState(
        emoji: '⚠️',
        title: 'Could not load logs',
        message: 'Something went wrong while reading the logs on this device.',
        actionLabel: 'Try again',
        onAction: notifier.load,
      );
    }
    if (state.entries.isEmpty) {
      return state.filter.isActive
          ? EmptyState(
              emoji: '🔍',
              title: 'No matching logs',
              message: 'Try a different search, or clear the filters.',
              actionLabel: 'Clear filters',
              onAction: _clearFilters,
            )
          : const EmptyState(
              emoji: '📋',
              title: 'No logs yet',
              message:
                  'App activity, warnings and errors will appear here as you '
                  'use MyKhata.',
            );
    }

    final bottom = MediaQuery.of(context).padding.bottom + 24;
    return RefreshIndicator(
      onRefresh: notifier.load,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18, 4, 18, bottom),
        itemCount: state.entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                state.totalCount == 1 ? '1 log' : '${state.totalCount} logs',
                style: AppText.caption(p.muted),
              ),
            );
          }
          final entry = state.entries[i - 1];
          return _LogRow(
            entry: entry,
            onTap: () => showLogDetailSheet(context, entry),
          );
        },
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final AppLogEntry entry;
  final VoidCallback onTap;

  const _LogRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final time = DateFormat('d MMM, h:mm a').format(entry.timestamp);
    final isProblem =
        entry.level == LogLevel.error || entry.level == LogLevel.warning;

    return AppCard(
      elevation: CardElevation.low,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LogLevelBadge(level: entry.level),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(p.muted),
                ),
              ),
              Text(time, style: AppText.caption(p.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: isProblem ? AppText.bodyStrong(p.ink) : AppText.body(p.ink),
          ),
        ],
      ),
    );
  }
}
