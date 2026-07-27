import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/home/presentation/screens/home_screen.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/weekly_training_summary.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_actions_provider.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

class _RequestActionsNotifier extends AdaptationActionsNotifier {
  _RequestActionsNotifier(this.succeeds);

  final bool succeeds;
  DateTime? requestedWeekStart;
  DateTime? requestedWeekEnd;

  @override
  AdaptationActionState build() => const AdaptationActionIdle();

  @override
  Future<bool> requestWeeklyReview({
    DateTime? weekStart,
    DateTime? weekEnd,
  }) async {
    requestedWeekStart = weekStart;
    requestedWeekEnd = weekEnd;
    if (!succeeds) {
      state = const AdaptationActionFailure('adaptation_request_failed');
    }
    return succeeds;
  }

  @override
  Future<bool> acceptReview(AdaptationReview review) =>
      throw UnimplementedError();

  @override
  Future<bool> dismissReview(AdaptationReview review) =>
      throw UnimplementedError();
}

class _TrainingPlanNotifier extends TrainingPlanNotifier {
  _TrainingPlanNotifier(this.plan);

  final TrainingPlan plan;

  @override
  Future<TrainingPlan> build() async => plan;
}

const _defaultPlan = TrainingPlan(
  id: 'plan-1',
  raceType: TrainingPlanRaceType.halfMarathon,
  totalWeeks: 12,
  currentWeekNumber: 1,
  sessions: [],
);

class _UserPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

void main() {
  testWidgets('failed review request stays home and shows localized error', (
    tester,
  ) async {
    final router = _router();
    final notifier = _RequestActionsNotifier(false);
    await tester.pumpWidget(_app(router: router, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adaptation_coach_review_card')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.today);
    expect(
      find.text('We couldn’t complete that coach action. Try again.'),
      findsOneWidget,
    );
    expect(notifier.requestedWeekStart, _triggerSummary().weekStart);
    expect(notifier.requestedWeekEnd, _triggerSummary().weekEnd);
  });

  testWidgets('successful review request opens the review screen', (
    tester,
  ) async {
    final router = _router();
    final notifier = _RequestActionsNotifier(true);
    await tester.pumpWidget(_app(router: router, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adaptation_coach_review_card')));
    await tester.pumpAndSettle();

    expect(find.text('review destination'), findsOneWidget);
    expect(notifier.requestedWeekStart, _triggerSummary().weekStart);
    expect(notifier.requestedWeekEnd, _triggerSummary().weekEnd);
  });

  testWidgets('home session navigation captures the active plan id', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'home-provenance-session',
      date: DateTime.now(),
      type: SessionType.easyRun,
      status: SessionStatus.today,
      weekNumber: 1,
      distanceKm: 8,
      durationMinutes: 45,
    );
    final plan = TrainingPlan(
      id: 'home-plan-provenance',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [session],
    );
    SessionDetailArgs? receivedArgs;
    final router = _router(onSessionDetail: (args) => receivedArgs = args);
    final notifier = _RequestActionsNotifier(true);

    await tester.pumpWidget(
      _app(router: router, notifier: notifier, plan: plan),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    final l10n = AppLocalizations.of(context)!;
    await tester.tap(find.text(l10n.workoutViewDetailsButton));
    await tester.pumpAndSettle();

    expect(receivedArgs?.planVersionId, plan.id);
  });
}

Widget _app({
  required GoRouter router,
  required _RequestActionsNotifier notifier,
  TrainingPlan plan = _defaultPlan,
}) {
  return ProviderScope(
    overrides: [
      trainingPlanProvider.overrideWith(() => _TrainingPlanNotifier(plan)),
      userPreferencesProvider.overrideWith(_UserPreferencesNotifier.new),
      weeklyTrainingSummaryProvider.overrideWithValue(_triggerSummary()),
      pendingAdaptationReviewProvider.overrideWithValue(null),
      adaptationActionsProvider.overrideWith(() => notifier),
    ],
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

GoRouter _router({ValueChanged<SessionDetailArgs>? onSessionDetail}) {
  return GoRouter(
    initialLocation: RouteNames.today,
    routes: [
      GoRoute(path: RouteNames.today, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: RouteNames.adaptationReview,
        builder: (_, _) => const Scaffold(body: Text('review destination')),
      ),
      GoRoute(
        path: RouteNames.sessionDetail,
        builder: (_, state) {
          final args = state.extra as SessionDetailArgs;
          onSessionDetail?.call(args);
          return const Scaffold(body: Text('session detail destination'));
        },
      ),
    ],
  );
}

WeeklyTrainingSummary _triggerSummary() {
  return WeeklyTrainingSummary(
    weekStart: DateTime.utc(2026, 7, 6),
    weekEnd: DateTime.utc(2026, 7, 12),
    plannedSessions: 4,
    completedSessions: 1,
    plannedDistanceKm: 24,
    completedDistanceKm: 5,
    plannedDurationMinutes: 150,
    completedDurationMinutes: 30,
    hardSessionCount: 0,
    skippedSessionCount: 2,
    veryHardSessionCount: 0,
    poorRecoveryCount: 0,
    painCount: 0,
  );
}
