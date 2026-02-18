import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _cachedSkillsKey = 'cached_career_skills';
const String _cachedCareerKey = 'cached_career_name';

class CareerCacheService {
  static Future<void> cacheCareerSkills(String careerName, List<String> skills) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedCareerKey, careerName);
    await prefs.setString(_cachedSkillsKey, jsonEncode(skills));
  }

  static Future<String?> getCachedCareerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cachedCareerKey);
  }

  static Future<List<String>> getCachedSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedSkillsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }
}
