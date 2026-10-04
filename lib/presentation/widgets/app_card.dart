import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The one card surface used across the app (white/dark surface, hairline
/// border, soft shadow). Replaces ~27 hand-written BoxDecorations.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.radius = 20,
    this.gradient,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? p.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? [p.cardShadow] : null,
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
