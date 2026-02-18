import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/plan_service.dart';
import '../widgets/section_header.dart';
import 'goal_input_screen.dart';
import 'plan_screen.dart';

class NextStepScreen extends StatefulWidget {
  @override
  State<NextStepScreen> createState() => _NextStepScreenState();
}

class _NextStepScreenState extends State<NextStepScreen> {
  List<Plan> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await PlanService.getPlans();
    if (mounted) setState(() => _plans = plans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Next Step')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New Gap Analysis'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GoalInputScreen()),
                  );
                  _loadPlans();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'My Plans'),
              ..._plans.map((plan) {
                final completed = plan.items.where((i) => i.completed).length;
                final total = plan.items.length;
                return Card(
                  child: ListTile(
                    title: Text(plan.goal),
                    subtitle: Text('$completed/$total completed'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                      onPressed: () async {
                        await PlanService.deletePlan(plan.id);
                        await _loadPlans();
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PlanScreen(planId: plan.id)),
                      );
                      _loadPlans();
                    },
                  ),
                );
              }),
            ],
            if (_plans.isEmpty) ...[
              const SizedBox(height: 48),
              Center(
                child: Text(
                  'No plans yet. Start a gap analysis to create your first action plan.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
