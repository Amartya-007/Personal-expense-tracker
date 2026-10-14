import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_palette.dart';
import 'pressable.dart';

/// A small square icon button: a surface fill with a hairline border, no
/// shadow (calm by default), wrapped in [Pressable] for the standard scale and
/// haptic. Replaces the per-screen hand-rolled square buttons so they stay
/// consistent.
class IconSquareButton extends StatelessWidget {
  /// Creates a square button rendering [icon] inside a fixed [size] box.
  const IconSquareButton({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconSize = 22,
    this.onTap,
    this.semanticLabel,
    this.badge,
  });

  /// The glyph drawn centred in the button.
  final IconData icon;

  /// Width and height of the square, in logical pixels.
  final double size;

  /// Size of [icon] in logical pixels.
  final double iconSize;

  /// Called when the button is tapped.
  final VoidCallback? onTap;

  /// Accessibility label announcing the button's purpose.
  final String? semanticLabel;

  /// Optional overlay (e.g. a count badge) stacked over the button.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final square = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(
          size > 44 ? AppRadius.md : AppRadius.sm,
        ),
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: p.ink),
    );

    final Widget content = badge == null
        ? square
        : Stack(clipBehavior: Clip.none, children: [square, badge!]);

    final button = Pressable(onTap: onTap, child: content);

    if (semanticLabel == null) return button;
    return Semantics(button: true, label: semanticLabel, child: button);
  }
}
