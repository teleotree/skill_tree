import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'skill_proposal_screen.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

const List<String> _loadingMessages = [
  'Analyzing your background...',
  'Mapping your skills...',
  'Consulting career experts...',
  'Identifying your strengths...',
  'Building your profile...',
];

class CurrentSkillsScreen extends StatefulWidget {
  final String goal;

  const CurrentSkillsScreen({Key? key, required this.goal}) : super(key: key);

  @override
  State<CurrentSkillsScreen> createState() => _CurrentSkillsScreenState();
}

class _CurrentSkillsScreenState extends State<CurrentSkillsScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _loadingMessage = '';
  Timer? _loadingMessageTimer;
  final Random _random = Random();
  List<int> _remainingIndices = [];

  String get _hintText {
    final goal = widget.goal;
    return 'e.g. I have 1 year of experience as a $goal. '
        'I\'m comfortable with basic tasks but haven\'t led projects yet. '
        'I have a degree in a related field...';
  }

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
    _textController.dispose();
    _loadingMessageTimer?.cancel();
    super.dispose();
  }

  void _next() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please describe your current skills and experience.');
      return;
    }
    if (text.length < 20) {
      setState(() => _error = 'Please provide more detail about your background (at least 20 characters).');
      return;
    }

    if (_geminiApiKey.isEmpty) {
      setState(() => _error = 'GEMINI_API_KEY not set.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    _startLoadingMessages();

    try {
      final proposals = await fetchSkillProposal(widget.goal, text, _geminiApiKey);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkillProposalScreen(
            goal: widget.goal,
            currentSkillsText: text,
            proposals: proposals,
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe Your Background')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Goal: ${widget.goal}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Tell us about your current skills, experience, and education:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: _hintText,
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                hintMaxLines: 5,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be specific! The more detail you provide, the better we can assess your current standing and identify gaps.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _loading ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Next'),
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
          ],
        ),
      ),
    );
  }
}
