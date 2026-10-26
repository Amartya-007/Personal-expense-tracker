import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/domain/splits/split_calculator.dart';

void main() {
  group('SplitCalculator Tests', () {
    test('Equal split with 3 participants divides integer paise deterministically', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice'),
        ParticipantCalculationInput(key: 'p2', name: 'Bob'),
        ParticipantCalculationInput(key: 'p3', name: 'Charlie'),
      ];

      final result = SplitCalculator.calculateEqualSplit(
        totalAmount: 1000.0,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      expect(result.shares.length, equals(3));

      // ₹1,000.00 is 100,000 paise.
      // 100,000 / 3 = 33,333 paise each, with 1 remainder paise.
      // First person gets 33,334 paise (₹333.34), others get 33,333 paise (₹333.33).
      expect(result.shares[0].allocatedAmount, equals(333.34));
      expect(result.shares[1].allocatedAmount, equals(333.33));
      expect(result.shares[2].allocatedAmount, equals(333.33));

      final sumPaise = result.shares.fold<int>(0, (acc, s) => acc + s.allocatedPaise);
      expect(sumPaise, equals(100000));
      expect(result.isExact, isTrue);
    });

    test('Equal split with 1 participant allocates full amount', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice'),
      ];

      final result = SplitCalculator.calculateEqualSplit(
        totalAmount: 499.50,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      expect(result.shares.first.allocatedAmount, equals(499.50));
      expect(result.shares.first.allocatedPaise, equals(49950));
    });

    test('Equal split with large participant count distributes remainder paise without loss', () {
      final participants = List.generate(
        77,
        (i) => ParticipantCalculationInput(key: 'p$i', name: 'Person $i'),
      );

      const total = 12345.67;
      final result = SplitCalculator.calculateEqualSplit(
        totalAmount: total,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      final totalPaise = (total * 100).round();
      final allocatedPaise = result.shares.fold<int>(
        0,
        (acc, s) => acc + s.allocatedPaise,
      );
      expect(allocatedPaise, equals(totalPaise));
      expect(result.remainingPaise, equals(0));
    });

    test('Percentage split allocates exact paise and validates 100% requirement', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', percentage: 50.0),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', percentage: 30.0),
        ParticipantCalculationInput(key: 'p3', name: 'Charlie', percentage: 20.0),
      ];

      final result = SplitCalculator.calculatePercentageSplit(
        totalAmount: 1500.0,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      expect(result.shares[0].allocatedAmount, equals(750.0));
      expect(result.shares[1].allocatedAmount, equals(450.0));
      expect(result.shares[2].allocatedAmount, equals(300.0));

      // Invalid percentage sum
      const invalidParticipants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', percentage: 50.0),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', percentage: 40.0),
      ];

      final invalidResult = SplitCalculator.calculatePercentageSplit(
        totalAmount: 1000.0,
        participants: invalidParticipants,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errorMessage, isNotNull);
      expect(invalidResult.errorMessage, contains('100%'));
    });

    test('Percentage split adjusts 1-paisa rounding anomaly to highest percentage share', () {
      // ₹100.00 with 33.33%, 33.33%, 33.34%
      // 10000 * 0.3333 = 3333 paise
      // 10000 * 0.3333 = 3333 paise
      // 10000 * 0.3334 = 3334 paise
      // Sum = 10000 paise (exact)
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', percentage: 33.33),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', percentage: 33.33),
        ParticipantCalculationInput(key: 'p3', name: 'Charlie', percentage: 33.34),
      ];

      final result = SplitCalculator.calculatePercentageSplit(
        totalAmount: 100.0,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      final totalPaise = result.shares.fold<int>(0, (acc, s) => acc + s.allocatedPaise);
      expect(totalPaise, equals(10000));
    });

    test('Shares (weight) split calculates proportional shares with exact paise conservation', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', shares: 2),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', shares: 1),
        ParticipantCalculationInput(key: 'p3', name: 'Charlie', shares: 1),
      ];

      // Total 4 shares. 1000 / 4 = 250 each.
      // Alice = 500, Bob = 250, Charlie = 250.
      final result = SplitCalculator.calculateSharesSplit(
        totalAmount: 1000.0,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      expect(result.shares[0].allocatedAmount, equals(500.0));
      expect(result.shares[1].allocatedAmount, equals(250.0));
      expect(result.shares[2].allocatedAmount, equals(250.0));
    });

    test('Shares split handles uneven fractions without losing paise', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', shares: 2),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', shares: 1),
      ];

      // Total 3 shares of ₹100.00 (10,000 paise).
      // 2/3 of 10000 = 6666.666... paise -> 6667
      // 1/3 of 10000 = 3333.333... paise -> 3333
      final result = SplitCalculator.calculateSharesSplit(
        totalAmount: 100.0,
        participants: participants,
      );

      expect(result.isValid, isTrue);
      final sumPaise = result.shares.fold<int>(0, (acc, s) => acc + s.allocatedPaise);
      expect(sumPaise, equals(10000));
      expect(result.shares[0].allocatedPaise, equals(6667));
      expect(result.shares[1].allocatedPaise, equals(3333));
    });

    test('Custom split validates when sum matches total and rejects shortfall or overfall', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', customAmount: 600.0),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', customAmount: 400.0),
      ];

      final validResult = SplitCalculator.calculateCustomSplit(
        totalAmount: 1000.0,
        participants: participants,
      );

      expect(validResult.isValid, isTrue);
      expect(validResult.remainingAmount, equals(0.0));
      expect(validResult.remainingPaise, equals(0));

      const shortfallParticipants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', customAmount: 500.0),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', customAmount: 400.0),
      ];

      final shortfallResult = SplitCalculator.calculateCustomSplit(
        totalAmount: 1000.0,
        participants: shortfallParticipants,
      );

      expect(shortfallResult.isValid, isFalse);
      expect(shortfallResult.remainingAmount, equals(100.0));
      expect(shortfallResult.errorMessage, contains('remaining to allocate'));

      const overfallParticipants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice', customAmount: 700.0),
        ParticipantCalculationInput(key: 'p2', name: 'Bob', customAmount: 400.0),
      ];

      final overfallResult = SplitCalculator.calculateCustomSplit(
        totalAmount: 1000.0,
        participants: overfallParticipants,
      );

      expect(overfallResult.isValid, isFalse);
      expect(overfallResult.errorMessage, contains('exceed total'));
    });

    test('Handles invalid and edge case amounts gracefully', () {
      const participants = [
        ParticipantCalculationInput(key: 'p1', name: 'Alice'),
      ];

      // Negative total
      final negResult = SplitCalculator.calculateEqualSplit(
        totalAmount: -50.0,
        participants: participants,
      );
      expect(negResult.isValid, isFalse);
      expect(negResult.errorMessage, contains('cannot be negative'));

      // Empty participants
      final emptyResult = SplitCalculator.calculateEqualSplit(
        totalAmount: 100.0,
        participants: const [],
      );
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.errorMessage, contains('At least one participant'));
    });
  });
}
