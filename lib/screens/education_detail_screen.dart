import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';

class EducationDetailScreen extends StatefulWidget {
  final EducationNode education;

  const EducationDetailScreen({Key? key, required this.education}) : super(key: key);

  @override
  State<EducationDetailScreen> createState() => _EducationDetailScreenState();
}

class _EducationDetailScreenState extends State<EducationDetailScreen> {
  List<Resource>? _resources;
  bool _loadingResources = false;

  Future<void> _findResources() async {
    setState(() => _loadingResources = true);
    try {
      final item = PlanItem(
        id: 'temp',
        type: 'education',
        name: widget.education.name,
        description: widget.education.description,
        fields: {'type': widget.education.type, 'years': widget.education.years},
      );
      final resources = await fetchEducationResources(item);
      if (mounted) setState(() => _resources = resources);
    } on GeminiRateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch resources.')));
      }
    } finally {
      if (mounted) setState(() => _loadingResources = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edu = widget.education;
    return Scaffold(
      appBar: AppBar(title: Text(edu.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.indigo[900], borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeChip(edu.type),
                const SizedBox(height: 12),
                Text(edu.description, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 12),
                Text('${edu.years} years', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                if (edu.prerequisites.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Prerequisites:', style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(edu.prerequisites, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ],
            ),
          ),
          if (edu.options.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Options', style: TextStyle(color: Colors.indigo[200], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...edu.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo[200]!, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Option ${String.fromCharCode(65 + idx)}', style: TextStyle(color: Colors.indigo[200], fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(option.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(option.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${option.years} years', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (option.prerequisites.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Prerequisites: ${option.prerequisites}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    if (option.links.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...option.links.map((r) => _buildLinkRow(r)),
                    ],
                  ],
                ),
              );
            }),
          ],
          if (edu.links.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Links', style: TextStyle(color: Colors.indigo[200], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...edu.links.map((r) => _buildLinkRow(r)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: _loadingResources
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: const Text('Find Resources'),
            onPressed: _loadingResources ? null : _findResources,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_resources != null && _resources!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Resources', style: TextStyle(color: Colors.blue[200], fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ..._resources!.map((r) => Card(
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
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isD = type == 'degree';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isD ? const Color(0xFF3F51B5) : const Color(0xFFFF7043),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isD ? Icons.school : Icons.verified, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(isD ? 'Degree' : 'Certification', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLinkRow(Resource r) {
    return Padding(
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
                r.title.isNotEmpty ? r.title : r.url,
                style: TextStyle(fontSize: 13, color: Colors.blue[200], decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
