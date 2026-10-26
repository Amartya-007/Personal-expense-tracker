import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';

enum ContactPermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  restricted;

  bool get isGranted => this == ContactPermissionState.granted;
  bool get isDenied => this == ContactPermissionState.denied;
  bool get isPermanentlyDenied =>
      this == ContactPermissionState.permanentlyDenied;

  String get label {
    switch (this) {
      case ContactPermissionState.notRequested:
        return 'Not requested';
      case ContactPermissionState.granted:
        return 'Granted';
      case ContactPermissionState.denied:
        return 'Denied';
      case ContactPermissionState.permanentlyDenied:
        return 'Blocked in settings';
      case ContactPermissionState.restricted:
        return 'Restricted';
    }
  }
}

class DeviceContact {
  final String id;
  final String lookupKey;
  final String displayName;
  final List<String> phones;

  const DeviceContact({
    required this.id,
    required this.lookupKey,
    required this.displayName,
    required this.phones,
  });

  String? get primaryPhone => phones.isNotEmpty ? phones.first : null;

  factory DeviceContact.fromMap(Map<dynamic, dynamic> map) {
    final rawPhones = map['phones'];
    final phonesList = <String>[];
    if (rawPhones is List) {
      for (final p in rawPhones) {
        if (p != null) {
          final s = p.toString().trim();
          if (s.isNotEmpty && !phonesList.contains(s)) {
            phonesList.add(s);
          }
        }
      }
    }
    return DeviceContact(
      id: (map['contactId'] ?? '').toString(),
      lookupKey: (map['lookupKey'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Unknown Contact').toString().trim(),
      phones: phonesList,
    );
  }
}

class ContactService {
  static const MethodChannel _channel =
      MethodChannel('com.MyKhata.mykhata/contacts');

  /// Gets the actual, current contact permission status from Android.
  static Future<ContactPermissionState> getPermissionState() async {
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted) return ContactPermissionState.granted;
      if (status.isPermanentlyDenied) {
        return ContactPermissionState.permanentlyDenied;
      }
      if (status.isRestricted) return ContactPermissionState.restricted;
      if (status.isDenied) return ContactPermissionState.denied;
      return ContactPermissionState.notRequested;
    } catch (_) {
      return ContactPermissionState.notRequested;
    }
  }

  /// Requests the READ_CONTACTS permission.
  ///
  /// Safe to call multiple times. Records audit logs locally.
  static Future<bool> requestPermission() async {
    AppLogger.info(
      'Contact permission requested',
      category: LogCategory.permissions,
    );
    try {
      final status = await Permission.contacts.request();
      final granted = status.isGranted;
      AppLogger.info(
        'Contact permission ${granted ? 'granted' : 'denied'}',
        category: LogCategory.permissions,
      );
      return granted;
    } catch (e, stack) {
      AppLogger.error(
        'Contact permission request failed',
        category: LogCategory.permissions,
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Opens the app's Android settings page for permission management.
  static Future<bool> openSettings() => openAppSettings();

  /// Reads contacts from the device's address book.
  ///
  /// Only queries `ContactsContract.CommonDataKinds.Phone`.
  /// Never stores a full copy of the address book.
  /// Gracefully returns an empty list if permission is missing or on non-Android test environments.
  static Future<List<DeviceContact>> fetchDeviceContacts({
    String? query,
  }) async {
    try {
      final hasPerm = await Permission.contacts.isGranted;
      if (!hasPerm) return const [];

      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getContacts',
        {'query': query},
      );
      if (raw == null) return const [];

      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => DeviceContact.fromMap(m))
          .where((c) => c.displayName.isNotEmpty)
          .toList();
    } on MissingPluginException {
      // In host/unit test environments where native channel is absent
      return const [];
    } catch (e, stack) {
      AppLogger.error(
        'Failed to read device contacts',
        category: LogCategory.permissions,
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }
}
