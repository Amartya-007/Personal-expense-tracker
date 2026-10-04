class DatabaseTables {
  static const String createAccountsTable = '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      current_balance REAL NOT NULL,
      initial_balance REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

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

  static const String createAppLogsTable = '''
    CREATE TABLE app_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp INTEGER NOT NULL,
      level TEXT NOT NULL,
      message TEXT NOT NULL,
      details TEXT
    );
  ''';

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
  ];
}
