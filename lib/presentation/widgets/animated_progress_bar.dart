import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';

/// Budget bar colour: primary normally, amber from 75%, red at the limit.
Color budgetProgressColor(AppPalette p, double percentage) {
  if (percentage >= 1.0) return p.expense;
  if (percentage >= 0.75) return p.secondary;
  return p.primary;
}

/// Rounded progress bar that animates to its value.
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.enter,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: p.surface2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
