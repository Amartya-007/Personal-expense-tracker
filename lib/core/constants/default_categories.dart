class DefaultCategorySeed {
  final String id;
  final String name;
  final String icon;
  final int color;
  final String type; // 'expense' or 'income'

  const DefaultCategorySeed({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class DefaultCategories {
  static const List<DefaultCategorySeed> list = [
    // Expense Categories
    DefaultCategorySeed(
      id: 'cat_food',
      name: 'Food & Dining',
      icon: 'restaurant',
      color: 0xFFEF4444, // Red
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_groceries',
      name: 'Groceries',
      icon: 'shopping_cart',
      color: 0xFFF97316, // Orange
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_transport',
      name: 'Transport',
      icon: 'directions_bus',
      color: 0xFFF59E0B, // Amber
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_shopping',
      name: 'Shopping',
      icon: 'shopping_bag',
      color: 0xFFEC4899, // Pink
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_bills',
      name: 'Bills & Utilities',
      icon: 'receipt_long',
      color: 0xFF3B82F6, // Blue
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_entertainment',
      name: 'Entertainment',
      icon: 'movie',
      color: 0xFF8B5CF6, // Purple
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_health',
      name: 'Health & Medical',
      icon: 'local_hospital',
      color: 0xFF10B981, // Emerald
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_stationery',
      name: 'Stationery & Education',
      icon: 'school',
      color: 0xFF06B6D4, // Cyan
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_electronics',
      name: 'Electronics',
      icon: 'devices',
      color: 0xFF6366F1, // Indigo
      type: 'expense',
    ),
    DefaultCategorySeed(
      id: 'cat_other_expense',
      name: 'Other Expense',
      icon: 'more_horiz',
      color: 0xFF64748B, // Slate
      type: 'expense',
    ),

    // Income Categories
    DefaultCategorySeed(
      id: 'cat_salary',
      name: 'Salary',
      icon: 'payments',
      color: 0xFF16A34A, // Green
      type: 'income',
    ),
    DefaultCategorySeed(
      id: 'cat_freelance',
      name: 'Freelance & Business',
      icon: 'work',
      color: 0xFF0D9488, // Teal
      type: 'income',
    ),
    DefaultCategorySeed(
      id: 'cat_investments',
      name: 'Returns / Cashback',
      icon: 'trending_up',
      color: 0xFF2563EB, // Blue
      type: 'income',
    ),
    DefaultCategorySeed(
      id: 'cat_other_income',
      name: 'Other Income',
      icon: 'account_balance_wallet',
      color: 0xFF059669, // Emerald
      type: 'income',
    ),
  ];
}
