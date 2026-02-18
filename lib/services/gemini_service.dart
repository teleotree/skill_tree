import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Typed exceptions for UI-specific error handling.
class GeminiNetworkException implements Exception {
  final String message;
  GeminiNetworkException(this.message);
  @override
  String toString() => 'GeminiNetworkException: $message';
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;
  GeminiApiException(this.statusCode, this.body);
  @override
  String toString() => 'GeminiApiException: HTTP $statusCode';
}

class GeminiParseException implements Exception {
  final String message;
  GeminiParseException(this.message);
  @override
  String toString() => 'GeminiParseException: $message';
}

Future<SkillTreeResponse> fetchSkillTreeFromGemini(String goal, String apiKey) async {
  final prompt = '''
You are an expert career advisor and curriculum designer. I will give you a job or skill that someone wants to learn.

For the given job or skill, return a hierarchical, ordered list of skills required to attain it. Each skill should include:
- "name": the skill name
- "description": a one-sentence summary of what the skill is and why it matters
- "resources": a list of recommended resources (each with "title" and "url")
- "subskills": a list of subskills (with the same structure), ordered by learning sequence
- "tag": either "degree" (learned as part of a required degree), "certification" (learned as part of a required certification), "experience" (learned primarily through work experience), or "other" (learned outside formal education/certification/experience)
- "education_name": if the tag is "degree" or "certification", the exact name of the education/certification entry from the education list where this skill is learned. Must match one of the education names exactly. Omit if tag is "experience" or "other".

In addition to skills and experience, also return an "education" field: a list of traditional education and certification requirements for the goal.

**For each required degree (Bachelor's, Master's, Doctorate, etc.), include a separate entry in the education list, in the order they must be obtained. Do not only mention prerequisites in the description—list each as its own education requirement. Assume high school is already completed and does not need to be listed.**

**For every certification referenced in the skills (tagged as "certification"), ensure it is also listed as a top-level entry in the education array.**

Each education/certification should include:
- "name": the name of the degree or certification
- "description": a one-sentence summary of what it is and why it matters
- "years": the typical number of years required to complete this degree or certification
- "links": a list of authoritative websites to learn more
- "prerequisites": a brief note on any significant prerequisites (e.g., "Bachelor's required before Master's")
- "type": either "degree" or "certification"
- "options": a list of alternative options, each with:
  - "name": the name of the alternative option
  - "description": a one-sentence summary of what it is and why it matters
  - "years": the typical number of years required to complete this option
  - "links": a list of authoritative websites to learn more
  - "prerequisites": any specific prerequisites for this option

Also return an "experience" field: a list of experience areas required to attain the goal. Each experience area should include:
- "title": the name of the experience area
- "description": a one-sentence summary of the experience and why it matters
- "years_required": the typical number of years required in this area
- "breakdown": a list of bullet points describing specific experiences or milestones within that area

Return your response as a JSON object with this structure:
{
  "goal": "<the original goal>",
  "description": "<one-sentence summary of the goal>",
  "education": [ ... ],
  "experience": [ ... ],
  "skills": [ ... ]
}

Only return valid JSON. Do not include any explanations or extra text.
''';

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final requestBody = jsonEncode({
    "contents": [
      {"parts": [
        {"text": "$prompt\n\nGoal: $goal"}
      ]}
    ]
  });

  const maxRetries = 3;
  int retryCount = 0;
  const retryDelay = Duration(seconds: 2);

  while (retryCount < maxRetries) {
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          try {
            String cleaned = text.trim();
            if (cleaned.startsWith('```')) {
              cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
              if (cleaned.endsWith('```')) {
                cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
              }
            }
            final jsonData = jsonDecode(cleaned);
            return SkillTreeResponse.fromJson(jsonData);
          } catch (e) {
            debugPrint('Failed to parse JSON from Gemini: $e');
            throw GeminiParseException('Failed to parse response: $e');
          }
        }
        throw GeminiParseException('No text in Gemini response');
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        debugPrint('Gemini API ${response.statusCode == 429 ? "rate limited" : "overloaded"}, attempt ${retryCount + 1} of $maxRetries');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount * (response.statusCode == 429 ? 2 : 1));
          continue;
        }
        throw GeminiApiException(response.statusCode, response.body);
      } else {
        debugPrint('Gemini API error: ${response.statusCode} ${response.body}');
        throw GeminiApiException(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is GeminiParseException || e is GeminiApiException) rethrow;
      debugPrint('Network error: $e');
      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay * retryCount);
        continue;
      }
      throw GeminiNetworkException('$e');
    }
  }

  throw GeminiNetworkException('All retries exhausted');
}

Future<Plan> fetchGapAnalysis(String goal, String currentSkills, List<SkillProposal> checkedSkills, String apiKey) async {
  final checkedSection = checkedSkills.isNotEmpty
      ? '\nSkills the user already has (from career exploration):\n${checkedSkills.map((s) => '- ${s.name}').join('\n')}'
      : '';

  final prompt = '''
You are an expert career advisor. A user wants to achieve a career goal and has described their current skills. Perform a gap analysis and return a prioritized action plan.

Target career/goal: $goal

User's self-described current skills and experience:
$currentSkills
$checkedSection

Based on the gap between where they are and where they need to be, return a JSON object with this structure:
{
  "goal": "<the target goal>",
  "items": [
    {
      "type": "education" | "experience" | "skill",
      "name": "<action item name>",
      "description": "<what they need to do and why>",
      "priority": "high" | "medium" | "low",
      "fields": {
        "tag": "degree" | "certification" | "experience" | "other"
      }
    }
  ]
}

Order items by recommended sequence (what to do first). Include 5-15 items covering the most important gaps. Each item should be actionable.

Only return valid JSON. Do not include any explanations or extra text.
''';

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final requestBody = jsonEncode({
    "contents": [
      {"parts": [
        {"text": prompt}
      ]}
    ]
  });

  const maxRetries = 3;
  int retryCount = 0;
  const retryDelay = Duration(seconds: 2);

  while (retryCount < maxRetries) {
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          try {
            String cleaned = text.trim();
            if (cleaned.startsWith('```')) {
              cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
              if (cleaned.endsWith('```')) {
                cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
              }
            }
            final jsonData = jsonDecode(cleaned);

            // Create completed PlanItems from skills user already has
            final completedItems = checkedSkills.asMap().entries.map((entry) {
              final skill = entry.value;
              return PlanItem(
                id: 'initial-${entry.key}',
                type: 'skill',
                name: skill.name,
                description: skill.description.isNotEmpty ? skill.description : 'Skill you already have',
                fields: {'tag': 'other', 'level': skill.level},
                completed: true,
              );
            }).toList();

            // Create pending PlanItems from gap analysis
            final pendingItems = (jsonData['items'] as List<dynamic>).asMap().entries.map((entry) {
              final e = entry.value;
              return PlanItem(
                id: 'gap-${entry.key}',
                type: e['type'] ?? 'skill',
                name: e['name'] ?? '',
                description: e['description'] ?? '',
                fields: Map<String, dynamic>.from(e['fields'] ?? {}),
                priority: e['priority'],
              );
            }).toList();

            return Plan(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              goal: jsonData['goal'] ?? goal,
              createdAt: DateTime.now(),
              items: [...completedItems, ...pendingItems],
              initiallyCompletedSkills: checkedSkills.map((s) => s.name).toList(),
            );
          } catch (e) {
            debugPrint('Failed to parse JSON from Gemini: $e');
            throw GeminiParseException('Failed to parse response: $e');
          }
        }
        throw GeminiParseException('No text in Gemini response');
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount * (response.statusCode == 429 ? 2 : 1));
          continue;
        }
        throw GeminiApiException(response.statusCode, response.body);
      } else {
        throw GeminiApiException(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is GeminiParseException || e is GeminiApiException) rethrow;
      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay * retryCount);
        continue;
      }
      throw GeminiNetworkException('$e');
    }
  }

  throw GeminiNetworkException('All retries exhausted');
}

class SkillProposal {
  final String name;
  final String category;
  final int level; // 1=beginner, 2=intermediate, 3=advanced
  final String description;
  final bool proposedCompleted;

  SkillProposal({
    required this.name,
    required this.category,
    required this.level,
    required this.description,
    required this.proposedCompleted,
  });

  factory SkillProposal.fromJson(Map<String, dynamic> json) {
    return SkillProposal(
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      level: json['level'] ?? 1,
      description: json['description'] ?? '',
      proposedCompleted: json['completed'] ?? false,
    );
  }
}

Future<List<SkillProposal>> fetchSkillProposal(String goal, String currentSkillsText, String apiKey) async {
  final prompt = '''
You are an expert career advisor. A user wants to achieve a career goal and has described their background. Based on their description, propose a list of skills needed for the goal and indicate which ones they likely already have.

Target career/goal: $goal

User's self-described background:
$currentSkillsText

Return a JSON array of skills with this structure:
[
  {
    "name": "<skill name>",
    "description": "<one sentence explaining what this skill is and why it matters for the goal>",
    "category": "<category like 'Programming', 'Communication', 'Domain Knowledge', 'Tools', etc.>",
    "level": <1 for beginner/foundational, 2 for intermediate, 3 for advanced/specialized>,
    "completed": <true if the user likely already has this skill based on their description, false otherwise>
  }
]

Include 10-20 skills covering the main requirements for the goal. Order skills within each category from beginner (level 1) to advanced (level 3). Be generous in marking skills as completed if the user's description suggests relevant experience.

Only return valid JSON. Do not include any explanations or extra text.
''';

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final requestBody = jsonEncode({
    "contents": [
      {"parts": [
        {"text": prompt}
      ]}
    ]
  });

  const maxRetries = 3;
  int retryCount = 0;
  const retryDelay = Duration(seconds: 2);

  while (retryCount < maxRetries) {
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          try {
            String cleaned = text.trim();
            if (cleaned.startsWith('```')) {
              cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
              if (cleaned.endsWith('```')) {
                cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
              }
            }
            final jsonData = jsonDecode(cleaned) as List<dynamic>;
            return jsonData.map((e) => SkillProposal.fromJson(e)).toList();
          } catch (e) {
            debugPrint('Failed to parse JSON from Gemini: $e');
            throw GeminiParseException('Failed to parse response: $e');
          }
        }
        throw GeminiParseException('No text in Gemini response');
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount * (response.statusCode == 429 ? 2 : 1));
          continue;
        }
        throw GeminiApiException(response.statusCode, response.body);
      } else {
        throw GeminiApiException(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is GeminiParseException || e is GeminiApiException) rethrow;
      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay * retryCount);
        continue;
      }
      throw GeminiNetworkException('$e');
    }
  }

  throw GeminiNetworkException('All retries exhausted');
}

Future<List<Resource>> fetchEducationResources(PlanItem item, String apiKey) async {
  final prompt = '''
You are an expert career advisor. Given the following plan item, recommend learning resources.

Item name: ${item.name}
Item type: ${item.type}
Item description: ${item.description}
Additional fields: ${item.fields}

Return a JSON array of resources, each with:
- "title": the resource name
- "url": a valid URL to the resource
- "description": a one-sentence description of what the resource offers

Only return valid JSON. Do not include any explanations or extra text.
''';

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final requestBody = jsonEncode({
    "contents": [
      {"parts": [
        {"text": prompt}
      ]}
    ]
  });

  const maxRetries = 3;
  int retryCount = 0;
  const retryDelay = Duration(seconds: 2);

  while (retryCount < maxRetries) {
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          try {
            String cleaned = text.trim();
            if (cleaned.startsWith('```')) {
              cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
              if (cleaned.endsWith('```')) {
                cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
              }
            }
            final jsonData = jsonDecode(cleaned) as List<dynamic>;
            return jsonData.map((e) => Resource.fromJson(e)).toList();
          } catch (e) {
            debugPrint('Failed to parse JSON from Gemini: $e');
            throw GeminiParseException('Failed to parse response: $e');
          }
        }
        throw GeminiParseException('No text in Gemini response');
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount * (response.statusCode == 429 ? 2 : 1));
          continue;
        }
        throw GeminiApiException(response.statusCode, response.body);
      } else {
        throw GeminiApiException(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is GeminiParseException || e is GeminiApiException) rethrow;
      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay * retryCount);
        continue;
      }
      throw GeminiNetworkException('$e');
    }
  }

  throw GeminiNetworkException('All retries exhausted');
}
