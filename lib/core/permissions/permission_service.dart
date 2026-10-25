import 'package:permission_handler/permission_handler.dart';

import '../../services/sms/sms_capture_service.dart';
import '../logging/app_logger.dart';
import '../logging/log_category.dart';

class PermissionService {
  /// Runs a permission [request] and records that it was asked for, and
  /// whether it was granted or denied, in the activity log.
  static Future<bool> _logged(
    String name,
    Future<bool> Function() request,
  ) async {
    AppLogger.info(
      '$name permission requested',
      category: LogCategory.permissions,
    );
    try {
      final granted = await request();
      AppLogger.info(
        '$name permission ${granted ? 'granted' : 'denied'}',
        category: LogCategory.permissions,
      );
      return granted;
    } catch (e, stack) {
      AppLogger.error(
        '$name permission request failed',
        category: LogCategory.permissions,
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Requests the RECEIVE_SMS permission via the native MethodChannel.
  ///
  /// Using [SmsCaptureService] instead of the `permission_handler` package
  /// keeps the permission request in sync with the MethodChannel that the
  /// BroadcastReceiver and inbox reader rely on, and works correctly on
  /// devices where the system blocks `Permission.sms.request()` (e.g. because
  /// the app is not the default SMS app).
  ///
  /// Returns [false] gracefully if permission is denied or unavailable —
  /// the app continues to work normally without SMS features.
  static Future<bool> requestSmsPermission() => _logged('SMS', () async {
    try {
      final status = await Permission.sms.request();
      if (status.isGranted) return true;
      return await SmsCaptureService.requestPermission();
    } catch (_) {
      return await SmsCaptureService.requestPermission();
    }
  });

  /// Opens this app's page in Android Settings (where permissions, and the
  /// "Allow restricted settings" menu for sideloaded apps, live).
  static Future<bool> openSettings() => openAppSettings();

  static Future<bool> requestLocationPermission() =>
      _logged('Location', () async {
        final status = await Permission.locationWhenInUse.request();
        return status.isGranted;
      });

  static Future<bool> requestCameraPermission() => _logged('Camera', () async {
    final status = await Permission.camera.request();
    return status.isGranted;
  });

  static Future<bool> requestNotificationPermission() =>
      _logged('Notification', () async {
        final status = await Permission.notification.request();
        return status.isGranted;
      });

  static Future<Map<String, bool>> checkAllPermissions() async {
    bool hasSms = false;
    try {
      hasSms = await Permission.sms.isGranted;
    } catch (_) {}
    if (!hasSms) {
      hasSms = await SmsCaptureService.hasPermission();
    }
    return {
      'sms': hasSms,
      'location': await Permission.locationWhenInUse.isGranted,
      'camera': await Permission.camera.isGranted,
      'notification': await Permission.notification.isGranted,
    };
  }
}
