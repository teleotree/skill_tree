import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
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
  List<SearchHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

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
      await HistoryService.addEntry(skillTree);
      await _loadHistory();
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

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
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
            if (_history.isNotEmpty) ...[
              SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
            Expanded(
              child: _history.isEmpty
                  ? SizedBox.shrink()
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final entry = _history[index];
                        return Card(
                          child: ListTile(
                            title: Text(entry.goal),
                            subtitle: Text(_relativeTime(entry.timestamp)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                              onPressed: () async {
                                await HistoryService.deleteEntry(entry.id);
                                await _loadHistory();
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SkillTreeScreen(skillTree: entry.response),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
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
