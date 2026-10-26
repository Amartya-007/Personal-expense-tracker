import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/contacts/contact_service.dart';

final contactPermissionStatusProvider =
    FutureProvider.autoDispose<ContactPermissionState>((ref) async {
  return ContactService.getPermissionState();
});

final contactSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final deviceContactsProvider =
    FutureProvider.autoDispose<List<DeviceContact>>((ref) async {
  final status = await ref.watch(contactPermissionStatusProvider.future);
  if (!status.isGranted) return const [];

  final query = ref.watch(contactSearchQueryProvider);
  return ContactService.fetchDeviceContacts(
    query: query.trim().isEmpty ? null : query.trim(),
  );
});

class ContactPermissionNotifier extends StateNotifier<ContactPermissionState> {
  final Ref _ref;

  ContactPermissionNotifier(this._ref)
      : super(ContactPermissionState.notRequested) {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    final status = await ContactService.getPermissionState();
    state = status;
    _ref.invalidate(contactPermissionStatusProvider);
  }

  Future<bool> requestPermission() async {
    final granted = await ContactService.requestPermission();
    await refreshStatus();
    if (granted) {
      _ref.invalidate(deviceContactsProvider);
    }
    return granted;
  }

  Future<void> openSettings() async {
    await ContactService.openSettings();
  }
}

final contactPermissionControllerProvider =
    StateNotifierProvider.autoDispose<ContactPermissionNotifier, ContactPermissionState>(
  (ref) => ContactPermissionNotifier(ref),
);
