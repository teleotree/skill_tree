import 'resource.dart';

class SkillNode {
  final String name;
  final List<Resource> resources;
  final List<SkillNode> subskills;
  final String description;
  final String tag;
  final String? educationName;

  SkillNode({
    required this.name,
    required this.resources,
    required this.subskills,
    required this.description,
    required this.tag,
    this.educationName,
  });

  factory SkillNode.fromJson(Map<String, dynamic> json) {
    return SkillNode(
      name: json['name'] ?? '',
      resources: (json['resources'] as List<dynamic>? ?? [])
          .map((e) => Resource.fromJson(e))
          .toList(),
      subskills: (json['subskills'] as List<dynamic>? ?? [])
          .map((e) => SkillNode.fromJson(e))
          .toList(),
      description: json['description'] ?? '',
      tag: json['tag'] ?? 'other',
      educationName: json['education_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'resources': resources.map((e) => e.toJson()).toList(),
    'subskills': subskills.map((e) => e.toJson()).toList(),
    'description': description,
    'tag': tag,
    if (educationName != null) 'education_name': educationName,
  };
}
