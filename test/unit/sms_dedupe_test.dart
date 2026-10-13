import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/sms_review_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/data/repositories/sms_repository.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The same SMS used to show up 2-3 times in the review queue because:
///  * every status list (detected/confirmed/dismissed) processed the pending
///    messages at the same moment,
///  * the check only looked at the transactions table, never the queue, so
///    every re-scan queued the message again,
///  * the background receiver and the inbox scan give the same SMS different
///    ids, so an id check alone could not catch it.

class _TempIO extends IOOverrides {
  final Directory dir;
  _TempIO(this.dir);

  @override
  Directory getSystemTempDirectory() => dir;
}

final _t0 = DateTime(2026, 3, 10, 14, 30);

SmsReviewModel _sms(
  String id, {
  String body = 'Rs 250.00 debited from A/c XX1234 at CAFE on 10-03-26. Avl bal 9000',
  double amount = 250,
  String direction = 'debit',
  String? messageId,
  String? ref,
  DateTime? date,
}) {
  return SmsReviewModel(
    id: id,
    rawSms: body,
    sender: 'VM-HDFCBK',
    amount: amount,
    direction: direction,
    date: date ?? _t0,
    referenceId: ref,
    smsMessageId: messageId,
    createdAt: _t0,
  );
}

void main() {
  late Directory tmp;
  final repo = SmsRepository();

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('mykhata_sms_');
    IOOverrides.global = _TempIO(tmp);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    IOOverrides.global = null;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    for (final table in [
      'sms_review_queue',
      'transaction_tags',
      'receipts',
      'transaction_splits',
      'transactions',
      'balance_adjustments',
      'accounts',
    ]) {
      await db.delete(table);
    }
    await AccountRepository().createAccount(
      AccountModel(
        id: 'acc',
        name: 'Main',
        currentBalance: 10000,
        initialBalance: 10000,
        createdAt: _t0,
        updatedAt: _t0,
      ),
    );
  });

  Future<int> queueSize() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM sms_review_queue');
    return rows.first['n'] as int;
  }

  Future<void> addTransaction({
    required String id,
    required String type,
    required double amount,
    String? smsMessageId,
  }) {
    return TransactionRepository().createTransaction(
      TransactionModel(
        id: id,
        type: type,
        amount: amount,
        description: 'T $id',
        paymentMethod: 'UPI',
        accountId: 'acc',
        date: _t0,
        createdAt: _t0,
        updatedAt: _t0,
        smsMessageId: smsMessageId,
      ),
    );
  }

  group('Same message must be queued once', () {
    test('same id twice', () async {
      expect(await repo.addToQueueIfNew(_sms('1', messageId: 'm1')), isTrue);
      expect(
        await repo.addToQueueIfNew(_sms('2', messageId: 'm1')),
        isFalse,
      );
      expect(await queueSize(), 1);
    });

    test('background receiver and inbox scan: different ids, same text',
        () async {
      // Background receiver: hashed id, text as delivered.
      expect(
        await repo.addToQueueIfNew(_sms('1', messageId: 'native-hash-9f3a')),
        isTrue,
      );
      // Inbox scan: Android row id, same text with different spacing/case.
      expect(
        await repo.addToQueueIfNew(
          _sms(
            '2',
            messageId: '4821',
            body: 'RS 250.00  debited from a/c xx1234 at cafe on 10-03-26.\n'
                'Avl bal 9000',
          ),
        ),
        isFalse,
      );
      expect(await queueSize(), 1);
    });

    test('five callers racing with the same message insert it once', () async {
      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          repo.addToQueueIfNew(_sms('r$i', messageId: 'id-$i')),
      ]);
      expect(results.where((added) => added).length, 1);
      expect(await queueSize(), 1);
    });

    test('a dismissed message is not offered again by the next scan', () async {
      await repo.addToQueueIfNew(_sms('1', messageId: 'm1'));
      await repo.updateStatus('1', 'dismissed');

      expect(
        await repo.addToQueueIfNew(_sms('2', messageId: 'inbox-77')),
        isFalse,
      );
      expect(await queueSize(), 1);
    });
  });

  group('Genuinely different messages are kept', () {
    test('two payments of the same amount a minute apart', () async {
      expect(
        await repo.addToQueueIfNew(
          _sms('1', messageId: 'a', body: 'Rs 20 paid to CHAI WALA. Ref 111'),
        ),
        isTrue,
      );
      expect(
        await repo.addToQueueIfNew(
          _sms(
            '2',
            messageId: 'b',
            body: 'Rs 20 paid to CHAI WALA. Ref 222',
            date: _t0.add(const Duration(minutes: 1)),
          ),
        ),
        isTrue,
      );
      expect(await queueSize(), 2);
    });

    test('a refund may reuse the payment reference', () async {
      expect(
        await repo.addToQueueIfNew(
          _sms('1', messageId: 'a', ref: 'REF9', body: 'Rs 500 debited. Ref REF9'),
        ),
        isTrue,
      );
      expect(
        await repo.addToQueueIfNew(
          _sms(
            '2',
            messageId: 'b',
            ref: 'REF9',
            direction: 'credit',
            amount: 500,
            body: 'Rs 500 credited as refund. Ref REF9',
          ),
        ),
        isTrue,
      );
      expect(await queueSize(), 2);
    });

    test('same bank reference and direction is the same payment', () async {
      expect(
        await repo.addToQueueIfNew(
          _sms('1', messageId: 'a', ref: 'REF7', body: 'Bank alert: Rs 250 debited, ref REF7'),
        ),
        isTrue,
      );
      expect(
        await repo.addToQueueIfNew(
          _sms('2', messageId: 'b', ref: 'REF7', body: 'UPI: paid Rs 250 to CAFE, ref REF7'),
        ),
        isFalse,
      );
    });
  });

  group('Transactions the person already has', () {
    test('a manual expense of the same amount at the same time is skipped',
        () async {
      await addTransaction(id: 'm', type: 'expense', amount: 250);
      expect(await repo.addToQueueIfNew(_sms('1', messageId: 'a')), isFalse);
    });

    test('a manual expense does not hide a refund of the same amount',
        () async {
      await addTransaction(id: 'm', type: 'expense', amount: 250);
      expect(
        await repo.addToQueueIfNew(
          _sms('1', messageId: 'a', direction: 'credit', body: 'Rs 250 credited'),
        ),
        isTrue,
      );
    });

    test('an SMS-sourced transaction does not hide a different payment',
        () async {
      await addTransaction(
        id: 'from-sms',
        type: 'expense',
        amount: 250,
        smsMessageId: 'earlier-sms',
      );
      expect(
        await repo.addToQueueIfNew(
          _sms('1', messageId: 'a', body: 'Rs 250 debited at another shop'),
        ),
        isTrue,
      );
    });

    test('a message that already became a transaction is not queued again',
        () async {
      await addTransaction(
        id: 'from-sms',
        type: 'expense',
        amount: 250,
        smsMessageId: 'same-sms',
      );
      expect(
        await repo.addToQueueIfNew(_sms('1', messageId: 'same-sms')),
        isFalse,
      );
    });
  });

  group('Copies queued before the fix', () {
    test('only the earliest of identical waiting messages survives', () async {
      final db = await DatabaseHelper.instance.database;
      // Written straight to the table, as the old code did.
      for (var i = 0; i < 3; i++) {
        final row = _sms('dup$i', messageId: 'x$i').toMap();
        row['created_at'] = _t0.add(Duration(seconds: i)).millisecondsSinceEpoch;
        await db.insert('sms_review_queue', row);
      }
      final other = _sms('other', body: 'Rs 99 debited at ANOTHER', amount: 99);
      await db.insert('sms_review_queue', other.toMap());
      final confirmed = _sms('done', messageId: 'c1').toMap()
        ..['status'] = 'confirmed';
      await db.insert('sms_review_queue', confirmed);

      expect(await repo.collapseDuplicateDetected(), 2);

      final left = await db.query('sms_review_queue', orderBy: 'id');
      expect(left.map((r) => r['id']).toSet(), {'dup0', 'other', 'done'});
      // Safe to run again.
      expect(await repo.collapseDuplicateDetected(), 0);
    });
  });
}
