import 'resource.dart';
import 'education_option.dart';

class EducationNode {
  final String name;
  final String description;
  final List<Resource> links;
  final String prerequisites;
  final String type;
  final List<EducationOption> options;
  final int years;

  EducationNode({
    required this.name,
    required this.description,
    required this.links,
    required this.prerequisites,
    required this.type,
    this.options = const [],
    required this.years,
  });

  factory EducationNode.fromJson(Map<String, dynamic> json) {
    final years = json['years'];
    return EducationNode(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      links: (json['links'] as List<dynamic>? ?? []).map((e) => Resource.fromJson(e)).toList(),
      prerequisites: json['prerequisites'] ?? '',
      type: json['type'] ?? 'degree',
      options: (json['options'] as List<dynamic>? ?? []).map((e) => EducationOption.fromJson(e)).toList(),
      years: years is int ? years : (years is double ? years.round() : 0),
    );
  }
}
