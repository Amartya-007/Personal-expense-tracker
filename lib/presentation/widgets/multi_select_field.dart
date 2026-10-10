import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_sheets.dart';
import 'field_decoration.dart';
import 'primary_button.dart';

/// A dropdown-style field that allows more than one choice. Tapping it opens
/// a checklist sheet; the chosen items show inside the field, each with a
/// small x to remove it. (A normal dropdown can only pick one value.)
class MultiSelectField extends StatelessWidget {
  final String hint;
  final String sheetTitle;
  final String emptyMessage;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MultiSelectField({
    super.key,
    required this.hint,
    required this.sheetTitle,
    required this.emptyMessage,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (options.isEmpty) {
      return Text(emptyMessage, style: TextStyle(fontSize: 12.5, color: p.muted));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => AppBottomSheet.show<void>(
        context,
        title: sheetTitle,
        builder: (_) => _MultiSelectSheet(
          options: options,
          initial: selected,
          onChanged: onChanged,
        ),
      ),
      child: InputDecorator(
        isEmpty: selected.isEmpty,
        decoration: appFieldDecoration(p).copyWith(
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: p.muted, size: 30),
        ),
        child: selected.isEmpty
            ? Text(
                hint,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.muted.withValues(alpha: 0.7),
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in selected)
                    _SelectedChip(
                      label: name,
                      onRemove: () => onChanged([
                        for (final s in selected)
                          if (s != name) s,
                      ]),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppText.caption(p.primary).copyWith(fontWeight: FontWeight.w700),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 14, color: p.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final List<String> options;
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectSheet({
    required this.options,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _chosen = {...widget.initial};

  void _toggle(String name, bool on) {
    AppHaptics.select();
    setState(() => on ? _chosen.add(name) : _chosen.remove(name));
    // Keep the field behind the sheet in step as boxes are ticked.
    widget.onChanged([
      for (final option in widget.options)
        if (_chosen.contains(option)) option,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in widget.options)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: p.primary,
            title: Text(option, style: AppText.body(p.ink)),
            value: _chosen.contains(option),
            onChanged: (v) => _toggle(option, v ?? false),
          ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
