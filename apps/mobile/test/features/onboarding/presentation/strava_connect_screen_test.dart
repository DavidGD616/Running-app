import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/core/widgets/app_button.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_values.dart';
import 'package:running_app/features/onboarding/presentation/screens/strava_connect_screen.dart';
import 'package:running_app/features/strava/data/strava_service.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStravaService implements StravaService {
  _FakeStravaService({
    required this.allRunActivityCount,
    required this.activitiesBuilder,
  });

  final int allRunActivityCount;
  final List<StravaSummaryActivity> Function(DateTime nowUtc) activitiesBuilder;

  int fetchAthleteCount = 0;
  int fetchAthleteStatsCount = 0;
  int fetchSummaryActivitiesCount = 0;

  @override
  Future<StravaAthlete> fetchAthlete() async {
    fetchAthleteCount++;
    return const StravaAthlete(
      sex: StravaAthleteSex.female,
      weightKg: 58,
      heartRateZones: StravaHeartRateZones(
        zone1: StravaHeartRateZone(maxBpm: 138),
        zone2: StravaHeartRateZone(minBpm: 139, maxBpm: 151),
        zone3: StravaHeartRateZone(minBpm: 152, maxBpm: 164),
        zone4: StravaHeartRateZone(minBpm: 165, maxBpm: 176),
        zone5: StravaHeartRateZone(minBpm: 177, maxBpm: 190),
      ),
    );
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() async {
    fetchAthleteStatsCount++;
    return StravaAthleteStats(
      recentRunTotals: const StravaRunTotals(
        distanceMeters: 34_000,
        movingTimeSeconds: 12_000,
        activityCount: 4,
        elevationGainMeters: 220,
      ),
      ytdRunTotals: const StravaRunTotals(
        distanceMeters: 610_000,
        movingTimeSeconds: 220_000,
        activityCount: 58,
        elevationGainMeters: 4_500,
      ),
      allRunTotals: StravaRunTotals(
        distanceMeters: 1_900_000,
        movingTimeSeconds: 720_000,
        activityCount: allRunActivityCount,
        elevationGainMeters: 13_800,
      ),
    );
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() async {
    fetchSummaryActivitiesCount++;
    return activitiesBuilder(DateTime.now().toUtc());
  }

  @override
  Future<void> disconnect() async {}
}

class _FailingStravaService implements StravaService {
  const _FailingStravaService(this.errorCode);

  final StravaServiceErrorCode errorCode;

  @override
  Future<StravaAthlete> fetchAthlete() {
    throw StravaServiceException(errorCode);
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() {
    throw const StravaServiceException(StravaServiceErrorCode.syncFailed);
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() {
    throw const StravaServiceException(StravaServiceErrorCode.syncFailed);
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> createContainer(_FakeStravaService service) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        stravaServiceProvider.overrideWithValue(service),
      ],
    );
    await container.read(onboardingProvider.future);
    return container;
  }

  Widget buildApp(ProviderContainer container) {
    final router = GoRouter(
      initialLocation: RouteNames.stravaConnect,
      routes: [
        GoRoute(
          path: RouteNames.stravaConnect,
          builder: (context, state) => const StravaConnectScreen(),
        ),
        GoRoute(
          path: RouteNames.fitness,
          builder: (context, state) =>
              const Scaffold(body: Text('fitness-screen')),
        ),
        GoRoute(
          path: RouteNames.schedule,
          builder: (context, state) =>
              const Scaffold(body: Text('schedule-screen')),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
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

  testWidgets('connected with sufficient Strava data navigates to schedule', (
    tester,
  ) async {
    final service = _FakeStravaService(
      allRunActivityCount: 40,
      activitiesBuilder: _buildSufficientRuns,
    );
    final container = await createContainer(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StravaConnectScreen)),
    )!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.onboardingStravaConnectPrimary),
    );
    await tester.pumpAndSettle();

    expect(find.text('schedule-screen'), findsOneWidget);
    expect(find.text('fitness-screen'), findsNothing);
  });

  testWidgets('connected with insufficient Strava data routes to fitness', (
    tester,
  ) async {
    final service = _FakeStravaService(
      allRunActivityCount: 2,
      activitiesBuilder: _buildSparseRuns,
    );
    final container = await createContainer(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StravaConnectScreen)),
    )!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.onboardingStravaConnectPrimary),
    );
    await tester.pumpAndSettle();

    expect(find.text('fitness-screen'), findsOneWidget);
    expect(find.text('schedule-screen'), findsNothing);
  });

  testWidgets('continue without Strava keeps manual fitness onboarding path', (
    tester,
  ) async {
    final service = _FakeStravaService(
      allRunActivityCount: 40,
      activitiesBuilder: _buildSufficientRuns,
    );
    final container = await createContainer(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StravaConnectScreen)),
    )!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.onboardingStravaConnectSecondary),
    );
    await tester.pumpAndSettle();

    final draft = container.read(onboardingProvider).asData?.value;
    expect(find.text('fitness-screen'), findsOneWidget);
    expect(draft?.fitness.fitnessSource, OnboardingValues.fitnessSourceManual);
    expect(service.fetchAthleteCount, 0);
    expect(service.fetchAthleteStatsCount, 0);
    expect(service.fetchSummaryActivitiesCount, 0);
  });

  testWidgets('Strava missing-scope error shows localized message', (
    tester,
  ) async {
    final service = const _FailingStravaService(
      StravaServiceErrorCode.oauthMissingScope,
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        stravaServiceProvider.overrideWithValue(service),
      ],
    );
    await container.read(onboardingProvider.future);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StravaConnectScreen)),
    )!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.onboardingStravaConnectPrimary),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.onboardingStravaConnectMissingScopeError), findsOneWidget);
    expect(find.text('schedule-screen'), findsNothing);
    expect(find.text('fitness-screen'), findsNothing);
  });
}

List<StravaSummaryActivity> _buildSufficientRuns(DateTime nowUtc) {
  final weekStart = _mondayOf(nowUtc);
  final activities = <StravaSummaryActivity>[];

  for (var weeksAgo = 7; weeksAgo >= 0; weeksAgo--) {
    final start = weekStart.subtract(Duration(days: weeksAgo * 7));
    activities.addAll([
      _run(
        date: start.add(const Duration(days: 1)),
        distanceKm: 8,
        paceSecPerKm: 360,
      ),
      _run(
        date: start.add(const Duration(days: 4)),
        distanceKm: 10,
        paceSecPerKm: 345,
      ),
    ]);
  }

  return activities;
}

List<StravaSummaryActivity> _buildSparseRuns(DateTime nowUtc) {
  final weekStart = _mondayOf(nowUtc);
  return [
    _run(
      date: weekStart.subtract(const Duration(days: 50)),
      distanceKm: 2,
      paceSecPerKm: 420,
    ),
    _run(
      date: weekStart.subtract(const Duration(days: 1)),
      distanceKm: 3,
      paceSecPerKm: 430,
    ),
  ];
}

StravaSummaryActivity _run({
  required DateTime date,
  required double distanceKm,
  required int paceSecPerKm,
}) {
  final distanceMeters = distanceKm * 1000;
  final movingTimeSeconds = (distanceKm * paceSecPerKm).round();
  return StravaSummaryActivity(
    distanceMeters: distanceMeters,
    movingTimeSeconds: movingTimeSeconds,
    averageSpeedMetersPerSecond: distanceMeters / movingTimeSeconds,
    averageHeartrate: 150,
    startDate: date.toUtc(),
    type: 'Run',
    sportType: 'Run',
  );
}

DateTime _mondayOf(DateTime date) {
  final normalized = DateTime.utc(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
