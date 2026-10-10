import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_haptics.dart';

final defaultUpiAccountProvider =
    StateNotifierProvider<DefaultUpiNotifier, String?>((ref) {
      return DefaultUpiNotifier();
    });

class DefaultUpiNotifier extends StateNotifier<String?> {
  DefaultUpiNotifier() : super(null) {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(AppConstants.prefDefaultUpiAccount);
  }

  Future<void> setDefaultUpiAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefDefaultUpiAccount, accountId);
    state = accountId;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(AppConstants.prefThemeMode);
    if (modeStr == 'light') {
      state = ThemeMode.light;
    } else if (modeStr == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    await prefs.setString(AppConstants.prefThemeMode, mode.name);
  }
}

final userNameProvider = StateNotifierProvider<UserNameNotifier, String>((ref) {
  return UserNameNotifier();
});

/// The user's display name. Empty until they set one (onboarding or
/// Settings); it used to default to a hardcoded developer name.
class UserNameNotifier extends StateNotifier<String> {
  UserNameNotifier() : super('') {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getString(AppConstants.prefUserName) ?? '';
  }

  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserName, trimmed);
    if (!mounted) return;
    state = trimmed;
  }
}

/// A persisted on/off preference.
class BoolPrefNotifier extends StateNotifier<bool> {
  final String _key;

  BoolPrefNotifier(this._key, {bool defaultValue = true}) : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getBool(_key) ?? state;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// Auto-detect bank SMS into the review queue.
final autoSmsDetectionProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
      return BoolPrefNotifier(AppConstants.prefAutoSmsDetection);
    });

/// Save the current location with a transaction when it is saved.
final autoLocationCaptureProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
      return BoolPrefNotifier(AppConstants.prefAutoLocationCapture);
    });

final mainTabProvider = StateProvider<int>((ref) => 0);

final hapticsEnabledProvider =
    StateNotifierProvider<HapticsNotifier, bool>((ref) => HapticsNotifier());

/// Haptic feedback on/off. Mirrors the value into [AppHaptics.enabled], which
/// the shared widgets read, so a change takes effect everywhere at once.
class HapticsNotifier extends StateNotifier<bool> {
  HapticsNotifier() : super(AppHaptics.enabled) {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(AppConstants.prefHapticsEnabled) ?? true;
    AppHaptics.enabled = value;
    if (mounted) state = value;
  }

  Future<void> setEnabled(bool value) async {
    AppHaptics.enabled = value;
    state = value;
    // Let the person feel what they just switched on.
    AppHaptics.select();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefHapticsEnabled, value);
  }
}
