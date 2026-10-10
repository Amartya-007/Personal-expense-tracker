import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_sheets.dart';
import 'field_decoration.dart';

/// The app's single-choice dropdown. It looks like every other field and opens
/// a roomy, scrollable sheet instead of Material's cramped popup menu: each
/// option can carry an emoji and a second line, the current choice is ticked,
/// and long lists (more than [searchThreshold]) get a search box.
///
/// Use it wherever the user picks one thing from a list (category, account,
/// ...). For several choices use `MultiSelectField`.
class AppDropdown<T> extends StatelessWidget {
  /// Floating label (forms with labelled fields). Leave null when the caption
  /// is drawn by the screen, and set [hint] instead.
  final String? label;
  final String hint;
  final String? sheetTitle;
  final String emptyMessage;
  final T? value;
  final List<T> items;
  final String Function(T item) labelOf;
  final String? Function(T item)? subtitleOf;
  final String? Function(T item)? emojiOf;

  /// Identity of an item, so a value from an older list still matches the
  /// current one (models are re-created when lists reload). Defaults to the
  /// item itself.
  final Object Function(T item)? keyOf;
  final int searchThreshold;
  final ValueChanged<T> onChanged;

  const AppDropdown({
    super.key,
    this.label,
    this.hint = 'Select',
    this.sheetTitle,
    this.emptyMessage = 'Nothing to choose from yet.',
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.subtitleOf,
    this.emojiOf,
    this.keyOf,
    this.searchThreshold = 7,
  });

  Object _key(T item) => keyOf == null ? item as Object : keyOf!(item);

  Future<void> _open(BuildContext context) async {
    final picked = await AppBottomSheet.show<T>(
      context,
      title: sheetTitle ?? label ?? hint,
      builder: (_) => _DropdownSheet<T>(
        items: items,
        selectedKey: value == null ? null : _key(value as T),
        labelOf: labelOf,
        subtitleOf: subtitleOf,
        emojiOf: emojiOf,
        keyOf: _key,
        showSearch: items.length > searchThreshold,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = value;
    final emoji = current == null ? null : emojiOf?.call(current);

    final Widget child;
    if (current == null) {
      // With a floating label the label itself is the placeholder.
      child = label != null
          ? const SizedBox.shrink()
          : Text(
              items.isEmpty ? emptyMessage : hint,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.muted.withValues(alpha: 0.7),
              ),
            );
    } else {
      child = Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              labelOf(current),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: items.isEmpty ? null : () => _open(context),
      child: InputDecorator(
        isEmpty: current == null,
        decoration: appFieldDecoration(p).copyWith(
          labelText: label,
          suffixIcon: Icon(
            Icons.arrow_drop_down_rounded,
            color: p.muted,
            size: 30,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _DropdownSheet<T> extends StatefulWidget {
  final List<T> items;
  final Object? selectedKey;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final String? Function(T)? emojiOf;
  final Object Function(T) keyOf;
  final bool showSearch;

  const _DropdownSheet({
    required this.items,
    required this.selectedKey,
    required this.labelOf,
    required this.subtitleOf,
    required this.emojiOf,
    required this.keyOf,
    required this.showSearch,
  });

  @override
  State<_DropdownSheet<T>> createState() => _DropdownSheetState<T>();
}

class _DropdownSheetState<T> extends State<_DropdownSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final item in widget.items)
        if (q.isEmpty || widget.labelOf(item).toLowerCase().contains(q)) item,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearch) ...[
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: appFieldDecoration(p, hint: 'Search').copyWith(
              prefixIcon: Icon(Icons.search_rounded, color: p.muted),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No matches',
              textAlign: TextAlign.center,
              style: AppText.body(p.muted),
            ),
          ),
        for (final item in shown)
          _OptionTile(
            title: widget.labelOf(item),
            subtitle: widget.subtitleOf?.call(item),
            emoji: widget.emojiOf?.call(item),
            selected: widget.selectedKey != null &&
                widget.keyOf(item) == widget.selectedKey,
            onTap: () => Navigator.pop(context, item),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (emoji != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji!, style: const TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong(p.ink)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption(p.muted)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: p.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
