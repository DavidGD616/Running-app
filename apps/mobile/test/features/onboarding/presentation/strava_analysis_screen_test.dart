import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/core/widgets/app_button.dart';
import 'package:running_app/features/integrations/data/device_connection_repository.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_values.dart';
import 'package:running_app/features/onboarding/presentation/screens/strava_analysis_screen.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/strava/data/strava_service.dart';
import 'package:running_app/features/strava/domain/athlete_summary.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStravaService implements StravaService {
  _FakeStravaService({this.failDisconnect = false});

  final bool failDisconnect;
  int disconnectCount = 0;

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    if (failDisconnect) {
      throw const StravaServiceException(
        StravaServiceErrorCode.disconnectFailed,
      );
    }
  }

  @override
  Future<StravaAthlete> fetchAthlete() {
    throw UnimplementedError();
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() {
    throw UnimplementedError();
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> createContainer({
    StravaDataConfidence confidence = StravaDataConfidence.high,
    UnitSystem unitSystem = UnitSystem.km,
    _FakeStravaService? service,
    SharedPreferences? existingPrefs,
  }) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    await SharedPreferencesUserPreferencesRepository(
      prefs,
    ).save(UserPreferences(unitSystem: unitSystem));
    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        runnerProfileRepositoryProvider.overrideWithValue(
          SharedPreferencesRunnerProfileRepository(prefs),
        ),
        asyncDeviceConnectionRepositoryProvider.overrideWithValue(
          DeviceConnectionRepositoryAsyncAdapter(
            SharedPreferencesDeviceConnectionRepository(prefs),
          ),
        ),
        userPreferencesRepositoryProvider.overrideWithValue(
          SharedPreferencesUserPreferencesRepository(prefs),
        ),
        stravaServiceProvider.overrideWithValue(
          service ?? _FakeStravaService(),
        ),
      ],
    );
    await container.read(onboardingProvider.future);
    container
        .read(onboardingProvider.notifier)
        .setStravaCoachingProfile(
          summary: _buildAthleteSummary(),
          coachingProfile: _buildStravaCoachingProfile(confidence: confidence),
        );
    await container.pump();
    return container;
  }

  Widget buildApp(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: RouteNames.stravaAnalysis,
      routes: [
        GoRoute(
          path: RouteNames.stravaAnalysis,
          builder: (context, state) => const StravaAnalysisScreen(),
        ),
        GoRoute(
          path: RouteNames.raceTarget,
          builder: (context, state) =>
              const Scaffold(body: Text('race-target-screen')),
        ),
        GoRoute(
          path: RouteNames.manualFitness,
          builder: (context, state) =>
              const Scaffold(body: Text('fitness-screen')),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        routerConfig: router,
      ),
    );
  }

  Future<void> pumpAnalysis(
    WidgetTester tester,
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildApp(container, locale: locale));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'high confidence renders sections, dates, pace zones, and Strava primary action',
    (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);

      await pumpAnalysis(tester, container);

      final context = tester.element(find.byType(StravaAnalysisScreen));
      final l10n = AppLocalizations.of(context)!;
      final dateFormatter = DateFormat.yMMMd('en');

      expect(find.text(l10n.onboardingStep(3, 9)), findsOneWidget);
      expect(
        find.text(l10n.onboardingStravaAnalysisTrainingBaseSection),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisEnduranceSection),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisSpeedSection),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisTerrainSection),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisRecoverySection),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisRaceTargetSection),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisPlanFocusSection),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisConfidenceStrong),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.onboardingStravaAnalysisWindow(
            dateFormatter.format(DateTime.utc(2026, 3, 10)),
            dateFormatter.format(DateTime.utc(2026, 6, 2)),
            32,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisPaceZoneEasy),
        findsOneWidget,
      );
      expect(find.text('5:50-6:35 min/km'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, l10n.onboardingStravaAnalysisUseAction),
        findsOneWidget,
      );
    },
  );

  testWidgets('medium confidence uses manual-details primary action', (
    tester,
  ) async {
    final container = await createContainer(
      confidence: StravaDataConfidence.medium,
    );
    addTearDown(container.dispose);

    await pumpAnalysis(tester, container);

    final context = tester.element(find.byType(StravaAnalysisScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(
      find.text(l10n.onboardingStravaAnalysisConfidenceWeak),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        AppButton,
        l10n.onboardingStravaAnalysisManualContinueAction,
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, l10n.onboardingStravaAnalysisUseAction),
      findsNothing,
    );
  });

  testWidgets('limited confidence uses manual-details primary action', (
    tester,
  ) async {
    final container = await createContainer(
      confidence: StravaDataConfidence.limited,
    );
    addTearDown(container.dispose);

    await pumpAnalysis(tester, container);

    final context = tester.element(find.byType(StravaAnalysisScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(
      find.text(l10n.onboardingStravaAnalysisConfidenceNoUsefulData),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        AppButton,
        l10n.onboardingStravaAnalysisManualContinueAction,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Spanish locale renders Spanish labels and localized dates', (
    tester,
  ) async {
    final container = await createContainer();
    addTearDown(container.dispose);

    await pumpAnalysis(tester, container, locale: const Locale('es'));

    final context = tester.element(find.byType(StravaAnalysisScreen));
    final l10n = AppLocalizations.of(context)!;
    final dateFormatter = DateFormat.yMMMd('es');

    expect(
      find.text(l10n.onboardingStravaAnalysisTrainingBaseSection),
      findsOneWidget,
    );
    expect(
      find.text(l10n.onboardingStravaAnalysisConfidenceStrong),
      findsOneWidget,
    );
    expect(find.textContaining('32,5 km/semana'), findsOneWidget);
    expect(find.textContaining('14,2 km'), findsOneWidget);
    expect(
      find.text(
        l10n.onboardingStravaAnalysisWindow(
          dateFormatter.format(DateTime.utc(2026, 3, 10)),
          dateFormatter.format(DateTime.utc(2026, 6, 2)),
          32,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, l10n.onboardingStravaAnalysisUseAction),
      findsOneWidget,
    );
  });

  testWidgets(
    'miles preference converts distances and paces to mi and per-mile pace',
    (tester) async {
      final container = await createContainer(unitSystem: UnitSystem.miles);
      addTearDown(container.dispose);

      await pumpAnalysis(tester, container);

      expect(find.textContaining('20.2 mi/week'), findsOneWidget);
      expect(find.textContaining('8.8 mi'), findsOneWidget);
      expect(find.text('9:23-10:36 min/mi'), findsOneWidget);
    },
  );

  testWidgets(
    'evidence rows show localized labels, dates, and no raw keys or activity names',
    (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);

      await pumpAnalysis(tester, container);

      final context = tester.element(find.byType(StravaAnalysisScreen));
      final l10n = AppLocalizations.of(context)!;
      final dateFormatter = DateFormat.yMMMd('en');

      expect(
        find.text(l10n.onboardingStravaAnalysisMetricWeeklyVolume),
        findsOneWidget,
      );
      expect(
        find.textContaining(dateFormatter.format(DateTime.utc(2026, 6, 1))),
        findsWidgets,
      );
      expect(find.textContaining('32.5 km/week'), findsOneWidget);
      expect(find.textContaining('training_base_weekly_km'), findsNothing);
      expect(find.textContaining('speed_marker_threshold_pace'), findsNothing);
      expect(find.textContaining('Morning Run'), findsNothing);
    },
  );

  testWidgets(
    'sanitized persisted profile renders guardrail and focus category mappings',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final seeded = await createContainer(existingPrefs: prefs);
      await seeded.pump();
      seeded.dispose();

      final service = _FakeStravaService();
      final reloaded = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          runnerProfileRepositoryProvider.overrideWithValue(
            SharedPreferencesRunnerProfileRepository(prefs),
          ),
          asyncDeviceConnectionRepositoryProvider.overrideWithValue(
            DeviceConnectionRepositoryAsyncAdapter(
              SharedPreferencesDeviceConnectionRepository(prefs),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          stravaServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(reloaded.dispose);
      await reloaded.read(onboardingProvider.future);

      await pumpAnalysis(tester, reloaded);

      final context = tester.element(find.byType(StravaAnalysisScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.text(l10n.onboardingStravaAnalysisGuardrailDetrainingTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.onboardingStravaAnalysisPlanFocusThresholdEndurance),
        findsOneWidget,
      );
      expect(
        find.textContaining('Increase consistency before adding intensity'),
        findsNothing,
      );
      expect(
        find.textContaining('Build consistency and threshold durability'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'manual primary action clears Strava state and routes to manual fitness',
    (tester) async {
      final container = await createContainer(
        confidence: StravaDataConfidence.medium,
      );
      addTearDown(container.dispose);

      await pumpAnalysis(tester, container);

      final context = tester.element(find.byType(StravaAnalysisScreen));
      final l10n = AppLocalizations.of(context)!;
      await tester.tap(
        find.widgetWithText(
          AppButton,
          l10n.onboardingStravaAnalysisManualContinueAction,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final draft = container.read(onboardingProvider).value!;
      expect(find.text('fitness-screen'), findsOneWidget);
      expect(draft.fitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(draft.fitness.stravaCoachingProfile, isNull);
    },
  );

  testWidgets('failed disconnect shows localized error and stays on analysis', (
    tester,
  ) async {
    final service = _FakeStravaService(failDisconnect: true);
    final container = await createContainer(service: service);
    addTearDown(container.dispose);

    await pumpAnalysis(tester, container);

    final context = tester.element(find.byType(StravaAnalysisScreen));
    final l10n = AppLocalizations.of(context)!;
    await tester.tap(
      find.widgetWithText(
        AppButton,
        l10n.onboardingStravaAnalysisDisconnectAction,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final draft = container.read(onboardingProvider).value!;
    expect(service.disconnectCount, 1);
    expect(
      find.text(l10n.onboardingStravaAnalysisDisconnectError),
      findsOneWidget,
    );
    expect(find.text('fitness-screen'), findsNothing);
    expect(draft.fitness.fitnessSource, OnboardingValues.fitnessSourceStrava);
    expect(draft.fitness.stravaCoachingProfile, isNotNull);
  });

  testWidgets(
    'disconnect action clears local Strava state and routes to manual fitness',
    (tester) async {
      final service = _FakeStravaService();
      final container = await createContainer(service: service);
      addTearDown(container.dispose);

      await pumpAnalysis(tester, container);

      final context = tester.element(find.byType(StravaAnalysisScreen));
      final l10n = AppLocalizations.of(context)!;
      await tester.tap(
        find.widgetWithText(
          AppButton,
          l10n.onboardingStravaAnalysisDisconnectAction,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final draft = container.read(onboardingProvider).value!;
      expect(service.disconnectCount, 1);
      expect(find.text('fitness-screen'), findsOneWidget);
      expect(draft.fitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(draft.fitness.stravaCoachingProfile, isNull);
    },
  );

  testWidgets('high confidence primary routes to race target', (tester) async {
    final container = await createContainer();
    addTearDown(container.dispose);

    await pumpAnalysis(tester, container);

    final context = tester.element(find.byType(StravaAnalysisScreen));
    final l10n = AppLocalizations.of(context)!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.onboardingStravaAnalysisUseAction),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('race-target-screen'), findsOneWidget);
  });
}

AthleteSummary _buildAthleteSummary() {
  return const AthleteSummary(
    weeklyVolumeKm: 32.5,
    volumeTrend: VolumeTrend.steady,
    acuteChronicRatio: 1.05,
    longestRecentRunKm: 14.2,
    typicalEasyPaceSecPerKm: 330,
    typicalHardPaceSecPerKm: 270,
    estimatedThresholdPaceSecPerKm: 290,
    runsPerWeek: 4,
    longestLayoffDays: 3,
    weeksActiveInLast8: 8,
    dataWeeks: 8,
    insufficientData: false,
    hasHeartRateZones: true,
  );
}

StravaCoachingProfile _buildStravaCoachingProfile({
  required StravaDataConfidence confidence,
}) {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 32.5,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime.utc(2026, 6, 2, 8),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime.utc(2026, 3, 10),
      dataThroughDate: DateTime.utc(2026, 6, 2),
      activityCount: 34,
      runActivityCount: 32,
      confidence: confidence,
    ),
    dataConfidence: confidence,
    trainingBase: [
      evidence,
      StravaEvidencePoint(
        metric: 'training_base_runs_per_week',
        date: DateTime.utc(2026, 6, 1),
        value: 4,
        unit: 'runs_per_week',
      ),
    ],
    endurance: [
      StravaEvidencePoint(
        metric: 'endurance_long_run_km',
        date: DateTime.utc(2026, 5, 31),
        value: 14.2,
        unit: 'km',
      ),
    ],
    speedMarkers: [
      StravaEvidencePoint(
        metric: 'speed_marker_threshold_pace',
        date: DateTime.utc(2026, 5, 30),
        value: 290,
        unit: 'sec_per_km',
      ),
    ],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 395, paceMaxSecPerKm: 445),
      easy: StravaPaceZone(paceMinSecPerKm: 350, paceMaxSecPerKm: 395),
      longRun: StravaPaceZone(paceMinSecPerKm: 345, paceMaxSecPerKm: 380),
      steady: StravaPaceZone(paceMinSecPerKm: 325, paceMaxSecPerKm: 345),
      tempo: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 325),
      threshold: StravaPaceZone(paceMinSecPerKm: 285, paceMaxSecPerKm: 300),
      racePace: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 295),
      intervals: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 280),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 255),
    ),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 1,
        category: 'recovery_detraining',
        message:
            'Increase consistency before adding intensity from persisted data.',
      ),
    ],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 21.097,
        primaryTime: const Duration(hours: 1, minutes: 55),
        stretchTime: const Duration(hours: 1, minutes: 50),
        confidence: confidence,
        evidence: [
          StravaEvidencePoint(
            metric: 'race_target_reference_effort',
            date: DateTime.utc(2026, 5, 30),
            value: 6900,
            unit: 'sec',
          ),
        ],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_threshold_and_endurance',
      summary: 'Build consistency and threshold durability from raw summary.',
    ),
  );
}
