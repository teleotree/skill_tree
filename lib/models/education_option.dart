import 'resource.dart';

class EducationOption {
  final String name;
  final String description;
  final List<Resource> links;
  final String prerequisites;
  final int years;

  EducationOption({
    required this.name,
    required this.description,
    required this.links,
    required this.prerequisites,
    required this.years,
  });

  factory EducationOption.fromJson(Map<String, dynamic> json) {
    final years = json['years'];
    return EducationOption(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      links: (json['links'] as List<dynamic>? ?? []).map((e) =>
        e is String ? Resource(title: e, url: e) : Resource.fromJson(e as Map<String, dynamic>)
      ).toList(),
      prerequisites: json['prerequisites'] ?? '',
      years: years is int ? years : (years is double ? years.round() : 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'links': links.map((e) => e.toJson()).toList(),
    'prerequisites': prerequisites,
    'years': years,
  };
}
