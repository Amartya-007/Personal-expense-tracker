import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'empty_state.dart';
import 'fade_slide_in.dart';

/// A card that stacks rows and draws dividers between them automatically
/// (no more manual `isLast` flags).
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(color: p.border, height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: icon/emoji tile, title, optional subtitle, optional trailing.
class ListRowTile extends StatelessWidget {
  final String? emoji;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const ListRowTile({
    super.key,
    this.emoji,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget? lead = leading;
    if (lead == null && emoji != null) {
      lead = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(emoji!, style: const TextStyle(fontSize: 19)),
      );
    }

    final tail = trailing ??
        (onTap != null
            ? Icon(Icons.chevron_right_rounded, size: 20, color: p.muted)
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(titleColor ?? p.ink),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (tail != null) ...[const SizedBox(width: 8), tail],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared shell for "manage a list of things" screens (accounts, tags,
/// categories, recurring rules...). Handles loading, error, empty state, the
/// grouped list with staggered entrance, and the add button.
class ManagementScaffold<T> extends StatelessWidget {
  final String title;
  final AsyncValue<List<T>> items;
  final Widget Function(BuildContext context, T item) rowBuilder;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptyMessage;
  final String addLabel;
  final VoidCallback? onAdd;
  final Future<void> Function()? onRefresh;

  const ManagementScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.rowBuilder,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptyMessage,
    this.addLabel = 'Add',
    this.onAdd,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel),
            ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyState(
          emoji: '⚠️',
          title: 'Something went wrong',
          message: '$err',
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              emoji: emptyEmoji,
              title: emptyTitle,
              message: emptyMessage,
              actionLabel: onAdd == null ? null : addLabel,
              onAction: onAdd,
            );
          }
          final listView = ListView(
            padding: EdgeInsets.fromLTRB(18, 8, 18, bottom + 110),
            children: [
              FadeSlideIn(
                child: SettingsGroup(
                  children: [for (final item in list) rowBuilder(context, item)],
                ),
              ),
            ],
          );
          if (onRefresh == null) return listView;
          return RefreshIndicator(
            color: p.primary,
            onRefresh: onRefresh!,
            child: listView,
          );
        },
      ),
    );
  }
}
