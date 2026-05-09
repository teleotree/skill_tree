import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/plan_service.dart';
import 'plan_screen.dart';

const List<String> _loadingMessages = [
  'Analyzing your gaps...',
  'Building your action plan...',
  'Prioritizing next steps...',
  'Mapping your path forward...',
  'Calculating optimal route...',
];

class SkillProposalScreen extends StatefulWidget {
  final String goal;
  final String currentSkillsText;
  final List<SkillProposal> proposals;

  const SkillProposalScreen({
    Key? key,
    required this.goal,
    required this.currentSkillsText,
    required this.proposals,
  }) : super(key: key);

  @override
  State<SkillProposalScreen> createState() => _SkillProposalScreenState();
}

class _SkillProposalScreenState extends State<SkillProposalScreen> {
  late Map<String, bool> _completedStatus;
  final Set<String> _expandedSkills = {};
  bool _loading = false;
  String? _error;
  String _loadingMessage = '';
  Timer? _loadingMessageTimer;
  final Random _random = Random();
  List<int> _remainingIndices = [];

  @override
  void initState() {
    super.initState();
    _completedStatus = {
      for (var p in widget.proposals) p.name: p.proposedCompleted,
    };
  }

  Map<String, List<SkillProposal>> get _groupedSkills {
    final grouped = <String, List<SkillProposal>>{};
    for (var p in widget.proposals) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }
    // Sort each category's skills by level (beginner first)
    for (var skills in grouped.values) {
      skills.sort((a, b) => a.level.compareTo(b.level));
    }
    return grouped;
  }

  int get _completedCount => _completedStatus.values.where((v) => v).length;
  int get _totalCount => widget.proposals.length;

  String _pickNextMessage() {
    if (_remainingIndices.isEmpty) {
      _remainingIndices = List.generate(_loadingMessages.length, (i) => i);
    }
    final pick = _remainingIndices.removeAt(_random.nextInt(_remainingIndices.length));
    return _loadingMessages[pick];
  }

  void _startLoadingMessages() {
    _remainingIndices = List.generate(_loadingMessages.length, (i) => i);
    _loadingMessage = _pickNextMessage();
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _loadingMessage = _pickNextMessage());
    });
  }

  void _stopLoadingMessages() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;
    _loadingMessage = '';
  }

  @override
  void dispose() {
    _loadingMessageTimer?.cancel();
    super.dispose();
  }

  void _analyzeGap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _startLoadingMessages();

    try {
      final checkedSkills = widget.proposals
          .where((p) => _completedStatus[p.name] == true)
          .toList();

      final plan = await fetchGapAnalysis(
        widget.goal,
        widget.currentSkillsText,
        checkedSkills,
      );
      if (!mounted) return;

      // Note: Initially completed skills are now created as completed PlanItems
      // directly in fetchGapAnalysis, so no additional marking is needed here

      await PlanService.savePlan(plan);
      if (!mounted) return;

      // Navigate back to Next Step root and push plan
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlanScreen(planId: plan.id)),
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

  Widget _buildLevelIndicator(int level) {
    final colors = [Colors.green, Colors.orange, Colors.red];
    final labels = ['Beginner', 'Intermediate', 'Advanced'];
    final color = colors[level - 1];
    final label = labels[level - 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedSkills;
    final categories = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Skills')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goal: ${widget.goal}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Based on your description, we identified $_completedCount/$_totalCount skills you may already have. '
                  'Review and adjust the checkboxes below.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _totalCount > 0 ? _completedCount / _totalCount : 0,
                  backgroundColor: Colors.grey[700],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var category in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[300],
                      ),
                    ),
                  ),
                  ...grouped[category]!.map((skill) {
                    final isCompleted = _completedStatus[skill.name] ?? false;
                    final isExpanded = _expandedSkills.contains(skill.name);
                    return Card(
                      color: Colors.grey[850],
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: (val) {
                                setState(() {
                                  _completedStatus[skill.name] = val ?? false;
                                });
                              },
                              activeColor: Colors.green[600],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    skill.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isCompleted ? Colors.grey[500] : Colors.white,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildLevelIndicator(skill.level),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Colors.grey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedSkills.remove(skill.name);
                                  } else {
                                    _expandedSkills.add(skill.name);
                                  }
                                });
                              },
                            ),
                            dense: true,
                          ),
                          if (isExpanded && skill.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  skill.description,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _analyzeGap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Analyze Gap & Create Plan'),
                ),
                if (_loading && _loadingMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _loadingMessage,
                      key: ValueKey(_loadingMessage),
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 12),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
