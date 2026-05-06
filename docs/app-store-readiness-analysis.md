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
- `flutter test`: **392 tests passing**
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
| 4 | App icons? | **COMPLETED** — Generated for both platforms | Resolved |
| 5 | Icon design? | **TBD later** | Can use a simple generated mark for launch |
| 6 | Privacy policy/terms? | **LIVE** at striviq.fit | **RESOLVED** |
| 7 | Privacy label strategy? | **Need help deciding** | Recommend "optional" health data, no third-party sharing |
| 8 | Crash reporting/analytics? | **COMPLETED** — Firebase Crashlytics integrated | Resolved |
| 9 | Location permission? | **"Always"** on iOS + Android | Update permissions, stronger review justification needed |
| 10 | App name? | **"StrivIQ"** | **COMPLETED** — Updated on both platforms |
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
| ~~**App Launcher Icons**~~ | ~~Both stores require proper icons~~ | **COMPLETED** — Generated for iOS and Android |
| ~~**App Display Name = "StrivIQ"**~~ | ~~Currently "Running App" / "running_app"~~ | **COMPLETED** |

---

## Recommended Prioritized Plan

Since the timeline is **days**, here's the execution order:

### Phase 1: Start RIGHT NOW (today)
1. ~~**User**: Sign up for Apple Developer Account and Google Play Developer Account~~ ✅ **COMPLETED**
2. ~~**AI**: Generate privacy policy & terms of service text for a GPS fitness app~~ ✅ **COMPLETED** — Live at striviq.fit
3. ~~**AI**: Create a simple StrivIQ app launcher icon (dark square with green accent mark)~~ ✅ **COMPLETED**
4. ~~**AI**: Update app display names to "StrivIQ"~~ ✅ **COMPLETED**

### Phase 2: Code Readiness (tomorrow)
5. ~~**AI**: Integrate Firebase Crashlytics~~ ✅ **COMPLETED**
6. ~~**AI**: Update location permission to "Always" on iOS + Android with proper justification strings~~ ✅ **COMPLETED**
7. ~~**AI**: Verify all native configs are correct for store review~~ ✅ **COMPLETED**
8. ~~**Both**: Fill out privacy nutrition labels / data safety forms with recommended answers~~ ✅ **COMPLETED**

### Phase 2 Completion Notes
- **Step 6 — Location Permission Updates**:
  - **iOS**: Updated `Info.plist` permission strings from `RunFlow` to `StrivIQ`; `NSLocationAlwaysAndWhenInUseUsageDescription` now adds explicit background-tracking justification for active workouts.
  - **Android**: Added `android.permission.ACCESS_BACKGROUND_LOCATION` to `AndroidManifest.xml` for Android 10+ background tracking support.
  - **Pre-run flow**: Updated `_onContinue()` in `pre_run_screen.dart` so that distance-based workouts now require `LocationPermission.always`. If the user only has `whileInUse` permission, a new "Allow Always Location" dialog is shown that opens app settings. Non-distance workouts can still fall back to timer-only mode.
  - **Localization**: Added new ARB strings (`allowAlwaysLocationTitle`, `allowAlwaysLocationBody`, `allowAlwaysLocationOpenSettings`) in both English and Spanish, and ran `flutter gen-l10n`.
  - **Tests**: Added 4 new widget tests covering: always permission starts GPS run, whileInUse shows guidance dialog, denied shows GPS required dialog, and non-distance workouts allow timer-only fallback. All 392 tests pass.
- **Step 7 — Native Config Audit**:
  - **Android**:
    - **Fixed critical native package mismatch**: `android/app/build.gradle.kts` uses `namespace = "com.davidgd616.striviq"` and `applicationId = "com.davidgd616.striviq"`, and the Kotlin native files were moved from `com.example.running_app` to `com.davidgd616.striviq` so generated `R` resources resolve correctly.
    - `applicationId` is correctly set to `com.davidgd616.striviq`.
    - `AndroidManifest.xml` has required permissions for active run tracking: foreground service location, fine/coarse/background location, notifications, and wake lock.
    - Geolocator service and custom `RunForegroundService` are declared with `foregroundServiceType="location"` so Play Console foreground-service declarations align with GPS run tracking.
    - Deep link intent filters for `striviq://login-callback` and `striviq://active-run` are present.
    - Release builds no longer fall back to debug signing. `android/key.properties` is ignored by git and can be used for the production upload keystore.
    - Verified `flutter build apk --debug` and `flutter build appbundle --release`.
  - **iOS**:
    - **Fixed deep linking**: `FlutterDeepLinkingEnabled` was `false` despite `striviq://` URL schemes being registered. Changed to `true` so Flutter properly handles deep links.
    - `CFBundleDisplayName` and `CFBundleName` are both "StrivIQ".
    - Bundle identifier is `com.davidgd616.striviq` across all targets (Runner, Tests, Live Activity Extension).
    - `Info.plist` has proper location permission strings (updated in Step 6), background location mode, and Live Activities support. Unused `fetch` and `processing` background modes were removed.
    - `IPHONEOS_DEPLOYMENT_TARGET` is 13.0 for main app, 16.2 for Live Activity Extension — appropriate for feature requirements.
    - `ENABLE_BITCODE = NO` — correct, Apple deprecated bitcode.
    - `INFOPLIST_KEY_LSApplicationCategoryType` is `public.app-category.sports`.
    - Development Team ID is set (`6RUW3X93HY`).
    - App icon is configured via `flutter_launcher_icons`.
    - Verified `flutter build ios --no-codesign`.
  - **Flutter-level**:
    - `pubspec.yaml`: `version: 1.0.0+1` — appropriate for initial release.
    - `main.dart`: No debug flags left enabled; `debugShowCheckedModeBanner: false`; Crashlytics properly initialized; Supabase initialization is conditional (gracefully skips if env vars missing).
    - All dependencies are current and compatible.

- **Step 8 — Privacy Labels / Data Safety**:
  - **iOS**: All 7 App Privacy labels published in App Store Connect: Name, Email Address, User ID, Precise Location, Fitness (linked to identity, App Functionality); Crash Data, Performance Data (not linked to identity, App Functionality). Privacy Policy URL set to https://striviq.fit/privacy-policy.html.
  - **Android**: StrivIQ app created in Google Play Console (`com.davidgd616.striviq`). Data Safety form completed: data encrypted in transit, email+OAuth account creation, precise location + personal info + fitness + crash/diagnostics + device IDs declared as collected, no data shared with third parties. Content ratings (IARC) completed — rated E/3+. Target audience set to 18+. Advertising ID declared as not used. Health app features declared as Activity and fitness.

### Phase 3: Store Metadata (next day)
9. ~~**AI**: Prepare App Store listing (description, keywords, screenshots guidance)~~ ✅ **COMPLETED**
10. ~~**AI**: Prepare Google Play listing (description, feature graphic guidance)~~ ✅ **COMPLETED**
11. **AI**: Build release APK/AAB and iOS archive — **Android AAB completed; iOS archive pending**

- **Step 9 — App Store Listing**:
  - **App Information**: Name set to `StrivIQ`, subtitle updated to `Train Smarter. Run Farther.`; category Health & Fitness / Sports confirmed.
  - **Description**: Full 2,706-char copy entered covering personalized plans, GPS tracking, session guidance, progress tracking, and EN/ES support.
  - **Promotional Text**: `Your personalized running coach. Build a training plan, track GPS runs, and crush your next race — 5K to Marathon.`
  - **Keywords**: `running,training plan,marathon,5K,half marathon,GPS run tracker,race training,pace,coaching` (9 keywords, within 100-char limit).
  - **URLs**: Support URL `https://striviq.fit/support`, Marketing URL `https://striviq.fit`.
  - **Copyright**: `© 2026 David Guerrero Diaz`.
  - **Screenshots**: 5 × 6.5" iPhone screenshots uploaded (Today, session detail, active GPS run, progress, onboarding).
  - **App Review Information**: Test account `reviewer@striviq.fit` entered; contact info filled.

- **Step 10 — Google Play Listing**:
  - **Short description**: `Personalized running plans, GPS tracking & race coaching — 5K to Marathon.`
  - **Full description**: Full copy entered covering personalized plans, GPS tracking, session guidance, progress, EN/ES support.
  - **Graphics**: Feature graphic (1024×500px, dark bg + logo + tagline), app icon, phone screenshots, 7" and 10" tablet screenshots uploaded.
  - **Status**: Default store listing → "Ready to send for review" ✅

- **Step 11 — Release Builds**:
  - **Android**: Release App Bundle built successfully with production dart defines using `flutter build appbundle --release --dart-define-from-file=config/dart_defines.env`.
  - **Android output**: `apps/mobile/build/app/outputs/bundle/release/app-release.aab` (`1.0.0+1`, 53.1 MB).
  - **Android signing**: Upload keystore created at `/Users/davidgd616/upload-keystore.jks`; `apps/mobile/android/key.properties` configured locally and ignored by git.
  - **Google Play signing**: Play App Signing / automatic protection is enabled. The Play app signing SHA-1 was confirmed to match the Android OAuth client for `com.davidgd616.striviq`.
  - **Google Sign-In**: Confirmed working for at least one tester on the Play-installed internal test build.
  - **iOS**: Release archive / IPA still pending.

### Phase 4: Submit
12. **User**: Upload to App Store Connect + Google Play Console — **Google Play internal testing completed; App Store Connect pending**
13. **Both**: Handle any review rejection fixes

- **Step 12 — Google Play Internal Testing**:
  - Android AAB uploaded to Google Play Console.
  - Internal testing release `1 (1.0.0)` is active and available to internal testers.
  - Tester opt-in flow is working; at least one tester has installed the Play build.
  - Next Android release milestone is closed testing / production access, depending on Google Play account requirements.

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
- ~~**App Icons**: ~1-2 hours to create~~ **DONE**
- ~~**App Display Name**: 5 minute code change~~ **DONE**

### Native Config Status
- **iOS**: `Info.plist` has `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` present. Live Activities enabled. Deep linking (`striviq://`) configured. `FlutterDeepLinkingEnabled` is currently `true`. Background modes are limited to `location`.
- **Android**: Manifest has foreground service location permission, location permissions, Geolocator service declaration, custom `RunForegroundService` declaration, and location foreground service types. Application ID is `com.davidgd616.striviq`.
- **Signing**: Android release builds no longer use debug signing. Local `android/key.properties` is configured with the production upload keystore and must remain uncommitted.

### Bundle ID
- **Android**: `com.davidgd616.striviq`
- **iOS**: Should match or be consistent (e.g., `com.davidgd616.striviq`)
- Bundle IDs are permanent once an app is submitted.

### Submitted Privacy / Data Safety Summary
- **Apple App Privacy**: Name, email address, user ID, precise location, and fitness data are declared as linked to identity and used for app functionality. Crash data and performance data are declared as not linked to identity and used for app functionality.
- **Google Play Data Safety**: Email/OAuth account data, precise location, personal info, fitness data, crash/diagnostics data, and device IDs are declared as collected. Data is declared encrypted in transit, not shared with third parties, and not used for ads.
- **Crash Reporting**: Firebase Crashlytics is integrated and declared through crash/diagnostics and performance data categories.
- **Data retention**: User can delete account and data.
- **Export compliance**: iOS `ITSAppUsesNonExemptEncryption` is set to `false`; StrivIQ uses standard HTTPS/TLS through Supabase, Firebase, Google Sign-In, and platform networking, with no proprietary or non-standard encryption.

---

## Open Decisions Pending User Input

1. ~~**App launcher icon design**~~ ✅ **RESOLVED** — Generated StrivIQ launcher icon is in place for launch.
2. ~~**Crash reporting service**~~ ✅ **RESOLVED** — Firebase Crashlytics integrated.
3. ~~**Privacy policy hosting**~~ ✅ **RESOLVED** — Hosted at striviq.fit with custom domain.
4. ~~**Supabase auth callback URL**~~ ✅ **RESOLVED** — Site URL updated to `https://striviq.fit`, `striviq://login-callback` added to redirect allowlist. Code updated: `signUp` passes `emailRedirectTo` and `resetPasswordForEmail` passes `redirectTo`.
5. ~~**Google Play data safety form**~~ ✅ **RESOLVED** — Completed in Play Console.

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
