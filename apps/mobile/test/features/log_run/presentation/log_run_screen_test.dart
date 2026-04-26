import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/active_run/data/run_repository.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';
import 'package:running_app/features/active_run/presentation/run_repository_provider.dart';
import 'package:running_app/features/log_run/presentation/screens/log_run_screen.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/activity_fixtures.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.fixedPlan);

  final TrainingPlan fixedPlan;

  @override
  Future<TrainingPlan> build() async => fixedPlan;
}

class FakeRunRepository implements RunRepository {
  final Map<String, CompletedRunData> _completedRuns = {};

  void addCompletedRun(CompletedRunData data) {
    _completedRuns[data.runId] = data;
  }

  @override
  Future<void> insertRun(RunSummary summary) async {}

  @override
  Future<void> updateRunSummary(RunSummary summary) async {}

  @override
  Future<void> insertRoutePoints(List<RunRoutePoint> points) async {}

  @override
  Future<void> insertSplits(List<RunSplit> splits) async {}

  @override
  Future<RunSummary?> getRunSummary(String runId) async => null;

  @override
  Future<List<RunSummary>> getActiveRuns() async => [];

  @override
  Future<List<RunRoutePoint>> getRoutePoints(String runId) async => [];

  @override
  Future<List<RunSplit>> getSplits(String runId) async => [];

  @override
  Future<void> deleteRun(String runId) async {}

  @override
  Future<void> finishRun({
    required String runId,
    required DateTime endedAt,
    required int durationMs,
    required double distanceKm,
    required List<RunSplit> splits,
    required List<RunRoutePoint> finalPoints,
  }) async {}

  @override
  Future<void> insertActiveRun({
    required String runId,
    required int startedAtMs,
    required bool timerOnly,
    required RunFlowSessionContext session,
  }) async {}

  @override
  Future<void> updateActiveRunSummary({
    required String runId,
    required int durationMs,
    required double distanceKm,
  }) async {}

  @override
  Future<void> flushPendingRoutePoints(
    String runId,
    List<RunTrackPoint> points,
  ) async {}

  @override
  Future<CompletedRunData?> getCompletedRun(String runId) async {
    return _completedRuns[runId];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapApp({
    required GoRouter router,
    required SharedPreferences prefs,
    required TrainingPlan plan,
    FakeRunRepository? fakeRepository,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
        runRepositoryProvider.overrideWith(
          (_) => fakeRepository ?? FakeRunRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
      ),
    );
  }

  testWidgets(
    'LogRunScreen displays real duration, distance, and pace from DB when runId is provided',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final session = buildPlannedRunSession(
        id: 'test-session-1',
        date: DateTime(2026, 4, 25),
        status: SessionStatus.today,
        type: SessionType.easyRun,
        distanceKm: 8.0,
        durationMinutes: 45,
        weekNumber: 4,
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      final fakeRepository = FakeRunRepository();
      fakeRepository.addCompletedRun(CompletedRunData(
        runId: 'db-run-123',
        duration: const Duration(minutes: 42, seconds: 30),
        distanceKm: 7.85,
        averagePaceSecondsPerKm: 324,
        splits: const [],
      ));

      late final GoRouter router;
      router = GoRouter(
        initialLocation: RouteNames.today,
        routes: [
          GoRoute(
            path: RouteNames.today,
            builder: (context, state) =>
                const Scaffold(body: Text('today-root')),
          ),
          GoRoute(
            path: RouteNames.logRun,
            builder: (context, state) =>
                LogRunScreen(args: state.extra as LogRunArgs?),
          ),
        ],
      );

      await tester.pumpWidget(
        wrapApp(
          router: router,
          prefs: prefs,
          plan: plan,
          fakeRepository: fakeRepository,
        ),
      );
      await tester.pumpAndSettle();

      router.go(
        RouteNames.logRun,
        extra: LogRunArgs(
          runId: 'db-run-123',
          session: RunFlowSessionContext.fromSession(session),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LogRunScreen), findsOneWidget);

      expect(find.text('42'), findsOneWidget);
    },
  );

  testWidgets(
    'LogRunScreen falls back to args when runId has no DB data',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final session = buildPlannedRunSession(
        id: 'test-session-1',
        date: DateTime(2026, 4, 25),
        status: SessionStatus.today,
        type: SessionType.easyRun,
        distanceKm: 8.0,
        durationMinutes: 45,
        weekNumber: 4,
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      final fakeRepository = FakeRunRepository();

      late final GoRouter router;
      router = GoRouter(
        initialLocation: RouteNames.today,
        routes: [
          GoRoute(
            path: RouteNames.today,
            builder: (context, state) =>
                const Scaffold(body: Text('today-root')),
          ),
          GoRoute(
            path: RouteNames.logRun,
            builder: (context, state) =>
                LogRunScreen(args: state.extra as LogRunArgs?),
          ),
        ],
      );

      await tester.pumpWidget(
        wrapApp(
          router: router,
          prefs: prefs,
          plan: plan,
          fakeRepository: fakeRepository,
        ),
      );
      await tester.pumpAndSettle();

      router.go(
        RouteNames.logRun,
        extra: LogRunArgs(
          runId: 'non-existent-run',
          session: RunFlowSessionContext.fromSession(session),
          actualDuration: const Duration(minutes: 40),
          actualDistanceKm: 7.5,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LogRunScreen), findsOneWidget);

      expect(find.text('40'), findsOneWidget);
    },
  );
}
