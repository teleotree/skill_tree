class ExperienceNode {
  final String title;
  final String description;
  final int yearsRequired;
  final List<String> breakdown;

  ExperienceNode({
    required this.title,
    required this.description,
    required this.yearsRequired,
    required this.breakdown,
  });

  factory ExperienceNode.fromJson(Map<String, dynamic> json) {
    final years = json['years_required'];
    return ExperienceNode(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      yearsRequired: years is int ? years : (years is double ? years.round() : 0),
      breakdown: (json['breakdown'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
