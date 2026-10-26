import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../data/models/saved_view_model.dart';
import 'transaction_providers.dart';

final savedViewsProvider =
    StateNotifierProvider<SavedViewsNotifier, List<SavedViewModel>>((ref) {
      return SavedViewsNotifier();
    });

final activeSavedViewIdProvider = StateProvider<String?>((ref) => null);

class SavedViewsNotifier extends StateNotifier<List<SavedViewModel>> {
  static const Uuid _uuid = Uuid();

  SavedViewsNotifier() : super(defaultPresets) {
    load();
  }

  static List<SavedViewModel> get defaultPresets => [
    SavedViewModel(
      id: 'preset_this_month',
      name: 'This month',
      icon: '📅',
      isPreset: true,
      filter: const TransactionFilter(datePeriod: 'This Month'),
      createdAt: DateTime(2026, 1, 1),
    ),
    SavedViewModel(
      id: 'preset_high_value',
      name: 'High value',
      icon: '🔥',
      isPreset: true,
      filter: const TransactionFilter(minAmount: 1000),
      createdAt: DateTime(2026, 1, 1),
    ),
    SavedViewModel(
      id: 'preset_needs_receipt',
      name: 'Needs receipt',
      icon: '🧾',
      isPreset: true,
      filter: const TransactionFilter(type: 'expense', hasReceipt: false),
      createdAt: DateTime(2026, 1, 1),
    ),
    SavedViewModel(
      id: 'preset_recurring',
      name: 'Recurring',
      icon: '🔄',
      isPreset: true,
      filter: const TransactionFilter(isRecurring: true),
      createdAt: DateTime(2026, 1, 1),
    ),
    SavedViewModel(
      id: 'preset_transfers',
      name: 'Transfers',
      icon: '🏦',
      isPreset: true,
      filter: const TransactionFilter(type: 'transfer'),
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.prefSavedViews);
      if (raw == null || raw.isEmpty) {
        state = [...defaultPresets, ...state.where((v) => !v.isPreset)];
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final userViews =
          decoded
              .map((m) => SavedViewModel.fromMap(m as Map<String, dynamic>))
              .toList();

      state = [...defaultPresets, ...userViews];
    } catch (e) {
      AppLogger.warning(
        'Failed to load saved views, falling back to defaults: $e',
        category: LogCategory.app,
      );
      state = defaultPresets;
    }
  }

  Future<void> _persistCustomViews() async {
    final prefs = await SharedPreferences.getInstance();
    final customViews = state.where((v) => !v.isPreset).toList();
    final jsonList = customViews.map((v) => v.toMap()).toList();
    await prefs.setString(AppConstants.prefSavedViews, jsonEncode(jsonList));
  }

  Future<SavedViewModel> saveView({
    required String name,
    required String icon,
    required TransactionFilter filter,
  }) async {
    final newView = SavedViewModel(
      id: _uuid.v4(),
      name: name.trim(),
      icon: icon.trim().isEmpty ? '🔍' : icon.trim(),
      filter: filter,
      isPreset: false,
      createdAt: DateTime.now(),
    );

    state = [...state, newView];
    await _persistCustomViews();
    return newView;
  }

  Future<void> deleteView(String id) async {
    // Cannot delete built-in presets
    state = state.where((v) => v.id != id || v.isPreset).toList();
    await _persistCustomViews();
  }

  Future<void> updateView(SavedViewModel updated) async {
    state = [
      for (final v in state)
        if (v.id == updated.id && !v.isPreset) updated else v,
    ];
    await _persistCustomViews();
  }
}
