# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter admin dashboard for the Longeviva healthcare platform. Manages professional signup requests (approve/reject), user management, and admin authentication. Targets web primarily, with mobile/desktop support.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (web)
flutter run -d chrome

# Build
flutter build web
flutter build apk

# Lint
flutter analyze

# Tests
flutter test
flutter test test/specific_test.dart  # single test file

# Firebase functions (in my-firebase-functions/functions/)
npm run serve    # local emulator
npm run deploy   # deploy to Firebase
```

## Architecture

**Pattern:** UI → BLoC → Controller → Repository → Firebase

```
lib/
├── main.dart                          # Entry, Firebase init, BLoC providers, routing
├── backend/
│   ├── bloc/                          # State management (BLoC pattern)
│   │   ├── admin_auth_bloc.dart
│   │   ├── admin_bloc.dart
│   │   └── signup_request_bloc.dart   # Most complex BLoC — handles approval workflow
│   ├── controllers/                   # Business logic
│   │   ├── admin_controller.dart
│   │   └── signup_request_controller.dart
│   ├── models/                        # Data models
│   │   ├── signup_request_model.dart  # Core model for professional signup requests
│   │   └── doctor/
│   │       ├── doctor_model.dart
│   │       └── sign_up_data.dart
│   ├── repositories/                  # Firestore access layer
│   └── services/                      # External services (auth, email, dialogs)
├── frontend/
│   ├── auth/auth_wrapper.dart         # Auth-gated routing
│   └── screens/admin_dashboard/
│       ├── landing_page/              # Screen-level widgets
│       ├── view_model/                # Responsive split: *_large_screen_* / *_small_screen_*
│       └── widgets/                   # Reusable dashboard widgets
└── shared/
    ├── config/environment_config.dart # Dev vs prod DB selection (singleton)
    ├── localization/                  # i18n via JSON files + BLoC
    └── utils/                         # Colors, sizes, error handler
```

**Responsive design:** Breakpoint at 1100px width. Every screen has two view models: `*_large_screen_view_model.dart` and `*_small_screen_view_model.dart`. The landing page selects between them with `LayoutBuilder`.

## Firebase & Environment

- **Firestore collections:** `signup_requests`, `doctors`, `patients`, `admin_profiles`, `admins`
- **Dev DB:** `longeviva-web-app-dev-sviluppo` (enabled via `.env` with `USE_DEV_DB=true`)
- **Prod DB:** default Firebase instance (`longeviva-web-app-dev`)
- **Cloud Functions:** `my-firebase-functions/functions/index.js` — `createAdminUser` handles admin user creation with custom claims

Admin authentication uses a 3-method fallback: `admin_profiles` collection → `admins` collection → custom Firebase claims (or `doctors` with ADMIN role on Windows). Sessions last 8 hours; "Remember Me" persists via `flutter_secure_storage`.

## Localization

Translation files: `assets/lang/it.json` and `assets/lang/en.json`. Use the `.tr(context)` extension from `translation_extension.dart`. Language switching is handled by `LanguageBloc`. Always add new strings to both JSON files.

## Key Models

### SignupRequest (`signup_request_model.dart`)

Supports multiple roles per applicant. Has backward-compatible `role` (single, legacy) alongside `roles` (list, current). Helper getters: `isNutritionist`, `isPersonalTrainer`, `isPsychologist`, `professionalRegistrationNumber`, `formattedHourlyFees`.

**Role strings in Firestore:** `'NUTRITIONIST'`, `'PERSONAL TRAINER'`, `'PSYCHOLOGIST'`

**Display names (current, per admin panel UI spec):**
- `NUTRITIONIST` → "Professionista salute alimentare"
- `PERSONAL TRAINER` → "Professionista salute motoria"
- `PSYCHOLOGIST` → "Professionista salute mentale"

### Professional Registration Fields

The signup form collects certification data with two fields:
- `registrationEntityType`: `'universita'` | `'ente'` | `'attestato'` (dropdown: Laurea / Tesserino / Attestato)
- `registrationValue`: free text for the issuing institution

These replace the old `numero_iscrizione_albo`, `numero_iscrizione_ente`, and `issuer` fields. Old Firestore documents still use the legacy field names — keep backward compatibility when reading.

## Colors & Theming

Defined in `shared/utils/colors.dart`. Primary palette:
- Verde Abisso: `#025861` (primary)
- Verde Tropicale: `#59B69B`, Verde Mare: `#75C0AC`
- Menta Fredda: `#C4F0E5` (accent)
- Rosso Simone: `#EA4335` (error)

Fonts: Montserrat (headings), Nunito (body).
