import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mykhata/data/models/saved_view_model.dart';
import 'package:mykhata/presentation/providers/saved_views_provider.dart';
import 'package:mykhata/presentation/providers/transaction_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionFilter Serialization Tests', () {
    test('serializes and deserializes all filter fields accurately', () {
      final range = DateTimeRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );

      final filter = TransactionFilter(
        searchQuery: 'groceries',
        type: 'expense',
        datePeriod: 'Custom',
        customDateRange: range,
        minAmount: 50.0,
        maxAmount: 2000.0,
        categoryIds: const ['cat-food', 'cat-drinks'],
        tagIds: const ['tag-weekend'],
        accountIds: const ['acc-primary'],
        paymentMethods: const ['UPI'],
        hasReceipt: true,
        isRecurring: false,
        hasNote: true,
        hasLocation: false,
        sortBy: TransactionSortOption.amountDesc,
      );

      final map = filter.toMap();
      expect(map['searchQuery'], 'groceries');
      expect(map['type'], 'expense');
      expect(map['datePeriod'], 'Custom');
      expect(map['customDateRangeStart'], range.start.millisecondsSinceEpoch);
      expect(map['customDateRangeEnd'], range.end.millisecondsSinceEpoch);
      expect(map['minAmount'], 50.0);
      expect(map['maxAmount'], 2000.0);
      expect(map['categoryIds'], ['cat-food', 'cat-drinks']);
      expect(map['hasReceipt'], isTrue);
      expect(map['isRecurring'], isFalse);
      expect(map['sortBy'], 'amountDesc');

      final fromMap = TransactionFilter.fromMap(map);
      expect(fromMap.searchQuery, 'groceries');
      expect(fromMap.type, 'expense');
      expect(fromMap.datePeriod, 'Custom');
      expect(fromMap.customDateRange?.start, range.start);
      expect(fromMap.customDateRange?.end, range.end);
      expect(fromMap.minAmount, 50.0);
      expect(fromMap.maxAmount, 2000.0);
      expect(fromMap.categoryIds, ['cat-food', 'cat-drinks']);
      expect(fromMap.tagIds, ['tag-weekend']);
      expect(fromMap.accountIds, ['acc-primary']);
      expect(fromMap.paymentMethods, ['UPI']);
      expect(fromMap.hasReceipt, isTrue);
      expect(fromMap.isRecurring, isFalse);
      expect(fromMap.hasNote, isTrue);
      expect(fromMap.hasLocation, isFalse);
      expect(fromMap.sortBy, TransactionSortOption.amountDesc);
    });

    test('handles empty / default filter in fromMap', () {
      final fromMap = TransactionFilter.fromMap(const {});
      expect(fromMap.searchQuery, isNull);
      expect(fromMap.type, isNull);
      expect(fromMap.categoryIds, isEmpty);
      expect(fromMap.sortBy, TransactionSortOption.dateDesc);
    });
  });

  group('SavedViewModel Tests', () {
    test('serializes and deserializes SavedViewModel', () {
      final view = SavedViewModel(
        id: 'view-1',
        name: 'Weekend Dinners',
        icon: '🍽️',
        isPreset: false,
        filter: const TransactionFilter(
          type: 'expense',
          categoryIds: ['cat-dining'],
        ),
        createdAt: DateTime(2026, 10, 26),
      );

      final map = view.toMap();
      expect(map['id'], 'view-1');
      expect(map['name'], 'Weekend Dinners');
      expect(map['icon'], '🍽️');
      expect(map['is_preset'], 0);

      final fromMap = SavedViewModel.fromMap(map);
      expect(fromMap.id, 'view-1');
      expect(fromMap.name, 'Weekend Dinners');
      expect(fromMap.icon, '🍽️');
      expect(fromMap.isPreset, isFalse);
      expect(fromMap.filter.type, 'expense');
      expect(fromMap.filter.categoryIds, ['cat-dining']);
    });
  });

  group('SavedViewsNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default presets when no custom views are saved', () async {
      final notifier = SavedViewsNotifier();
      await notifier.load();

      expect(notifier.state.length, SavedViewsNotifier.defaultPresets.length);
      expect(notifier.state.any((v) => v.id == 'preset_this_month'), isTrue);
      expect(notifier.state.any((v) => v.id == 'preset_high_value'), isTrue);
      expect(notifier.state.any((v) => v.id == 'preset_needs_receipt'), isTrue);
      expect(notifier.state.every((v) => v.isPreset), isTrue);
    });

    test('saves a custom view and persists it', () async {
      final notifier = SavedViewsNotifier();
      await notifier.load();

      final custom = await notifier.saveView(
        name: 'Freelance Invoices',
        icon: '💼',
        filter: const TransactionFilter(type: 'income', minAmount: 5000),
      );

      expect(custom.name, 'Freelance Invoices');
      expect(custom.icon, '💼');
      expect(custom.isPreset, isFalse);
      expect(notifier.state.contains(custom), isTrue);

      // Verify persistence by loading into a fresh notifier
      final freshNotifier = SavedViewsNotifier();
      await freshNotifier.load();
      expect(
        freshNotifier.state.any((v) => v.name == 'Freelance Invoices'),
        isTrue,
      );
    });

    test('deleting a custom view removes it but presets cannot be deleted', () async {
      final notifier = SavedViewsNotifier();
      await notifier.load();

      final custom = await notifier.saveView(
        name: 'Temporary View',
        icon: '⚡',
        filter: const TransactionFilter(type: 'expense'),
      );

      expect(notifier.state.any((v) => v.id == custom.id), isTrue);

      // Attempt to delete a preset (should be ignored)
      await notifier.deleteView('preset_this_month');
      expect(notifier.state.any((v) => v.id == 'preset_this_month'), isTrue);

      // Delete custom view
      await notifier.deleteView(custom.id);
      expect(notifier.state.any((v) => v.id == custom.id), isFalse);
    });
  });
}
