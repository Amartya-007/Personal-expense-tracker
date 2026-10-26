import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/data/models/khata_entry_model.dart';
import 'package:mykhata/data/models/khata_person_model.dart';

void main() {
  group('Khata Domain & Accounting Invariants', () {
    final now = DateTime.now();

    test('KhataPersonModel balance classification: receivable vs payable vs settled', () {
      final receivablePerson = KhataPersonModel(
        id: 'p1',
        name: 'Amit',
        netBalance: 500.0,
        createdAt: now,
        updatedAt: now,
      );
      expect(receivablePerson.isReceivable, isTrue);
      expect(receivablePerson.isPayable, isFalse);
      expect(receivablePerson.isSettled, isFalse);
      expect(receivablePerson.balanceStatusLabel, equals("You'll Get"));
      expect(receivablePerson.absoluteBalance, equals(500.0));

      final payablePerson = KhataPersonModel(
        id: 'p2',
        name: 'Pooja',
        netBalance: -250.0,
        createdAt: now,
        updatedAt: now,
      );
      expect(payablePerson.isReceivable, isFalse);
      expect(payablePerson.isPayable, isTrue);
      expect(payablePerson.isSettled, isFalse);
      expect(payablePerson.balanceStatusLabel, equals("You'll Give"));
      expect(payablePerson.absoluteBalance, equals(250.0));

      final settledPerson = KhataPersonModel(
        id: 'p3',
        name: 'Rohan',
        netBalance: 0.0,
        createdAt: now,
        updatedAt: now,
      );
      expect(settledPerson.isReceivable, isFalse);
      expect(settledPerson.isPayable, isFalse);
      expect(settledPerson.isSettled, isTrue);
      expect(settledPerson.balanceStatusLabel, equals('Settled'));

      // Near-zero float precision tolerance check
      final nearZeroPerson = KhataPersonModel(
        id: 'p4',
        name: 'ZeroFloat',
        netBalance: 0.000001,
        createdAt: now,
        updatedAt: now,
      );
      expect(nearZeroPerson.isSettled, isTrue);
    });

    test('KhataEntryModel signedEffect accurately reflects capital directions', () {
      final lentEntry = KhataEntryModel(
        id: 'e1',
        personId: 'p1',
        type: KhataEntryType.lent,
        amount: 1000.0,
        sign: 1,
        date: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(lentEntry.signedEffect, equals(1000.0));
      expect(lentEntry.isReceivableIncrease, isTrue);

      final repaymentReceived = KhataEntryModel(
        id: 'e2',
        personId: 'p1',
        type: KhataEntryType.repaymentReceived,
        amount: 400.0,
        sign: -1,
        date: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(repaymentReceived.signedEffect, equals(-400.0));
      expect(repaymentReceived.isReceivableIncrease, isFalse);

      final borrowedEntry = KhataEntryModel(
        id: 'e3',
        personId: 'p1',
        type: KhataEntryType.borrowed,
        amount: 800.0,
        sign: -1,
        date: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(borrowedEntry.signedEffect, equals(-800.0));

      final repaymentMade = KhataEntryModel(
        id: 'e4',
        personId: 'p1',
        type: KhataEntryType.repaymentMade,
        amount: 800.0,
        sign: 1,
        date: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(repaymentMade.signedEffect, equals(800.0));
    });

    test('Chronological running balance calculation across mixed interactions', () {
      final entries = [
        KhataEntryModel(
          id: '1',
          personId: 'p1',
          type: KhataEntryType.lent,
          amount: 500,
          sign: 1,
          date: now.subtract(const Duration(days: 4)),
          createdAt: now,
          updatedAt: now,
        ),
        KhataEntryModel(
          id: '2',
          personId: 'p1',
          type: KhataEntryType.lent,
          amount: 300,
          sign: 1,
          date: now.subtract(const Duration(days: 3)),
          createdAt: now,
          updatedAt: now,
        ),
        KhataEntryModel(
          id: '3',
          personId: 'p1',
          type: KhataEntryType.repaymentReceived,
          amount: 400,
          sign: -1,
          date: now.subtract(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
        KhataEntryModel(
          id: '4',
          personId: 'p1',
          type: KhataEntryType.settlement,
          amount: 400,
          sign: -1,
          date: now.subtract(const Duration(days: 1)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      double running = 0.0;
      final runningHistory = <double>[];
      for (final e in entries) {
        running += e.signedEffect;
        runningHistory.add(running);
      }

      // Expected progression:
      // Start: 0
      // 1. Lent 500 -> +500
      // 2. Lent 300 -> +800
      // 3. Repaid 400 -> +400
      // 4. Settled 400 -> 0 (fully settled)
      expect(runningHistory, equals([500.0, 800.0, 400.0, 0.0]));
      expect(running, equals(0.0));
    });

    test('KhataEntryModel serialization round-trip preservation', () {
      final original = KhataEntryModel(
        id: 'entry-xyz',
        personId: 'person-abc',
        type: KhataEntryType.borrowed,
        amount: 1450.75,
        sign: -1,
        date: DateTime(2026, 10, 26, 14, 30),
        notes: 'Grocery store trip',
        dueDate: DateTime(2026, 11, 1),
        accountId: 'acc-hdfc',
        isSettled: false,
        createdAt: DateTime(2026, 10, 26, 14, 30),
        updatedAt: DateTime(2026, 10, 26, 14, 30),
      );

      final map = original.toMap();
      final revived = KhataEntryModel.fromMap(map);

      expect(revived.id, equals(original.id));
      expect(revived.personId, equals(original.personId));
      expect(revived.type, equals(original.type));
      expect(revived.amount, equals(original.amount));
      expect(revived.sign, equals(original.sign));
      expect(revived.signedEffect, equals(-1450.75));
      expect(revived.notes, equals('Grocery store trip'));
      expect(revived.accountId, equals('acc-hdfc'));
    });
  });
}
