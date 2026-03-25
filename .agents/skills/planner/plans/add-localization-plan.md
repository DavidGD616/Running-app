# Plan: Add Full App Localization (EN/ES)

**Generated**: 2026-03-23
**Estimated Complexity**: Medium

---

## Overview

Add English and Spanish localization to the entire RunFlow app using Flutter's official `flutter_gen_l10n` toolchain (ARB files). On first launch, the app auto-detects the device locale and defaults to Spanish if the device is in Spanish, otherwise English. The user can manually override the language via the existing toggle on the welcome screen (and later from a settings screen). The override persists across sessions using SharedPreferences.

**Approach**:
1. Set up the Flutter localization infrastructure (packages, ARB files, generated code)
2. Create a Riverpod `AsyncNotifier` provider for locale state (matching existing app patterns)
3. Wire `MaterialApp.router` to consume the locale provider
4. Connect the welcome screen toggle to the provider
5. Audit and translate every screen string — auth, onboarding, account setup, home

**State management recommendation**: Use `AsyncNotifier<Locale>` (same pattern as `user_preferences_provider.dart`). It handles the async SharedPreferences read on startup cleanly, is consistent with the codebase, and Riverpod will automatically show a loading state while the locale is being read from disk.

---

## Prerequisites

- Flutter SDK installed (already set up)
- `shared_preferences: ^2.3.0` already in `pubspec.yaml` ✅
- `flutter_riverpod: ^2.6.1` already in `pubspec.yaml` ✅
- Working directory for all tasks: `apps/mobile/`

---

## Sprint 1: Infrastructure Setup

**Goal**: Add localization packages, create the ARB translation files, generate the Dart localization class, and confirm code generation works. No UI changes yet — just the foundation.

**Demo/Validation**:
- Run `flutter gen-l10n` in `apps/mobile/` — no errors
- A file appears at `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`
- Importing `app_localizations.dart` in any file does not cause a compile error

---

### Task 1.1: Add localization packages to pubspec.yaml

- **Location**: `apps/mobile/pubspec.yaml`
- **Description**: Add `flutter_localizations` (Flutter SDK package) and `intl`, and enable code generation.
- **Dependencies**: None
- **What to do**:
  1. Under `dependencies:`, add:
     ```yaml
     flutter_localizations:
       sdk: flutter
     intl: ^0.19.0
     ```
  2. Under the `flutter:` section (at the bottom of the file), add:
     ```yaml
     flutter:
       generate: true   # add this line — enables flutter gen-l10n
       uses-material-design: true
       # ... rest of existing config
     ```
- **Acceptance Criteria**:
  - `pubspec.yaml` has `flutter_localizations` and `intl` under dependencies
  - `generate: true` is under the `flutter:` section
- **Validation**:
  - Run `flutter pub get` in `apps/mobile/` — no errors

---

### Task 1.2: Create l10n.yaml configuration file

- **Location**: `apps/mobile/l10n.yaml` (new file, at the same level as `pubspec.yaml`)
- **Description**: This file tells Flutter where your translation files live and what to generate.
- **Dependencies**: Task 1.1
- **What to create**:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  ```
- **Acceptance Criteria**:
  - File exists at `apps/mobile/l10n.yaml`
- **Validation**:
  - The file is readable and YAML-valid (no indentation errors)

---

### Task 1.3: Create the English ARB template file

- **Location**: `apps/mobile/lib/l10n/app_en.arb` (new file and new folder)
- **Description**: This is the master translation file. Every string in the app gets a key here. The `@key` metadata entries are required in the English template. Start with **all strings for the entire app** — we'll fill in the Spanish equivalents in Task 1.4.

  > **Beginner tip**: ARB keys use `camelCase`. Each key has a matching `@key` entry with a `description`. That description is only needed in the English template file — it documents what the string is used for.

- **Dependencies**: Task 1.2
- **What to create**:

  ```json
  {
    "@@locale": "en",

    "appTitle": "RunFlow",
    "@appTitle": { "description": "App name" },

    "languageCode": "EN",
    "@languageCode": { "description": "Short code shown on the language toggle button" },

    "welcomeTitle": "Welcome to RunFlow",
    "@welcomeTitle": { "description": "Main heading on the welcome screen" },

    "welcomeSubtitle": "Your personal running coach. Build a plan tailored to your goals, fitness level, and schedule.",
    "@welcomeSubtitle": { "description": "Subtitle on the welcome screen" },

    "welcomeFeature1": "Personalized training plans",
    "@welcomeFeature1": { "description": "First feature bullet on welcome screen" },

    "welcomeFeature2": "AI-powered progression",
    "@welcomeFeature2": { "description": "Second feature bullet on welcome screen" },

    "welcomeFeature3": "Flexible scheduling",
    "@welcomeFeature3": { "description": "Third feature bullet on welcome screen" },

    "createAccount": "Create Account",
    "@createAccount": { "description": "Primary CTA button on welcome screen and sign up screen" },

    "logIn": "Log In",
    "@logIn": { "description": "Log in button label" },

    "signUpTitle": "Create your account",
    "@signUpTitle": { "description": "Heading on the sign up screen" },

    "signUpSubtitle": "Start your running journey today",
    "@signUpSubtitle": { "description": "Subtitle on the sign up screen" },

    "fullName": "Full Name",
    "@fullName": { "description": "Full name field label" },

    "email": "Email",
    "@email": { "description": "Email field label" },

    "password": "Password",
    "@password": { "description": "Password field label" },

    "alreadyHaveAccount": "Already have an account?",
    "@alreadyHaveAccount": { "description": "Sign up screen prompt to log in" },

    "logInTitle": "Welcome back",
    "@logInTitle": { "description": "Heading on the log in screen" },

    "logInSubtitle": "Sign in to continue your training",
    "@logInSubtitle": { "description": "Subtitle on the log in screen" },

    "forgotPassword": "Forgot password?",
    "@forgotPassword": { "description": "Forgot password link" },

    "dontHaveAccount": "Don't have an account?",
    "@dontHaveAccount": { "description": "Log in screen prompt to sign up" },

    "forgotPasswordTitle": "Reset your password",
    "@forgotPasswordTitle": { "description": "Heading on the forgot password screen" },

    "forgotPasswordSubtitle": "Enter your email and we'll send you a reset link",
    "@forgotPasswordSubtitle": { "description": "Subtitle on the forgot password screen" },

    "sendResetLink": "Send Reset Link",
    "@sendResetLink": { "description": "Button on forgot password screen" },

    "backToLogIn": "Back to Log In",
    "@backToLogIn": { "description": "Back link on forgot password screen" },

    "continueButton": "Continue",
    "@continueButton": { "description": "Generic continue button label" },

    "backButton": "Back",
    "@backButton": { "description": "Generic back button label" },

    "skipButton": "Skip",
    "@skipButton": { "description": "Generic skip button label" },

    "onboardingIntroTitle": "Let's build your plan",
    "@onboardingIntroTitle": { "description": "Heading on the onboarding intro screen" },

    "onboardingIntroSubtitle": "Answer a few questions so we can create a training plan tailored just for you.",
    "@onboardingIntroSubtitle": { "description": "Subtitle on the onboarding intro screen" },

    "getStarted": "Get Started",
    "@getStarted": { "description": "CTA button on the onboarding intro screen" },

    "goalTitle": "What's your running goal?",
    "@goalTitle": { "description": "Heading on the goal screen" },

    "goalSubtitle": "Pick the goal that best describes what you're working toward.",
    "@goalSubtitle": { "description": "Subtitle on the goal screen" },

    "fitnessTitle": "What's your current fitness level?",
    "@fitnessTitle": { "description": "Heading on the current fitness screen" },

    "fitnessSubtitle": "Be honest — this helps us set the right starting point.",
    "@fitnessSubtitle": { "description": "Subtitle on the current fitness screen" },

    "scheduleTitle": "How many days a week can you train?",
    "@scheduleTitle": { "description": "Heading on the schedule screen" },

    "scheduleSubtitle": "Choose a number that feels sustainable, not just ambitious.",
    "@scheduleSubtitle": { "description": "Subtitle on the schedule screen" },

    "healthTitle": "Any injuries or health concerns?",
    "@healthTitle": { "description": "Heading on the health & injury screen" },

    "healthSubtitle": "This helps us avoid movements that could cause discomfort.",
    "@healthSubtitle": { "description": "Subtitle on the health & injury screen" },

    "noneLabel": "None",
    "@noneLabel": { "description": "Option label meaning no injuries/concerns" },

    "trainingPrefsTitle": "Training preferences",
    "@trainingPrefsTitle": { "description": "Heading on the training preferences screen" },

    "trainingPrefsSubtitle": "Tell us how you like to train.",
    "@trainingPrefsSubtitle": { "description": "Subtitle on the training preferences screen" },

    "watchTitle": "Connect your device",
    "@watchTitle": { "description": "Heading on the watch/device screen" },

    "watchSubtitle": "Sync your wearable for automatic tracking.",
    "@watchSubtitle": { "description": "Subtitle on the watch/device screen" },

    "watchSkip": "I'll connect later",
    "@watchSkip": { "description": "Skip option on the watch/device screen" },

    "recoveryTitle": "Recovery & lifestyle",
    "@recoveryTitle": { "description": "Heading on the recovery & lifestyle screen" },

    "recoverySubtitle": "Good recovery is part of great training.",
    "@recoverySubtitle": { "description": "Subtitle on the recovery & lifestyle screen" },

    "motivationTitle": "What motivates you?",
    "@motivationTitle": { "description": "Heading on the motivation screen" },

    "motivationSubtitle": "Pick what drives you — we'll remind you on hard days.",
    "@motivationSubtitle": { "description": "Subtitle on the motivation screen" },

    "summaryTitle": "Here's your profile",
    "@summaryTitle": { "description": "Heading on the summary screen" },

    "summarySubtitle": "Review your answers before we generate your plan.",
    "@summarySubtitle": { "description": "Subtitle on the summary screen" },

    "generatePlan": "Generate My Plan",
    "@generatePlan": { "description": "CTA button to start plan generation" },

    "planGenerationTitle": "Building your plan...",
    "@planGenerationTitle": { "description": "Heading on the plan generation loading screen" },

    "planGenerationSubtitle": "This only takes a moment.",
    "@planGenerationSubtitle": { "description": "Subtitle on the plan generation screen" },

    "accountSetupTitle": "Set up your account",
    "@accountSetupTitle": { "description": "Heading on the account setup screen" },

    "accountSetupSubtitle": "A few more details to personalize your experience.",
    "@accountSetupSubtitle": { "description": "Subtitle on the account setup screen" },

    "homeTitle": "Today's Plan",
    "@homeTitle": { "description": "Heading on the home screen" },

    "homeSubtitle": "Here's what's on your schedule.",
    "@homeSubtitle": { "description": "Subtitle on the home screen" },

    "settingsLanguage": "Language",
    "@settingsLanguage": { "description": "Language label in settings (future use)" },

    "errorGeneric": "Something went wrong. Please try again.",
    "@errorGeneric": { "description": "Generic error message" }
  }
  ```

  > **Note**: Some string values above are reasonable defaults. You **must** open each screen file and verify the exact text used, then update the ARB values to match exactly.

- **Acceptance Criteria**:
  - `lib/l10n/app_en.arb` exists and is valid JSON
  - Every key has a matching `@key` metadata entry
- **Validation**:
  - Paste the file contents into a JSON validator (e.g., jsonlint.com) — no errors

---

### Task 1.4: Create the Spanish ARB translation file

- **Location**: `apps/mobile/lib/l10n/app_es.arb` (new file)
- **Description**: Spanish translations for every key defined in `app_en.arb`. The `@key` metadata entries are **not** needed here — only the translated strings.
- **Dependencies**: Task 1.3
- **What to create**:

  ```json
  {
    "@@locale": "es",

    "appTitle": "RunFlow",
    "languageCode": "ES",

    "welcomeTitle": "Bienvenido a RunFlow",
    "welcomeSubtitle": "Tu entrenador personal de running. Crea un plan adaptado a tus objetivos, nivel de forma física y horario.",
    "welcomeFeature1": "Planes de entrenamiento personalizados",
    "welcomeFeature2": "Progresión potenciada por IA",
    "welcomeFeature3": "Horarios flexibles",
    "createAccount": "Crear cuenta",
    "logIn": "Iniciar sesión",

    "signUpTitle": "Crea tu cuenta",
    "signUpSubtitle": "Comienza tu camino de running hoy",
    "fullName": "Nombre completo",
    "email": "Correo electrónico",
    "password": "Contraseña",
    "alreadyHaveAccount": "¿Ya tienes una cuenta?",

    "logInTitle": "Bienvenido de nuevo",
    "logInSubtitle": "Inicia sesión para continuar tu entrenamiento",
    "forgotPassword": "¿Olvidaste tu contraseña?",
    "dontHaveAccount": "¿No tienes una cuenta?",

    "forgotPasswordTitle": "Restablecer contraseña",
    "forgotPasswordSubtitle": "Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña",
    "sendResetLink": "Enviar enlace",
    "backToLogIn": "Volver a iniciar sesión",

    "continueButton": "Continuar",
    "backButton": "Atrás",
    "skipButton": "Omitir",

    "onboardingIntroTitle": "Construyamos tu plan",
    "onboardingIntroSubtitle": "Responde algunas preguntas para que podamos crear un plan de entrenamiento hecho justo para ti.",
    "getStarted": "Comenzar",

    "goalTitle": "¿Cuál es tu objetivo de running?",
    "goalSubtitle": "Elige el objetivo que mejor describe lo que quieres lograr.",

    "fitnessTitle": "¿Cuál es tu nivel de forma física actual?",
    "fitnessSubtitle": "Sé honesto — esto nos ayuda a establecer el punto de partida correcto.",

    "scheduleTitle": "¿Cuántos días a la semana puedes entrenar?",
    "scheduleSubtitle": "Elige un número que se sienta sostenible, no solo ambicioso.",

    "healthTitle": "¿Tienes lesiones o problemas de salud?",
    "healthSubtitle": "Esto nos ayuda a evitar movimientos que puedan causar molestias.",
    "noneLabel": "Ninguno",

    "trainingPrefsTitle": "Preferencias de entrenamiento",
    "trainingPrefsSubtitle": "Cuéntanos cómo te gusta entrenar.",

    "watchTitle": "Conecta tu dispositivo",
    "watchSubtitle": "Sincroniza tu wearable para seguimiento automático.",
    "watchSkip": "Lo conectaré más tarde",

    "recoveryTitle": "Recuperación y estilo de vida",
    "recoverySubtitle": "Una buena recuperación es parte de un gran entrenamiento.",

    "motivationTitle": "¿Qué te motiva?",
    "motivationSubtitle": "Elige lo que te impulsa — te lo recordaremos en los días difíciles.",

    "summaryTitle": "Tu perfil",
    "summarySubtitle": "Revisa tus respuestas antes de que generemos tu plan.",
    "generatePlan": "Generar mi plan",

    "planGenerationTitle": "Construyendo tu plan...",
    "planGenerationSubtitle": "Solo tarda un momento.",

    "accountSetupTitle": "Configura tu cuenta",
    "accountSetupSubtitle": "Algunos detalles más para personalizar tu experiencia.",

    "homeTitle": "Plan de hoy",
    "homeSubtitle": "Esto es lo que tienes en tu agenda.",

    "settingsLanguage": "Idioma",

    "errorGeneric": "Algo salió mal. Por favor intenta de nuevo."
  }
  ```

- **Acceptance Criteria**:
  - `lib/l10n/app_es.arb` exists and is valid JSON
  - Every key from `app_en.arb` has a Spanish translation here
- **Validation**:
  - Same key count in both files (run `grep -c '"@' app_en.arb` and `grep -c '":' app_es.arb` to compare)

---

### Task 1.5: Run code generation and verify output

- **Location**: Terminal, inside `apps/mobile/`
- **Description**: Trigger Flutter's localization code generator to produce the `AppLocalizations` Dart class.
- **Dependencies**: Tasks 1.1–1.4
- **What to do**:
  ```bash
  cd apps/mobile
  flutter gen-l10n
  ```
- **Acceptance Criteria**:
  - Command exits with no errors
  - File exists: `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`
  - File exists: `.dart_tool/flutter_gen/gen_l10n/app_localizations_en.dart`
  - File exists: `.dart_tool/flutter_gen/gen_l10n/app_localizations_es.dart`
- **Validation**:
  - Run `flutter pub get && flutter analyze` — no errors related to localization

---

## Sprint 2: Locale Provider + MaterialApp Wiring

**Goal**: Create the Riverpod locale provider, connect it to `MaterialApp.router`, and verify that the app compiles and respects locale changes at the `MaterialApp` level. No UI toggle changes yet.

**Demo/Validation**:
- Run the app — it launches without errors
- Temporarily hardcode `const Locale('es')` in the provider and verify the app compiles (even if no strings are translated yet)
- Revert to auto-detect logic after verifying

---

### Task 2.1: Create the locale provider

- **Location**: `apps/mobile/lib/features/localization/presentation/locale_provider.dart` (new file and folder)
- **Description**: A Riverpod `AsyncNotifier` that reads the saved locale from SharedPreferences on startup, falls back to device locale detection (ES or EN only), and exposes a `setLocale()` method to update and persist the locale.
- **Dependencies**: Sprint 1 complete
- **Why `AsyncNotifier`**: SharedPreferences reads are async. Using `AsyncNotifier` mirrors the existing `user_preferences_provider.dart` pattern and handles the loading state automatically.
- **What to create**:

  ```dart
  import 'dart:ui';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  const _kLocaleKey = 'pref_locale';

  class LocaleNotifier extends AsyncNotifier<Locale> {
    @override
    Future<Locale> build() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLocaleKey);

      // If the user has previously set a language, use that
      if (saved != null) {
        return Locale(saved);
      }

      // First launch: detect device locale
      // PlatformDispatcher gives us the device's preferred locale
      final deviceLocale = PlatformDispatcher.instance.locale;
      if (deviceLocale.languageCode == 'es') {
        return const Locale('es');
      }

      // Default to English for all other languages
      return const Locale('en');
    }

    /// Call this when the user picks a language from the UI
    Future<void> setLocale(Locale locale) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, locale.languageCode);
      state = AsyncValue.data(locale);
    }
  }

  final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale>(
    LocaleNotifier.new,
  );
  ```

- **Acceptance Criteria**:
  - File compiles without errors
  - `localeProvider` is exported and importable
- **Validation**:
  - Run `flutter analyze` — no errors in this file

---

### Task 2.2: Update main.dart to consume the locale provider

- **Location**: `apps/mobile/lib/main.dart`
- **Description**: Convert `RunningApp` from a `StatelessWidget` to a `ConsumerWidget` so it can watch the locale provider. Pass the locale and all localization delegates to `MaterialApp.router`. Handle the async loading state gracefully (show default English locale while loading from disk).
- **Dependencies**: Task 2.1
- **What to change** (full updated `main.dart`):

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_localizations/flutter_localizations.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_gen/gen_l10n/app_localizations.dart';

  import 'core/router/app_router.dart';
  import 'core/theme/app_theme.dart';
  import 'features/localization/presentation/locale_provider.dart';

  void main() {
    runApp(const ProviderScope(child: RunningApp()));
  }

  class RunningApp extends ConsumerWidget {
    const RunningApp({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      // Watch the locale — rebuilds MaterialApp when the locale changes
      final localeAsync = ref.watch(localeProvider);

      // While locale is loading from disk, use English as a fallback
      // This prevents a flash of the wrong language on startup
      final locale = localeAsync.valueOrNull ?? const Locale('en');

      return MaterialApp.router(
        title: 'RunFlow',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,

        // Localization setup
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
      );
    }
  }
  ```

- **Acceptance Criteria**:
  - App compiles and runs without errors
  - `MaterialApp.router` has `locale`, `localizationsDelegates`, and `supportedLocales`
- **Validation**:
  - Run `flutter run` — app launches normally

---

## Sprint 3: Welcome Screen Toggle Integration

**Goal**: Wire the existing EN/ES toggle on the welcome screen to the locale provider, so tapping the toggle actually changes the app language and persists it. This is the first user-facing locale change.

**Demo/Validation**:
- Launch the app
- Tap "ES" on the toggle → the toggle animates (existing behavior)
- Verify that `localeProvider` state changes to `Locale('es')`
- Kill and relaunch the app → the locale is still Spanish
- Tap "EN" → reverts to English, persists on relaunch

---

### Task 3.1: Connect the toggle to the locale provider

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- **Description**: Replace the local `_selectedLanguage` state with the locale provider. When the user taps a language option, call `localeProvider.notifier.setLocale()`. Initialize the toggle's visual state from the provider.
- **Dependencies**: Task 2.1
- **What to change**:

  1. Convert `WelcomeScreen` from `StatefulWidget` to `ConsumerStatefulWidget` (or make it a `ConsumerWidget` if there's no other local state)
  2. Remove the `String _selectedLanguage = 'EN'` local state variable
  3. Derive `_selectedLanguage` from the locale provider:
     ```dart
     final locale = ref.watch(localeProvider).valueOrNull ?? const Locale('en');
     final selectedLanguage = locale.languageCode.toUpperCase(); // 'EN' or 'ES'
     ```
  4. In the toggle's `onTap` handler, call:
     ```dart
     final lang = option == 'EN' ? const Locale('en') : const Locale('es');
     ref.read(localeProvider.notifier).setLocale(lang);
     ```
  5. Pass `selectedLanguage` (derived from provider) into `_LanguageSwitcher` instead of the local state variable

- **Acceptance Criteria**:
  - Tapping the toggle calls `setLocale()` on the provider
  - The visual toggle state matches the current locale from the provider
  - No more local `_selectedLanguage` state variable
- **Validation**:
  - Toggle EN → ES → restart app → still ES
  - Toggle ES → EN → restart app → still EN

---

### Task 3.2: Translate welcome screen strings

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- **Description**: Replace all 7 hardcoded English strings with `AppLocalizations.of(context)!.keyName` calls.
- **Dependencies**: Sprint 1 complete, Task 3.1
- **String replacements**:

  | Current hardcoded string | ARB key |
  |---|---|
  | `"Welcome to RunFlow"` | `l10n.welcomeTitle` |
  | `"Your personal running coach..."` | `l10n.welcomeSubtitle` |
  | `"Personalized training plans"` | `l10n.welcomeFeature1` |
  | `"AI-powered progression"` | `l10n.welcomeFeature2` |
  | `"Flexible scheduling"` | `l10n.welcomeFeature3` |
  | `"Create Account"` | `l10n.createAccount` |
  | `"Log In"` | `l10n.logIn` |

- **How to use the localization object**:
  ```dart
  // Add this near the top of your build() method:
  final l10n = AppLocalizations.of(context)!;

  // Then use it:
  Text(l10n.welcomeTitle)
  ```

- **Acceptance Criteria**:
  - No hardcoded English strings remain on the welcome screen
  - Switching to ES shows Spanish text, switching to EN shows English text
- **Validation**:
  - Toggle EN/ES on the welcome screen and verify all 7 strings update instantly

---

## Sprint 4: Translate Auth Screens

**Goal**: Translate all remaining auth screens — splash, sign up, log in, forgot password.

**Demo/Validation**:
- Set language to ES
- Navigate through: Welcome → Log In → Forgot Password and Welcome → Sign Up
- All text appears in Spanish
- Set language to EN, repeat — all text in English

---

### Task 4.1: Translate splash_screen.dart

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/splash_screen.dart`
- **Description**: Open the file, identify all hardcoded strings, replace with ARB keys. If new strings are found that aren't in the ARB files, add them to both `app_en.arb` and `app_es.arb` first, then re-run `flutter gen-l10n`.
- **Dependencies**: Sprint 2 complete
- **Process for every screen in Sprints 4–7**:
  1. Read the screen file
  2. Find every hardcoded string (look for `"..."` inside `Text()`, `hint`, `label`, `title`, `message`, button labels)
  3. If the string has an ARB key → replace with `l10n.keyName`
  4. If the string is missing from ARB files → add it to both ARB files, run `flutter gen-l10n`, then replace
- **Validation**: Run app in ES mode, navigate to screen, verify Spanish text

### Task 4.2: Translate sign_up_screen.dart

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart`
- **Dependencies**: Task 4.1

### Task 4.3: Translate log_in_screen.dart

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/log_in_screen.dart`
- **Dependencies**: Task 4.1

### Task 4.4: Translate forgot_password_screen.dart

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart`
- **Dependencies**: Task 4.1

---

## Sprint 5: Translate Account Setup Screen

**Goal**: Translate the account setup screen.

**Demo/Validation**:
- With ES locale, complete the welcome screen and navigate to account setup
- All text appears in Spanish

### Task 5.1: Translate account_setup_screen.dart

- **Location**: `apps/mobile/lib/features/account_setup/presentation/screens/account_setup_screen.dart`
- **Description**: Same process as Sprint 4 tasks — read file, find hardcoded strings, replace with ARB keys. Add any missing keys to both ARB files first.
- **Dependencies**: Sprint 4 complete

---

## Sprint 6: Translate Onboarding Screens

**Goal**: Translate all 11 onboarding screens. This is the largest sprint due to volume — tackle one screen per task.

**Demo/Validation**:
- With ES locale, run through the complete onboarding flow (intro → goal → ... → plan generation)
- Every screen shows Spanish text
- Dynamic content (e.g., chip labels, option names) should also be translated

> **Note on dynamic option labels** (e.g., running goals like "5K", "Marathon"): If these labels come from hardcoded lists in the screen file, they need ARB keys too. If they come from a data model/enum, you may need to add a `toLocalizedString(BuildContext)` method to the model — the implementing task should note this.

### Task 6.1: Translate onboarding_intro_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/onboarding_intro_screen.dart`

### Task 6.2: Translate goal_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/goal_screen.dart`
- **Note**: Goal option labels (e.g., "Lose weight", "Run a 5K") are likely hardcoded — add ARB keys for each.

### Task 6.3: Translate current_fitness_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/current_fitness_screen.dart`

### Task 6.4: Translate schedule_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/schedule_screen.dart`

### Task 6.5: Translate health_injury_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/health_injury_screen.dart`
- **Note**: Injury options (e.g., "Knee pain", "None") need ARB keys.

### Task 6.6: Translate training_preferences_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/training_preferences_screen.dart`

### Task 6.7: Translate watch_device_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/watch_device_screen.dart`

### Task 6.8: Translate recovery_lifestyle_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/recovery_lifestyle_screen.dart`

### Task 6.9: Translate motivation_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/motivation_screen.dart`
- **Note**: Motivation option labels need ARB keys.

### Task 6.10: Translate summary_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/summary_screen.dart`
- **Note**: Summary labels (field names like "Goal", "Fitness Level") need ARB keys.

### Task 6.11: Translate plan_generation_screen.dart
- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart`

---

## Sprint 7: Translate Home Screen + Settings Hook

**Goal**: Translate the home screen and prepare the settings language hook so a future settings screen can change the locale using the same provider.

**Demo/Validation**:
- With ES locale, navigate to home screen — all text in Spanish
- Changing locale from welcome screen toggle still works end-to-end

### Task 7.1: Translate home_screen.dart

- **Location**: `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`
- **Dependencies**: Sprint 6 complete

### Task 7.2: Document the settings language hook

- **Location**: `apps/mobile/lib/features/localization/presentation/locale_provider.dart`
- **Description**: Add a comment block explaining how the future settings screen should use this provider. No code changes needed — just documentation for when the settings screen is built.
- **Comment to add**:
  ```dart
  // HOW TO USE FROM THE SETTINGS SCREEN:
  //
  // 1. Make your settings widget a ConsumerWidget (or ConsumerStatefulWidget)
  // 2. Read the current locale:
  //    final locale = ref.watch(localeProvider).valueOrNull;
  //    final isSpanish = locale?.languageCode == 'es';
  //
  // 3. When the user picks a language:
  //    ref.read(localeProvider.notifier).setLocale(const Locale('en'));
  //    ref.read(localeProvider.notifier).setLocale(const Locale('es'));
  //
  // That's all — the locale persists automatically.
  ```

---

## Testing Strategy

**Per sprint**:
- Sprint 1: `flutter gen-l10n` runs clean; `flutter analyze` passes
- Sprint 2: App runs with no errors; locale defaults to device language
- Sprint 3: Toggle on welcome screen changes and persists locale
- Sprints 4–7: Each screen verified in both EN and ES manually

**Key test scenarios**:
1. First launch, device in Spanish → app starts in Spanish
2. First launch, device in French → app starts in English
3. First launch, device in English → app starts in English
4. User toggles to ES → closes app → reopens → still ES
5. User toggles back to EN → closes app → reopens → still EN
6. Navigate entire onboarding flow in ES → all text is Spanish
7. Navigate entire onboarding flow in EN → all text is English

---

## Potential Risks & Gotchas

1. **ARB key mismatches**: If a key exists in `app_en.arb` but is missing from `app_es.arb`, the Flutter generator will throw a build error. Always add to both files together.

2. **Missing strings discovered mid-sprint**: When reading screen files, you'll likely find strings that weren't anticipated (e.g., validation error messages, tooltip text, accessibility labels). The fix is always: add key to both ARB files → run `flutter gen-l10n` → use the key.

3. **Dynamic option labels in onboarding**: Screens like `goal_screen.dart` may have option lists defined as a `List<String>` or `List<Map>` in the file. These need ARB keys or a localization helper. Read each file before starting its task.

4. **`flutter gen-l10n` must be re-run after every ARB change**: The generated `app_localizations.dart` is not updated automatically in real time. Run `flutter gen-l10n` (or `flutter pub get`) after every ARB file edit.

5. **The `.dart_tool/` directory is gitignored**: The generated localization files live in `.dart_tool/flutter_gen/` which is gitignored. This is correct — they are regenerated on build. Do not commit them.

6. **`PlatformDispatcher.instance.locale`**: This is the correct way to get the device locale in Flutter. Do not use `window.locale` (deprecated) or `Platform.localeName` (requires `dart:io` and may fail on web).

7. **`ConsumerStatefulWidget` vs `ConsumerWidget`**: If a screen currently extends `StatefulWidget` for local state (like the welcome screen), change it to `ConsumerStatefulWidget` with a `ConsumerState`. If it's a simple `StatelessWidget`, change to `ConsumerWidget`. Do not mix these up — it will cause compile errors.

8. **Import path for generated file**: The generated file is imported as:
   ```dart
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';
   ```
   This works because of the `generate: true` flag in `pubspec.yaml`. If the import fails, run `flutter pub get` to re-trigger generation.

---

## Rollback Plan

If anything in this plan causes a regression:
- All ARB files are new files — delete `lib/l10n/` to remove them
- `pubspec.yaml` changes: remove `flutter_localizations`, `intl`, and `generate: true`
- `l10n.yaml`: delete the file
- `locale_provider.dart`: delete the file
- `main.dart`: revert `ConsumerWidget` → `StatelessWidget`, remove locale params
- `welcome_screen.dart`: revert `ConsumerStatefulWidget` → `StatefulWidget`, restore `_selectedLanguage` local state
- Run `flutter pub get` to restore original dependency state
