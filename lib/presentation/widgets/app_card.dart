import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';

/// How far a card appears to sit above the page.
enum CardElevation { flat, low, medium, high }

/// The one card surface used across the app (surface colour, hairline border).
///
/// Content cards carry at most one edge signal: a hairline border and NO
/// shadow, so a screen reads calm. Only [CardElevation.high] keeps a subtle
/// shadow, reserved for the single thing a screen is about (the hero). Heavier
/// [AppPalette.shadowMd]/[AppPalette.shadowLg] belong to floating chrome (nav
/// pill, FAB, sheets, dialogs), which live outside this widget. Pick an
/// [elevation] by importance: `low` for rows inside a list, `medium` (default)
/// for ordinary cards, `high` for a hero.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;
  final bool shadow;
  final CardElevation elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.radius = AppRadius.card,
    this.gradient,
    this.shadow = true,
    this.elevation = CardElevation.medium,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: gradient == null
            ? (elevation == CardElevation.high ? p.surfaceRaised : p.surface)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: !shadow
            ? null
            : switch (elevation) {
                // Content cards stay border-only (calm). Only the hero keeps a
                // subtle shadow; heavier shadows are reserved for floating
                // chrome, which lives outside AppCard.
                CardElevation.flat => null,
                CardElevation.low => null,
                CardElevation.medium => null,
                CardElevation.high => p.shadowSm,
              },
        border: gradient == null ? Border.all(color: p.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
