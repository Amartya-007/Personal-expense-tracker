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

  /// The account new expenses default to, or `null` if none is set.
  /// A removed account is never primary.
  Future<AccountModel?> getPrimaryAccount() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'accounts',
      where: 'is_active = 1 AND is_primary = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AccountModel.fromMap(maps.first);
  }

  /// Creates the account. If [AccountModel.isPrimary] is set, the previous
  /// primary account is cleared in the same transaction.
  Future<void> createAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (account.isPrimary) {
        await txn.update('accounts', {'is_primary': 0}, where: 'is_primary = 1');
      }
      await txn.insert('accounts', account.toMap());
    });
    await AppLogger.i('Created account: ${account.name}');
  }

  /// Makes [accountId] the one primary account (clearing any other) in one
  /// transaction. Existing transactions are not touched.
  Future<void> setPrimaryAccount(String accountId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [accountId],
      );
      if (rows.isEmpty) throw Exception('Account not found');
      await txn.update('accounts', {'is_primary': 0}, where: 'is_primary = 1');
      await txn.update(
        'accounts',
        {'is_primary': 1},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
    await AppLogger.i('Primary account set to $accountId');
  }

  Future<void> clearPrimaryAccount() async {
    final db = await _dbHelper.database;
    await db.update('accounts', {'is_primary': 0}, where: 'is_primary = 1');
    await AppLogger.i('Primary account cleared');
  }

  Future<void> updateAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    // The primary flag is changed only through setPrimaryAccount /
    // clearPrimaryAccount, so an edit can never create a second primary.
    final values = account.toMap()..remove('is_primary');
    await db.update(
      'accounts',
      values,
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
        // A removed account can no longer be the primary one.
        'is_primary': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
    await AppLogger.i('Deactivated account $accountId');
  }
}
