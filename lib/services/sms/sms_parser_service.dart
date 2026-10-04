import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/sms_review_model.dart';
import '../../data/repositories/sms_repository.dart';
import 'bank_parsers/axis_parser.dart';
import 'bank_parsers/bank_parser_interface.dart';
import 'bank_parsers/boi_parser.dart';
import 'bank_parsers/generic_bank_parser.dart';
import 'bank_parsers/hdfc_parser.dart';
import 'bank_parsers/sbi_parser.dart';
import 'duplicate_detector.dart';
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
  final DuplicateDetector _duplicateDetector = DuplicateDetector();
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
  }) {
    for (final parser in _parsers) {
      if (parser.canParse(sender, body)) {
        final extracted = parser.parse(sender, body);
        if (extracted != null && extracted.status == 'SUCCESS') {
          final txDate = date ?? DateTime.now();
          return SmsReviewModel(
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
        }
      }
    }
    return null;
  }

  /// Reads the SMS inbox history via the legacy MethodChannel and queues any
  /// unprocessed bank transactions for user review.
  ///
  /// Used by the manual "Scan Inbox" button on [SmsReviewScreen].
  Future<int> scanInboxAndQueue({int limit = 100}) async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod(
        'getInboxSms',
        {'limit': limit},
      );
      if (rawList == null || rawList.isEmpty) return 0;

      int addedCount = 0;
      for (final raw in rawList) {
        if (raw is Map) {
          final sender = raw['sender']?.toString() ?? '';
          final body = raw['body']?.toString() ?? '';
          final msgId = raw['id']?.toString();
          final dateMs = raw['date'] as int?;
          final date = dateMs != null
              ? DateTime.fromMillisecondsSinceEpoch(dateMs)
              : DateTime.now();

          final parsed = parseSmsMessage(
            sender,
            body,
            date: date,
            messageId: msgId,
          );
          if (parsed != null) {
            final isDup = await _duplicateDetector.isDuplicate(
              referenceId: parsed.referenceId,
              smsMessageId: parsed.smsMessageId,
              amount: parsed.amount,
              date: parsed.date,
            );
            if (!isDup) {
              await _smsRepo.addToQueue(parsed);
              addedCount++;
            }
          }
        }
      }
      await AppLogger.i(
        'Inbox SMS scan completed. Added $addedCount items to review queue.',
      );
      return addedCount;
    } catch (e, stack) {
      await AppLogger.e(
        'Failed to scan SMS inbox',
        error: e,
        stackTrace: stack,
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
  Future<int> processPendingMessages() async {
    try {
      // Do nothing if the user has not granted SMS permission.
      final hasPermission = await SmsCaptureService.hasPermission();
      if (!hasPermission) return 0;

      final messages = await SmsCaptureService.readPendingMessages();
      if (messages.isEmpty) return 0;

      int addedCount = 0;
      final acknowledgedIds = <String>[];

      for (final message in messages) {
        // Always acknowledge — even unparseable messages must not be
        // re-processed on every resume.
        acknowledgedIds.add(message.id);

        final parsed = parseSmsMessage(
          message.sender,
          message.body,
          date: message.receivedAt,
          messageId: message.id,
        );
        if (parsed == null) continue;

        final isDup = await _duplicateDetector.isDuplicate(
          referenceId: parsed.referenceId,
          smsMessageId: parsed.smsMessageId,
          amount: parsed.amount,
          date: parsed.date,
        );
        if (isDup) continue;

        await _smsRepo.addToQueue(parsed);
        addedCount++;
      }

      // Remove all processed messages from the native pending queue in one call.
      await SmsCaptureService.acknowledgeMessages(acknowledgedIds);

      if (addedCount > 0) {
        await AppLogger.i(
          'Background SMS processing complete. Added $addedCount items to review queue.',
        );
      }
      return addedCount;
    } catch (e, stack) {
      await AppLogger.e(
        'Failed to process pending SMS messages',
        error: e,
        stackTrace: stack,
      );
      return 0;
    }
  }
}
