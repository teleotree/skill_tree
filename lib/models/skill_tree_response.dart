import 'education_node.dart';
import 'skill_node.dart';
import 'experience_node.dart';

class SkillTreeResponse {
  final String goal;
  final String description;
  final List<EducationNode> education;
  final List<SkillNode> skills;
  final List<ExperienceNode> experience;

  SkillTreeResponse({
    required this.goal,
    required this.description,
    required this.education,
    required this.skills,
    required this.experience,
  });

  factory SkillTreeResponse.fromJson(Map<String, dynamic> json) {
    return SkillTreeResponse(
      goal: json['goal'] ?? '',
      description: json['description'] ?? '',
      education: (json['education'] as List<dynamic>? ?? []).map((e) => EducationNode.fromJson(e)).toList(),
      skills: (json['skills'] as List<dynamic>? ?? []).map((e) => SkillNode.fromJson(e)).toList(),
      experience: (json['experience'] as List<dynamic>? ?? []).map((e) => ExperienceNode.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'description': description,
    'education': education.map((e) => e.toJson()).toList(),
    'skills': skills.map((e) => e.toJson()).toList(),
    'experience': experience.map((e) => e.toJson()).toList(),
  };
}
