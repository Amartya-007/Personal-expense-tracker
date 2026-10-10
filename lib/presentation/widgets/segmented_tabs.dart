import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// Equal-width segmented switch: a recessed track with a raised thumb that
/// glides to the chosen segment. Shared by the transaction-type, payment-method,
/// period and appearance pickers.
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
    final index = options.indexOf(selected);
    final count = options.length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                alignment: Alignment(
                  count <= 1 ? 0 : -1 + 2 * index / (count - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: p.shadowSm,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final option in options)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: option == selected,
                    label: option,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (option == selected) return;
                        AppHaptics.select();
                        onSelected(option);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.fast,
                          style: AppText.caption(
                            option == selected ? p.ink : p.muted,
                          ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                          child: Text(option),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
