import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skill_tree/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen()));

    expect(find.text('Enter Your Goal'), findsOneWidget);
    expect(find.text('Show Skill Tree'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
