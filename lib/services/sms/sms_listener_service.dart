import '../../core/logging/app_logger.dart';
import 'sms_parser_service.dart';

class SmsListenerService {
  final SmsParserService _parserService = SmsParserService();

  Future<void> startListening() async {
    await AppLogger.i('Initializing SMS listener service and checking pending messages...');
    final added = await _parserService.processPendingMessages();
    await AppLogger.i('SMS listener startup complete. Added $added new items to queue.');
  }

  Future<int> triggerManualSync() async {
    final pendingCount = await _parserService.processPendingMessages();
    final inboxCount = await _parserService.scanInboxAndQueue(limit: 50);
    return pendingCount + inboxCount;
  }
}
