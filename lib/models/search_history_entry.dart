import 'skill_tree_response.dart';

class SearchHistoryEntry {
  final String id;
  final String goal;
  final DateTime timestamp;
  final SkillTreeResponse response;

  SearchHistoryEntry({
    required this.id,
    required this.goal,
    required this.timestamp,
    required this.response,
  });

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: json['id'] ?? '',
      goal: json['goal'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      response: SkillTreeResponse.fromJson(json['response']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'timestamp': timestamp.toIso8601String(),
    'response': response.toJson(),
  };
}
