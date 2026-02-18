import 'package:flutter/material.dart';

class SkillTagChip extends StatelessWidget {
  final String tag;
  final VoidCallback? onTap;

  const SkillTagChip({Key? key, required this.tag, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData icon;
    String label;
    String tooltip;
    switch (tag) {
      case 'degree':
        bgColor = const Color(0xFF3F51B5);
        icon = Icons.school;
        label = 'Degree';
        tooltip = 'Skill learned as part of a formal degree program';
        break;
      case 'certification':
        bgColor = const Color(0xFFFF7043);
        icon = Icons.verified;
        label = 'Certification';
        tooltip = 'Skill learned as part of a professional certification';
        break;
      case 'experience':
        bgColor = const Color(0xFF00897B);
        icon = Icons.work;
        label = 'Experience';
        tooltip = 'Skill learned primarily through work experience';
        break;
      case 'informal':
      default:
        bgColor = const Color(0xFF43A047);
        icon = Icons.lightbulb;
        label = 'Other';
        tooltip = 'Skill learned outside formal education/certification/experience';
        break;
    }
    return InkWell(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tooltip), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
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
}
