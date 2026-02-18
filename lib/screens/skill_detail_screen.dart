import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../widgets/skill_tag_chip.dart';

class SkillDetailScreen extends StatelessWidget {
  final SkillNode skill;

  const SkillDetailScreen({Key? key, required this.skill}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(skill.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkillTagChip(tag: skill.tag),
                const SizedBox(height: 12),
                Text(
                  skill.description.isNotEmpty ? skill.description : 'This skill is essential for achieving your goal.',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
          if (skill.resources.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Resources', style: TextStyle(color: Colors.blue[200], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...skill.resources.map((r) => Card(
              color: Colors.grey[850],
              child: ListTile(
                title: Text(r.title, style: TextStyle(color: Colors.blue[200])),
                subtitle: r.description != null ? Text(r.description!, style: const TextStyle(color: Colors.white70, fontSize: 12)) : null,
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () async {
                  final uri = Uri.tryParse(r.url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            )),
          ],
          if (skill.subskills.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Subskills', style: TextStyle(color: Colors.blue[200], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...skill.subskills.map((sub) => Card(
              color: Colors.grey[850],
              child: ExpansionTile(
                title: Row(
                  children: [
                    Expanded(child: Text(sub.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                    SkillTagChip(tag: sub.tag),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.description.isNotEmpty ? sub.description : 'A subskill of ${skill.name}.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (sub.resources.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...sub.resources.map((r) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () async {
                                final uri = Uri.tryParse(r.url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 14, color: Colors.blue[200]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      r.title,
                                      style: TextStyle(fontSize: 13, color: Colors.blue[200], decoration: TextDecoration.underline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
