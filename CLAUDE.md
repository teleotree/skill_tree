# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Skill Tree is a Flutter mobile application for career exploration and skill development planning. It uses Google Gemini AI to generate skill trees for various career paths, helping users visualize education/experience requirements and create learning plans.

**Stack:** Flutter 3.38.9 / Dart 3.10.8

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Run linter (uses flutter_lints)
flutter test             # Run widget tests
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build ios        # Build iOS app
```

## Architecture

**Two-tab navigation app:**
- **Explore tab** - Search careers/skills, view detailed skill trees
- **Next Step tab** - Manage personalized learning plans

**Directory structure:**
```
lib/
├── main.dart              # App entry, MaterialApp with GoogleFonts theme
├── models/                # Data models (SkillTreeResponse, SkillNode, Plan, etc.)
├── screens/               # UI screens (MainNavScreen is root navigation)
├── services/              # Business logic
│   ├── gemini_service.dart    # Google Gemini API integration
│   ├── plan_service.dart      # SharedPreferences plan storage
│   ├── career_cache_service.dart
│   └── history_service.dart
└── widgets/               # Reusable UI components
```

**Key patterns:**
- `MainNavScreen` manages bottom navigation with nested navigators per tab
- All persistence uses SharedPreferences (plans stored as JSON)
- No backend server - Gemini API called directly from app

## API Integration

Uses Google Gemini 2.5 Flash model for AI-generated career guidance:
- API key loaded from `.env` file (GEMINI_API_KEY)
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
- Service: `lib/services/gemini_service.dart`

## Development Tools

`tools/prompt_tester.dart` - CLI tool for testing Gemini prompts (logs to `tools/prompt_log.json`)
