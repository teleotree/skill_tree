import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const String _plansKey = 'plans';

class PlanService {
  static Future<List<Plan>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final plans = <Plan>[];
    for (final e in list) {
      try {
        plans.add(Plan.fromJson(e));
      } catch (_) {}
    }
    return plans;
  }

  static Future<Plan?> getPlan(String id) async {
    final plans = await getPlans();
    try {
      return plans.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlan(Plan plan) async {
    final plans = await getPlans();
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.insert(0, plan);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plansKey, jsonEncode(plans.map((e) => e.toJson()).toList()));
  }

  static Future<void> deletePlan(String id) async {
    final plans = await getPlans();
    plans.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plansKey, jsonEncode(plans.map((e) => e.toJson()).toList()));
  }

  static Future<void> updatePlanItem(String planId, PlanItem updatedItem) async {
    final plan = await getPlan(planId);
    if (plan == null) return;
    final index = plan.items.indexWhere((i) => i.id == updatedItem.id);
    if (index >= 0) {
      plan.items[index] = updatedItem;
      await savePlan(plan);
    }
  }
}
