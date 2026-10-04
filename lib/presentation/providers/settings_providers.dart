import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

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

class UserNameNotifier extends StateNotifier<String> {
  UserNameNotifier() : super('Amar') {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(AppConstants.prefUserName) ?? 'Amar';
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserName, name);
    state = name;
  }
}

final mainTabProvider = StateProvider<int>((ref) => 0);
