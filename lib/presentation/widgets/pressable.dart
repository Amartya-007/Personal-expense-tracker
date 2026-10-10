import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';

/// Which haptic a [Pressable] fires when tapped.
enum PressHaptic { none, tap, select }

/// Wraps any widget with tactile feedback: it scales down and dims slightly
/// while pressed, and gives a light haptic tick on tap.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final PressHaptic haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = PressHaptic.tap,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case PressHaptic.tap:
        AppHaptics.tap();
      case PressHaptic.select:
        AppHaptics.select();
      case PressHaptic.none:
        break;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppMotion.instant,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.9 : 1.0,
          duration: AppMotion.instant,
          child: widget.child,
        ),
      ),
    );
  }
}
