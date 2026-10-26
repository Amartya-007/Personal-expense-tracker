import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../models/balance_adjustment_model.dart';
import '../models/khata_entry_model.dart';
import '../models/khata_person_model.dart';

class KhataSummary {
  final double totalReceivable; // "You'll Get"
  final double totalPayable;    // "You'll Give"
  final double netBalance;      // totalReceivable - totalPayable
  final int activePeopleCount;

  const KhataSummary({
    required this.totalReceivable,
    required this.totalPayable,
    required this.netBalance,
    required this.activePeopleCount,
  });

  static const empty = KhataSummary(
    totalReceivable: 0.0,
    totalPayable: 0.0,
    netBalance: 0.0,
    activePeopleCount: 0,
  );
}

class KhataLedgerItem {
  final KhataEntryModel entry;
  final double runningBalance;

  const KhataLedgerItem({
    required this.entry,
    required this.runningBalance,
  });
}

class KhataRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  KhataRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Creates a new person in the Khata system.
  Future<KhataPersonModel> createPerson({
    required String name,
    String? phone,
    String? notes,
    String? contactId,
    String? lookupKey,
    String source = 'manual',
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Person name cannot be empty');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final person = KhataPersonModel(
      id: _uuid.v4(),
      name: trimmedName,
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      contactId: contactId,
      lookupKey: lookupKey,
      source: source,
      isArchived: false,
      netBalance: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('khata_people', person.toMap());
    await AppLogger.info(
      'Created Khata person',
      category: LogCategory.database,
      details: 'name: ${person.name}, id: ${person.id}',
    );
    return person;
  }

  /// Finds an existing person by contact ID, or returns null.
  Future<KhataPersonModel?> findPersonByContactId(String contactId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'khata_people',
      where: 'contact_id = ? AND is_archived = 0',
      whereArgs: [contactId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KhataPersonModel.fromMap(rows.first);
  }

  /// Finds an existing person by phone number, or returns null.
  Future<KhataPersonModel?> findPersonByPhone(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'khata_people',
      where: 'phone = ? AND is_archived = 0',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KhataPersonModel.fromMap(rows.first);
  }

  /// Creates a new person from a selected device contact, or reuses existing.
  Future<KhataPersonModel> getOrCreatePersonFromContact({
    required String displayName,
    String? phone,
    String? contactId,
    String? lookupKey,
  }) async {
    if (contactId != null && contactId.isNotEmpty) {
      final existing = await findPersonByContactId(contactId);
      if (existing != null) return existing;
    }
    if (phone != null && phone.trim().isNotEmpty) {
      final existing = await findPersonByPhone(phone.trim());
      if (existing != null) {
        // Link contact ID if missing
        if (contactId != null && existing.contactId == null) {
          final db = await _dbHelper.database;
          await db.update(
            'khata_people',
            {'contact_id': contactId, 'lookup_key': lookupKey},
            where: 'id = ?',
            whereArgs: [existing.id],
          );
          return existing.copyWith(contactId: contactId, lookupKey: lookupKey);
        }
        return existing;
      }
    }

    return createPerson(
      name: displayName,
      phone: phone,
      contactId: contactId,
      lookupKey: lookupKey,
      source: 'contact',
    );
  }

  /// Returns the names of groups that [personId] belongs to.
  Future<List<String>> getPersonGroupNames(String personId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT g.name 
      FROM group_members m
      JOIN expense_groups g ON m.group_id = g.id
      WHERE m.person_id = ? AND g.is_archived = 0
      ORDER BY g.name ASC
    ''', [personId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  /// Returns historical expense splits that [personId] participated in.
  Future<List<Map<String, dynamic>>> getPersonSplitsHistory(String personId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        s.id AS split_id,
        s.title,
        s.total_amount,
        s.date,
        p.allocated_amount,
        p.is_settled,
        p.is_payer
      FROM split_participants p
      JOIN expense_splits s ON p.split_id = s.id
      WHERE p.person_id = ?
      ORDER BY s.date DESC
    ''', [personId]);
    return rows;
  }

  /// Updates person details (name, phone, notes).
  Future<void> updatePerson(KhataPersonModel person) async {
    final trimmedName = person.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Person name cannot be empty');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.update(
      'khata_people',
      {
        'name': trimmedName,
        'phone': person.phone?.trim().isEmpty == true ? null : person.phone?.trim(),
        'notes': person.notes?.trim().isEmpty == true ? null : person.notes?.trim(),
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  /// Archives or unarchives a person.
  Future<void> setArchived(String personId, bool isArchived) async {
    final db = await _dbHelper.database;
    await db.update(
      'khata_people',
      {
        'is_archived': isArchived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [personId],
    );
    await AppLogger.info(
      isArchived ? 'Archived Khata person' : 'Unarchived Khata person',
      category: LogCategory.database,
      details: 'id: $personId',
    );
  }

  /// Permanently deletes a person and cascades to all ledger entries.
  Future<void> deletePerson(String personId) async {
    final db = await _dbHelper.database;
    await db.delete('khata_people', where: 'id = ?', whereArgs: [personId]);
    await AppLogger.info(
      'Deleted Khata person',
      category: LogCategory.database,
      details: 'id: $personId',
    );
  }

  /// Fetches people with their computed net balance and latest entry date.
  Future<List<KhataPersonModel>> getPeople({
    bool includeArchived = false,
    String? searchQuery,
    String? filter, // 'all', 'receivable', 'payable', 'settled'
  }) async {
    final db = await _dbHelper.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeArchived) {
      conditions.add('p.is_archived = 0');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(p.name LIKE ? OR p.phone LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      args.addAll([term, term]);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final query = '''
      SELECT 
        p.*,
        COALESCE(SUM(e.amount * e.sign), 0.0) as net_balance,
        MAX(e.date) as last_entry_date
      FROM khata_people p
      LEFT JOIN khata_entries e ON p.id = e.person_id
      $whereClause
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE ASC
    ''';

    final rows = await db.rawQuery(query, args);
    var list = rows.map((r) => KhataPersonModel.fromMap(r)).toList();

    if (filter != null && filter != 'all') {
      if (filter == 'receivable') {
        list = list.where((p) => p.isReceivable).toList();
      } else if (filter == 'payable') {
        list = list.where((p) => p.isPayable).toList();
      } else if (filter == 'settled') {
        list = list.where((p) => p.isSettled).toList();
      }
    }

    return list;
  }

  /// Fetches a single person by ID with net balance.
  Future<KhataPersonModel?> getPersonById(String personId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        p.*,
        COALESCE(SUM(e.amount * e.sign), 0.0) as net_balance,
        MAX(e.date) as last_entry_date
      FROM khata_people p
      LEFT JOIN khata_entries e ON p.id = e.person_id
      WHERE p.id = ?
      GROUP BY p.id
    ''';
    final rows = await db.rawQuery(query, [personId]);
    if (rows.isEmpty) return null;
    return KhataPersonModel.fromMap(rows.first);
  }

  /// Fetches chronological ledger entries for a person with running balances.
  Future<List<KhataLedgerItem>> getLedgerEntries(
    String personId, {
    KhataEntryType? typeFilter,
  }) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT e.*, a.name as account_name
      FROM khata_entries e
      LEFT JOIN accounts a ON e.account_id = a.id
      WHERE e.person_id = ?
      ORDER BY e.date ASC, e.created_at ASC, e.id ASC
    ''';

    final rows = await db.rawQuery(query, [personId]);
    final entries = rows.map((r) => KhataEntryModel.fromMap(r)).toList();

    double running = 0.0;
    final allItems = <KhataLedgerItem>[];

    for (final e in entries) {
      running = ((running + e.signedEffect) * 100).round() / 100;
      allItems.add(KhataLedgerItem(entry: e, runningBalance: running));
    }

    if (typeFilter != null) {
      return allItems.where((item) => item.entry.type == typeFilter).toList();
    }

    // Return in reverse chronological order for display, but each item carries
    // its exact historical running balance.
    return allItems.reversed.toList();
  }

  /// Records a new Khata entry atomically.
  /// If [accountId] is provided, updates account balance and creates a balance adjustment record.
  Future<KhataEntryModel> addEntry({
    required String personId,
    required KhataEntryType type,
    required double amount,
    required DateTime date,
    int? signOverride,
    String? notes,
    DateTime? dueDate,
    String? accountId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    // Determine sign on the person's net balance:
    // +1: user is owed more / owes less
    // -1: user is owed less / owes more
    final int sign;
    if (signOverride != null) {
      sign = signOverride;
    } else {
      switch (type) {
        case KhataEntryType.lent:
          sign = 1;
          break;
        case KhataEntryType.repaymentReceived:
          sign = -1;
          break;
        case KhataEntryType.borrowed:
          sign = -1;
          break;
        case KhataEntryType.repaymentMade:
          sign = 1;
          break;
        case KhataEntryType.settlement:
          throw ArgumentError('Use settlePerson() for settlement entries');
      }
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final entryId = _uuid.v4();

    final entry = KhataEntryModel(
      id: entryId,
      personId: personId,
      type: type,
      amount: amount,
      sign: sign,
      date: date,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      dueDate: dueDate,
      accountId: accountId,
      isSettled: false,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. If linked to an account, adjust balance atomically
      if (accountId != null && accountId.isNotEmpty) {
        final accMap = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
        if (accMap.isEmpty) {
          throw StateError('Linked account not found');
        }

        final prevBalance = (accMap.first['current_balance'] as num).toDouble();
        
        // Signed impact on user's cash account:
        // lent: cash decreases (-amount)
        // repaymentReceived: cash increases (+amount)
        // borrowed: cash increases (+amount)
        // repaymentMade: cash decreases (-amount)
        // settlement: if sign == -1 (collected receivable), cash increases (+amount)
        //             if sign == 1 (paid payable), cash decreases (-amount)
        final double accountDelta;
        switch (type) {
          case KhataEntryType.lent:
          case KhataEntryType.repaymentMade:
            accountDelta = -amount;
            break;
          case KhataEntryType.borrowed:
          case KhataEntryType.repaymentReceived:
            accountDelta = amount;
            break;
          case KhataEntryType.settlement:
            accountDelta = sign == -1 ? amount : -amount;
            break;
        }

        final newBalance = ((prevBalance + accountDelta) * 100).round() / 100;

        final personRow = await txn.query('khata_people', where: 'id = ?', whereArgs: [personId]);
        final personName = personRow.isNotEmpty ? personRow.first['name'] as String : 'Khata';

        final adj = BalanceAdjustmentModel(
          id: _uuid.v4(),
          accountId: accountId,
          previousBalance: prevBalance,
          newBalance: newBalance,
          adjustmentAmount: accountDelta,
          reason: 'Khata: ${type.label} ($personName)',
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
      }

      // 2. Insert Khata entry
      await txn.insert('khata_entries', entry.toMap());

      // 3. Update person timestamp
      await txn.update(
        'khata_people',
        {'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [personId],
      );
    });

    await AppLogger.info(
      'Added Khata entry',
      category: LogCategory.transactions,
      details: 'type: ${type.toDbString()}, amount: $amount, person: $personId',
    );

    return entry;
  }

  /// Settles a person's balance (full or partial).
  Future<KhataEntryModel> settlePerson(
    String personId, {
    required double amount,
    DateTime? date,
    String? accountId,
    String? notes,
  }) async {
    final person = await getPersonById(personId);
    if (person == null) {
      throw StateError('Person not found');
    }

    if (person.isSettled) {
      throw StateError('Person balance is already settled');
    }

    if (amount <= 0) {
      throw ArgumentError('Settlement amount must be positive');
    }

    // If person owed user (isReceivable, balance > 0):
    // Settlement brings balance towards zero -> sign must be -1.
    // If user owed person (isPayable, balance < 0):
    // Settlement brings balance towards zero -> sign must be +1.
    final int sign = person.isReceivable ? -1 : 1;

    return addEntry(
      personId: personId,
      type: KhataEntryType.settlement,
      amount: amount,
      date: date ?? DateTime.now(),
      signOverride: sign,
      accountId: accountId,
      notes: notes ?? 'Settlement',
    );
  }

  /// Deletes a Khata entry and reverses any associated account balance adjustment atomically.
  Future<void> deleteEntry(String entryId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final entryRows = await txn.query('khata_entries', where: 'id = ?', whereArgs: [entryId]);
      if (entryRows.isEmpty) return;

      final entry = KhataEntryModel.fromMap(entryRows.first);

      if (entry.accountId != null) {
        final accMap = await txn.query('accounts', where: 'id = ?', whereArgs: [entry.accountId]);
        if (accMap.isNotEmpty) {
          final prevBalance = (accMap.first['current_balance'] as num).toDouble();

          // Determine original delta so we can invert it
          final double originalDelta;
          switch (entry.type) {
            case KhataEntryType.lent:
            case KhataEntryType.repaymentMade:
              originalDelta = -entry.amount;
              break;
            case KhataEntryType.borrowed:
            case KhataEntryType.repaymentReceived:
              originalDelta = entry.amount;
              break;
            case KhataEntryType.settlement:
              originalDelta = entry.sign == -1 ? entry.amount : -entry.amount;
              break;
          }

          final reverseDelta = -originalDelta;
          final newBalance = ((prevBalance + reverseDelta) * 100).round() / 100;

          final adj = BalanceAdjustmentModel(
            id: _uuid.v4(),
            accountId: entry.accountId!,
            previousBalance: prevBalance,
            newBalance: newBalance,
            adjustmentAmount: reverseDelta,
            reason: 'Reversal: Deleted Khata entry (${entry.type.label})',
            createdAt: DateTime.now(),
          );

          await txn.insert('balance_adjustments', adj.toMap());
          await txn.update(
            'accounts',
            {
              'current_balance': newBalance,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [entry.accountId],
          );
        }
      }

      await txn.delete('khata_entries', where: 'id = ?', whereArgs: [entryId]);
    });

    await AppLogger.info(
      'Deleted Khata entry',
      category: LogCategory.transactions,
      details: 'id: $entryId',
    );
  }

  /// Calculates total receivables, payables, and net balance.
  Future<KhataSummary> getSummary() async {
    final people = await getPeople(includeArchived: false);
    if (people.isEmpty) return KhataSummary.empty;

    double receivable = 0.0;
    double payable = 0.0;

    for (final p in people) {
      if (p.isReceivable) {
        receivable += p.netBalance;
      } else if (p.isPayable) {
        payable += p.netBalance.abs();
      }
    }

    receivable = (receivable * 100).round() / 100;
    payable = (payable * 100).round() / 100;
    final net = ((receivable - payable) * 100).round() / 100;

    return KhataSummary(
      totalReceivable: receivable,
      totalPayable: payable,
      netBalance: net,
      activePeopleCount: people.length,
    );
  }
}
