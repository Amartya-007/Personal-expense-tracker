import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/logging/app_logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);
    } catch (e) {
      await AppLogger.w('Failed to initialize local notifications plugin: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'mykhata_channel',
        'MyKhata Notifications',
        channelDescription: 'Notifications for budget alerts and recurring payment reminders',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      await AppLogger.w('Failed to show notification: $e');
    }
  }
}
