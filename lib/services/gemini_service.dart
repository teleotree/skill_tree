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
- "estimated_time_hours": estimated hours to learn
- "resources": a list of recommended resources (each with "title" and "url")
- "subskills": a list of subskills (with the same structure), ordered by learning sequence
- "tag": either "degree" (learned as part of a required degree), "certification" (learned as part of a required certification), or "informal" (learned outside formal education/certification)

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
      } else if (response.statusCode == 503) {
        debugPrint('Gemini API overloaded, attempt ${retryCount + 1} of $maxRetries');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount);
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
