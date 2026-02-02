import 'plan_item.dart';

class Plan {
  final String id;
  final String goal;
  final DateTime createdAt;
  final List<PlanItem> items;

  Plan({
    required this.id,
    required this.goal,
    required this.createdAt,
    required this.items,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] ?? '',
      goal: json['goal'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => PlanItem.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };
}
