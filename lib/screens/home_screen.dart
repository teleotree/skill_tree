import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../services/plan_service.dart';
import 'skill_tree_screen.dart';
import 'plan_screen.dart';

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
  'Summoning a mass of butterflies...',
  'Asking the cat... cat walked away...',
  'Reticulating splines...',
  'Compiling the meaning of life...',
  'Defragmenting the cosmos...',
  'Consulting the monastery Wi-Fi...',
  'Spinning up the hamster wheels...',
  'Translating from dolphin...',
  'Rebooting the astral plane...',
  'Flipping through the Rolodex...',
  'Waiting for paint to dry...',
  'Herding cats...',
  'Counting backwards from infinity...',
  'Asking the nearest toddler...',
  'Unfolding a paper map...',
  'Dividing by zero (carefully)...',
  'Warming up the abacus...',
  'Poking the server with a stick...',
  'Yelling into the void...',
  'Consulting the fridge for answers...',
  'Tuning the banjo of knowledge...',
  'Dueling with a spreadsheet...',
  'Meditating on your query...',
  'Asking a very old turtle...',
  'Sorting the junk drawer of the internet...',
  'Running uphill in flip flops...',
  'Performing interpretive dance for the CPU...',
  'Crowdsourcing from parallel universes...',
  'Befriending the firewall...',
  'Reading the room...',
  'Blowing on the cartridge...',
  'Consulting the town crier...',
  'Composing a strongly worded letter...',
  'Rewinding the internet...',
  'Asking a magic conch shell...',
  'Googling it (the old fashioned way)...',
  'Checking behind the bookshelf...',
  'Decrypting the Enigma machine...',
  'Microwaving some knowledge...',
  'Following the white rabbit...',
  'Asking the neighbor\'s dog...',
  'Performing a rain dance for data...',
  'Hitchhiking across the information superhighway...',
  'Opening fortune cookies...',
  'Consulting the bathroom mirror...',
  'Whistling for the data bus...',
  'Negotiating with squirrels...',
  'Sifting through cosmic dust...',
  'Rechecking the manual... there is no manual...',
  'Teaching fish to climb trees...',
  'Polishing the monocle of insight...',
  'Excavating digital fossils...',
  'Assembling the council of wizards...',
  'Calling tech support...',
  'Winding up the clockwork brain...',
  'Putting on the thinking cap...',
  'Consulting the cave paintings...',
  'Flipping a very large coin...',
  'Asking a random stranger on the bus...',
  'Charging the wisdom crystals...',
  'Borrowing a cup of knowledge...',
  'Dusting off the crystal radio...',
  'Conducting a seance with Alan Turing...',
  'Peeling the onion of truth...',
  'Checking the suggestion box...',
  'Sharpening the pencil of destiny...',
  'Calibrating the sass detector...',
  'Waking the sleeping giant...',
  'Activating ludicrous speed...',
  'Consulting the janitor (they know everything)...',
  'Sending smoke signals...',
  'Scanning the horizon with a telescope...',
  'Building a bridge to the answer...',
  'Asking the houseplant for advice...',
  'Dropping a penny in the wishing well...',
  'Consulting the HOA bylaws...',
  'Launching carrier pigeons 2.0...',
  'Digging through the couch for answers...',
  'Playing 20 questions with the cloud...',
  'Bribing the gnomes...',
  'Turning it off and on again...',
  'Squinting at the fine print...',
  'Asking the office fish tank...',
  'Decoding the Zodiac...',
  'Sending an owl...',
  'Checking the lost and found...',
  'Performing open heart surgery on the data...',
  'Bargaining with the WiFi gods...',
  'Tracing the constellation of answers...',
  'Ringing the bell of enlightenment...',
  'Swiping right on knowledge...',
  'Checking under the rug...',
  'Consulting the drive-thru oracle...',
  'Appeasing the server gremlins...',
  'Knitting a sweater of understanding...',
  'Asking the wise old vending machine...',
  'Unraveling the yarn of wisdom...',
  'Speed-reading the encyclopedia...',
];

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  bool _loading = false;
  String? _error;
  String? _validationError;
  List<SearchHistoryEntry> _history = [];
  List<Plan> _plans = [];
  String _loadingMessage = '';
  Timer? _loadingMessageTimer;
  List<int> _remainingMessageIndices = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadPlans();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _loadPlans() async {
    final plans = await PlanService.getPlans();
    if (mounted) {
      setState(() {
        _plans = plans;
      });
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
        setState(() {
          _loadingMessage = _pickNextMessage();
        });
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
    _startLoadingMessages();

    try {
      final skillTree = await fetchSkillTreeFromGemini(goal, _geminiApiKey);
      if (!mounted) return;
      await HistoryService.addEntry(skillTree);
      await _loadHistory();
      _controller.clear();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkillTreeScreen(skillTree: skillTree),
        ),
      );
      _loadPlans();
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
      _stopLoadingMessages();
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

  // Max height for scrollable list sections (approx 3 items)
  static const double _maxSectionHeight = 240;

  @override
  Widget build(BuildContext context) {
    final sectionTitleColor = Theme.of(context).inputDecorationTheme.labelStyle?.color
        ?? Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: Text('What do you want to do?')),
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
            Center(
              child: ElevatedButton(
                onPressed: _loading ? null : _goToSkillTree,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Show me the way'),
              ),
            ),
            if (_loading && _loadingMessage.isNotEmpty) ...[
              SizedBox(height: 12),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _loadingMessage,
                    key: ValueKey(_loadingMessage),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: 16),
              Center(child: Text(_error!, style: TextStyle(color: Colors.red))),
            ],
            if (_plans.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'My Plans',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: sectionTitleColor,
                ),
              ),
              SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _maxSectionHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
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
                            MaterialPageRoute(
                              builder: (context) => PlanScreen(planId: plan.id),
                            ),
                          );
                          _loadPlans();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_history.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: sectionTitleColor,
                ),
              ),
              SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _maxSectionHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final eduYears = entry.response.education.fold<int>(0, (sum, e) => sum + e.years);
                    final expYears = entry.response.experience.fold<int>(0, (sum, e) => sum + e.yearsRequired);
                    return Card(
                      child: ListTile(
                        title: Text(entry.goal),
                        subtitle: Text(
                          '${_relativeTime(entry.timestamp)}\n'
                          '${eduYears}y education · ${expYears}y experience',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                          onPressed: () async {
                            await HistoryService.deleteEntry(entry.id);
                            await _loadHistory();
                          },
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SkillTreeScreen(skillTree: entry.response),
                            ),
                          );
                          _loadPlans();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16),
            Center(
              child: Text(
                'Your goals are sent to Google\'s Gemini API for processing.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
