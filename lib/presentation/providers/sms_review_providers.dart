import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/sms_review_model.dart';
import '../../data/repositories/sms_repository.dart';
import '../../services/sms/sms_capture_service.dart';
import '../../services/sms/sms_parser_service.dart';

final smsRepositoryProvider = Provider((ref) => SmsRepository());
final smsParserServiceProvider = Provider((ref) => SmsParserService());

final smsQueueStatusTabProvider = StateProvider<String>((ref) => 'detected');

/// The account chosen for a detected SMS (keyed by review id). Null means
/// "use the best match".
final smsAccountChoiceProvider = StateProvider.family<String?, String>(
  (ref, smsId) => null,
);

/// Whether Android currently lets the app read/receive SMS.
final smsPermissionProvider = FutureProvider.autoDispose<bool>((ref) async {
  return SmsCaptureService.hasPermission();
});

class SmsQueueNotifier extends StateNotifier<AsyncValue<List<SmsReviewModel>>> {
  final SmsRepository _repository;
  final SmsParserService _parserService;
  final String _status;

  SmsQueueNotifier(this._repository, this._parserService, this._status)
      : super(const AsyncValue.loading()) {
    loadQueue();
  }

  Future<void> loadQueue() async {
    // Keep showing existing data while reloading so lists don't blink.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      await _parserService.processPendingMessages();
      final list = await _repository.getQueueByStatus(_status);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      await _repository.updateStatus(id, status);
      await loadQueue();
    } catch (e, st) {
      await AppLogger.e(
        'SmsQueueNotifier.updateStatus failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Adds hand-pasted messages to the queue (no SMS permission required).
  Future<({int added, int duplicate, int unrecognized})> addPasted(
    String text,
  ) async {
    final result = await _parserService.queueManualMessages(text);
    await loadQueue();
    return result;
  }

  Future<int> scanInbox() async {
    try {
      final pendingCount =
          await _parserService.processPendingMessages(force: true);
      final inboxCount = await _parserService.scanInboxAndQueue();
      await loadQueue();
      return pendingCount + inboxCount;
    } catch (e, st) {
      await AppLogger.e(
        'SmsQueueNotifier.scanInbox failed',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }
}

final smsQueueProvider =
    StateNotifierProvider.family<
      SmsQueueNotifier,
      AsyncValue<List<SmsReviewModel>>,
      String
    >((ref, status) {
      final repo = ref.watch(smsRepositoryProvider);
      final parser = ref.watch(smsParserServiceProvider);
      return SmsQueueNotifier(repo, parser, status);
    });
