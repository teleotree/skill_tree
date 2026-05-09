import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'device_service.dart';

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

/// Rate limit exception with retry information.
class GeminiRateLimitException implements Exception {
  final String message;
  final int? retryAfterSeconds;
  GeminiRateLimitException(this.message, {this.retryAfterSeconds});
  @override
  String toString() => 'GeminiRateLimitException: $message';
}

/// Backend API base URL - change this after deploying your Cloudflare Worker.
/// Format: https://skill-tree-api.YOUR_SUBDOMAIN.workers.dev
const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://skill-tree-api.YOUR_SUBDOMAIN.workers.dev',
);

Future<Map<String, String>> _getHeaders() async {
  final deviceId = await DeviceService.getDeviceId();
  return {
    'Content-Type': 'application/json',
    'X-Device-ID': deviceId,
  };
}

Future<dynamic> _makeApiCall(String endpoint, Map<String, dynamic> body) async {
  final url = Uri.parse('$_apiBaseUrl$endpoint');
  final headers = await _getHeaders();

  const maxRetries = 3;
  int retryCount = 0;
  const retryDelay = Duration(seconds: 2);

  while (retryCount < maxRetries) {
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 429) {
        // Rate limited
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        String message = 'Rate limit exceeded.';
        try {
          final errorBody = jsonDecode(response.body);
          message = errorBody['error'] ?? message;
        } catch (_) {}
        throw GeminiRateLimitException(message, retryAfterSeconds: retryAfter);
      } else if (response.statusCode == 503 || response.statusCode == 502) {
        debugPrint('API service error ${response.statusCode}, attempt ${retryCount + 1} of $maxRetries');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount);
          continue;
        }
        throw GeminiApiException(response.statusCode, response.body);
      } else {
        debugPrint('API error: ${response.statusCode} ${response.body}');
        throw GeminiApiException(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is GeminiRateLimitException || e is GeminiApiException) rethrow;
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

Future<SkillTreeResponse> fetchSkillTreeFromGemini(String goal) async {
  try {
    final jsonData = await _makeApiCall('/api/skill-tree', {'goal': goal});
    return SkillTreeResponse.fromJson(jsonData);
  } catch (e) {
    if (e is GeminiNetworkException ||
        e is GeminiApiException ||
        e is GeminiRateLimitException) {
      rethrow;
    }
    debugPrint('Failed to parse skill tree response: $e');
    throw GeminiParseException('Failed to parse response: $e');
  }
}

Future<Plan> fetchGapAnalysis(String goal, String currentSkills, List<SkillProposal> checkedSkills) async {
  try {
    final jsonData = await _makeApiCall('/api/gap-analysis', {
      'goal': goal,
      'currentSkills': currentSkills,
      'checkedSkills': checkedSkills.map((s) => {'name': s.name}).toList(),
    });

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
    if (e is GeminiNetworkException ||
        e is GeminiApiException ||
        e is GeminiRateLimitException) {
      rethrow;
    }
    debugPrint('Failed to parse gap analysis response: $e');
    throw GeminiParseException('Failed to parse response: $e');
  }
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

Future<List<SkillProposal>> fetchSkillProposal(String goal, String currentSkillsText) async {
  try {
    final jsonData = await _makeApiCall('/api/skill-proposal', {
      'goal': goal,
      'currentSkillsText': currentSkillsText,
    });
    return (jsonData as List<dynamic>).map((e) => SkillProposal.fromJson(e)).toList();
  } catch (e) {
    if (e is GeminiNetworkException ||
        e is GeminiApiException ||
        e is GeminiRateLimitException) {
      rethrow;
    }
    debugPrint('Failed to parse skill proposal response: $e');
    throw GeminiParseException('Failed to parse response: $e');
  }
}

Future<List<Resource>> fetchEducationResources(PlanItem item) async {
  try {
    final jsonData = await _makeApiCall('/api/education-resources', {
      'item': {
        'name': item.name,
        'type': item.type,
        'description': item.description,
        'fields': item.fields,
      },
    });
    return (jsonData as List<dynamic>).map((e) => Resource.fromJson(e)).toList();
  } catch (e) {
    if (e is GeminiNetworkException ||
        e is GeminiApiException ||
        e is GeminiRateLimitException) {
      rethrow;
    }
    debugPrint('Failed to parse education resources response: $e');
    throw GeminiParseException('Failed to parse response: $e');
  }
}
