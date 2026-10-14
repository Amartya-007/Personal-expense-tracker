import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/account_model.dart';
import '../../data/models/sms_review_model.dart';
import '../../data/repositories/sms_repository.dart';
import '../../services/sms/sms_capture_service.dart';
import '../../services/sms/sms_parser_service.dart';

final smsRepositoryProvider = Provider((ref) => SmsRepository());
final smsParserServiceProvider = Provider((ref) => SmsParserService());

final smsQueueStatusTabProvider = StateProvider<String>((ref) => 'detected');

/// True while the Detected-tab "Add all" batch action is running, so repeated
/// taps during the run are ignored.
final smsBatchProcessingProvider = StateProvider<bool>((ref) => false);

/// Best-effort match of an SMS's bank to one of the user's accounts, so money
/// isn't always booked against the first account. Shared by the single SMS
/// card and the Detected-tab batch action (behaviour-preserving: same
/// lowercase contains / reverse-contains logic). Returns null when there is no
/// bank name or no confident match.
AccountModel? smsBestMatchAccount(
  SmsReviewModel sms,
  List<AccountModel> accounts,
) {
  final bank = (sms.bankName ?? '').toLowerCase().trim();
  if (bank.isEmpty) return null;
  for (final a in accounts) {
    final name = a.name.toLowerCase();
    if (name.contains(bank) || (name.length >= 3 && bank.contains(name))) {
      return a;
    }
  }
  return null;
}

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
      // Copies queued before duplicates were checked: keep one of each.
      await _repository.collapseDuplicateDetected();
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
      final pendingCount = await _parserService.processPendingMessages(
        force: true,
      );
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
