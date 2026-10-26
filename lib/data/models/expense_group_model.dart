import 'khata_person_model.dart';

class ExpenseGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final bool isArchived;
  final int memberCount;
  final List<KhataPersonModel> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.isArchived = false,
    this.memberCount = 0,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ExpenseGroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    bool? isArchived,
    int? memberCount,
    List<KhataPersonModel>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ExpenseGroupModel.fromMap(
    Map<String, dynamic> map, {
    int memberCount = 0,
    List<KhataPersonModel> members = const [],
  }) {
    return ExpenseGroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      isArchived: (map['is_archived'] as int?) == 1,
      memberCount: (map['member_count'] as num?)?.toInt() ?? memberCount,
      members: members,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
