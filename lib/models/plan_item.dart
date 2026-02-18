import 'resource.dart';

class PlanItem {
  final String id;
  final String type; // 'education', 'experience', 'skill'
  final String name;
  final String description;
  final Map<String, dynamic> fields;
  bool completed;
  List<Resource> resources;
  /// IDs of skill PlanItems that are learned as part of this item.
  /// When this item is marked complete, linked skills are also completed.
  List<String> linkedSkillIds;
  /// Priority for gap analysis results: 'high', 'medium', 'low', or null.
  String? priority;
  /// Whether this item is currently being actively worked on.
  bool isActive;

  PlanItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.fields,
    this.completed = false,
    this.resources = const [],
    this.linkedSkillIds = const [],
    this.priority,
    this.isActive = false,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'skill',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      fields: Map<String, dynamic>.from(json['fields'] ?? {}),
      completed: json['completed'] ?? false,
      resources: (json['resources'] as List<dynamic>? ?? [])
          .map((e) => Resource.fromJson(e))
          .toList(),
      linkedSkillIds: (json['linked_skill_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      priority: json['priority'],
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'description': description,
    'fields': fields,
    'completed': completed,
    'resources': resources.map((e) => e.toJson()).toList(),
    'linked_skill_ids': linkedSkillIds,
    if (priority != null) 'priority': priority,
    'is_active': isActive,
  };
}
