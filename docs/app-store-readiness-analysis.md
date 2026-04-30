# App Store Readiness Analysis

**Generated**: 2026-04-28
**App**: StrivIQ
**Platform**: iOS + Android (Flutter)
**Target**: Free launch, no monetization initially
**Timeline**: Days (aggressive)

---

## App Analysis Summary

### What the App Is
**StrivIQ** is a Flutter running training app that creates personalized race training plans (5K through Marathon), tracks real GPS runs, and helps athletes follow structured workouts. It supports English and Spanish.

### Architecture & Tech Stack
- **Flutter 3.11+** with Material 3 dark theme only
- **Navigation**: `go_router` with 4-tab shell (Today, Plan, Progress, Settings)
- **State**: `flutter_riverpod` — very well-structured with typed profiles, providers, and repositories
- **Backend**: Supabase for auth (email + Google Sign-In) and training plan storage
- **Local Persistence**: `sqflite` for GPS runs/routes/splits, `SharedPreferences` for profile/preferences
- **GPS Tracking**: Real `geolocator` implementation with background tracking, pause/resume, splits, and mid-run app-kill restore
- **Native Features**: iOS Live Activities, Android foreground notification, deep links for auth (`striviq://`)
- **Localization**: Full EN/ES via ARB files with runtime placeholders

### Current Quality
- `flutter analyze`: **Clean**
- `flutter test`: **388 tests passing**
- Well-documented data models and implementation plans in `docs/`

### What's Implemented
- **Auth**: Splash → Welcome → Sign Up / Log In / Forgot Password / Reset Password / Google Sign-In
- **Onboarding**: 8+ screens (Goal, Fitness, Schedule, Health, Training Preferences, Watch, Summary, Plan Generation, Plan Ready)
- **Account Setup**: Units, gender, birthday
- **Main App**: Home/Today, Weekly Plan, Session Detail, Pre-run Check-in, Active Run with GPS, Log Run, Progress, Training History, Full Plan View
- **Settings**: Profile, Account, Language, Units, Integrations, Subscription screens (UI only), Goal editing, Plan update flows
- **Domain Models**: Very comprehensive typed profile, activity records, device connections, goals, workout targets/steps, session feedback, plan adjustments/revisions

---

## Q&A Context (12 Questions)

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | Monetization? | **Free launch**, payment later | No IAP/billing needed now |
| 2 | Beta testing? | **Already field-tested on physical devices** | Skip beta setup for speed |
| 3 | Supabase production? | **Yes**, production project active | Good, auth ready |
| 4 | App icons? | **Not yet**, need help | Need to generate/create launcher icons |
| 5 | Icon design? | **TBD later** | Can use a simple generated mark for launch |
| 6 | Privacy policy/terms? | **Not yet**, need help | **Hard blocker** for both stores |
| 7 | Privacy label strategy? | **Need help deciding** | Recommend "optional" health data, no third-party sharing |
| 8 | Crash reporting/analytics? | **Yes, want it** | Recommend Firebase Crashlytics + Analytics |
| 9 | Location permission? | **"Always"** on iOS + Android | Update permissions, stronger review justification needed |
| 10 | App name? | **"StrivIQ"** | Update Android label + iOS display name from defaults |
| 11 | Dev accounts? | **Apple & Google Play accounts created and verified** | Resolved |
| 12 | Timeline? | **Days** | Very aggressive; need to parallelize everything |

---

## Immediate Hard Blockers

| Blocker | Why It's Required | ETA |
|---------|-------------------|-----|
| ~~**Apple Developer Account** ($99/yr)~~ | ~~Need it for App Store Connect, signing certificates, provisioning profiles~~ | **RESOLVED** |
| ~~**Google Play Developer Account** ($25)~~ | ~~Need it for Play Console~~ | **RESOLVED** |
| ~~**Privacy Policy URL**~~ | ~~Required by both Apple & Google~~ | **LIVE** — https://striviq.fit/privacy-policy.html |
| ~~**Terms of Service URL**~~ | ~~Required/strongly recommended~~ | **LIVE** — https://striviq.fit/terms-of-service.html |
| **App Launcher Icons** | Both stores require proper icons | Can generate in 1-2 hours |
| **App Display Name = "StrivIQ"** | Currently "Running App" / "running_app" | 5 min code change |

---

## Recommended Prioritized Plan

Since the timeline is **days**, here's the execution order:

### Phase 1: Start RIGHT NOW (today)
1. ~~**User**: Sign up for Apple Developer Account and Google Play Developer Account~~ ✅ **COMPLETED**
2. **AI**: Generate privacy policy & terms of service text for a GPS fitness app
3. **AI**: Create a simple StrivIQ app launcher icon (dark square with green accent mark)
4. **AI**: Update app display names to "StrivIQ"

### Phase 2: Code Readiness (tomorrow)
5. **AI**: Integrate Firebase Crashlytics + Analytics (or Sentry if user prefers lighter)
6. **AI**: Update location permission to "Always" on iOS + Android with proper justification strings
7. **AI**: Verify all native configs are correct for store review
8. **Both**: Fill out privacy nutrition labels / data safety forms with recommended answers

### Phase 3: Store Metadata (next day)
9. **AI**: Prepare App Store listing (description, keywords, screenshots guidance)
10. **AI**: Prepare Google Play listing (description, feature graphic guidance)
11. **AI**: Build release APK/AAB and iOS archive

### Phase 4: Submit
12. **User**: Upload to App Store Connect + Google Play Console
13. **Both**: Handle any review rejection fixes

---

## Key Notes

### Website Deployed
The StrivIQ marketing website is now live at **https://striviq.fit** (deployed via GitHub Pages). It includes:
- Landing page with hero, features, how-it-works, and download CTA sections
- Privacy Policy at https://striviq.fit/privacy-policy.html
- Terms of Service at https://striviq.fit/terms-of-service.html
- Canvas particle system, scroll animations, and responsive design
- Custom domain via CNAME (striviq.fit)

### Timeline Reality Check
**Developer accounts are now resolved.** The remaining blockers are technical and can be completed in parallel:
- ~~**Privacy Policy & Terms**: ~1 hour to generate~~ **DONE** — Live at striviq.fit
- **App Icons**: ~1-2 hours to create
- **App Display Name**: 5 minute code change

### Native Config Status
- **iOS**: `Info.plist` has `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` present. Live Activities enabled. Deep linking (`striviq://`) configured. `FlutterDeepLinkingEnabled` is currently `false`.
- **Android**: Manifest has foreground service permissions, location permissions, Geolocator service declaration, custom `RunForegroundService` declaration. Application ID is `com.davidgd616.striviq`.
- **Signing**: Android release build currently uses debug signing config — needs proper signing for store release.

### Bundle ID
- **Android**: `com.davidgd616.striviq`
- **iOS**: Should match or be consistent (e.g., `com.davidgd616.striviq`)
- Bundle IDs are permanent once an app is submitted.

### Privacy Label Recommendations (for when forms are filled)
- **Health/Fitness data**: Declare as "optional" since users can use the app without a watch and without logging all health details.
- **Location**: Declare as "required" for core functionality (GPS tracking).
- **Email**: Declare as "required" for account creation.
- **Third-party sharing**: Declare "no sharing" initially (no analytics or ads at launch; add Crashlytics later and update).
- **Data retention**: User can delete account and data.

### Crash Reporting Service Options
1. **Firebase Crashlytics** (recommended for first launch)
   - Free, easy Flutter integration via `firebase_crashlytics`
   - Requires Firebase project creation
   - Also gives Firebase Analytics for free
   - Google-owned, well-supported

2. **Sentry**
   - Developer-friendly, free tier generous
   - No Google dependency
   - Good for privacy-conscious apps

---

## Open Decisions Pending User Input

1. **App launcher icon design**: User wants to decide later; can use a simple generated mark for now.
2. **Crash reporting service**: User said yes but didn't specify which one. Firebase Crashlytics recommended.
3. **Privacy policy hosting**: Does the user have a domain/website to host the generated policy?
4. **Supabase auth callback URL**: User didn't know if `striviq://login-callback` is configured on Supabase dashboard. Should verify before launch.
5. **Google Play data safety form**: Will need to be filled out manually in Play Console; this doc provides the recommended answers.

---

## Files Referenced in Analysis

- `apps/mobile/pubspec.yaml`
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/core/router/app_router.dart`
- `apps/mobile/lib/core/config/supabase_config.dart`
- `apps/mobile/lib/features/auth/presentation/auth_state_provider.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart`
- `apps/mobile/lib/features/training_plan/presentation/training_plan_provider.dart`
- `apps/mobile/lib/features/active_run/presentation/active_run_controller.dart`
- `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`
- `apps/mobile/lib/features/settings/presentation/screens/settings_screen.dart`
- `apps/mobile/lib/features/auth/presentation/screens/splash_screen.dart`
- `apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart`
- `apps/mobile/android/app/src/main/AndroidManifest.xml`
- `apps/mobile/android/app/build.gradle.kts`
- `apps/mobile/ios/Runner/Info.plist`
- `apps/mobile/assets/logos/striviq_logo.svg`
- `docs/running_app_mvp_plan.md`
- `docs/data-models.md`
- `docs/dynamic-data-local-persistence-plan.md`
- `docs/domain-model-expansion-plan.md`
- `docs/active-run-real-gps-implementation-plan.md`
- `docs/live-activity-gps-sync-implementation-plan.md`
- `docs/manual-device-field-test-checklist.md`
- `docs/2026-04-27-training-plan-schedule-rules-plan.md`
