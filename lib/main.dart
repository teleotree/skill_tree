import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'Skill Tree',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      textTheme: GoogleFonts.interTextTheme(),
    ),
    home: MainNavScreen(),
  ));
}
