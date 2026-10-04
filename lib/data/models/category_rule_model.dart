class CategoryRuleModel {
  final String id;
  final String keyword;
  final String categoryId;
  final DateTime createdAt;

  CategoryRuleModel({
    required this.id,
    required this.keyword,
    required this.categoryId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keyword': keyword,
      'category_id': categoryId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CategoryRuleModel.fromMap(Map<String, dynamic> map) {
    return CategoryRuleModel(
      id: map['id'] as String,
      keyword: map['keyword'] as String,
      categoryId: map['category_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
