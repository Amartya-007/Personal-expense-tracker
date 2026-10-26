class ParticipantCalculationInput {
  final String key; // Unique identifier in the calculation (e.g. personId or 'user')
  final String name;
  final bool isUser;
  final bool isPayer;
  final double? customAmount;
  final double? percentage;
  final double? shares;

  const ParticipantCalculationInput({
    required this.key,
    required this.name,
    this.isUser = false,
    this.isPayer = false,
    this.customAmount,
    this.percentage,
    this.shares,
  });
}

class CalculatedParticipantShare {
  final String key;
  final String name;
  final bool isUser;
  final bool isPayer;
  final double allocatedAmount; // in Rupees
  final int allocatedPaise; // integer minor units
  final double shareValue; // percentage, shares count, or entered amount

  const CalculatedParticipantShare({
    required this.key,
    required this.name,
    required this.isUser,
    required this.isPayer,
    required this.allocatedAmount,
    required this.allocatedPaise,
    required this.shareValue,
  });
}

class SplitCalculationResult {
  final double totalAmount;
  final int totalPaise;
  final List<CalculatedParticipantShare> shares;
  final double remainingAmount;
  final int remainingPaise;
  final bool isValid;
  final String? errorMessage;

  const SplitCalculationResult({
    required this.totalAmount,
    required this.totalPaise,
    required this.shares,
    required this.remainingAmount,
    required this.remainingPaise,
    required this.isValid,
    this.errorMessage,
  });

  bool get isExact => isValid && remainingPaise == 0;
}

class SplitCalculator {
  const SplitCalculator._();

  /// Converts a Rupee amount to integer paise (minor units), safely rounding.
  static int toPaise(double rupees) => (rupees * 100.0).round();

  /// Converts integer paise back to standard Rupee double precision.
  static double toRupees(int paise) => paise / 100.0;

  /// Calculates an Equal Split among participants.
  ///
  /// Distributes remainder paise deterministically one by one so that
  /// the sum of allocated paise matches [totalAmount] to the exact paisa (0.01).
  static SplitCalculationResult calculateEqualSplit({
    required double totalAmount,
    required List<ParticipantCalculationInput> participants,
  }) {
    final totalPaise = toPaise(totalAmount);
    if (participants.isEmpty) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'At least one participant is required',
      );
    }
    if (totalPaise < 0) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'Amount cannot be negative',
      );
    }

    final n = participants.length;
    final basePaise = totalPaise ~/ n;
    final remainderPaise = totalPaise % n;

    final shares = <CalculatedParticipantShare>[];
    for (var i = 0; i < n; i++) {
      final p = participants[i];
      // Distribute 1 extra paisa to the first `remainderPaise` participants
      final allocatedPaise = basePaise + (i < remainderPaise ? 1 : 0);
      shares.add(
        CalculatedParticipantShare(
          key: p.key,
          name: p.name,
          isUser: p.isUser,
          isPayer: p.isPayer,
          allocatedPaise: allocatedPaise,
          allocatedAmount: toRupees(allocatedPaise),
          shareValue: 1.0,
        ),
      );
    }

    final allocatedTotalPaise = shares.fold<int>(0, (sum, s) => sum + s.allocatedPaise);
    final remainingPaise = totalPaise - allocatedTotalPaise;

    return SplitCalculationResult(
      totalAmount: totalAmount,
      totalPaise: totalPaise,
      shares: shares,
      remainingAmount: toRupees(remainingPaise),
      remainingPaise: remainingPaise,
      isValid: remainingPaise == 0,
    );
  }

  /// Calculates a Percentage-based Split.
  ///
  /// Requires percentages to sum to 100.0 (tolerance +/- 0.05).
  /// Allocates paise and adjusts any 1-paisa rounding anomaly to the participant
  /// with the highest percentage.
  static SplitCalculationResult calculatePercentageSplit({
    required double totalAmount,
    required List<ParticipantCalculationInput> participants,
  }) {
    final totalPaise = toPaise(totalAmount);
    if (participants.isEmpty) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'At least one participant is required',
      );
    }
    if (totalPaise < 0) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'Amount cannot be negative',
      );
    }

    var totalPercentage = 0.0;
    for (final p in participants) {
      final pct = p.percentage ?? 0.0;
      if (pct < 0) {
        return SplitCalculationResult(
          totalAmount: totalAmount,
          totalPaise: totalPaise,
          shares: const [],
          remainingAmount: totalAmount,
          remainingPaise: totalPaise,
          isValid: false,
          errorMessage: 'Percentages cannot be negative',
        );
      }
      totalPercentage += pct;
    }

    final isSum100 = (totalPercentage - 100.0).abs() <= 0.05;
    if (!isSum100) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage:
            'Percentages must sum to 100% (currently ${totalPercentage.toStringAsFixed(1)}%)',
      );
    }

    final rawShares = <int>[];
    int sumPaise = 0;
    int maxIndex = 0;
    double maxPct = -1.0;

    for (var i = 0; i < participants.length; i++) {
      final pct = participants[i].percentage ?? 0.0;
      if (pct > maxPct) {
        maxPct = pct;
        maxIndex = i;
      }
      final paise = ((totalPaise * pct) / 100.0).round();
      rawShares.add(paise);
      sumPaise += paise;
    }

    // Adjust any rounding diff onto the largest percentage share
    final diff = totalPaise - sumPaise;
    if (diff != 0 && rawShares.isNotEmpty) {
      rawShares[maxIndex] += diff;
    }

    final shares = <CalculatedParticipantShare>[];
    for (var i = 0; i < participants.length; i++) {
      final p = participants[i];
      final paise = rawShares[i];
      shares.add(
        CalculatedParticipantShare(
          key: p.key,
          name: p.name,
          isUser: p.isUser,
          isPayer: p.isPayer,
          allocatedPaise: paise,
          allocatedAmount: toRupees(paise),
          shareValue: p.percentage ?? 0.0,
        ),
      );
    }

    return SplitCalculationResult(
      totalAmount: totalAmount,
      totalPaise: totalPaise,
      shares: shares,
      remainingAmount: 0.0,
      remainingPaise: 0,
      isValid: true,
    );
  }

  /// Calculates a Weighted Share Split (e.g. 2 shares, 1 share).
  ///
  /// Distributes remainder paise deterministically by largest fractional remainder.
  static SplitCalculationResult calculateSharesSplit({
    required double totalAmount,
    required List<ParticipantCalculationInput> participants,
  }) {
    final totalPaise = toPaise(totalAmount);
    if (participants.isEmpty) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'At least one participant is required',
      );
    }
    if (totalPaise < 0) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'Amount cannot be negative',
      );
    }

    var totalWeights = 0.0;
    for (final p in participants) {
      final w = p.shares ?? 1.0;
      if (w <= 0) {
        return SplitCalculationResult(
          totalAmount: totalAmount,
          totalPaise: totalPaise,
          shares: const [],
          remainingAmount: totalAmount,
          remainingPaise: totalPaise,
          isValid: false,
          errorMessage: 'Each share weight must be greater than 0',
        );
      }
      totalWeights += w;
    }

    if (totalWeights <= 0) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'Total shares must be greater than 0',
      );
    }

    // Calculate base paise and fractional remainders
    final basePaiseList = <int>[];
    final remainders = <({int index, double frac})>[];
    int sumAllocated = 0;

    for (var i = 0; i < participants.length; i++) {
      final w = participants[i].shares ?? 1.0;
      final exactPaise = (totalPaise * w) / totalWeights;
      final base = exactPaise.floor();
      basePaiseList.add(base);
      sumAllocated += base;
      remainders.add((index: i, frac: exactPaise - base));
    }

    // Sort by largest fractional remainder descending
    remainders.sort((a, b) => b.frac.compareTo(a.frac));

    int leftover = totalPaise - sumAllocated;
    for (var i = 0; i < leftover; i++) {
      final targetIdx = remainders[i % remainders.length].index;
      basePaiseList[targetIdx] += 1;
    }

    final shares = <CalculatedParticipantShare>[];
    for (var i = 0; i < participants.length; i++) {
      final p = participants[i];
      final paise = basePaiseList[i];
      shares.add(
        CalculatedParticipantShare(
          key: p.key,
          name: p.name,
          isUser: p.isUser,
          isPayer: p.isPayer,
          allocatedPaise: paise,
          allocatedAmount: toRupees(paise),
          shareValue: p.shares ?? 1.0,
        ),
      );
    }

    return SplitCalculationResult(
      totalAmount: totalAmount,
      totalPaise: totalPaise,
      shares: shares,
      remainingAmount: 0.0,
      remainingPaise: 0,
      isValid: true,
    );
  }

  /// Calculates a Custom-entered amount split.
  ///
  /// Verifies that all entered amounts sum up to [totalAmount] to the exact paisa.
  static SplitCalculationResult calculateCustomSplit({
    required double totalAmount,
    required List<ParticipantCalculationInput> participants,
  }) {
    final totalPaise = toPaise(totalAmount);
    if (participants.isEmpty) {
      return SplitCalculationResult(
        totalAmount: totalAmount,
        totalPaise: totalPaise,
        shares: const [],
        remainingAmount: totalAmount,
        remainingPaise: totalPaise,
        isValid: false,
        errorMessage: 'At least one participant is required',
      );
    }

    final shares = <CalculatedParticipantShare>[];
    int sumPaise = 0;

    for (final p in participants) {
      final amt = p.customAmount ?? 0.0;
      if (amt < 0) {
        return SplitCalculationResult(
          totalAmount: totalAmount,
          totalPaise: totalPaise,
          shares: const [],
          remainingAmount: totalAmount,
          remainingPaise: totalPaise,
          isValid: false,
          errorMessage: 'Amounts cannot be negative',
        );
      }
      final paise = toPaise(amt);
      sumPaise += paise;
      shares.add(
        CalculatedParticipantShare(
          key: p.key,
          name: p.name,
          isUser: p.isUser,
          isPayer: p.isPayer,
          allocatedPaise: paise,
          allocatedAmount: toRupees(paise),
          shareValue: amt,
        ),
      );
    }

    final remainingPaise = totalPaise - sumPaise;
    final isExact = remainingPaise == 0;
    String? error;
    if (!isExact) {
      final diff = toRupees(remainingPaise.abs());
      if (remainingPaise > 0) {
        error = '₹${diff.toStringAsFixed(2)} remaining to allocate';
      } else {
        error = 'Allocated amounts exceed total by ₹${diff.toStringAsFixed(2)}';
      }
    }

    return SplitCalculationResult(
      totalAmount: totalAmount,
      totalPaise: totalPaise,
      shares: shares,
      remainingAmount: toRupees(remainingPaise),
      remainingPaise: remainingPaise,
      isValid: isExact,
      errorMessage: error,
    );
  }
}
