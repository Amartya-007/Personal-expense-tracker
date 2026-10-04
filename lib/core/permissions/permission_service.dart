import 'package:permission_handler/permission_handler.dart';

import '../../services/sms/sms_capture_service.dart';

class PermissionService {
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
  static Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
      if (status.isGranted) return true;
      return await SmsCaptureService.requestPermission();
    } catch (_) {
      return await SmsCaptureService.requestPermission();
    }
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

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
