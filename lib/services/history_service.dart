import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const String _historyKey = 'search_history';
const int _maxEntries = 50;

class HistoryService {
  static Future<List<SearchHistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SearchHistoryEntry.fromJson(e)).toList();
  }

  static Future<void> addEntry(SkillTreeResponse response) async {
    final history = await getHistory();
    final entry = SearchHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goal: response.goal,
      timestamp: DateTime.now(),
      response: response,
    );
    history.insert(0, entry);
    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> deleteEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}
