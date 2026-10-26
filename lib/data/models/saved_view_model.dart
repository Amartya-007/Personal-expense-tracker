import '../../presentation/providers/transaction_providers.dart';

class SavedViewModel {
  final String id;
  final String name;
  final String icon;
  final TransactionFilter filter;
  final bool isPreset;
  final DateTime createdAt;

  SavedViewModel({
    required this.id,
    required this.name,
    this.icon = '🔍',
    required this.filter,
    this.isPreset = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'filter': filter.toMap(),
      'is_preset': isPreset ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavedViewModel.fromMap(Map<String, dynamic> map) {
    return SavedViewModel(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? '🔍',
      filter: TransactionFilter.fromMap(
        (map['filter'] as Map<dynamic, dynamic>).cast<String, dynamic>(),
      ),
      isPreset: (map['is_preset'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  SavedViewModel copyWith({
    String? name,
    String? icon,
    TransactionFilter? filter,
  }) {
    return SavedViewModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      filter: filter ?? this.filter,
      isPreset: isPreset,
      createdAt: createdAt,
    );
  }
}
