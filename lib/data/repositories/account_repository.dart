import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/account_model.dart';
import '../models/balance_adjustment_model.dart';

class AccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<AccountModel>> getActiveAccounts() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'accounts',
      where: 'is_active = 1',
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => AccountModel.fromMap(m)).toList();
  }

  Future<AccountModel?> getAccountById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return AccountModel.fromMap(maps.first);
  }

  Future<void> createAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    await db.insert('accounts', account.toMap());
    await AppLogger.i('Created account: ${account.name}');
  }

  Future<void> updateAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    await AppLogger.i('Updated account: ${account.name}');
  }

  Future<void> updateAccountBalanceDirect(String accountId, double newBalance, {String? reason}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final maps = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (maps.isEmpty) throw Exception('Account not found');

      final currentAcc = AccountModel.fromMap(maps.first);
      final prevBalance = currentAcc.currentBalance;
      final adjustmentAmount = newBalance - prevBalance;
      final now = DateTime.now();

      final adj = BalanceAdjustmentModel(
        id: _uuid.v4(),
        accountId: accountId,
        previousBalance: prevBalance,
        newBalance: newBalance,
        adjustmentAmount: adjustmentAmount,
        reason: reason ?? 'Direct balance edit from Home screen',
        createdAt: now,
      );

      await txn.insert('balance_adjustments', adj.toMap());

      await txn.update(
        'accounts',
        {
          'current_balance': newBalance,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
    await AppLogger.i('Directly updated account balance for $accountId to ₹$newBalance');
  }

  Future<void> deleteAccount(String accountId) async {
    final db = await _dbHelper.database;
    await db.update(
      'accounts',
      {
        'is_active': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
    await AppLogger.i('Deactivated account $accountId');
  }
}
