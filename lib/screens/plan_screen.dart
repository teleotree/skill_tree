import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/plan_service.dart';
import '../services/gemini_service.dart';

class PlanScreen extends StatefulWidget {
  final String planId;

  const PlanScreen({Key? key, required this.planId}) : super(key: key);

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Plan? _plan;
  String? _expandedId;
  final Set<String> _loadingResources = {};

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await PlanService.getPlan(widget.planId);
    if (mounted) {
      setState(() {
        _plan = plan;
      });
    }
  }

  Future<void> _savePlan() async {
    if (_plan != null) {
      await PlanService.savePlan(_plan!);
    }
  }

  /// IDs of all skills that are linked under some education item.
  Set<String> get _linkedSkillIds {
    final ids = <String>{};
    for (final item in _plan!.items) {
      ids.addAll(item.linkedSkillIds);
    }
    return ids;
  }

  /// Top-level items: everything except skills nested under education.
  List<PlanItem> get _topLevelItems {
    final linked = _linkedSkillIds;
    return _plan!.items.where((i) => !linked.contains(i.id)).toList();
  }

  PlanItem? _itemById(String id) {
    try {
      return _plan!.items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      _expandedId = (_expandedId == id) ? null : id;
    });
    _savePlan();
  }

  void _toggleCompleted(PlanItem item) {
    setState(() {
      final newState = !item.completed;
      item.completed = newState;

      // Cascade to linked skills
      if (item.linkedSkillIds.isNotEmpty) {
        for (final linkedId in item.linkedSkillIds) {
          final linked = _itemById(linkedId);
          if (linked != null) {
            linked.completed = newState;
          }
        }
      }
    });
    _savePlan();
  }

  void _toggleLinkedSkillCompleted(PlanItem skill) {
    setState(() {
      skill.completed = !skill.completed;
    });
    _savePlan();
  }

  void _toggleActive(PlanItem item) {
    setState(() {
      // If activating this item, deactivate all others
      if (!item.isActive) {
        for (final i in _plan!.items) {
          i.isActive = false;
        }
      }
      item.isActive = !item.isActive;
    });
    _savePlan();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final topLevel = _topLevelItems;
      final movedItem = topLevel[oldIndex];
      final targetItem = newIndex < topLevel.length ? topLevel[newIndex] : null;

      // Reorder in the actual items list
      _plan!.items.remove(movedItem);
      if (targetItem != null) {
        final targetIdx = _plan!.items.indexOf(targetItem);
        _plan!.items.insert(targetIdx, movedItem);
      } else {
        _plan!.items.add(movedItem);
      }
    });
    _savePlan();
  }

  Future<void> _findEducation(PlanItem item) async {
    setState(() {
      _loadingResources.add(item.id);
    });

    try {
      final resources = await fetchEducationResources(item);
      if (!mounted) return;
      setState(() {
        item.resources = resources;
        _loadingResources.remove(item.id);
      });
      _savePlan();
    } on GeminiRateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingResources.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingResources.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch resources. Please try again.')),
      );
    }
  }

  Widget _buildTagChip(String tag, {bool completed = false}) {
    Color bgColor;
    IconData icon;
    String label;
    switch (tag) {
      case 'degree':
        bgColor = completed ? Color(0xFF1A237E) : Color(0xFF3F51B5);
        icon = Icons.school;
        label = 'Degree';
        break;
      case 'certification':
        bgColor = completed ? Color(0xFF4E2700) : Color(0xFFFF7043);
        icon = Icons.verified;
        label = 'Certification';
        break;
      case 'experience':
        bgColor = completed ? Color(0xFF004D40) : Color(0xFF00897B);
        icon = Icons.work;
        label = 'Experience';
        break;
      default:
        bgColor = completed ? Color(0xFF1B5E20) : Color(0xFF43A047);
        icon = Icons.lightbulb;
        label = 'Other';
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: completed ? Colors.white60 : Colors.white, size: 12),
          SizedBox(width: 3),
          Text(label, style: TextStyle(
            color: completed ? Colors.white60 : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, {bool completed = false}) {
    Color bgColor;
    String label;
    switch (type) {
      case 'education':
        bgColor = completed ? Color(0xFF1A237E) : Color(0xFF3F51B5);
        label = 'Education';
        break;
      case 'experience':
        bgColor = completed ? Color(0xFF004D40) : Color(0xFF00897B);
        label = 'Experience';
        break;
      case 'skill':
      default:
        bgColor = completed ? Color(0xFF1A3A6B) : Color(0xFF5B8CFF);
        label = 'Skill';
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(
        color: completed ? Colors.white60 : Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      )),
    );
  }

  Widget _buildPriorityChip(String priority, {bool completed = false}) {
    Color bgColor;
    String label;
    switch (priority) {
      case 'high':
        bgColor = completed ? const Color(0xFF5D1A1A) : Colors.red[700]!;
        label = 'High';
        break;
      case 'medium':
        bgColor = completed ? const Color(0xFF5D4A1A) : Colors.orange[700]!;
        label = 'Medium';
        break;
      case 'low':
      default:
        bgColor = completed ? const Color(0xFF1A4D1A) : Colors.green[700]!;
        label = 'Low';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(
        color: completed ? Colors.white60 : Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      )),
    );
  }

  Widget _buildLevelIndicator(int level, {bool completed = false}) {
    final colors = [Colors.green, Colors.orange, Colors.red];
    final labels = ['Beginner', 'Intermediate', 'Advanced'];
    final color = colors[level - 1];
    final label = labels[level - 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: completed ? color.withOpacity(0.1) : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: completed ? color.withOpacity(0.5) : color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: completed ? color.withOpacity(0.6) : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubtitleChips(PlanItem item) {
    final completed = item.completed;
    final level = item.fields['level'] as int?;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        children: [
          _buildTypeChip(item.type, completed: completed),
          if (item.type == 'skill')
            _buildTagChip(item.fields['tag'] as String? ?? 'other', completed: completed),
          if (level != null && level >= 1 && level <= 3)
            _buildLevelIndicator(level, completed: completed),
          if (item.priority != null)
            _buildPriorityChip(item.priority!, completed: completed),
        ],
      ),
    );
  }

  Widget _buildExpandedView(PlanItem item, bool completed) {
    final controllers = <String, TextEditingController>{};
    for (final entry in item.fields.entries) {
      // Skip 'tag' for skills — already shown as chip
      if (entry.key == 'tag') continue;
      if (entry.value is String || entry.value is int || entry.value is double) {
        controllers[entry.key] = TextEditingController(text: entry.value.toString());
      }
    }

    final descColor = completed ? Colors.grey[500] : Colors.grey[300];
    final resourceTitleColor = completed ? Colors.blue[300] : Colors.blue[200];
    final resourceDescColor = completed ? Colors.grey[500] : Colors.grey[400];
    final sectionLabelColor = completed ? Colors.blue[200] : Colors.blue[300];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(item.description, style: TextStyle(color: descColor, fontSize: 13)),
            ),
          ...controllers.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                controller: entry.value,
                style: TextStyle(color: completed ? Colors.grey[400] : Colors.white),
                decoration: InputDecoration(
                  labelText: entry.key.replaceAll('_', ' '),
                  labelStyle: TextStyle(color: completed ? Colors.grey[500] : Colors.grey[300]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: completed ? Colors.grey[700]! : Colors.grey[600]!),
                  ),
                  isDense: true,
                ),
                onChanged: (val) {
                  final original = item.fields[entry.key];
                  if (original is int) {
                    item.fields[entry.key] = int.tryParse(val) ?? 0;
                  } else if (original is double) {
                    item.fields[entry.key] = double.tryParse(val) ?? 0.0;
                  } else {
                    item.fields[entry.key] = val;
                  }
                },
              ),
            );
          }),
          SizedBox(height: 4),
          ElevatedButton.icon(
            icon: _loadingResources.contains(item.id)
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.search),
            label: Text('Find Education'),
            onPressed: _loadingResources.contains(item.id) ? null : () => _findEducation(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.blue[900],
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (item.resources.isNotEmpty) ...[
            SizedBox(height: 12),
            Text('Resources:', style: TextStyle(color: sectionLabelColor, fontWeight: FontWeight.bold)),
            ...item.resources.map((r) => Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(r.url);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, size: 14, color: resourceTitleColor),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                r.title,
                                style: TextStyle(fontSize: 13, color: resourceTitleColor, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        if (r.description != null && r.description!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 18, top: 2),
                            child: Text(r.description!, style: TextStyle(color: resourceDescColor, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedSkillTile(PlanItem skill) {
    final completed = skill.completed;
    return Container(
      margin: EdgeInsets.only(left: 32, right: 8, bottom: 4),
      decoration: BoxDecoration(
        color: completed ? Color(0xFF3A3A3A) : Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: completed ? Colors.grey[700]! : Colors.grey[600]!, width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Checkbox(
              value: completed,
              onChanged: (_) => _toggleLinkedSkillCompleted(skill),
              checkColor: Colors.white,
              activeColor: Colors.green[700],
              side: BorderSide(color: completed ? Colors.grey[500]! : Colors.white70),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            title: Text(
              skill.name,
              style: TextStyle(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? Colors.grey[500] : Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _buildTagChip(skill.fields['tag'] as String? ?? 'other', completed: completed),
            ),
            trailing: IconButton(
              icon: Icon(
                _expandedId == skill.id ? Icons.expand_less : Icons.expand_more,
                color: completed ? Colors.grey[500] : Colors.white70,
                size: 20,
              ),
              onPressed: () => _toggleExpanded(skill.id),
            ),
          ),
          if (_expandedId == skill.id)
            _buildExpandedView(skill, completed),
        ],
      ),
    );
  }

  Widget _buildTopLevelCard(PlanItem item, int topLevelIndex) {
    final isExpanded = _expandedId == item.id;
    final completed = item.completed;
    final isActive = item.isActive;
    final linkedSkills = item.linkedSkillIds
        .map((id) => _itemById(id))
        .where((s) => s != null)
        .cast<PlanItem>()
        .toList();

    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      color: completed ? const Color(0xFF424242) : (isActive ? const Color(0xFF1A3A4A) : const Color(0xFF303030)),
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue[400]!, width: 2),
            )
          : null,
      child: Column(
        children: [
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: topLevelIndex,
                  child: Icon(Icons.drag_handle, color: completed ? Colors.grey[600] : Colors.grey[400]),
                ),
                const SizedBox(width: 4),
                Checkbox(
                  value: completed,
                  onChanged: (_) => _toggleCompleted(item),
                  checkColor: Colors.white,
                  activeColor: Colors.green[700],
                  side: BorderSide(color: completed ? Colors.grey[500]! : Colors.white70),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? Colors.grey[500] : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isActive && !completed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: _buildSubtitleChips(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!completed)
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.star : Icons.star_border,
                      color: isActive ? Colors.amber : Colors.grey[500],
                      size: 22,
                    ),
                    onPressed: () => _toggleActive(item),
                    tooltip: isActive ? 'Remove from active' : 'Set as active goal',
                  ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: completed ? Colors.grey[500] : Colors.white70,
                  ),
                  onPressed: () => _toggleExpanded(item.id),
                ),
              ],
            ),
          ),
          if (isExpanded)
            _buildExpandedView(item, completed),
          // Show linked skills nested under this item
          if (linkedSkills.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 24, bottom: 4, top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Skills covered:',
                  style: TextStyle(
                    color: completed ? Colors.grey[500] : Colors.grey[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...linkedSkills.map((skill) => _buildLinkedSkillTile(skill)),
            SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    final total = _plan!.items.length;
    final completed = _plan!.items.where((i) => i.completed).length;
    final activeItem = _plan!.items.where((i) => i.isActive).firstOrNull;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed / $total completed',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
          ),
          if (activeItem != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active: ${activeItem.name}',
                    style: TextStyle(color: Colors.blue[200], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showAddStepDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Add Step', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[400]!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[400]!),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final newItem = PlanItem(
                id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                type: 'skill',
                name: name,
                description: descController.text.trim(),
                fields: {'tag': 'other'},
              );

              setState(() {
                _plan!.items.add(newItem);
              });
              _savePlan();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final topLevel = _topLevelItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan: ${_plan!.goal}'),
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              itemCount: topLevel.length,
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                return _buildTopLevelCard(topLevel[index], index);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Card(
              color: const Color(0xFF303030),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue[400]!, width: 1, style: BorderStyle.solid),
              ),
              child: InkWell(
                onTap: _showAddStepDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.blue[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Add Step',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
