import 'plan_item.dart';

class Plan {
  final String id;
  final String goal;
  final DateTime createdAt;
  final List<PlanItem> items;
  final List<String> initiallyCompletedSkills;

  Plan({
    required this.id,
    required this.goal,
    required this.createdAt,
    required this.items,
    this.initiallyCompletedSkills = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] ?? '',
      goal: json['goal'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => PlanItem.fromJson(e))
          .toList(),
      initiallyCompletedSkills: (json['initially_completed_skills'] as List<dynamic>?)
          ?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'initially_completed_skills': initiallyCompletedSkills,
  };
}
