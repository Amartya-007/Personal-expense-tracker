import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../data/models/sms_review_model.dart';
import '../../data/repositories/sms_repository.dart';
import 'bank_parsers/axis_parser.dart';
import 'bank_parsers/bank_parser_interface.dart';
import 'bank_parsers/boi_parser.dart';
import 'bank_parsers/generic_bank_parser.dart';
import 'bank_parsers/hdfc_parser.dart';
import 'bank_parsers/sbi_parser.dart';
import 'sms_capture_service.dart';

class SmsParserService {
  final List<BankParserInterface> _parsers = [
    BoiSmsParser(),
    AxisSmsParser(),
    SbiSmsParser(),
    HdfcSmsParser(),
    GenericBankParser(),
  ];

  final SmsRepository _smsRepo = SmsRepository();
  final Uuid _uuid = const Uuid();

  // Legacy channel kept for the manual inbox scan path (SmsReviewScreen sync button).
  static const MethodChannel _channel = MethodChannel(
    'com.MyKhata.mykhata/sms',
  );

  /// Parses a single raw SMS and returns a [SmsReviewModel] ready for the
  /// review queue, or [null] when the message is not a recognised bank SMS.
  SmsReviewModel? parseSmsMessage(
    String sender,
    String body, {
    DateTime? date,
    String? messageId,
  }) => _parse(sender, body, date: date, messageId: messageId).model;

  /// Same as [parseSmsMessage], also reporting which parser matched (its
  /// class name only, never message text) for the activity log.
  ({SmsReviewModel? model, String? parser}) _parse(
    String sender,
    String body, {
    DateTime? date,
    String? messageId,
  }) {
    for (final parser in _parsers) {
      if (parser.canParse(sender, body)) {
        final extracted = parser.parse(sender, body);
        if (extracted != null && extracted.status == 'SUCCESS') {
          final txDate = date ?? DateTime.now();
          final model = SmsReviewModel(
            id: _uuid.v4(),
            rawSms: body,
            sender: sender,
            amount: extracted.amount,
            direction: extracted.direction,
            merchant: extracted.merchant,
            bankName: extracted.bankName,
            accountRef: extracted.accountRef,
            date: txDate,
            status: 'detected',
            referenceId: extracted.referenceId,
            smsMessageId: messageId,
            createdAt: DateTime.now(),
          );
          return (model: model, parser: parser.runtimeType.toString());
        }
      }
    }
    return (model: null, parser: null);
  }

  /// "BoiSmsParser: 3, GenericBankParser: 1" for the activity log.
  static String _describeParsers(Map<String, int> used) => used.isEmpty
      ? 'none matched'
      : used.entries.map((e) => '${e.key}: ${e.value}').join(', ');

  // Last SMS permission state seen, so only a change is logged.
  static bool? _lastSmsPermission;

  static void _noteSmsPermission(bool granted) {
    if (_lastSmsPermission == granted) return;
    final first = _lastSmsPermission == null;
    _lastSmsPermission = granted;
    AppLogger.info(
      first
          ? 'SMS permission is ${granted ? 'granted' : 'not granted'}'
          : 'SMS permission changed to ${granted ? 'granted' : 'not granted'}',
      category: LogCategory.permissions,
    );
  }

  /// Queues bank messages the user pasted in by hand. This needs **no SMS
  /// permission**, so it works even when Android blocks SMS access (for
  /// example "restricted settings" on a sideloaded app).
  ///
  /// Several messages can be pasted at once; separate them with a blank line.
  Future<({int added, int duplicate, int unrecognized})> queueManualMessages(
    String text,
  ) async {
    var added = 0;
    var duplicate = 0;
    var unrecognized = 0;

    final chunks = text
        .split(RegExp(r'\n\s*\n'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    AppLogger.info(
      'Manual SMS paste processing started',
      category: LogCategory.sms,
      details: '${chunks.length} messages',
    );

    final parsersUsed = <String, int>{};
    for (final chunk in chunks) {
      final parsed = _parse('PASTED', chunk);
      final model = parsed.model;
      if (model == null) {
        unrecognized++;
        continue;
      }
      parsersUsed.update(parsed.parser!, (n) => n + 1, ifAbsent: () => 1);
      if (await _smsRepo.addToQueueIfNew(model)) {
        added++;
      } else {
        duplicate++;
      }
    }
    AppLogger.info(
      'Manual SMS paste processing completed',
      category: LogCategory.sms,
      details:
          '${chunks.length} processed, $added queued, $duplicate duplicate, '
          '$unrecognized not recognised. Parsers: ${_describeParsers(parsersUsed)}',
    );
    return (added: added, duplicate: duplicate, unrecognized: unrecognized);
  }

  /// Reads the SMS inbox history via the legacy MethodChannel and queues any
  /// unprocessed bank transactions for user review.
  ///
  /// Used by the manual "Scan Inbox" button on [SmsReviewScreen].
  Future<int> scanInboxAndQueue({int limit = 100}) async {
    try {
      AppLogger.info(
        'Inbox SMS scan started',
        category: LogCategory.sms,
        details: 'limit $limit',
      );
      final List<dynamic>? rawList = await _channel.invokeMethod(
        'getInboxSms',
        {'limit': limit},
      );
      if (rawList == null || rawList.isEmpty) {
        AppLogger.info(
          'Inbox SMS scan completed',
          category: LogCategory.sms,
          details: 'no messages found',
        );
        return 0;
      }

      int addedCount = 0;
      int duplicateCount = 0;
      int skippedCount = 0;
      final parsersUsed = <String, int>{};
      for (final raw in rawList) {
        if (raw is! Map) {
          skippedCount++;
          continue;
        }
        final sender = raw['sender']?.toString() ?? '';
        final body = raw['body']?.toString() ?? '';
        final msgId = raw['id']?.toString();
        final dateMs = raw['date'] as int?;
        final date = dateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
            : DateTime.now();

        final parsed = _parse(sender, body, date: date, messageId: msgId);
        final model = parsed.model;
        if (model == null) {
          skippedCount++;
          continue;
        }
        parsersUsed.update(parsed.parser!, (n) => n + 1, ifAbsent: () => 1);
        if (await _smsRepo.addToQueueIfNew(model)) {
          addedCount++;
        } else {
          duplicateCount++;
        }
      }
      AppLogger.info(
        'Inbox SMS scan completed',
        category: LogCategory.sms,
        details:
            '${rawList.length} processed, $addedCount queued, '
            '$duplicateCount already known, $skippedCount not recognised. '
            'Parsers: ${_describeParsers(parsersUsed)}',
      );
      return addedCount;
    } catch (e, stack) {
      await AppLogger.error(
        'Failed to scan SMS inbox',
        error: e,
        stackTrace: stack,
        category: LogCategory.sms,
      );
      return 0;
    }
  }

  /// Processes SMS messages captured in the background by [IncomingSmsReceiver]
  /// and stored in the native SharedPreferences queue.
  ///
  /// Should be called on app launch and every time the app resumes from the
  /// background so that bank SMSes received while the app was backgrounded or
  /// killed are picked up automatically.
  ///
  /// Returns the number of new items added to the review queue.
  /// Gracefully returns 0 when SMS permission has not been granted — the app
  /// continues to function normally without SMS features.
  ///
  /// Skipped when the user turned "Detect bank SMS" off in Settings, unless
  /// [force] is set (an explicit manual sync).
  Future<int> processPendingMessages({bool force = false}) {
    // The app start and every status list (detected / confirmed / dismissed)
    // ask for this at the same moment. They share one run instead of each
    // reading the same pending messages. (Even if two runs did overlap,
    // addToQueueIfNew checks and inserts atomically.)
    final running = _processing;
    if (running != null && !force) return running;

    final run = _processPendingMessages(force: force);
    _processing = run;
    run.then((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_processing, run)) _processing = null;
    });
    return run;
  }

  static Future<int>? _processing;

  Future<int> _processPendingMessages({bool force = false}) async {
    try {
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(AppConstants.prefAutoSmsDetection) ?? true)) {
          return 0;
        }
      }

      // Do nothing if the user has not granted SMS permission.
      final hasPermission = await SmsCaptureService.hasPermission();
      _noteSmsPermission(hasPermission);
      if (!hasPermission) return 0;

      final messages = await SmsCaptureService.readPendingMessages();
      if (messages.isEmpty) return 0;

      AppLogger.info(
        'Background SMS processing started',
        category: LogCategory.sms,
        details: '${messages.length} messages',
      );
      int addedCount = 0;
      int duplicateCount = 0;
      int skippedCount = 0;
      final parsersUsed = <String, int>{};
      final acknowledgedIds = <String>[];

      for (final message in messages) {
        // Always acknowledge — even unparseable messages must not be
        // re-processed on every resume.
        acknowledgedIds.add(message.id);

        final parsed = _parse(
          message.sender,
          message.body,
          date: message.receivedAt,
          messageId: message.id,
        );
        final model = parsed.model;
        if (model == null) {
          skippedCount++;
          continue;
        }
        parsersUsed.update(parsed.parser!, (n) => n + 1, ifAbsent: () => 1);

        if (await _smsRepo.addToQueueIfNew(model)) {
          addedCount++;
        } else {
          duplicateCount++;
        }
      }

      // Remove all processed messages from the native pending queue in one call.
      await SmsCaptureService.acknowledgeMessages(acknowledgedIds);

      AppLogger.info(
        'Background SMS processing completed',
        category: LogCategory.sms,
        details:
            '${messages.length} processed, $addedCount queued, '
            '$duplicateCount already known, $skippedCount not recognised. '
            'Parsers: ${_describeParsers(parsersUsed)}',
      );
      return addedCount;
    } catch (e, stack) {
      await AppLogger.error(
        'Failed to process pending SMS messages',
        error: e,
        stackTrace: stack,
        category: LogCategory.sms,
      );
      return 0;
    }
  }
}
