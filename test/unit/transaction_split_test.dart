import 'package:flutter_test/flutter_test.dart';

import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/models/transaction_split_model.dart';

void main() {
  group('TransactionSplitModel Unit Tests', () {
    test('serializes to and from Map correctly', () {
      final split = TransactionSplitModel(
        id: 'split-1',
        transactionId: 'tx-100',
        categoryId: 'cat-food',
        categoryName: 'Food & Dining',
        amount: 250.50,
        note: 'Lunch share',
      );

      final map = split.toMap();
      expect(map['id'], 'split-1');
      expect(map['transaction_id'], 'tx-100');
      expect(map['category_id'], 'cat-food');
      expect(map['amount'], 250.50);
      expect(map['note'], 'Lunch share');

      final fromMap = TransactionSplitModel.fromMap(map);
      expect(fromMap.id, 'split-1');
      expect(fromMap.transactionId, 'tx-100');
      expect(fromMap.categoryId, 'cat-food');
      expect(fromMap.amount, 250.50);
      expect(fromMap.note, 'Lunch share');
    });

    test('handles null optional note in fromMap', () {
      final map = {
        'id': 'split-2',
        'transaction_id': 'tx-101',
        'category_id': 'cat-travel',
        'amount': 150,
        'note': null,
      };

      final split = TransactionSplitModel.fromMap(map);
      expect(split.id, 'split-2');
      expect(split.amount, 150.0);
      expect(split.note, isNull);
    });
  });

  group('TransactionModel Split Integration Tests', () {
    test('transaction holds splits and preserves them in copyWith', () {
      final split1 = TransactionSplitModel(
        id: 's1',
        transactionId: 't1',
        categoryId: 'c1',
        categoryName: 'Groceries',
        amount: 300,
      );
      final split2 = TransactionSplitModel(
        id: 's2',
        transactionId: 't1',
        categoryId: 'c2',
        categoryName: 'Household',
        amount: 200,
      );

      final now = DateTime.now();
      final tx = TransactionModel(
        id: 't1',
        type: 'expense',
        amount: 500,
        description: 'Supermarket shopping',
        categoryId: 'c1',
        paymentMethod: 'UPI',
        accountId: 'acc-1',
        date: DateTime(2026, 10, 26),
        splits: [split1, split2],
        createdAt: now,
        updatedAt: now,
      );

      expect(tx.splits.length, 2);
      expect(tx.splits[0].amount, 300);
      expect(tx.splits[1].amount, 200);

      // Total of splits equals transaction amount
      final totalSplits = tx.splits.fold<double>(0.0, (sum, s) => sum + s.amount);
      expect(totalSplits, 500.0);

      // copyWith without splits preserves existing splits
      final copied = tx.copyWith(description: 'Updated description');
      expect(copied.splits.length, 2);
      expect(copied.description, 'Updated description');
    });

    test('validates equal split remainder distribution logic', () {
      // Test distributing 100 across 3 splits (100 / 3 = 33.333...)
      const total = 100.0;
      const count = 3;
      final baseAmount = (total / count * 100).truncateToDouble() / 100; // 33.33
      final remainder = ((total - (baseAmount * count)) * 100).round() / 100; // 0.01

      final distributed = List.generate(count, (i) {
        final amt = (i == 0) ? (baseAmount + remainder) : baseAmount;
        return double.parse(amt.toStringAsFixed(2));
      });

      expect(distributed[0], 33.34);
      expect(distributed[1], 33.33);
      expect(distributed[2], 33.33);

      final sum = distributed.fold<double>(0.0, (s, a) => s + a);
      expect(sum, 100.0);
    });

    test('validates balance detection helper', () {
      bool isSplitBalanced(double txTotal, List<double> splitAmounts) {
        final totalAllocated = splitAmounts.fold<double>(0.0, (s, a) => s + a);
        return (totalAllocated - txTotal).abs() <= 0.01;
      }

      expect(isSplitBalanced(500.0, [250.0, 250.0]), isTrue);
      expect(isSplitBalanced(500.0, [200.0, 300.0]), isTrue);
      expect(isSplitBalanced(500.0, [200.0, 200.0]), isFalse); // under-allocated
      expect(isSplitBalanced(500.0, [300.0, 300.0]), isFalse); // over-allocated
    });
  });
}
