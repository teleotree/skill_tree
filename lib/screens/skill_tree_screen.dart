import 'package:flutter/material.dart';
import '../models/models.dart';

class SkillTreeScreen extends StatelessWidget {
  final SkillTreeResponse skillTree;

  const SkillTreeScreen({Key? key, required this.skillTree}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skill Tree for: ${skillTree.goal}'),
      ),
      body: SkillTreeListView(skillTree: skillTree),
    );
  }
}

class SkillTreeListView extends StatefulWidget {
  final SkillTreeResponse skillTree;
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

  SkillTreeListView({Key? key, required this.skillTree}) : super(key: key);

  @override
  State<SkillTreeListView> createState() => _SkillTreeListViewState();
}

class _SkillTreeListViewState extends State<SkillTreeListView> {
  Set<String> expandedKeys = {};
  bool get allExpanded => expandedKeys.length >= _allNodeKeys(widget.skillTree.skills).length + (widget.skillTree.experience.isNotEmpty ? widget.skillTree.experience.length : 0);

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

  int _totalHours(SkillNode node) {
    int sum = node.estimatedTimeHours;
    for (var sub in node.subskills) {
      sum += _totalHours(sub);
    }
    return sum;
  }

  int get totalHours {
    int sum = 0;
    for (var node in widget.skillTree.skills) {
      sum += _totalHours(node);
    }
    return sum;
  }

  void _expandAll() {
    setState(() {
      expandedKeys.addAll(_allSkillKeys());
      expandedKeys.addAll(_allEducationKeys());
      expandedKeys.addAll(_allExperienceKeys());
    });
  }

  void _collapseAll() {
    setState(() {
      expandedKeys.clear();
    });
  }

  Widget _buildSummaryCard(BuildContext context) {
    int totalExperienceYears = 0;
    int totalDegreeHours = 0;
    int totalCertificationHours = 0;
    int totalInformalHours = 0;

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

    for (var node in widget.skillTree.skills) {
      _countHoursByTag(node, (tag, hours) {
        if (tag == 'degree') {
          totalDegreeHours += hours;
        } else if (tag == 'certification') {
          totalCertificationHours += hours;
        } else {
          totalInformalHours += hours;
        }
      });
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
          SizedBox(height: 8),
          Text(
            'Total Skills Hours: $totalHours',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Skill Hours Breakdown:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Degree: $totalDegreeHours hours',
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: 14,
            ),
          ),
          Text(
            'Certification: $totalCertificationHours hours',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 14,
            ),
          ),
          Text(
            'Informal: $totalInformalHours hours',
            style: TextStyle(
              color: Colors.green[300],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.skillTree.description.isNotEmpty ? widget.skillTree.description : _goalDescription(widget.skillTree.goal),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _countHoursByTag(SkillNode node, Function(String tag, int hours) callback) {
    callback(node.tag, node.estimatedTimeHours);
    for (var sub in node.subskills) {
      _countHoursByTag(sub, callback);
    }
  }

  String _goalDescription(String goal) {
    return 'This skill tree outlines the key skills and resources needed to achieve the goal of "$goal". Expand each section to explore the learning path.';
  }

  @override
  Widget build(BuildContext context) {
    final expCount = widget.skillTree.experience.length;
    final skillCount = widget.skillTree.skills.length;
    final eduCount = widget.skillTree.education.length;
    final hasExperience = expCount > 0;
    final hasEducation = eduCount > 0;
    return ListView.builder(
        padding: EdgeInsets.all(16),
      itemCount: skillCount + (hasExperience ? 1 + expCount : 0) + (hasEducation ? 1 + eduCount : 0) + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(context);
        }
        if (index == 1) {
          return Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more),
                label: Text(allExpanded ? 'Collapse All' : 'Expand All'),
                onPressed: allExpanded ? _collapseAll : _expandAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        }
        if (hasEducation && index == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Education/Certification Required',
                      style: TextStyle(
                        color: Colors.indigo[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Tooltip(
                      message: 'This section lists all required degrees and certifications for your goal.',
                      child: InkWell(
                        onTap: () => _showTooltip(context, 'This section lists all required degrees and certifications for your goal.'),
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(Icons.info_outline, size: 18, color: Colors.indigo[300]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(_isSectionExpanded('education') ? Icons.unfold_less : Icons.unfold_more),
                      label: Text(_isSectionExpanded('education') ? 'Collapse Section' : 'Expand Section'),
                      onPressed: _isSectionExpanded('education') ? () => _collapseSection('education') : () => _expandSection('education'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        if (hasEducation && index > 2 && index <= 2 + eduCount) {
          final edu = widget.skillTree.education[index - 3];
          return _buildEducationTile(edu, (index - 3).toString());
        }
        final expStart = hasEducation ? 3 + eduCount : 2;
        if (hasExperience && index == expStart) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Experience Required',
                      style: TextStyle(
                        color: Colors.tealAccent[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Tooltip(
                      message: 'This section lists the types and years of experience typically required.',
                      child: InkWell(
                        onTap: () => _showTooltip(context, 'This section lists the types and years of experience typically required.'),
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(Icons.info_outline, size: 18, color: Colors.tealAccent[400]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(_isSectionExpanded('experience') ? Icons.unfold_less : Icons.unfold_more),
                      label: Text(_isSectionExpanded('experience') ? 'Collapse Section' : 'Expand Section'),
                      onPressed: _isSectionExpanded('experience') ? () => _collapseSection('experience') : () => _expandSection('experience'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        if (hasExperience && index > expStart && index <= expStart + expCount) {
          final exp = widget.skillTree.experience[index - (expStart + 1)];
          return _buildExperienceTile(exp, (index - (expStart + 1)).toString());
        }
        final skillStart = (hasEducation ? 3 + eduCount : 2) + (hasExperience ? 1 + expCount : 0);
        if (index == skillStart) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Skills Required',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Tooltip(
                      message: 'This section lists all the skills you need to achieve your goal.',
                      child: InkWell(
                        onTap: () => _showTooltip(context, 'This section lists all the skills you need to achieve your goal.'),
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(Icons.info_outline, size: 18, color: Colors.blue[300]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(_isSectionExpanded('skills') ? Icons.unfold_less : Icons.unfold_more),
                      label: Text(_isSectionExpanded('skills') ? 'Collapse Section' : 'Expand Section'),
                      onPressed: _isSectionExpanded('skills') ? () => _collapseSection('skills') : () => _expandSection('skills'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        final nodeIndex = index - (skillStart + 1);
        if (nodeIndex < 0 || nodeIndex >= skillCount) return SizedBox.shrink();
        final node = widget.skillTree.skills[nodeIndex];
        final color = widget.branchColors[nodeIndex % widget.branchColors.length];
        return _buildExpansionTile(node, color, 0, nodeIndex.toString());
      },
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
                      Text('${node.estimatedTimeHours} hrs', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      if (node.description.isNotEmpty)
                        Text(node.description, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      if (node.description.isEmpty)
                        Text(_skillDescription(node.name), style: TextStyle(color: Colors.white70, fontSize: 13)),
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

  String _skillDescription(String name) {
    return 'This skill is essential for achieving your goal and will help you progress along your learning path.';
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
      default:
        bgColor = Color(0xFF43A047);
        icon = Icons.lightbulb;
        label = 'Informal';
        tooltip = 'Skill learned outside formal education/certification';
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
