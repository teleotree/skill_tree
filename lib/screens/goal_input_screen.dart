import 'package:flutter/material.dart';
import 'current_skills_screen.dart';

class GoalInputScreen extends StatefulWidget {
  final String? prefillGoal;

  const GoalInputScreen({Key? key, this.prefillGoal}) : super(key: key);

  @override
  State<GoalInputScreen> createState() => _GoalInputScreenState();
}

class _GoalInputScreenState extends State<GoalInputScreen> {
  late TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.prefillGoal ?? '');
  }

  void _next() {
    final goal = _controller.text.trim();
    if (goal.length < 3) {
      setState(() => _validationError = 'Goal must be at least 3 characters.');
      return;
    }
    if (goal.length > 200) {
      setState(() => _validationError = 'Goal must be 200 characters or fewer.');
      return;
    }
    setState(() => _validationError = null);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CurrentSkillsScreen(goal: goal)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Goal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What career or skill do you want to achieve?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Target career/goal',
                hintText: 'e.g. Data Scientist, UX Designer',
                border: const OutlineInputBorder(),
                errorText: _validationError,
              ),
              onSubmitted: (_) => _next(),
              onChanged: (_) {
                if (_validationError != null) setState(() => _validationError = null);
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _next,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
