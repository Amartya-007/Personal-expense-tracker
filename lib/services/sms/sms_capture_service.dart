import 'package:flutter/services.dart';

/// A single message captured by the Android BroadcastReceiver and stored in
/// SharedPreferences until the Flutter side acknowledges it.
class SmsCaptureMessage {
  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;

  const SmsCaptureMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  factory SmsCaptureMessage.fromMap(Map<dynamic, dynamic> map) {
    final ts = (map['receivedAt'] as num?)?.toInt() ?? 0;
    return SmsCaptureMessage(
      id: map['id'] as String? ?? '',
      sender: map['sender'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }
}

/// Dart bridge to the native SMS capture MethodChannel.
///
/// All methods silently degrade to safe defaults when the native channel is
/// unavailable (e.g. on iOS, in tests, or before permissions are granted),
/// so the rest of the app continues to work normally.
class SmsCaptureService {
  static const _channel = MethodChannel('com.MyKhata.mykhata/sms');

  /// Returns [true] if the RECEIVE_SMS runtime permission is currently granted.
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Requests the RECEIVE_SMS permission from the user.
  ///
  /// Returns [true] if granted, [false] if denied or unavailable.
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Reads the pending SMS queue that the BroadcastReceiver filled while the
  /// app was backgrounded or killed.
  ///
  /// Returns an empty list when there are no pending messages or the channel
  /// is unavailable.
  static Future<List<SmsCaptureMessage>> readPendingMessages() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('readPendingSms');
      return (raw ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map(SmsCaptureMessage.fromMap)
          .where((m) => m.id.isNotEmpty && m.body.isNotEmpty)
          .toList();
    } on PlatformException {
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Removes the given message IDs from the native pending queue so they are
  /// not processed again on the next resume.
  ///
  /// Silently does nothing if the channel is unavailable — the messages will
  /// simply be re-processed on the next app launch (duplicate detection in
  /// [SmsParserService] will skip them).
  static Future<void> acknowledgeMessages(Iterable<String> ids) async {
    final messageIds = ids.where((id) => id.isNotEmpty).toList();
    if (messageIds.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('acknowledgePendingSms', messageIds);
    } on PlatformException {
      // Will be retried on next launch — duplicate detector protects against
      // double-processing.
    } on MissingPluginException {
      // Channel unavailable (e.g. test environment) — ignore silently.
    }
  }
}
