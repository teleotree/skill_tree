import 'package:flutter/material.dart';
import '../models/models.dart';

class ExperienceDetailScreen extends StatelessWidget {
  final ExperienceNode experience;

  const ExperienceDetailScreen({Key? key, required this.experience}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(experience.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.teal[900], borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF00897B), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(experience.description, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 12),
                Text(
                  '${experience.yearsRequired} years required',
                  style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          if (experience.breakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Breakdown', style: TextStyle(color: Colors.tealAccent[400], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...experience.breakdown.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('  \u2022  ', style: TextStyle(color: Colors.tealAccent[400], fontSize: 14)),
                  Expanded(child: Text(b, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
