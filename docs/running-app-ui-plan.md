# Plan: Running App — Flutter UI Implementation

**Generated**: 2026-03-12
**Estimated Complexity**: High
**Scope**: UI only — no backend, no auth logic, no real state persistence

---

## Overview

Build the complete UI layer for the Running App in Flutter (iOS + Android), pixel-matching the Figma design. The app is dark-mode first, uses Material 3, and follows a strict design token system (Inter font, #00E676 green accent, #121212 background). The work is organized into 6 sprints: project foundation → design system components → auth screens → account setup → onboarding part 1 → onboarding part 2.

### Architecture: Feature-First with Clean Layers (UI only)

```
lib/
  core/
    theme/          ← design tokens: colors, typography, spacing, radius
    widgets/        ← shared reusable components
    router/         ← go_router navigation config
  features/
    auth/
      presentation/screens/
    account_setup/
      presentation/screens/
    onboarding/
      presentation/screens/
  main.dart
```

**Rationale:**
- Feature-first keeps each screen's code co-located and easy to expand with logic later
- `core/theme/` isolates design tokens — change one file and it propagates everywhere
- `core/widgets/` is the reusable component library matching Figma's component page
- go_router is the standard Flutter navigation solution (URL-based, deep-link ready)
- Riverpod wraps go_router and handles lightweight UI state (onboarding step, form values) — easy to extend with real data later

---

## Prerequisites

- Flutter SDK ≥ 3.11.1 installed
- Dart SDK included with Flutter
- iOS Simulator or Android Emulator running
- Figma file access: https://www.figma.com/design/AzGhuMQKAmJL2UCQq3IW0S/Running-App
- Design system doc: `docs/running-app-system-desing.md`

---

## Sprint 1: Project Foundation

**Goal**: Clean project structure, all dependencies installed, design token system set up, routing skeleton running on simulator.

**Demo/Validation**:
- `flutter run` shows a dark `#121212` screen with "RunRun" text in Inter font in green
- All routes navigate (even to placeholder screens)
- No linter errors (`flutter analyze`)

---

### Task 1.1: Replace pubspec.yaml with full dependency set

- **Location**: `apps/mobile/pubspec.yaml`
- **Description**: Add all required packages. No optional or speculative deps — only what the UI needs.
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    cupertino_icons: ^1.0.8
    go_router: ^14.0.0          # Navigation
    flutter_riverpod: ^2.6.1    # UI state management
    google_fonts: ^6.2.1        # Inter font
    flutter_svg: ^2.0.10        # SVG icons from Figma

  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^6.0.0
    flutter_riverpod: ^2.6.1    # for riverpod lints
  ```
- **Dependencies**: none
- **Acceptance Criteria**:
  - `flutter pub get` runs without errors
  - All packages resolve
- **Validation**: Run `flutter pub get`

---

### Task 1.2: Create folder structure

- **Location**: `apps/mobile/lib/`
- **Description**: Create the empty directory and file scaffolding. Use placeholder files (`// TODO`) to establish the structure.
  ```
  lib/
    core/
      theme/
        app_colors.dart
        app_typography.dart
        app_spacing.dart
        app_radius.dart
        app_theme.dart
      widgets/
        app_button.dart
        app_card.dart
        app_chip.dart
        app_text_field.dart
        app_progress_bar.dart
        app_top_nav_bar.dart
        app_bottom_sheet.dart
        app_segmented_control.dart
      router/
        app_router.dart
        route_names.dart
    features/
      auth/presentation/screens/
        splash_screen.dart
        welcome_screen.dart
        sign_up_screen.dart
        log_in_screen.dart
        forgot_password_screen.dart
      account_setup/presentation/screens/
        account_setup_screen.dart
      onboarding/presentation/screens/
        onboarding_intro_screen.dart
        goal_screen.dart
        current_fitness_screen.dart
        schedule_screen.dart
        health_injury_screen.dart
        training_preferences_screen.dart
        watch_device_screen.dart
        recovery_lifestyle_screen.dart
        motivation_screen.dart
        summary_screen.dart
        plan_generation_screen.dart
    main.dart
  ```
- **Dependencies**: Task 1.1
- **Acceptance Criteria**: All files exist, no import errors
- **Validation**: `flutter analyze` passes

---

### Task 1.3: Implement design token files

- **Location**: `apps/mobile/lib/core/theme/`
- **Description**: Convert the design system doc into Dart constants. These are the single source of truth — never use raw hex or pixel values in widgets.

  **`app_colors.dart`**:
  ```dart
  import 'package:flutter/material.dart';

  abstract class AppColors {
    // Backgrounds
    static const backgroundPrimary   = Color(0xFF121212);
    static const backgroundSecondary = Color(0xFF1E1E1E);
    static const backgroundCard      = Color(0xFF2A2A2A);
    static const surfaceElevated     = Color(0xFF333333);

    // Text
    static const textPrimary   = Color(0xFFFFFFFF);
    static const textSecondary = Color(0xFFB3B3B3);
    static const textDisabled  = Color(0xFF666666);

    // Accent
    static const accentPrimary = Color(0xFF00E676);
    static const accentLight   = Color(0xFF69F0AE);
    static const accentMuted   = Color(0x3300E676); // 20% opacity

    // Borders
    static const borderDefault = Color(0xFF3A3A3A);
    // borderFocused = accentPrimary

    // Semantic
    static const success = Color(0xFF4CAF50);
    static const warning = Color(0xFFFFC107);
    static const error   = Color(0xFFEF5350);
    static const info    = Color(0xFF42A5F5);
  }
  ```

  **`app_spacing.dart`**:
  ```dart
  abstract class AppSpacing {
    static const double xs     = 4;
    static const double sm     = 8;
    static const double md     = 12;
    static const double base   = 16;
    static const double lg     = 20;
    static const double xl     = 24;
    static const double xxl    = 32;
    static const double xxxl   = 40;
    static const double screen = 20; // horizontal screen padding
  }
  ```

  **`app_radius.dart`**:
  ```dart
  import 'package:flutter/material.dart';

  abstract class AppRadius {
    static const sm   = Radius.circular(8);
    static const md   = Radius.circular(12);
    static const lg   = Radius.circular(16);
    static const xl   = Radius.circular(20);
    static const full = Radius.circular(999);

    static const borderSm   = BorderRadius.all(sm);
    static const borderMd   = BorderRadius.all(md);
    static const borderLg   = BorderRadius.all(lg);
    static const borderXl   = BorderRadius.all(xl);
    static const borderFull = BorderRadius.all(full);
  }
  ```

  **`app_typography.dart`**: Define TextStyles using `GoogleFonts.inter()` for each scale level (headlineLarge, headlineMedium, titleLarge, titleMedium, bodyLarge, bodyMedium, labelLarge, labelMedium, caption).

- **Dependencies**: Task 1.1 (google_fonts package)
- **Acceptance Criteria**: All token files compile; no raw hex or pixel values elsewhere
- **Validation**: `flutter analyze`

---

### Task 1.4: Implement AppTheme with Material 3 dark theme

- **Location**: `apps/mobile/lib/core/theme/app_theme.dart`
- **Description**: Build the `ThemeData` that wires the design tokens into Material 3.
  ```dart
  import 'package:flutter/material.dart';
  import 'app_colors.dart';
  import 'app_typography.dart';

  abstract class AppTheme {
    static ThemeData get dark => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        primaryContainer: AppColors.accentMuted,
        surface: AppColors.backgroundSecondary,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      textTheme: AppTypography.textTheme,
      // Override card, input, etc. to match design tokens
    );
  }
  ```
- **Dependencies**: Tasks 1.3
- **Acceptance Criteria**: Theme compiles and applies dark background on all scaffolds
- **Validation**: Visual check on simulator

---

### Task 1.5: Set up go_router with all routes

- **Location**: `apps/mobile/lib/core/router/`
- **Description**: Define all route names as constants and wire up go_router with placeholder screens.

  **`route_names.dart`**:
  ```dart
  abstract class RouteNames {
    static const splash             = '/';
    static const welcome            = '/welcome';
    static const signUp             = '/sign-up';
    static const logIn              = '/log-in';
    static const forgotPassword     = '/forgot-password';
    static const accountSetup       = '/account-setup';
    static const onboardingIntro    = '/onboarding';
    static const goal               = '/onboarding/goal';
    static const currentFitness     = '/onboarding/fitness';
    static const schedule           = '/onboarding/schedule';
    static const healthInjury       = '/onboarding/health';
    static const trainingPrefs      = '/onboarding/training';
    static const watchDevice        = '/onboarding/watch';
    static const recovery           = '/onboarding/recovery';
    static const motivation         = '/onboarding/motivation';
    static const summary            = '/onboarding/summary';
    static const planGeneration     = '/onboarding/plan-generation';
  }
  ```

  **`app_router.dart`**: GoRouter with all routes pointing to screens.

- **Dependencies**: Tasks 1.2, 1.3
- **Acceptance Criteria**: All 17 routes defined; navigating between them works
- **Validation**: Tap through screens on simulator

---

### Task 1.6: Update main.dart

- **Location**: `apps/mobile/lib/main.dart`
- **Description**: Replace counter app with ProviderScope + MaterialApp.router using AppTheme.dark and the go_router config.
  ```dart
  void main() {
    runApp(const ProviderScope(child: RunningApp()));
  }

  class RunningApp extends StatelessWidget {
    const RunningApp({super.key});
    @override
    Widget build(BuildContext context) {
      return MaterialApp.router(
        title: 'RunRun',
        theme: AppTheme.dark,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      );
    }
  }
  ```
- **Dependencies**: Tasks 1.4, 1.5
- **Acceptance Criteria**: App launches with dark background; no counter app code remains
- **Validation**: `flutter run`

---

## Sprint 2: Design System Component Library

**Goal**: All reusable widgets built and visually matching Figma's Components page. Each widget is self-contained, themeable from design tokens, and covers all required states.

**Demo/Validation**:
- Create a temporary `ComponentGalleryScreen` that renders every component in all states
- Visual comparison against Figma components page screenshot
- Delete the gallery screen after sprint review

---

### Task 2.1: AppButton (Primary + Secondary)

- **Location**: `apps/mobile/lib/core/widgets/app_button.dart`
- **Description**: Single `AppButton` widget with a `variant` enum (`primary`, `secondary`).
  - Full-width by default
  - Min height 48px (tap target requirement)
  - Border radius: AppRadius.lg (16px)
  - Primary: accent background + white label
  - Secondary: transparent + accent border + accent label
  - States: default, loading (show CircularProgressIndicator), disabled (reduced opacity)
  - Text style: AppTypography.labelLarge
- **Acceptance Criteria**:
  - Renders correctly for both variants
  - Disabled state shows 38% opacity
  - Loading state shows spinner, not text
  - Tap target ≥ 48px verified with Flutter Inspector
- **Validation**: Visual check in ComponentGallery

---

### Task 2.2: AppChoiceCard

- **Location**: `apps/mobile/lib/core/widgets/app_card.dart`
- **Description**: Selectable card used in onboarding for multiple choice options.
  - Background: AppColors.backgroundCard (#2A2A2A)
  - Border radius: AppRadius.lg
  - Padding: AppSpacing.base (16px)
  - Default state: border AppColors.borderDefault (1px)
  - Selected state: border AppColors.accentPrimary (2px) + background AppColors.accentMuted
  - Optional leading icon, title, optional subtitle
  - `onTap` callback + `isSelected` bool
- **Acceptance Criteria**: Visual toggle between default/selected states
- **Validation**: Visual check in ComponentGallery

---

### Task 2.3: AppChip

- **Location**: `apps/mobile/lib/core/widgets/app_chip.dart`
- **Description**: Pill-shaped chip for day selection, tags, filters.
  - Border radius: AppRadius.full (999px)
  - Min height/tap target: 48px
  - Default: backgroundCard border
  - Selected: accentPrimary fill + white text
  - Label style: AppTypography.labelMedium
- **Acceptance Criteria**: Toggle works; min tap target met
- **Validation**: Visual check in ComponentGallery

---

### Task 2.4: AppTextField

- **Location**: `apps/mobile/lib/core/widgets/app_text_field.dart`
- **Description**: Themed input field.
  - Background: AppColors.backgroundSecondary
  - Border: AppColors.borderDefault; focused → AppColors.accentPrimary
  - Border radius: AppRadius.md (12px)
  - Padding: AppSpacing.base (16px)
  - Label above field (Body Medium / Secondary)
  - Placeholder inside field (Text Disabled)
  - Error state: AppColors.error border + error message below
  - Passes `TextEditingController` and `validator`
- **Acceptance Criteria**: Focus, error, and default states all render correctly
- **Validation**: Visual check in ComponentGallery

---

### Task 2.5: AppProgressBar

- **Location**: `apps/mobile/lib/core/widgets/app_progress_bar.dart`
- **Description**: Thin horizontal progress bar for onboarding step indicator.
  - Track: AppColors.backgroundSecondary
  - Fill: AppColors.accentPrimary
  - Takes `current` int and `total` int
  - Animates fill change with `AnimatedFractionallySizedBox` or `TweenAnimationBuilder`
  - Fixed height: 4px; full width
- **Acceptance Criteria**: Animates smoothly between steps; works for all step counts
- **Validation**: Visual check in ComponentGallery

---

### Task 2.6: AppTopNavBar

- **Location**: `apps/mobile/lib/core/widgets/app_top_nav_bar.dart`
- **Description**: Custom top navigation bar for onboarding and auth flows.
  - Back arrow (left) — calls `context.pop()` via go_router
  - Optional `AppProgressBar` below the bar (for onboarding screens)
  - Transparent or AppColors.backgroundPrimary background
  - Not a standard AppBar — build as a Column widget that sits at the top of each screen
- **Acceptance Criteria**: Back arrow pops route; progress bar shown only when `showProgress: true`
- **Validation**: Visual check in ComponentGallery

---

### Task 2.7: AppSegmentedControl

- **Location**: `apps/mobile/lib/core/widgets/app_segmented_control.dart`
- **Description**: Custom segmented control (units selector, gender selector).
  - 2–4 segments
  - Selected: AppColors.accentPrimary fill + white text
  - Unselected: AppColors.backgroundCard
  - Min tap target per segment: 48px height
  - Takes `List<String> options`, `int selectedIndex`, `onChanged` callback
- **Acceptance Criteria**: Selection updates correctly; all states render
- **Validation**: Visual check in ComponentGallery

---

### Task 2.8: AppBottomSheet helper

- **Location**: `apps/mobile/lib/core/widgets/app_bottom_sheet.dart`
- **Description**: Styled bottom sheet wrapper function.
  - Background: AppColors.surfaceElevated
  - Border radius: AppRadius.xl on top corners only
  - Drag handle indicator (small rounded bar at top center)
  - Content padding: AppSpacing.screen (20px)
  - Expose as `showAppBottomSheet(context, child)` function
- **Acceptance Criteria**: Renders with correct styling; dismissable
- **Validation**: Visual check in ComponentGallery

---

## Sprint 3: Auth Screens

**Goal**: All 5 auth screens built, pixel-matching Figma, with full navigation flow (Splash → Welcome → Sign Up / Log In → Forgot Password).

**Demo/Validation**:
- Launch app → see Splash animate → auto-navigate to Welcome
- Tap "Create Account" → Sign Up screen
- Tap "Log In" → Log In screen
- Tap "Forgot Password" → Forgot Password screen
- All back navigations work
- Visual match with Figma auth screens

---

### Task 3.1: Splash Screen

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/splash_screen.dart`
- **Description**: Full-screen dark background with RunRun logo/app name centered. Auto-navigates to Welcome after ~2 seconds using `Future.delayed`. Logo uses AppColors.accentPrimary for the brand mark.
- **Acceptance Criteria**: Shows for ~2s then transitions to Welcome
- **Validation**: `flutter run`, watch cold start

---

### Task 3.2: Welcome Screen

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/welcome_screen.dart`
- **Description**:
  - Full dark background
  - Logo/brand mark centered in upper portion
  - Headline (Headline Large): "Welcome to RunRun" or equivalent
  - Value proposition body text (Body Medium / Text Secondary)
  - Primary AppButton: "Create Account" → navigates to `/sign-up`
  - Secondary AppButton (text-only variant): "Log In" → navigates to `/log-in`
  - Buttons pinned at bottom with AppSpacing.screen padding
- **Acceptance Criteria**: Both CTAs navigate correctly
- **Validation**: Visual match with Figma Welcome screen

---

### Task 3.3: Sign Up Screen

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart`
- **Description**:
  - AppTopNavBar with back button (no progress bar)
  - Title: "Create your account" (Headline Medium)
  - AppTextField for Email
  - AppTextField for Password (obscured)
  - AppTextField for Confirm Password (obscured)
  - Primary AppButton: "Create Account" (disabled until fields filled — UI-only, no real validation logic)
  - "Already have an account? Log In" link at bottom → `/log-in`
- **Acceptance Criteria**: UI renders; navigation works; button shows disabled style when fields empty
- **Validation**: Visual match with Figma Sign Up screen

---

### Task 3.4: Log In Screen

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/log_in_screen.dart`
- **Description**:
  - AppTopNavBar with back button
  - Title: "Welcome back" (Headline Medium)
  - AppTextField for Email
  - AppTextField for Password (obscured)
  - Primary AppButton: "Log In"
  - "Forgot your password?" link → `/forgot-password`
  - "Don't have an account? Sign Up" link → `/sign-up`
- **Acceptance Criteria**: Navigation links work; UI matches Figma
- **Validation**: Visual check

---

### Task 3.5: Forgot Password Screen

- **Location**: `apps/mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart`
- **Description**:
  - AppTopNavBar with back button
  - Title: "Reset your password" (Headline Medium)
  - Descriptive body text (Body Medium / Text Secondary)
  - AppTextField for Email
  - Primary AppButton: "Send Reset Link"
  - Success state: Replace form with confirmation message (Text + icon) — toggle with local `ValueNotifier<bool>` or simple `setState`
- **Acceptance Criteria**: Tapping button shows success state (no API call — just UI toggle)
- **Validation**: Visual check

---

## Sprint 4: Account Setup Screen

**Goal**: Account setup screen fully built with all interactive components.

**Demo/Validation**:
- After Sign Up, "Create Account" button navigates to Account Setup
- Segmented control toggles between km/mi and gender options
- Birthday picker opens native date picker
- "Continue" navigates to Onboarding Intro

---

### Task 4.1: Account Setup Screen

- **Location**: `apps/mobile/lib/features/account_setup/presentation/screens/account_setup_screen.dart`
- **Description**:
  - AppTopNavBar (no progress bar — pre-onboarding)
  - Title: "Account Setup" (Headline Medium)
  - Units section: AppSegmentedControl with ["km", "mi"]
  - Gender section: AppSegmentedControl with ["Male", "Female", "Other"] (or match Figma labels)
  - Birthday section: AppTextField-style tappable trigger that opens `showDatePicker()` (native Flutter date picker)
  - Display selected date in the trigger field
  - Primary AppButton: "Continue" → navigates to `/onboarding`
  - All content in a `SingleChildScrollView` (short form, but safe area)
- **Acceptance Criteria**: Segmented controls toggle; date picker opens and populates field; Continue navigates
- **Validation**: Visual match with Figma Account Setup screen

---

## Sprint 5: Onboarding Screens — Part 1

**Goal**: First 5 onboarding screens built (Intro through Schedule), with step progress tracking.

**Demo/Validation**:
- Navigate from Account Setup → Onboarding Intro → Goal → Current Fitness → Schedule
- Progress bar updates on each screen
- Back navigation decrements progress bar
- All input types (choice cards, chips, text fields) work interactively

---

### Task 5.1: Onboarding state provider (UI only)

- **Location**: `apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart`
- **Description**: Simple Riverpod `NotifierProvider` to track current onboarding step (int 1–11) and store selected answers as a `Map<String, dynamic>`. This is UI state only — no persistence.
  ```dart
  final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);

  class OnboardingState {
    final int currentStep; // 1-11
    final Map<String, dynamic> answers;
  }
  ```
- **Dependencies**: Sprint 1 (Riverpod setup)
- **Acceptance Criteria**: Step increments/decrements; answers stored in map
- **Validation**: Unit test the notifier

---

### Task 5.2: Onboarding Intro Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/onboarding_intro_screen.dart`
- **Description**:
  - AppTopNavBar with back arrow (no progress bar — it's the intro)
  - Large headline explaining what comes next
  - Body text: estimated time, what the questions are for
  - Primary AppButton: "Let's start" → navigates to `/onboarding/goal`, increments step
- **Acceptance Criteria**: Navigation and step increment work
- **Validation**: Visual match with Figma

---

### Task 5.3: Goal Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/goal_screen.dart`
- **Description**:
  - AppTopNavBar with AppProgressBar (step 1/9)
  - Title: "What's your goal?" (Headline Medium)
  - Race type: AppChoiceCard options (5K, 10K, Half Marathon, Marathon, General Fitness)
  - Race date toggle (show/hide date picker using progressive disclosure — only show if not "General Fitness")
  - Goal type: AppChoiceCard options (Finish, Improve time, Comfortable running)
  - Time input fields: conditionally shown only if "Improve time" selected
  - Primary AppButton: "Next" → navigates to `/onboarding/fitness`
  - Wrap in `SingleChildScrollView`
- **Acceptance Criteria**: Race type selection toggles date picker; goal type selection toggles time inputs; selections stored in provider
- **Validation**: Visual match with Figma Goal screen

---

### Task 5.4: Current Fitness Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/current_fitness_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 2/9)
  - Experience level: AppChoiceCard options (Beginner, Intermediate, Advanced)
  - Weekly frequency: AppSegmentedControl or AppChoiceCard (1-2, 3-4, 5+ days)
  - Current weekly volume: AppTextField (numeric, with unit label)
  - Longest recent run: AppTextField (numeric, with unit label)
  - Yes/No toggle questions (current injury pain) using two AppChips side by side
  - Optional benchmark section (conditional — progressive disclosure)
  - Primary AppButton: "Next" → `/onboarding/schedule`
- **Acceptance Criteria**: All inputs interactive; conditional sections show/hide correctly
- **Validation**: Visual match with Figma Current Fitness screen

---

### Task 5.5: Schedule Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/schedule_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 3/9)
  - Training days: Row of 7 AppChip day selectors (M T W T F S S) — multi-select
  - Long run day: Single select from same AppChip pattern
  - Weekday availability: AppSegmentedControl or choice cards (< 45min, 45-60min, 60-90min, 90min+)
  - Weekend availability: same
  - Preferred time of day: AppChoiceCard options (Morning, Afternoon, Evening, Flexible)
  - Primary AppButton: "Next" → `/onboarding/health`
- **Acceptance Criteria**: Day chips multi-select works; long run day single-selects; all stored in provider
- **Validation**: Visual match with Figma Schedule screen

---

## Sprint 6: Onboarding Screens — Part 2

**Goal**: Remaining 6 onboarding screens built (Health through Plan Generation), completing the full UI flow.

**Demo/Validation**:
- Navigate through all 11 onboarding screens sequentially
- Progress bar goes 1/9 → 9/9 → Summary → Plan Generation animation
- Full end-to-end UI walkthrough from Splash to Plan Generation loads
- Visual match with all Figma onboarding screens

---

### Task 6.1: Health & Injury Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/health_injury_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 4/9)
  - Current pain toggle (Yes/No chips) + conditional pain location AppChoiceCards
  - Injury history: AppChoiceCard multi-select options
  - Health conditions: AppChoiceCard multi-select (Asthma, Heart condition, Diabetes, None, etc.)
  - Plan preference on injury: AppChoiceCard (Be conservative, Push through, Let AI decide)
  - Primary AppButton: "Next" → `/onboarding/training`
- **Acceptance Criteria**: Progressive disclosure for pain location works; multi-select works
- **Validation**: Visual match with Figma Health & Injury screen

---

### Task 6.2: Training Preferences Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/training_preferences_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 5/9)
  - Guidance mode: AppChoiceCard options (Structured plan, Flexible, Self-directed)
  - Speed workouts: Yes/No chips
  - Strength training: Yes/No chips
  - Preferred surface: AppChoiceCard (Road, Trail, Treadmill, Mixed)
  - Terrain preference: AppChoiceCard (Flat, Hilly, Mixed)
  - Walk/run preference: AppChoiceCard (Run only, Walk breaks OK, Walk/run intervals)
  - Primary AppButton: "Next" → `/onboarding/watch`
- **Acceptance Criteria**: All selections interactive and stored
- **Validation**: Visual match with Figma Training Preferences screen

---

### Task 6.3: Watch & Device Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/watch_device_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 6/9)
  - Watch toggle (Yes/No chips)
  - Conditional section (only if Yes): Watch type AppChoiceCard, Data usage preferences, Metrics, Heart rate zones toggle
  - No-watch fallback section (only if No): Brief explanation of phone-based tracking
  - Primary AppButton: "Next" → `/onboarding/recovery`
- **Acceptance Criteria**: Watch toggle shows/hides the device section
- **Validation**: Visual match with Figma Watch & Device screen

---

### Task 6.4: Recovery & Lifestyle Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/recovery_lifestyle_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 7/9)
  - Sleep hours: AppSegmentedControl or slider (< 6h, 6-7h, 7-8h, 8h+)
  - General activity level: AppChoiceCard (Sedentary, Lightly active, Moderately active, Very active)
  - Stress level: AppSegmentedControl (Low, Medium, High)
  - How do you feel after a hard effort: AppChoiceCard (Take days to recover, Bounce back quickly, Depends)
  - Primary AppButton: "Next" → `/onboarding/motivation`
- **Acceptance Criteria**: All inputs interactive and stored
- **Validation**: Visual match with Figma Recovery & Lifestyle screen

---

### Task 6.5: Motivation & Adherence Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/motivation_screen.dart`
- **Description**:
  - AppTopNavBar + AppProgressBar (step 8/9)
  - Reason for running: AppChoiceCard multi-select (Health, Race goal, Community, Stress relief, etc.)
  - Biggest obstacle: AppChoiceCard (Time, Motivation, Injury risk, Weather, Energy)
  - Confidence level: AppSegmentedControl (1-5 scale) or chip row
  - Coaching tone: AppChoiceCard (Supportive, Direct, Motivational, Flexible)
  - Primary AppButton: "Next" → `/onboarding/summary`
- **Acceptance Criteria**: Multi-select and single-select both work; stored in provider
- **Validation**: Visual match with Figma Motivation screen

---

### Task 6.6: Summary Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/summary_screen.dart`
- **Description**:
  - AppTopNavBar with back arrow (no progress bar — summary is end of flow)
  - Title: "Review your profile" (Headline Large)
  - Scrollable list of summary cards — one per onboarding section
  - Each summary card shows: section name, key selected values, "Edit" text button → navigates back to that section's route
  - Primary AppButton: "Build my plan" (pinned at bottom) → `/onboarding/plan-generation`
  - Read answers from `onboardingProvider` to populate summary cards
- **Acceptance Criteria**: All 8 sections summarized; Edit buttons navigate to correct screens; "Build my plan" navigates forward
- **Validation**: Full flow walkthrough; check all edit links

---

### Task 6.7: Plan Generation Screen

- **Location**: `apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart`
- **Description**:
  - No nav bar — full immersive screen
  - Dark background with centered animation (use `AnimatedBuilder` + rotation or a lottie/custom loading animation using pure Flutter — no lottie package needed for MVP)
  - Motivational message text (Body Large, accentPrimary color) that cycles through 2-3 messages with `Timer.periodic`
  - Auto-navigates to a placeholder Home screen after 3 seconds (stub route `/home` for now)
- **Acceptance Criteria**: Animation plays; messages cycle; auto-navigates after delay
- **Validation**: Visual match with Figma Plan Generation screen

---

## Testing Strategy

- **Per sprint**: Visual comparison against Figma screenshot at 390×844pt
- **Component tests**: Write widget tests for `AppButton`, `AppChoiceCard`, `AppChip`, `AppProgressBar` verifying render states (disabled, selected, etc.)
- **Navigation tests**: Use `flutter_test` + go_router's `GoRouter.of(context)` to verify route transitions
- **Run on both platforms**: `flutter run -d ios` and `flutter run -d android` after each sprint
- **Accessibility**: Use Flutter Inspector → Semantics overlay to verify 48×48px tap targets

---

## Potential Risks & Gotchas

### 1. Inter font loading delay
`GoogleFonts.inter()` fetches from the network on first run. Solution: pre-cache with `GoogleFonts.pendingFonts()` in `main()` before `runApp`, or bundle the Inter font as a local asset in `pubspec.yaml` (recommended for production).

### 2. SafeArea on different devices
iPhone 14 has a notch/Dynamic Island; Pixel 7 has a punch-hole camera. Wrap every screen in `SafeArea` — don't manually offset by hardcoded pixel values.

### 3. Progress bar step count
The onboarding has 9 sections but Figma may show different numbers. Lock down the total step count in `OnboardingState` before building screens — changing it later shifts every screen's indicator.

### 4. Conditional field animation
Progressive disclosure (show/hide fields) can feel jarring without animation. Use `AnimatedSwitcher` or `AnimatedCrossFade` for smooth expand/collapse — especially on Goal screen (time inputs) and Health screen (pain location).

### 5. go_router `pop` vs `go` in onboarding
Use `context.go(nextRoute)` for forward navigation (replaces history, so back returns to previous step correctly). Use `context.pop()` only for back button — this preserves the stack. Using `go` for back would skip screens.

### 6. Segmented control overlap with Material 3
Material 3's `SegmentedButton` widget might not match the Figma design exactly. Build `AppSegmentedControl` as a custom widget from scratch rather than wrapping the Material component, to guarantee pixel-accurate rendering.

### 7. Dart 3 / Flutter 3.11 compatibility
Riverpod 2.x requires Dart 2.17+. The project targets Dart 3.11.1 — all good. But verify no analyzer warnings after adding riverpod with `flutter analyze` before writing feature code.

### 8. Summary screen is tightly coupled to provider
The Summary screen reads from `onboardingProvider`. If the user navigates back from Summary and changes an answer, the summary must reflect the change. Since answers are stored in the Riverpod map and Summary reads from it at build time, this is automatic — but test this explicitly.

---

## Rollback Plan

- All work is on `main` branch; each sprint ends with a commit
- If a sprint goes wrong, `git revert` the sprint's commits
- Design tokens are isolated in `core/theme/` — changing a color or spacing value has controlled blast radius
- No backend or database changes are made during UI work — nothing to roll back except code
```
