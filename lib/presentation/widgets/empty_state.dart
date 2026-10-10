import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'fade_slide_in.dart';
import 'primary_button.dart';

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
        _Halo(emoji: emoji, compact: compact),
        SizedBox(height: compact ? 10 : 20),
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
          compact
              ? ElevatedButton(onPressed: onAction, child: Text(actionLabel!))
              : SizedBox(
                  width: 220,
                  child: PrimaryButton(label: actionLabel!, onPressed: onAction),
                ),
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

/// The emoji sits on two soft concentric discs, which gives the illustration
/// some depth and makes an empty screen feel designed rather than blank.
class _Halo extends StatelessWidget {
  final String emoji;
  final bool compact;

  const _Halo({required this.emoji, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final outer = compact ? 76.0 : 128.0;
    final inner = compact ? 54.0 : 92.0;

    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.primary.withValues(alpha: p.isDark ? 0.07 : 0.05),
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.primarySoft,
          border: Border.all(color: p.primary.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: compact ? 26 : 42)),
      ),
    );
  }
}
