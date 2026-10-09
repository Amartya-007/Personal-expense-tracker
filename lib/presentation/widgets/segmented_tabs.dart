import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// Equal-width segmented switch (a "pill" track with a raised selected
/// segment). Shared by the transaction-type and payment-method pickers, which
/// used to be two copies of the same ~40 lines.
class SegmentedTabs extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(options[i]),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: options[i] == selected
                        ? p.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: options[i] == selected ? [p.cardShadow] : null,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    style: AppText.caption(
                      options[i] == selected ? p.ink : p.muted,
                    ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                    child: Text(options[i]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
