import 'package:flutter/services.dart';

/// One place for haptic feedback, so the whole app feels consistent and the
/// user can switch it off (Settings -> Haptic feedback).
///
/// Use the lightest feedback that fits:
/// * [tap]      pressing a button or row
/// * [select]   changing a selection (tab, chip, dropdown choice, checkbox)
/// * [success]  a save or restore completed
/// * [warning]  a destructive action is confirmed
class AppHaptics {
  AppHaptics._();

  /// Mirrors the saved preference; set at startup and from Settings.
  static bool enabled = true;

  static void tap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void warning() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
