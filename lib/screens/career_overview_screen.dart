import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/skill_tag_chip.dart';
import 'education_detail_screen.dart';
import 'experience_detail_screen.dart';
import 'skill_detail_screen.dart';
import 'current_skills_screen.dart';

class CareerOverviewScreen extends StatefulWidget {
  final SkillTreeResponse skillTree;

  const CareerOverviewScreen({Key? key, required this.skillTree}) : super(key: key);

  @override
  State<CareerOverviewScreen> createState() => _CareerOverviewScreenState();
}

class _CareerOverviewScreenState extends State<CareerOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> expandedKeys = {};

  final List<Color> branchColors = [
    const Color(0xFF5B8CFF),
    const Color(0xFF6DD400),
    const Color(0xFFFFA940),
    const Color(0xFFB620E0),
    const Color(0xFF00C6AE),
    const Color(0xFFFF4D4F),
    const Color(0xFF36CFC9),
    const Color(0xFFFFC53D),
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
      SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
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

  List<String> _allSectionKeys(String section) {
    if (section == 'education') return List.generate(widget.skillTree.education.length, (i) => 'edu-$i');
    if (section == 'experience') return List.generate(widget.skillTree.experience.length, (i) => 'exp-$i');
    if (section == 'skills') return _allNodeKeys(widget.skillTree.skills);
    return [];
  }

  bool _isSectionExpanded(String section) => _allSectionKeys(section).every((k) => expandedKeys.contains(k));

  void _expandSection(String section) => setState(() => expandedKeys.addAll(_allSectionKeys(section)));
  void _collapseSection(String section) => setState(() => expandedKeys.removeAll(_allSectionKeys(section)));

  Widget _buildSummaryCard(BuildContext context) {
    int minTotalYears = 0;
    int maxTotalYears = 0;
    int totalExperienceYears = 0;

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

    String yearsText = minTotalYears == maxTotalYears ? '$minTotalYears years' : '$minTotalYears to $maxTotalYears years';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.skillTree.goal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 8),
          Text('Total Years of Degrees/Certifications Required: $yearsText', style: TextStyle(color: Colors.blue[300], fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Total Years of Experience Required: $totalExperienceYears', style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Text(
            widget.skillTree.description.isNotEmpty
                ? widget.skillTree.description
                : 'This skill tree outlines the key skills and resources needed to achieve the goal of "${widget.skillTree.goal}".',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.trending_up),
            label: const Text('Start Gap Analysis'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CurrentSkillsScreen(goal: widget.skillTree.goal),
                ),
              );
            },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    if (education.isEmpty) return const Center(child: Text('No education requirements found.', style: TextStyle(color: Colors.white70)));
    return _buildTabWithStickyButton(
      'education',
      Colors.indigo[800]!,
      ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: education.length,
        itemBuilder: (context, index) => _buildEducationTile(education[index], index.toString()),
      ),
    );
  }

  Widget _buildExperienceTab() {
    final experience = widget.skillTree.experience;
    if (experience.isEmpty) return const Center(child: Text('No experience requirements found.', style: TextStyle(color: Colors.white70)));
    return _buildTabWithStickyButton(
      'experience',
      Colors.teal[800]!,
      ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: experience.length,
        itemBuilder: (context, index) => _buildExperienceTile(experience[index], index.toString()),
      ),
    );
  }

  Widget _buildSkillsTab() {
    final skills = widget.skillTree.skills;
    if (skills.isEmpty) return const Center(child: Text('No skills found.', style: TextStyle(color: Colors.white70)));
    return _buildTabWithStickyButton(
      'skills',
      Colors.blue[800]!,
      ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      appBar: AppBar(title: Text('Career: ${widget.skillTree.goal}')),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildSummaryCard(context))),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'Education'), Tab(text: 'Experience'), Tab(text: 'Skills')],
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
          children: [_buildEducationTab(), _buildExperienceTab(), _buildSkillsTab()],
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
        bgColor = const Color(0xFF3F51B5);
        icon = Icons.school;
        label = 'Degree';
        tooltip = 'Formal academic degree (e.g., Bachelor\'s, Master\'s, Doctorate)';
        break;
      case 'certification':
        bgColor = const Color(0xFFFF7043);
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
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationTile(EducationNode edu, String key) {
    final nodeKey = 'edu-$key';
    final isExpanded = expandedKeys.contains(nodeKey);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => EducationDetailScreen(education: edu),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              collapsedBackgroundColor: Colors.indigo[800],
              backgroundColor: Colors.indigo[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(color: Colors.indigo[300], borderRadius: BorderRadius.circular(12)),
                      child: Text(edu.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  _buildEducationTypeChip(edu.type),
                ],
              ),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) expandedKeys.add(nodeKey); else expandedKeys.remove(nodeKey);
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (edu.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(edu.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      Text('${edu.years} years', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View Details'),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => EducationDetailScreen(education: edu),
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceTile(ExperienceNode exp, String key) {
    final isExpanded = expandedKeys.contains('exp-$key');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.teal[800],
            backgroundColor: Colors.teal[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(color: Colors.tealAccent[400], borderRadius: BorderRadius.circular(12)),
              child: Text(exp.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) expandedKeys.add('exp-$key'); else expandedKeys.remove('exp-$key');
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${exp.yearsRequired} years required', style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(exp.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Details'),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ExperienceDetailScreen(experience: exp),
                          ));
                        },
                      ),
                    ),
                  ],
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.grey[850],
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                    child: Text(node.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                SkillTagChip(tag: node.tag),
              ],
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) expandedKeys.add(nodeKey); else expandedKeys.remove(nodeKey);
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.description.isNotEmpty ? node.description : 'This skill is essential for achieving your goal.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Details'),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => SkillDetailScreen(skill: node),
                          ));
                        },
                      ),
                    ),
                    ...node.subskills.asMap().entries.map((entry) =>
                        _buildExpansionTile(entry.value, color, depth + 1, nodeKey + '-' + entry.key.toString())),
                  ],
                ),
              ),
            ],
          ),
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
    return Container(color: Colors.blueGrey[900], child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
