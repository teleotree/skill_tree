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
│   ├── gemini_service.dart    # Backend API client (proxies to Gemini)
│   ├── device_service.dart    # Device ID generation/storage
│   ├── plan_service.dart      # SharedPreferences plan storage
│   ├── career_cache_service.dart
│   └── history_service.dart
└── widgets/               # Reusable UI components

backend/                   # Cloudflare Worker backend
├── src/index.ts          # Worker entry point
├── wrangler.toml         # Cloudflare configuration
└── package.json          # Node dependencies
```

**Key patterns:**
- `MainNavScreen` manages bottom navigation with nested navigators per tab
- All persistence uses SharedPreferences (plans stored as JSON)
- Backend proxy handles API key security and rate limiting
- Device ID (UUID v4) sent via X-Device-ID header for rate limiting

## Backend Service

Cloudflare Worker backend (`backend/`) proxies requests to Google Gemini API:
- **Rate limiting:** 5/min, 30/hour, 100/day per device
- **Endpoints:**
  - POST /api/skill-tree - Generate skill trees
  - POST /api/skill-proposal - Get skill proposals
  - POST /api/gap-analysis - Perform gap analysis
  - POST /api/education-resources - Get learning resources

**Deployment:**
```bash
cd backend
npm install
npx wrangler login
npx wrangler kv:namespace create RATE_LIMIT
npx wrangler secret put GEMINI_API_KEY
npm run deploy
```

## Running the App

After deploying the backend, update API_BASE_URL when running:
```bash
flutter run --dart-define=API_BASE_URL=https://skill-tree-api.YOUR_SUBDOMAIN.workers.dev
```

## Development Tools

`tools/prompt_tester.dart` - CLI tool for testing Gemini prompts (logs to `tools/prompt_log.json`)
