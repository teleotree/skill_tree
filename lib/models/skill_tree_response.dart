import 'education_node.dart';
import 'skill_node.dart';
import 'experience_node.dart';
import 'goal_summary.dart';

class SkillTreeResponse {
  final String goal;
  final String description;
  final GoalSummary? summary;
  final List<EducationNode> education;
  final List<SkillNode> skills;
  final List<ExperienceNode> experience;

  SkillTreeResponse({
    required this.goal,
    required this.description,
    this.summary,
    required this.education,
    required this.skills,
    required this.experience,
  });

  factory SkillTreeResponse.fromJson(Map<String, dynamic> json) {
    return SkillTreeResponse(
      goal: json['goal'] ?? '',
      description: json['description'] ?? '',
      summary: json['summary'] != null ? GoalSummary.fromJson(json['summary']) : null,
      education: (json['education'] as List<dynamic>? ?? []).map((e) => EducationNode.fromJson(e)).toList(),
      skills: (json['skills'] as List<dynamic>? ?? []).map((e) => SkillNode.fromJson(e)).toList(),
      experience: (json['experience'] as List<dynamic>? ?? []).map((e) => ExperienceNode.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'description': description,
    if (summary != null) 'summary': summary!.toJson(),
    'education': education.map((e) => e.toJson()).toList(),
    'skills': skills.map((e) => e.toJson()).toList(),
    'experience': experience.map((e) => e.toJson()).toList(),
  };
}
