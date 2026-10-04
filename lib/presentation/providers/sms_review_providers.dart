import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/sms_review_model.dart';
import '../../data/repositories/sms_repository.dart';
import '../../services/sms/sms_parser_service.dart';

final smsRepositoryProvider = Provider((ref) => SmsRepository());
final smsParserServiceProvider = Provider((ref) => SmsParserService());

final smsQueueStatusTabProvider = StateProvider<String>((ref) => 'detected');

class SmsQueueNotifier extends StateNotifier<AsyncValue<List<SmsReviewModel>>> {
  final SmsRepository _repository;
  final SmsParserService _parserService;
  final String _status;

  SmsQueueNotifier(this._repository, this._parserService, this._status)
      : super(const AsyncValue.loading()) {
    loadQueue();
  }

  Future<void> loadQueue() async {
    state = const AsyncValue.loading();
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

  Future<int> scanInbox() async {
    try {
      final pendingCount = await _parserService.processPendingMessages();
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
