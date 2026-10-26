class DatabaseTables {
  static const String createAccountsTable = '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      current_balance REAL NOT NULL,
      initial_balance REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_primary INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  /// At most one account can have is_primary = 1 (enforced by the database,
  /// not just by app code).
  static const String createPrimaryAccountIndex =
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_single_primary '
      'ON accounts(is_primary) WHERE is_primary = 1;';

  static const String createCategoriesTable = '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      type TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );
  ''';

  static const String createCategoryRulesTable = '''
    CREATE TABLE category_rules (
      id TEXT PRIMARY KEY,
      keyword TEXT NOT NULL UNIQUE,
      category_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
    );
  ''';

  static const String createTagsTable = '''
    CREATE TABLE tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE
    );
  ''';

  static const String createTransactionsTable = '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      category_id TEXT,
      payment_method TEXT NOT NULL,
      account_id TEXT NOT NULL,
      destination_account_id TEXT,
      date INTEGER NOT NULL,
      note TEXT,
      latitude REAL,
      longitude REAL,
      location_name TEXT,
      source TEXT NOT NULL DEFAULT 'manual',
      status TEXT NOT NULL DEFAULT 'confirmed',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      recurring_payment_id TEXT,
      sms_message_id TEXT,
      external_reference TEXT,
      duplicate_status TEXT,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (destination_account_id) REFERENCES accounts(id),
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
  ''';

  static const String createTransactionTagsTable = '''
    CREATE TABLE transaction_tags (
      transaction_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      PRIMARY KEY (transaction_id, tag_id),
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    );
  ''';

  static const String createTransactionSplitsTable = '''
    CREATE TABLE transaction_splits (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      category_id TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
  ''';

  static const String createReceiptsTable = '''
    CREATE TABLE receipts (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      file_path TEXT NOT NULL,
      thumbnail_path TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
    );
  ''';

  static const String createBudgetsTable = '''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      category_id TEXT NOT NULL,
      period TEXT NOT NULL,
      amount REAL NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
  ''';

  static const String createRecurringPaymentsTable = '''
    CREATE TABLE recurring_payments (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      category_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      frequency TEXT NOT NULL,
      next_due_date INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      note TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id),
      FOREIGN KEY (account_id) REFERENCES accounts(id)
    );
  ''';

  static const String createSmsReviewQueueTable = '''
    CREATE TABLE sms_review_queue (
      id TEXT PRIMARY KEY,
      raw_sms TEXT NOT NULL,
      sender TEXT NOT NULL,
      amount REAL NOT NULL,
      direction TEXT NOT NULL,
      merchant TEXT,
      bank_name TEXT,
      account_ref TEXT,
      date INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'detected',
      reference_id TEXT,
      sms_message_id TEXT,
      latitude REAL,
      longitude REAL,
      location_name TEXT,
      created_at INTEGER NOT NULL
    );
  ''';

  static const String createBalanceAdjustmentsTable = '''
    CREATE TABLE balance_adjustments (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      previous_balance REAL NOT NULL,
      new_balance REAL NOT NULL,
      adjustment_amount REAL NOT NULL,
      reason TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id)
    );
  ''';

  // Local diagnostic log (Settings > Logs). `level` and `category` hold the
  // stable values of LogLevel / LogCategory. `category` has a default so rows
  // written without one (older code, tests) stay valid.
  static const String createAppLogsTable = '''
    CREATE TABLE IF NOT EXISTS app_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp INTEGER NOT NULL,
      level TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'app',
      message TEXT NOT NULL,
      details TEXT,
      error TEXT,
      stack_trace TEXT
    );
  ''';

  static const List<String> createAppLogIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_app_logs_time ON app_logs(timestamp DESC, id DESC);',
    'CREATE INDEX IF NOT EXISTS idx_app_logs_level ON app_logs(level, timestamp DESC);',
    'CREATE INDEX IF NOT EXISTS idx_app_logs_category ON app_logs(category, timestamp DESC);',
  ];

  static const String createFtsTable = '''
    CREATE VIRTUAL TABLE IF NOT EXISTS transactions_fts USING fts5(
      id UNINDEXED,
      description,
      note,
      payment_method,
      tokenize='unicode61'
    );
  ''';

  static const String createFtsTriggerInsert = '''
    CREATE TRIGGER IF NOT EXISTS tx_fts_ai AFTER INSERT ON transactions BEGIN
      INSERT INTO transactions_fts(id, description, note, payment_method)
      VALUES (
        new.id,
        new.description,
        coalesce(new.note, ''),
        new.payment_method
      );
    END;
  ''';

  static const String createFtsTriggerDelete = '''
    CREATE TRIGGER IF NOT EXISTS tx_fts_ad AFTER DELETE ON transactions BEGIN
      DELETE FROM transactions_fts WHERE id = old.id;
    END;
  ''';

  static const String createFtsTriggerUpdate = '''
    CREATE TRIGGER IF NOT EXISTS tx_fts_au AFTER UPDATE ON transactions BEGIN
      DELETE FROM transactions_fts WHERE id = old.id;
      INSERT INTO transactions_fts(id, description, note, payment_method)
      VALUES (
        new.id,
        new.description,
        coalesce(new.note, ''),
        new.payment_method
      );
    END;
  ''';

  static const String createKhataPeopleTable = '''
    CREATE TABLE IF NOT EXISTS khata_people (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT,
      notes TEXT,
      contact_id TEXT,
      lookup_key TEXT,
      source TEXT NOT NULL DEFAULT 'manual',
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  static const String createKhataEntriesTable = '''
    CREATE TABLE IF NOT EXISTS khata_entries (
      id TEXT PRIMARY KEY,
      person_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      sign INTEGER NOT NULL DEFAULT 1,
      date INTEGER NOT NULL,
      notes TEXT,
      due_date INTEGER,
      account_id TEXT,
      is_settled INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (person_id) REFERENCES khata_people(id) ON DELETE CASCADE,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL
    );
  ''';

  static const String createExpenseGroupsTable = '''
    CREATE TABLE IF NOT EXISTS expense_groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      icon TEXT,
      color TEXT,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  static const String createGroupMembersTable = '''
    CREATE TABLE IF NOT EXISTS group_members (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      person_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (group_id) REFERENCES expense_groups(id) ON DELETE CASCADE,
      FOREIGN KEY (person_id) REFERENCES khata_people(id) ON DELETE CASCADE,
      UNIQUE(group_id, person_id)
    );
  ''';

  static const String createExpenseSplitsTable = '''
    CREATE TABLE IF NOT EXISTS expense_splits (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      total_amount REAL NOT NULL,
      payer_type TEXT NOT NULL DEFAULT 'user',
      payer_person_id TEXT,
      group_id TEXT,
      split_mode TEXT NOT NULL,
      date INTEGER NOT NULL,
      transaction_id TEXT,
      notes TEXT,
      is_settled INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (group_id) REFERENCES expense_groups(id) ON DELETE SET NULL,
      FOREIGN KEY (payer_person_id) REFERENCES khata_people(id) ON DELETE SET NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
    );
  ''';

  static const String createSplitParticipantsTable = '''
    CREATE TABLE IF NOT EXISTS split_participants (
      id TEXT PRIMARY KEY,
      split_id TEXT NOT NULL,
      person_id TEXT,
      is_payer INTEGER NOT NULL DEFAULT 0,
      is_user INTEGER NOT NULL DEFAULT 0,
      person_name TEXT NOT NULL,
      person_phone TEXT,
      share_value REAL NOT NULL,
      allocated_amount REAL NOT NULL,
      is_settled INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (split_id) REFERENCES expense_splits(id) ON DELETE CASCADE,
      FOREIGN KEY (person_id) REFERENCES khata_people(id) ON DELETE SET NULL
    );
  ''';

  static const List<String> createKhataIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_khata_people_archived ON khata_people(is_archived, name);',
    'CREATE INDEX IF NOT EXISTS idx_khata_people_contact ON khata_people(contact_id);',
    'CREATE INDEX IF NOT EXISTS idx_khata_entries_person ON khata_entries(person_id, date DESC, id DESC);',
    'CREATE INDEX IF NOT EXISTS idx_khata_entries_account ON khata_entries(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_khata_entries_type ON khata_entries(type);',
  ];

  static const List<String> createExpenseGroupAndSplitIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);',
    'CREATE INDEX IF NOT EXISTS idx_group_members_person ON group_members(person_id);',
    'CREATE INDEX IF NOT EXISTS idx_expense_splits_group ON expense_splits(group_id);',
    'CREATE INDEX IF NOT EXISTS idx_expense_splits_date ON expense_splits(date DESC, id DESC);',
    'CREATE INDEX IF NOT EXISTS idx_expense_splits_tx ON expense_splits(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_split_participants_split ON split_participants(split_id);',
    'CREATE INDEX IF NOT EXISTS idx_split_participants_person ON split_participants(person_id);',
  ];

  static const List<String> createIndexes = [
    // Optimal Composite Index covering (deleted_at, date DESC, id DESC) for keyset pagination & queries
    'CREATE INDEX IF NOT EXISTS idx_tx_active_date_id ON transactions(deleted_at, date DESC, id DESC);',
    'CREATE INDEX IF NOT EXISTS idx_tx_date_del ON transactions(date DESC, deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_type_del ON transactions(type, deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id, deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id, deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_payment ON transactions(payment_method, deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_deleted ON transactions(deleted_at);',
    'CREATE INDEX IF NOT EXISTS idx_tx_sms ON transactions(sms_message_id);',
    'CREATE INDEX IF NOT EXISTS idx_tx_recurring ON transactions(recurring_payment_id);',
    'CREATE INDEX IF NOT EXISTS idx_sms_status ON sms_review_queue(status, date DESC);',
    'CREATE INDEX IF NOT EXISTS idx_cat_rules_kw ON category_rules(keyword);',
    'CREATE INDEX IF NOT EXISTS idx_receipts_tx ON receipts(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_tx_splits_tx ON transaction_splits(transaction_id);',
    createPrimaryAccountIndex,
    ...createAppLogIndexes,
    ...createKhataIndexes,
    ...createExpenseGroupAndSplitIndexes,
  ];
}
