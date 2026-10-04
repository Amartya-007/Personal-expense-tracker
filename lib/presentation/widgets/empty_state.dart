import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'fade_slide_in.dart';

/// Friendly empty state. `compact` renders inside a card for dashboard
/// sections; the default fills a whole screen body.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: compact ? 28 : 44)),
        SizedBox(height: compact ? 8 : 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact
              ? AppText.bodyStrong(p.ink)
              : AppText.title(p.ink),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? 12 : 20),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (compact) {
      return AppCard(
        padding: const EdgeInsets.all(22),
        shadow: false,
        child: SizedBox(width: double.infinity, child: body),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: FadeSlideIn(child: body),
      ),
    );
  }
}
