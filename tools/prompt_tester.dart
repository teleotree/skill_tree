import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _logFile = 'tools/prompt_log.json';

Future<void> main(List<String> args) async {
  if (args.contains('--list')) {
    await _listEntries();
    return;
  }

  String? goal;
  String? label;
  String? apiKey;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--goal' && i + 1 < args.length) {
      goal = args[++i];
    } else if (args[i] == '--label' && i + 1 < args.length) {
      label = args[++i];
    } else if (args[i] == '--api-key' && i + 1 < args.length) {
      apiKey = args[++i];
    }
  }

  if (goal == null || apiKey == null) {
    print('Usage: dart run tools/prompt_tester.dart --goal "CEO" --label "Initial Query" --api-key <key>');
    print('       dart run tools/prompt_tester.dart --list');
    exit(1);
  }

  label ??= 'Initial Query';

  print('Running prompt test: goal="$goal", label="$label"');

  final prompt = '''
You are an expert career advisor and curriculum designer. I will give you a job or skill that someone wants to learn.

Return a comprehensive overview with the following sections:

## 1. Summary
Provide a detailed "summary" object with these fields (each should be 2-4 sentences):
- "narrative": What do people who achieve this goal actually do? Describe the role/skill in practice.
- "core_competencies": What are the most important aspects and responsibilities of this role/skill?
- "considerations": What should someone think about when deciding whether to pursue this?
- "market_outlook": How competitive is the field? What's the job market and growth outlook?
- "compensation": What are typical salary ranges and earning potential at different levels?
- "challenges": What are the main difficulties, obstacles, and downsides?
- "benefits": What are the rewards, advantages, and fulfilling aspects?
- "career_path": What's the typical progression? Where do people come from and where do they go?
- "day_in_life": What does a typical day or week look like? Give concrete examples of activities.
- "industries": Which industry sectors and company types commonly need this role/skill?
- "work_style": What's the remote work potential, collaboration level, autonomy, and work-life balance?
- "barrier_to_entry": How hard is it to break in? What's the typical ramp-up time for newcomers?

## 2. Education
Return an "education" field: a list of education and certification requirements.

Each education/certification should include:
- "name": the name of the degree or certification
- "description": a one-sentence summary of what it is and why it matters
- "years": the typical number of years required
- "links": a list of authoritative websites to learn more
- "prerequisites": a brief note on any significant prerequisites
- "type": either "degree" or "certification"
- "options": a list of alternative options, each with name, description, years, links, prerequisites

## 3. Experience
Return an "experience" field: a list of experience areas required. Each should include:
- "title": the name of the experience area
- "description": a one-sentence summary of the experience and why it matters
- "years_required": the typical number of years required in this area
- "breakdown": a list of bullet points describing specific experiences or milestones

## 4. Skills
Return a "skills" field: a hierarchical, ordered list of skills required. Each skill should include:
- "name": the skill name
- "description": a one-sentence summary of what the skill is and why it matters
- "resources": a list of recommended resources (each with "title" and "url")
- "subskills": a list of subskills (with the same structure), ordered by learning sequence
- "tag": either "degree", "certification", "experience", or "other"
- "education_name": if tag is "degree" or "certification", the exact name from the education list. Omit otherwise.

Return your response as a JSON object with this structure:
{
  "goal": "<the original goal>",
  "description": "<one-sentence summary of the goal>",
  "summary": {
    "narrative": "...",
    "core_competencies": "...",
    "considerations": "...",
    "market_outlook": "...",
    "compensation": "...",
    "challenges": "...",
    "benefits": "...",
    "career_path": "...",
    "day_in_life": "...",
    "industries": "...",
    "work_style": "...",
    "barrier_to_entry": "..."
  },
  "education": [ ... ],
  "experience": [ ... ],
  "skills": [ ... ]
}

Only return valid JSON. Do not include any explanations or extra text.
''';

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final requestBody = {
    "contents": [
      {"parts": [
        {"text": "$prompt\n\nGoal: $goal"}
      ]}
    ],
    "generationConfig": {
      "maxOutputTokens": 65536,
    }
  };

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestBody),
    );

    final responseData = jsonDecode(response.body);

    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'label': label,
      'goal': goal,
      'status_code': response.statusCode,
      'request_payload': requestBody,
      'response': responseData,
    };

    await _appendLog(logEntry);

    if (response.statusCode == 200) {
      final text = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) {
        print('Success! Response length: ${text.length} chars');
        // Try to parse to validate
        String cleaned = text.trim();
        if (cleaned.startsWith('```')) {
          cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
          if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
          }
        }
        final parsed = jsonDecode(cleaned);
        final skills = (parsed['skills'] as List?)?.length ?? 0;
        final education = (parsed['education'] as List?)?.length ?? 0;
        final experience = (parsed['experience'] as List?)?.length ?? 0;
        final hasSummary = parsed['summary'] != null;
        final summaryFields = hasSummary ? (parsed['summary'] as Map).keys.length : 0;
        print('Parsed: $skills skills, $education education, $experience experience, summary: $summaryFields fields');
      }
    } else {
      print('Error: HTTP ${response.statusCode}');
    }

    print('Log entry written to $_logFile');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> _appendLog(Map<String, dynamic> entry) async {
  final file = File(_logFile);
  List<dynamic> log = [];
  if (await file.exists()) {
    try {
      log = jsonDecode(await file.readAsString()) as List<dynamic>;
    } catch (_) {
      log = [];
    }
  }
  log.add(entry);
  await file.writeAsString(JsonEncoder.withIndent('  ').convert(log));
}

Future<void> _listEntries() async {
  final file = File(_logFile);
  if (!await file.exists()) {
    print('No log file found at $_logFile');
    return;
  }
  try {
    final log = jsonDecode(await file.readAsString()) as List<dynamic>;
    print('${log.length} log entries:');
    for (final entry in log) {
      final ts = entry['timestamp'] ?? '?';
      final label = entry['label'] ?? '?';
      final goal = entry['goal'] ?? '?';
      final status = entry['status_code'] ?? '?';
      print('  [$ts] $label - goal: "$goal" - status: $status');
    }
  } catch (e) {
    print('Error reading log: $e');
  }
}
