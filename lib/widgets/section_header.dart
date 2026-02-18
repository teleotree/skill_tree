import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const SectionHeader({Key? key, required this.title, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sectionTitleColor = color
        ?? Theme.of(context).inputDecorationTheme.labelStyle?.color
        ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: sectionTitleColor,
        ),
      ),
    );
  }
}
