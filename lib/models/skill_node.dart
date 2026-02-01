import 'resource.dart';

class SkillNode {
  final String name;
  final int estimatedTimeHours;
  final List<Resource> resources;
  final List<SkillNode> subskills;
  final String description;
  final String tag;

  SkillNode({
    required this.name,
    required this.estimatedTimeHours,
    required this.resources,
    required this.subskills,
    required this.description,
    required this.tag,
  });

  factory SkillNode.fromJson(Map<String, dynamic> json) {
    return SkillNode(
      name: json['name'] ?? '',
      estimatedTimeHours: json['estimated_time_hours'] ?? 0,
      resources: (json['resources'] as List<dynamic>? ?? [])
          .map((e) => Resource.fromJson(e))
          .toList(),
      subskills: (json['subskills'] as List<dynamic>? ?? [])
          .map((e) => SkillNode.fromJson(e))
          .toList(),
      description: json['description'] ?? '',
      tag: json['tag'] ?? 'informal',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimated_time_hours': estimatedTimeHours,
    'resources': resources.map((e) => e.toJson()).toList(),
    'subskills': subskills.map((e) => e.toJson()).toList(),
    'description': description,
    'tag': tag,
  };
}
