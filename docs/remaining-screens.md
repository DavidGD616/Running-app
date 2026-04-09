# Remaining App Screens

## File Structure

```
apps/mobile/lib/
├── core/
│   └── router/
│       ├── app_router.dart          ← add new routes here
│       └── route_names.dart         ← add new route name constants here
│
└── features/
    ├── onboarding/
    │   └── presentation/
    │       └── screens/
    │           └── plan_ready_screen.dart   ← NEW (after plan_generation_screen)
    │
    ├── weekly_plan/                         ← NEW (Plan tab)
    │   └── presentation/
    │       └── screens/
    │           └── weekly_plan_screen.dart
    │
    ├── progress/                            ← NEW (Progress tab)
    │   └── presentation/
    │       └── screens/
    │           └── progress_screen.dart
    │
    ├── settings/                            ← NEW (Settings tab)
    │   └── presentation/
    │       └── screens/
    │           └── settings_screen.dart
    │
    ├── pre_run/                             ← NEW
    │   └── presentation/
    │       └── screens/
    │           └── pre_run_screen.dart
    │
    ├── log_run/                             ← NEW
    │   └── presentation/
    │       └── screens/
    │           └── log_run_screen.dart
    │
    └── session_detail/                      ← NEW
        └── presentation/
            └── screens/
                └── session_detail_screen.dart
```

---

## Complete App Structure

```
apps/mobile/lib/
├── main.dart
│
├── core/
│   ├── router/
│   │   ├── app_router.dart
│   │   └── route_names.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   └── app_theme.dart
│   ├── utils/
│   │   └── unit_formatter.dart
│   └── widgets/
│       ├── achievement_card.dart
│       ├── app_bottom_sheet.dart
│       ├── app_button.dart
│       ├── app_card.dart
│       ├── app_chip.dart
│       ├── app_header_bar.dart
│       ├── app_progress_bar.dart
│       ├── app_segmented_control.dart
│       ├── app_slider.dart
│       ├── app_tab_bar.dart
│       ├── app_text_field.dart
│       ├── app_top_nav_bar.dart
│       ├── plan_badge_pill.dart
│       ├── profile_card.dart
│       ├── section_label.dart
│       ├── session_card.dart
│       ├── settings_row.dart
│       ├── stat_card.dart
│       ├── status_badge.dart
│       ├── streak_banner.dart
│       ├── timeline_item.dart
│       ├── up_next_row_card.dart
│       ├── week_progress_card.dart
│       ├── weekly_calendar_card.dart
│       └── workout_hero_card.dart
│
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── screens/
│   │           ├── splash_screen.dart
│   │           ├── welcome_screen.dart
│   │           ├── sign_up_screen.dart
│   │           ├── log_in_screen.dart
│   │           └── forgot_password_screen.dart
│   │
│   ├── account_setup/
│   │   └── presentation/
│   │       └── screens/
│   │           └── account_setup_screen.dart
│   │
│   ├── onboarding/
│   │   └── presentation/
│   │       ├── onboarding_provider.dart
│   │       └── screens/
│   │           ├── onboarding_intro_screen.dart
│   │           ├── goal_screen.dart
│   │           ├── current_fitness_screen.dart
│   │           ├── schedule_screen.dart
│   │           ├── health_injury_screen.dart
│   │           ├── training_preferences_screen.dart
│   │           ├── watch_device_screen.dart
│   │           ├── recovery_lifestyle_screen.dart
│   │           ├── motivation_screen.dart
│   │           ├── plan_generation_screen.dart
│   │           ├── summary_screen.dart
│   │           └── plan_ready_screen.dart       ← NEW
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── screens/
│   │           └── home_screen.dart             (Today tab — hosts AppTabBar shell)
│   │
│   ├── weekly_plan/                             ← NEW (Plan tab)
│   │   └── presentation/
│   │       └── screens/
│   │           └── weekly_plan_screen.dart
│   │
│   ├── progress/                                ← NEW (Progress tab)
│   │   └── presentation/
│   │       └── screens/
│   │           └── progress_screen.dart
│   │
│   ├── settings/                                ← NEW (Settings tab)
│   │   └── presentation/
│   │       └── screens/
│   │           └── settings_screen.dart
│   │
│   ├── pre_run/                                 ← NEW
│   │   └── presentation/
│   │       └── screens/
│   │           └── pre_run_screen.dart
│   │
│   ├── log_run/                                 ← NEW
│   │   └── presentation/
│   │       └── screens/
│   │           └── log_run_screen.dart
│   │
│   ├── session_detail/                          ← NEW
│   │   └── presentation/
│   │       └── screens/
│   │           └── session_detail_screen.dart
│   │
│   ├── user_preferences/
│   │   ├── domain/
│   │   │   └── user_preferences.dart
│   │   └── presentation/
│   │       └── user_preferences_provider.dart
│   │
│   └── localization/
│       └── presentation/
│           └── locale_provider.dart
│
└── l10n/
    ├── app_en.arb
    └── app_es.arb
```
