import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'skill_tree_screen.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToSkillTree() async {
    final goal = _controller.text.trim();

    if (goal.length < 3) {
      setState(() {
        _validationError = 'Goal must be at least 3 characters.';
      });
      return;
    }
    if (goal.length > 200) {
      setState(() {
        _validationError = 'Goal must be 200 characters or fewer.';
      });
      return;
    }
    setState(() {
      _validationError = null;
    });

    if (_geminiApiKey.isEmpty) {
      setState(() {
        _error = 'GEMINI_API_KEY not set. Run with --dart-define=GEMINI_API_KEY=<key>';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final skillTree = await fetchSkillTreeFromGemini(goal, _geminiApiKey);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkillTreeScreen(skillTree: skillTree),
        ),
      );
    } on GeminiNetworkException {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please check your connection and try again.';
      });
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'API error (${e.statusCode}). Please try again later.';
      });
    } on GeminiParseException {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to parse response. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Your Goal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'What is your goal?',
                border: OutlineInputBorder(),
                errorText: _validationError,
              ),
              onSubmitted: (_) => _goToSkillTree(),
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() {
                    _validationError = null;
                  });
                }
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _goToSkillTree,
              child: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Show Skill Tree'),
            ),
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ],
            Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Your goals are sent to Google\'s Gemini API for processing.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
