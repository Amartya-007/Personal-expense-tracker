import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/expense_split_model.dart';
import '../../data/models/split_participant_model.dart';
import '../../data/repositories/expense_split_repository.dart';
import 'khata_providers.dart';

final expenseSplitRepositoryProvider = Provider<ExpenseSplitRepository>((ref) {
  return ExpenseSplitRepository();
});

final expenseSplitListProvider =
    FutureProvider.family<List<ExpenseSplitModel>, ({String? groupId, String? personId})>(
        (ref, arg) async {
  final repo = ref.watch(expenseSplitRepositoryProvider);
  return repo.getSplits(groupId: arg.groupId, personId: arg.personId);
});

final expenseSplitDetailProvider =
    FutureProvider.family<ExpenseSplitModel?, String>((ref, splitId) async {
  final repo = ref.watch(expenseSplitRepositoryProvider);
  return repo.getSplitById(splitId);
});

class ExpenseSplitController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final ExpenseSplitRepository _repo;

  ExpenseSplitController(this._ref, this._repo)
      : super(const AsyncValue.data(null));

  void _invalidateAll(String? splitId, String? personId) {
    _ref.invalidate(expenseSplitListProvider);
    _ref.invalidate(khataSummaryProvider);
    _ref.invalidate(khataPeopleListProvider);
    if (splitId != null) {
      _ref.invalidate(expenseSplitDetailProvider(splitId));
    }
    if (personId != null) {
      _ref.invalidate(khataPersonDetailProvider(personId));
      _ref.invalidate(khataPersonLedgerProvider);
    }
  }

  Future<ExpenseSplitModel?> createSplit({
    required ExpenseSplitModel split,
    required List<SplitParticipantModel> participants,
    bool recordInKhataLedger = false,
    String? accountId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repo.createSplit(
        split: split,
        participants: participants,
        recordInKhataLedger: recordInKhataLedger,
        accountId: accountId,
      );
      _invalidateAll(created.id, null);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateSplit({
    required ExpenseSplitModel split,
    required List<SplitParticipantModel> participants,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateSplit(split: split, participants: participants);
      _invalidateAll(split.id, null);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteSplit(String splitId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSplit(splitId);
      _invalidateAll(splitId, null);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setParticipantSettled({
    required String splitId,
    required String participantId,
    required bool settled,
  }) async {
    try {
      await _repo.setParticipantSettled(participantId, settled);
      _invalidateAll(splitId, null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final expenseSplitControllerProvider =
    StateNotifierProvider<ExpenseSplitController, AsyncValue<void>>((ref) {
  final repo = ref.watch(expenseSplitRepositoryProvider);
  return ExpenseSplitController(ref, repo);
});
