import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/activity/data/activity_repository.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/log_run/presentation/screens/log_run_screen.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/pre_run/presentation/screens/pre_run_screen.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/data/adaptation_repository.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/activity_fixtures.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.fixedPlan);

  final TrainingPlan fixedPlan;

  @override
  Future<TrainingPlan> build() async => fixedPlan;
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
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        trainingPlanProvider.overrideWith(() => _TestTrainingPlanNotifier(plan)),
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

  Future<void> pumpRouteChange(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'linked start-workout flow creates a persisted activity for the planned session',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final session = buildPlannedRunSession(
        id: 'w4-tue',
        date: DateTime(2026, 4, 7, 7, 30),
        status: SessionStatus.today,
        type: SessionType.easyRun,
        distanceKm: 8.4,
        durationMinutes: 42,
        weekNumber: 4,
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

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
            path: RouteNames.sessionDetail,
            builder: (context, state) {
              final args = state.extra as SessionDetailArgs;
              return SessionDetailScreen(
                session: args.session,
                showStartWorkout: args.showStartWorkout,
              );
            },
          ),
          GoRoute(
            path: RouteNames.preRun,
            builder: (context, state) => PreRunScreen(
              args: state.extra as PreRunArgs?,
            ),
          ),
          GoRoute(
            path: RouteNames.logRun,
            builder: (context, state) => LogRunScreen(
              args: state.extra as LogRunArgs?,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        wrapApp(router: router, prefs: prefs, plan: plan),
      );
      await tester.pumpAndSettle();

      router.go(
        RouteNames.sessionDetail,
        extra: SessionDetailArgs(session: session),
      );
      await pumpRouteChange(tester);

      final sessionDetailContext = tester.element(find.byType(SessionDetailScreen));
      final sessionDetailL10n = AppLocalizations.of(sessionDetailContext)!;
      await tester.tap(find.text(sessionDetailL10n.sessionDetailStartWorkout));
      await pumpRouteChange(tester);

      final preRunContext = tester.element(find.byType(PreRunScreen));
      final preRunL10n = AppLocalizations.of(preRunContext)!;
      expect(find.byType(PreRunScreen), findsOneWidget);
      await tester.tap(find.text(preRunL10n.preRunContinue));
      await pumpRouteChange(tester);

      final logRunContext = tester.element(find.byType(LogRunScreen));
      final logRunL10n = AppLocalizations.of(logRunContext)!;
      expect(find.byType(LogRunScreen), findsOneWidget);
      await tester.tap(find.text(logRunL10n.logSessionSaveButton));
      await pumpRouteChange(tester);

      expect(find.text('today-root'), findsOneWidget);

      final repository = SharedPreferencesActivityRepository(prefs);
      final activities = repository.loadAllActivities();
      expect(activities, hasLength(1));

      final saved = activities.single as RunActivity;
      expect(saved.id, session.id);
      expect(saved.linkedSessionId, session.id);
      expect(saved.source, ActivitySource.plannedSession);
      expect(saved.completionStatus, ActivityCompletionStatus.completed);
      expect(saved.actualDistanceKm, session.distanceKm);
      expect(saved.derivedDuration, const Duration(minutes: 42));
      expect(saved.notes, isNull);

      final adaptationRepository = SharedPreferencesAdaptationRepository(prefs);
      final feedback = adaptationRepository.loadSessionFeedback();
      expect(feedback, hasLength(1));
      expect(feedback.single.plannedSessionId, session.id);
      expect(feedback.single.activityId, session.id);
    },
  );
}
