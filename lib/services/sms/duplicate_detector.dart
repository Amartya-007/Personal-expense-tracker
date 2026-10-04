import '../../data/repositories/sms_repository.dart';

class DuplicateDetector {
  final SmsRepository _smsRepo = SmsRepository();

  Future<bool> isDuplicate({
    String? referenceId,
    String? smsMessageId,
    required double amount,
    required DateTime date,
  }) async {
    return await _smsRepo.isPossibleDuplicate(referenceId, smsMessageId, amount, date);
  }
}
