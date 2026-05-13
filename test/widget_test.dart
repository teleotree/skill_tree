import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skill_tree/screens/main_nav_screen.dart';

void main() {
  testWidgets('MainNavScreen renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: MainNavScreen()));

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
