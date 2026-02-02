import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/plan_service.dart';
import 'plan_screen.dart';

class SkillTreeScreen extends StatefulWidget {
  final SkillTreeResponse skillTree;

  const SkillTreeScreen({Key? key, required this.skillTree}) : super(key: key);

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> expandedKeys = {};

  final List<Color> branchColors = [
    Color(0xFF5B8CFF),
    Color(0xFF6DD400),
    Color(0xFFFFA940),
    Color(0xFFB620E0),
    Color(0xFF00C6AE),
    Color(0xFFFF4D4F),
    Color(0xFF36CFC9),
    Color(0xFFFFC53D),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTooltip(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<String> _allNodeKeys(List<SkillNode> nodes, [String prefix = '']) {
    List<String> keys = [];
    for (int i = 0; i < nodes.length; i++) {
      final key = prefix + i.toString();
      keys.add(key);
      keys.addAll(_allNodeKeys(nodes[i].subskills, key + '-'));
    }
    return keys;
  }

  List<String> _allExperienceKeys() {
    return List.generate(widget.skillTree.experience.length, (i) => 'exp-$i');
  }

  List<String> _allEducationKeys() {
    return List.generate(widget.skillTree.education.length, (i) => 'edu-$i');
  }

  List<String> _allSkillKeys() {
    return _allNodeKeys(widget.skillTree.skills);
  }

  List<String> _allSectionKeys(String section) {
    if (section == 'education') return _allEducationKeys();
    if (section == 'experience') return _allExperienceKeys();
    if (section == 'skills') return _allSkillKeys();
    return [];
  }

  bool _isSectionExpanded(String section) {
    final keys = _allSectionKeys(section);
    return keys.every((k) => expandedKeys.contains(k));
  }

  void _expandSection(String section) {
    setState(() {
      expandedKeys.addAll(_allSectionKeys(section));
    });
  }

  void _collapseSection(String section) {
    setState(() {
      expandedKeys.removeAll(_allSectionKeys(section));
    });
  }

  Plan _createPlanFromSkillTree() {
    final items = <PlanItem>[];
    int counter = 0;

    // Build education items first, tracking their IDs and types
    final eduItems = <PlanItem>[];
    for (final edu in widget.skillTree.education) {
      final item = PlanItem(
        id: 'plan-${counter++}',
        type: 'education',
        name: edu.name,
        description: edu.description,
        fields: {
          'years': edu.years,
          'type': edu.type,
          'prerequisites': edu.prerequisites,
        },
      );
      eduItems.add(item);
      items.add(item);
    }

    for (final exp in widget.skillTree.experience) {
      items.add(PlanItem(
        id: 'plan-${counter++}',
        type: 'experience',
        name: exp.title,
        description: exp.description,
        fields: {
          'years_required': exp.yearsRequired,
          'breakdown': exp.breakdown,
        },
      ));
    }

    // Collect skill items with their education_name for linking
    final skillItems = <(PlanItem, String?)>[];
    void addSkills(List<SkillNode> skills) {
      for (final skill in skills) {
        final item = PlanItem(
          id: 'plan-${counter++}',
          type: 'skill',
          name: skill.name,
          description: skill.description,
          fields: {
            'tag': skill.tag,
          },
          resources: List.from(skill.resources),
        );
        skillItems.add((item, skill.educationName));
        items.add(item);
        addSkills(skill.subskills);
      }
    }
    addSkills(widget.skillTree.skills);

    // Link skills to their specific education item by matching education_name.
    for (final edu in eduItems) {
      final linkedIds = <String>[];
      for (final (skill, eduName) in skillItems) {
        if (eduName != null && eduName == edu.name) {
          linkedIds.add(skill.id);
        }
      }
      edu.linkedSkillIds = linkedIds;
    }

    return Plan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goal: widget.skillTree.goal,
      createdAt: DateTime.now(),
      items: items,
    );
  }

  void _createPlan() async {
    final plan = _createPlanFromSkillTree();
    await PlanService.savePlan(plan);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanScreen(planId: plan.id),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    int totalExperienceYears = 0;
    int minTotalYears = 0;
    int maxTotalYears = 0;

    for (var edu in widget.skillTree.education) {
      if (edu.options.isNotEmpty) {
        int minYears = edu.options.map((o) => o.years).fold(1000, (a, b) => b < a ? b : a);
        int maxYears = edu.options.map((o) => o.years).fold(0, (a, b) => b > a ? b : a);
        minTotalYears += minYears;
        maxTotalYears += maxYears;
      } else {
        minTotalYears += edu.years;
        maxTotalYears += edu.years;
      }
    }

    for (var exp in widget.skillTree.experience) {
      totalExperienceYears += exp.yearsRequired;
    }

    String yearsText;
    if (minTotalYears == maxTotalYears) {
      yearsText = '$minTotalYears years';
    } else {
      yearsText = '$minTotalYears to $maxTotalYears years';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.skillTree.goal,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Total Years of Degrees/Certifications Required: $yearsText',
            style: TextStyle(
              color: Colors.blue[300],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Total Years of Experience Required: $totalExperienceYears',
            style: TextStyle(
              color: Colors.tealAccent[400],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.skillTree.description.isNotEmpty
                ? widget.skillTree.description
                : 'This skill tree outlines the key skills and resources needed to achieve the goal of "${widget.skillTree.goal}". Expand each section to explore the learning path.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.playlist_add_check),
            label: Text('Create Plan'),
            onPressed: _createPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionExpandButton(String section, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          ElevatedButton.icon(
            icon: Icon(_isSectionExpanded(section) ? Icons.unfold_less : Icons.unfold_more),
            label: Text(_isSectionExpanded(section) ? 'Collapse All' : 'Expand All'),
            onPressed: _isSectionExpanded(section) ? () => _collapseSection(section) : () => _expandSection(section),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithStickyButton(String section, Color buttonColor, Widget listContent) {
    return Column(
      children: [
        _buildSectionExpandButton(section, buttonColor),
        Expanded(child: listContent),
      ],
    );
  }

  Widget _buildEducationTab() {
    final education = widget.skillTree.education;
    if (education.isEmpty) {
      return Center(child: Text('No education requirements found.', style: TextStyle(color: Colors.white70)));
    }
    return _buildTabWithStickyButton(
      'education',
      Colors.indigo[800]!,
      ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: education.length,
        itemBuilder: (context, index) {
          return _buildEducationTile(education[index], index.toString());
        },
      ),
    );
  }

  Widget _buildExperienceTab() {
    final experience = widget.skillTree.experience;
    if (experience.isEmpty) {
      return Center(child: Text('No experience requirements found.', style: TextStyle(color: Colors.white70)));
    }
    return _buildTabWithStickyButton(
      'experience',
      Colors.teal[800]!,
      ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: experience.length,
        itemBuilder: (context, index) {
          return _buildExperienceTile(experience[index], index.toString());
        },
      ),
    );
  }

  Widget _buildSkillsTab() {
    final skills = widget.skillTree.skills;
    if (skills.isEmpty) {
      return Center(child: Text('No skills found.', style: TextStyle(color: Colors.white70)));
    }
    return _buildTabWithStickyButton(
      'skills',
      Colors.blue[800]!,
      ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final node = skills[index];
          final color = branchColors[index % branchColors.length];
          return _buildExpansionTile(node, color, 0, index.toString());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skill Tree for: ${widget.skillTree.goal}'),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _buildSummaryCard(context),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Education'),
                    Tab(text: 'Experience'),
                    Tab(text: 'Skills'),
                  ],
                  indicatorColor: Colors.blue[300],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEducationTab(),
            _buildExperienceTab(),
            _buildSkillsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationTile(EducationNode edu, String key) {
    final nodeKey = 'edu-$key';
    final isExpanded = expandedKeys.contains(nodeKey);
    if (edu.options.isNotEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo[300]!, width: 2),
              color: Colors.indigo[900],
            ),
            child: ExpansionTile(
              key: ValueKey(nodeKey + '-' + isExpanded.toString()),
              tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              collapsedBackgroundColor: Colors.indigo[800],
              backgroundColor: Colors.indigo[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        edu.name,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  _buildEducationTypeChip(edu.type),
                ],
              ),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    expandedKeys.add(nodeKey);
                  } else {
                    expandedKeys.remove(nodeKey);
                  }
                });
              },
              children: [
                AnimatedSize(
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (edu.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(edu.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ),
                        ...edu.options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final option = entry.value;
                          final optionLabel = 'Option ${String.fromCharCode(65 + idx)}';
                          return Container(
                            margin: EdgeInsets.only(bottom: 12, left: 8, right: 8),
                            decoration: BoxDecoration(
                              color: Colors.indigo[800],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo[200]!, width: 1.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(optionLabel, style: TextStyle(color: Colors.indigo[200], fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text(option.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  SizedBox(height: 4),
                                  Text(option.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _showTooltip(context, 'Typical number of years required to complete this degree/certification'),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Text('${option.years} years', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  if (option.prerequisites.isNotEmpty) ...[
                                    SizedBox(height: 6),
                                    Text('Prerequisites:', style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold)),
                                    Text(option.prerequisites, style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                  if (option.links.isNotEmpty) ...[
                                    SizedBox(height: 6),
                                    Text('Links:', style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold)),
                                    ...option.links.map((r) => Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.link, size: 13, color: Colors.indigo[300]),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  r.title + ': ' + r.url,
                                                  style: TextStyle(fontSize: 12, color: Colors.blue[200], decoration: TextDecoration.underline),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo[300]!, width: 2),
            color: Colors.indigo[900],
          ),
          child: ExpansionTile(
            key: ValueKey(nodeKey + '-' + isExpanded.toString()),
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.indigo[800],
            backgroundColor: Colors.indigo[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      edu.name,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                _buildEducationTypeChip(edu.type),
              ],
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  expandedKeys.add(nodeKey);
                } else {
                  expandedKeys.remove(nodeKey);
                }
              });
            },
            children: [
              AnimatedSize(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(edu.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showTooltip(context, 'Typical number of years required to complete this degree/certification'),
                        borderRadius: BorderRadius.circular(4),
                        child: Text('${edu.years} years', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      if (edu.prerequisites.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Prerequisites:', style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold)),
                        Text(edu.prerequisites, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                      if (edu.links.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Links:', style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold)),
                        ...edu.links.map((r) => Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 14, color: Colors.indigo[300]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      r.title + ': ' + r.url,
                                      style: TextStyle(fontSize: 12, color: Colors.blue[200], decoration: TextDecoration.underline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEducationTypeChip(String type) {
    Color bgColor;
    IconData icon;
    String label;
    String tooltip;
    switch (type) {
      case 'degree':
        bgColor = Color(0xFF3F51B5);
        icon = Icons.school;
        label = 'Degree';
        tooltip = 'Formal academic degree (e.g., Bachelor\'s, Master\'s, Doctorate)';
        break;
      case 'certification':
        bgColor = Color(0xFFFF7043);
        icon = Icons.verified;
        label = 'Certification';
        tooltip = 'Professional certification required for this field';
        break;
      default:
        bgColor = Colors.grey;
        icon = Icons.help;
        label = 'Other';
        tooltip = 'Other type of education or credential';
        break;
    }
    return InkWell(
      onTap: () => _showTooltip(context, tooltip),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(left: 8),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceTile(ExperienceNode exp, String key) {
    final isExpanded = expandedKeys.contains('exp-$key');
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.tealAccent[400]!, width: 2),
            color: Colors.teal[900],
          ),
          child: ExpansionTile(
            key: ValueKey('exp-$key-$isExpanded'),
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.teal[800],
            backgroundColor: Colors.teal[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.tealAccent[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                exp.title,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  expandedKeys.add('exp-$key');
                } else {
                  expandedKeys.remove('exp-$key');
                }
              });
            },
            children: [
              AnimatedSize(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${exp.yearsRequired} years required', style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(exp.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      if (exp.breakdown.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Breakdown:', style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold)),
                        ...exp.breakdown.map((b) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Expanded(child: Text(b, style: TextStyle(color: Colors.white70, fontSize: 13))),
                              ],
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile(SkillNode node, Color color, int depth, String keyPrefix) {
    final nodeKey = keyPrefix;
    final isExpanded = expandedKeys.contains(nodeKey);
    return Container(
      margin: EdgeInsets.only(bottom: 12, left: depth == 0 ? 0 : 8.0 + (depth - 1) * 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
            color: Colors.grey[900],
          ),
          child: ExpansionTile(
            key: ValueKey(nodeKey + '-' + isExpanded.toString()),
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.grey[850],
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      node.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                _buildSkillTagChip(node.tag),
              ],
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  expandedKeys.add(nodeKey);
                } else {
                  expandedKeys.remove(nodeKey);
                }
              });
            },
            children: [
              AnimatedSize(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (node.description.isNotEmpty)
                        Text(node.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      if (node.description.isEmpty)
                        Text('This skill is essential for achieving your goal and will help you progress along your learning path.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      if (node.resources.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Resources:', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        ...node.resources.map((r) => Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 14, color: color),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      r.title + ': ' + r.url,
                                      style: TextStyle(fontSize: 12, color: Colors.blue[200], decoration: TextDecoration.underline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      ...node.subskills.asMap().entries.map((entry) => _buildExpansionTile(entry.value, color, depth + 1, nodeKey + '-' + entry.key.toString())),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillTagChip(String tag) {
    Color bgColor;
    IconData icon;
    String label;
    String tooltip;
    switch (tag) {
      case 'degree':
        bgColor = Color(0xFF3F51B5);
        icon = Icons.school;
        label = 'Degree';
        tooltip = 'Skill learned as part of a formal degree program';
        break;
      case 'certification':
        bgColor = Color(0xFFFF7043);
        icon = Icons.verified;
        label = 'Certification';
        tooltip = 'Skill learned as part of a professional certification';
        break;
      case 'experience':
        bgColor = Color(0xFF00897B);
        icon = Icons.work;
        label = 'Experience';
        tooltip = 'Skill learned primarily through work experience';
        break;
      case 'informal':
      default:
        bgColor = Color(0xFF43A047);
        icon = Icons.lightbulb;
        label = 'Other';
        tooltip = 'Skill learned outside formal education/certification/experience';
        break;
    }
    return InkWell(
      onTap: () => _showTooltip(context, tooltip),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(left: 8),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.blueGrey[900],
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
