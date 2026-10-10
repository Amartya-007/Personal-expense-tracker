import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// How far a card appears to sit above the page.
enum CardElevation { flat, low, medium, high }

/// The one card surface used across the app (surface colour, hairline border,
/// layered soft shadow). Pick an [elevation] by importance: `low` for rows
/// inside a list, `medium` (default) for ordinary cards, `high` for the one
/// thing a screen is about (e.g. a hero or a modal-like panel).
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
    this.radius = 20,
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
                CardElevation.flat => null,
                CardElevation.low => p.shadowSm,
                CardElevation.medium => p.shadowMd,
                CardElevation.high => p.shadowLg,
              },
        border: gradient == null ? Border.all(color: p.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
