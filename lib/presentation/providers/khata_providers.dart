import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/khata_entry_model.dart';
import '../../data/models/khata_person_model.dart';
import '../../data/repositories/khata_repository.dart';
import 'account_providers.dart';

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  return KhataRepository();
});

final khataSummaryProvider = FutureProvider<KhataSummary>((ref) async {
  final repo = ref.watch(khataRepositoryProvider);
  return repo.getSummary();
});

final khataFilterProvider = StateProvider<String>((ref) => 'all');
final khataSearchQueryProvider = StateProvider<String>((ref) => '');

final khataPeopleListProvider = FutureProvider<List<KhataPersonModel>>((ref) async {
  final repo = ref.watch(khataRepositoryProvider);
  final filter = ref.watch(khataFilterProvider);
  final query = ref.watch(khataSearchQueryProvider);

  final isArchivedFilter = filter == 'archived';

  return repo.getPeople(
    includeArchived: isArchivedFilter,
    searchQuery: query.isEmpty ? null : query,
    filter: isArchivedFilter ? 'all' : filter,
  );
});

final khataPersonDetailProvider = FutureProvider.family<KhataPersonModel?, String>((ref, personId) async {
  final repo = ref.watch(khataRepositoryProvider);
  return repo.getPersonById(personId);
});

final khataPersonLedgerProvider = FutureProvider.family<List<KhataLedgerItem>, ({String personId, KhataEntryType? typeFilter})>((ref, arg) async {
  final repo = ref.watch(khataRepositoryProvider);
  return repo.getLedgerEntries(arg.personId, typeFilter: arg.typeFilter);
});

class KhataController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final KhataRepository _repo;

  KhataController(this._ref, this._repo) : super(const AsyncValue.data(null));

  void _invalidateAll(String? personId) {
    _ref.invalidate(khataSummaryProvider);
    _ref.invalidate(khataPeopleListProvider);
    _ref.invalidate(accountListProvider);
    if (personId != null) {
      _ref.invalidate(khataPersonDetailProvider(personId));
      _ref.invalidate(khataPersonLedgerProvider);
    }
  }

  Future<KhataPersonModel?> createPerson({
    required String name,
    String? phone,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final person = await _repo.createPerson(name: name, phone: phone, notes: notes);
      _invalidateAll(person.id);
      state = const AsyncValue.data(null);
      return person;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updatePerson(KhataPersonModel person) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updatePerson(person);
      _invalidateAll(person.id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setArchived(String personId, bool isArchived) async {
    state = const AsyncValue.loading();
    try {
      await _repo.setArchived(personId, isArchived);
      _invalidateAll(personId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deletePerson(String personId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deletePerson(personId);
      _invalidateAll(personId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> addEntry({
    required String personId,
    required KhataEntryType type,
    required double amount,
    required DateTime date,
    String? notes,
    DateTime? dueDate,
    String? accountId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addEntry(
        personId: personId,
        type: type,
        amount: amount,
        date: date,
        notes: notes,
        dueDate: dueDate,
        accountId: accountId,
      );
      _invalidateAll(personId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> settlePerson(
    String personId, {
    required double amount,
    DateTime? date,
    String? accountId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.settlePerson(
        personId,
        amount: amount,
        date: date,
        accountId: accountId,
        notes: notes,
      );
      _invalidateAll(personId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<KhataPersonModel?> createPersonFromContact({
    required String displayName,
    String? phone,
    String? contactId,
    String? lookupKey,
  }) async {
    state = const AsyncValue.loading();
    try {
      final person = await _repo.getOrCreatePersonFromContact(
        displayName: displayName,
        phone: phone,
        contactId: contactId,
        lookupKey: lookupKey,
      );
      _invalidateAll(person.id);
      state = const AsyncValue.data(null);
      return person;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteEntry(String entryId, String personId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteEntry(entryId);
      _invalidateAll(personId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final khataControllerProvider = StateNotifierProvider<KhataController, AsyncValue<void>>((ref) {
  final repo = ref.watch(khataRepositoryProvider);
  return KhataController(ref, repo);
});

final khataPersonGroupsProvider =
    FutureProvider.family<List<String>, String>((ref, personId) async {
  final repo = ref.watch(khataRepositoryProvider);
  return repo.getPersonGroupNames(personId);
});

final khataPersonSplitsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, personId) async {
  final repo = ref.watch(khataRepositoryProvider);
  return repo.getPersonSplitsHistory(personId);
});
