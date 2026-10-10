import 'package:flutter/animation.dart';

/// Shared animation timings and curves so every screen moves the same way.
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve bounce = Curves.easeOutBack;

  /// Material 3 "emphasized" feel: quick start, long soft landing. Use for
  /// things that slide into place (tab indicators, thumbs).
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Delay for the n-th item of a staggered entrance (capped, so a long list
  /// never makes the last row wait).
  static Duration stagger(int index, {int stepMs = 45, int maxSteps = 8}) =>
      Duration(milliseconds: stepMs * (index < maxSteps ? index : maxSteps));
}
