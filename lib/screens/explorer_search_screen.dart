import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../services/career_cache_service.dart';
import '../widgets/section_header.dart';
import 'career_overview_screen.dart';
import 'current_skills_screen.dart';

const List<String> _loadingMessages = [
  'Consulting the gurus...',
  'Dusting off encyclopedias...',
  'Searching the multiverse...',
  'Calculating psychohistory...',
  'Using a web browser like a caveman...',
  'LMGTFY...',
  'Asking the elder scrolls...',
  'Interrogating the hive mind...',
  'Summoning the oracle...',
  'Checking under the couch cushions...',
  'Consulting the ancient texts...',
  'Asking a friend of a friend...',
  'Rifling through the Library of Alexandria...',
  'Paging through the Akashic Records...',
  'Sending carrier pigeons...',
  'Shaking the Magic 8-Ball...',
  'Consulting the bones...',
  'Reading tea leaves...',
  'Phoning a friend...',
  'Asking Jeeves...',
  'Warming up the crystal ball...',
  'Checking the star charts...',
  'Polling the audience...',
  'Rummaging through the archives...',
  'Decoding the Rosetta Stone...',
  'Untangling the world wide web...',
  'Consulting the Dead Sea Scrolls...',
  'Asking the rubber duck...',
  'Reversing the polarity...',
  'Tuning the flux capacitor...',
  'Downloading more RAM...',
  'Enhancing... enhancing... enhancing...',
  'Deploying trained monkeys...',
  'Consulting Stack Overflow...',
  'Waiting for someone to answer on Quora...',
  'Checking Wikipedia citations...',
  'Triangulating with satellites...',
  'Bribing the search index...',
  'Feeding the hamsters that power the servers...',
  'Adjusting the tin foil antenna...',
  'Querying the Hitchhiker\'s Guide...',
  'Asking the deep thought computer...',
  'Negotiating with the database...',
  'Waking up the interns...',
  'Cross-referencing with the Voynich Manuscript...',
  'Consulting a ouija board...',
  'Unrolling the scrolls of wisdom...',
  'Pinging the mothership...',
  'Checking the back of the napkin...',
  'Sacrificing CPU cycles to the demo gods...',
  'Asking my mom...',
  'Recalibrating the quantum thrusters...',
  'Arguing with the algorithm...',
  'Reticulating splines...',
  'Compiling the meaning of life...',
  'Turning it off and on again...',
];

class ExplorerSearchScreen extends StatefulWidget {
  @override
  State<ExplorerSearchScreen> createState() => _ExplorerSearchScreenState();
}

class _ExplorerSearchScreenState extends State<ExplorerSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  bool _loading = false;
  String? _error;
  String? _validationError;
  List<SearchHistoryEntry> _history = [];
  String _loadingMessage = '';
  Timer? _loadingMessageTimer;
  List<int> _remainingMessageIndices = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  String _pickNextMessage() {
    if (_remainingMessageIndices.isEmpty) {
      _remainingMessageIndices = List.generate(_loadingMessages.length, (i) => i);
    }
    final pick = _remainingMessageIndices.removeAt(
      _random.nextInt(_remainingMessageIndices.length),
    );
    return _loadingMessages[pick];
  }

  void _startLoadingMessages() {
    _remainingMessageIndices = List.generate(_loadingMessages.length, (i) => i);
    _loadingMessage = _pickNextMessage();
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _loadingMessage = _pickNextMessage());
      }
    });
  }

  void _stopLoadingMessages() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;
    _loadingMessage = '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingMessageTimer?.cancel();
    super.dispose();
  }

  void _search() async {
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

    setState(() {
      _loading = true;
      _error = null;
    });
    _startLoadingMessages();

    try {
      final skillTree = await fetchSkillTreeFromGemini(goal);
      if (!mounted) return;
      await HistoryService.addEntry(skillTree);
      await _loadHistory();

      // Cache skills for Next Step checklist
      final allSkills = <String>[];
      void collectSkills(List<SkillNode> nodes) {
        for (final n in nodes) {
          allSkills.add(n.name);
          collectSkills(n.subskills);
        }
      }
      collectSkills(skillTree.skills);
      await CareerCacheService.cacheCareerSkills(skillTree.goal, allSkills);

      _controller.clear();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareerOverviewScreen(skillTree: skillTree),
        ),
      );
    } on GeminiRateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on GeminiNetworkException {
      if (!mounted) return;
      setState(() => _error = 'Network error. Please check your connection and try again.');
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'API error (${e.statusCode}). Please try again later.');
    } on GeminiParseException {
      if (!mounted) return;
      setState(() => _error = 'Failed to parse response. Please try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      _stopLoadingMessages();
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Career Explorer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Skill/Job Goal',
                hintText: 'e.g. fire breathing, CEO, linux',
                border: const OutlineInputBorder(),
                errorText: _validationError,
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) {
                if (_validationError != null) setState(() => _validationError = null);
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Show me the way'),
              ),
            ),
            if (_loading && _loadingMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _loadingMessage,
                    key: ValueKey(_loadingMessage),
                    style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
            ],
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Recent Searches'),
              ..._history.map((entry) => Card(
                child: ListTile(
                  title: Text(entry.goal),
                  subtitle: Text(
                    '${_relativeTime(entry.timestamp)}\n'
                    '${entry.response.education.fold<int>(0, (sum, e) => sum + e.years)}y education '
                    '· ${entry.response.experience.fold<int>(0, (sum, e) => sum + e.yearsRequired)}y experience',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.trending_up, color: Colors.green[400]),
                        tooltip: 'Start Gap Analysis',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CurrentSkillsScreen(goal: entry.goal),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                        onPressed: () async {
                          await HistoryService.deleteEntry(entry.id);
                          await _loadHistory();
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    // Cache skills when tapping history too
                    final allSkills = <String>[];
                    void collectSkills(List<SkillNode> nodes) {
                      for (final n in nodes) {
                        allSkills.add(n.name);
                        collectSkills(n.subskills);
                      }
                    }
                    collectSkills(entry.response.skills);
                    await CareerCacheService.cacheCareerSkills(entry.response.goal, allSkills);

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CareerOverviewScreen(skillTree: entry.response),
                      ),
                    );
                  },
                ),
              )),
            ],
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Your goals are sent to Google\'s Gemini API for processing.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
