import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/expense_group_model.dart';
import '../../data/models/khata_person_model.dart';
import '../../data/repositories/expense_group_repository.dart';

final expenseGroupRepositoryProvider = Provider<ExpenseGroupRepository>((ref) {
  return ExpenseGroupRepository();
});

final expenseGroupFilterArchivedProvider = StateProvider<bool>((ref) => false);

final expenseGroupListProvider =
    FutureProvider<List<ExpenseGroupModel>>((ref) async {
  final repo = ref.watch(expenseGroupRepositoryProvider);
  final includeArchived = ref.watch(expenseGroupFilterArchivedProvider);
  return repo.getGroups(includeArchived: includeArchived);
});

final expenseGroupDetailProvider =
    FutureProvider.family<ExpenseGroupModel?, String>((ref, groupId) async {
  final repo = ref.watch(expenseGroupRepositoryProvider);
  return repo.getGroupById(groupId);
});

final expenseGroupMembersProvider =
    FutureProvider.family<List<KhataPersonModel>, String>((ref, groupId) async {
  final repo = ref.watch(expenseGroupRepositoryProvider);
  return repo.getGroupMembers(groupId);
});

class ExpenseGroupController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final ExpenseGroupRepository _repo;

  ExpenseGroupController(this._ref, this._repo)
      : super(const AsyncValue.data(null));

  void _invalidateAll(String? groupId) {
    _ref.invalidate(expenseGroupListProvider);
    if (groupId != null) {
      _ref.invalidate(expenseGroupDetailProvider(groupId));
      _ref.invalidate(expenseGroupMembersProvider(groupId));
    }
  }

  Future<ExpenseGroupModel?> createGroup({
    required String name,
    String? description,
    String? icon,
    String? color,
    List<String> memberPersonIds = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final group = await _repo.createGroup(
        name: name,
        description: description,
        icon: icon,
        color: color,
        memberPersonIds: memberPersonIds,
      );
      _invalidateAll(group.id);
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateGroup({
    required String id,
    required String name,
    String? description,
    String? icon,
    String? color,
    List<String>? memberPersonIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateGroup(
        id: id,
        name: name,
        description: description,
        icon: icon,
        color: color,
        memberPersonIds: memberPersonIds,
      );
      _invalidateAll(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> addMembers(String groupId, List<String> personIds) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addMembers(groupId, personIds);
      _invalidateAll(groupId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeMember(String groupId, String personId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeMember(groupId, personId);
      _invalidateAll(groupId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archiveGroup(String groupId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archiveGroup(groupId);
      _invalidateAll(groupId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> restoreGroup(String groupId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.restoreGroup(groupId);
      _invalidateAll(groupId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteGroup(groupId);
      _invalidateAll(groupId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final expenseGroupControllerProvider =
    StateNotifierProvider<ExpenseGroupController, AsyncValue<void>>((ref) {
  final repo = ref.watch(expenseGroupRepositoryProvider);
  return ExpenseGroupController(ref, repo);
});
