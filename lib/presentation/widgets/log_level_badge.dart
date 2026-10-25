import 'package:flutter/material.dart';

import '../../core/logging/log_level.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// Theme colour that signals a log level. Only existing palette colours are
/// used: errors reuse the expense red, warnings the secondary gold.
Color logLevelColor(AppPalette p, LogLevel level) => switch (level) {
  LogLevel.error => p.expense,
  LogLevel.warning => p.secondary,
  LogLevel.info => p.primary,
  LogLevel.debug => p.muted,
};

/// Small pill: a coloured dot plus the level name. The text stays in the
/// normal ink colour so it is readable on every theme.
class LogLevelBadge extends StatelessWidget {
  final LogLevel level;

  const LogLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = logLevelColor(p, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            level.label,
            style: AppText.caption(p.ink)
                .copyWith(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
