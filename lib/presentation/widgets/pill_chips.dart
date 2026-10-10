import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'pressable.dart';

/// Single-select pill chips. Horizontal-scrolling by default, or wrapped
/// (e.g. inside a sheet) with [wrap]. Replaces the chip rows that were
/// hand-built separately in History, the filter sheet and elsewhere.
class PillChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool wrap;
  final EdgeInsetsGeometry padding;

  const PillChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.wrap = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final opt in options)
        PillChip(
          label: opt,
          selected: opt == selected,
          onTap: () => onSelected(opt),
        ),
    ];

    if (wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// One selectable pill. Used by [PillChips] (single choice) and directly for
/// multi-select groups such as transaction tags.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.select,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : p.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: AppText.caption(selected ? p.onPrimary : p.ink).copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
