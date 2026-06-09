import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/core/widgets/session_row.dart';
import 'package:running_app/features/full_plan/presentation/screens/full_plan_screen.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/support_session.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/features/weekly_plan/presentation/screens/weekly_plan_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.plan);

  final TrainingPlan plan;

  @override
  Future<TrainingPlan> build() async => plan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: child,
    );
  }

  Widget wrapWithPlan(
    TrainingPlan plan,
    Widget child, {
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
      child: wrap(child, locale: locale),
    );
  }

  Widget wrapWithPlanAndRouter(
    TrainingPlan plan, {
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: RouteNames.fullPlan,
      routes: [
        GoRoute(
          path: RouteNames.fullPlan,
          builder: (context, state) => const FullPlanScreen(),
        ),
        GoRoute(
          path: RouteNames.sessionDetail,
          builder: (context, state) {
            final args = state.extra as SessionDetailArgs;
            return SessionDetailScreen(
              session: args.session,
              showStartWorkout: false,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
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

  DateTime currentWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  testWidgets('full plan renders run rows and ignores plan guidance cards', (
    tester,
  ) async {
    final plan = TrainingPlan(
      id: 'full-plan-guidance',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 1),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 45,
        ),
      ],
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Run 90% effort in the first half and finish strong.',
        warmup: '10-minute easy jog',
        primaryTarget: Duration(hours: 1, minutes: 35),
      ),
    );

    await tester.pumpWidget(wrapWithPlan(plan, const FullPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(plan.raceGuidance!.raceDayExecution), findsNothing);

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(1));
    final rowTitles = rows.map((row) => row.title).toList(growable: false);
    expect(rowTitles, contains(l10n.weeklyPlanSessionEasyRun));
  });

  testWidgets('full plan does not render legacy support sessions', (
    tester,
  ) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'full-plan-support',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: weekStart,
          type: SessionType.thresholdRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 10,
          durationMinutes: 55,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'strength-1',
          date: weekStart.add(const Duration(days: 2)),
          weekNumber: 1,
          type: SupplementalSessionType.strength,
          status: SupportSessionStatus.planned,
          durationMinutes: 25,
        ),
      ],
      paceZones: null,
      raceGuidance: null,
    );

    await tester.pumpWidget(wrapWithPlan(plan, const FullPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(1));
    final rowTitles = rows.map((row) => row.title).toList(growable: false);
    expect(rowTitles, contains(l10n.sessionTypeThresholdRun));
    expect(rowTitles, isNot(contains(l10n.planSupportStrengthLabel)));
  });

  testWidgets('race day row opens info-only race day detail', (tester) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'full-plan-race-day',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'race-day',
          date: weekStart,
          type: SessionType.raceDay,
          status: SessionStatus.upcoming,
          weekNumber: 1,
        ),
      ],
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Start controlled, finish strong.',
      ),
    );

    await tester.pumpWidget(wrapWithPlanAndRouter(plan));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;
    final raceDayRow = find.widgetWithText(SessionRow, l10n.raceDayInfoTitle);

    await tester.tap(raceDayRow);
    await tester.pumpAndSettle();

    expect(find.text(l10n.raceDayInfoTitle), findsWidgets);
    expect(find.text('Start controlled, finish strong.'), findsOneWidget);
    expect(find.text(l10n.sessionDetailStartWorkout), findsNothing);
  });

  testWidgets('weekly plan view does not render legacy support sessions', (
    tester,
  ) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'weekly-plan-support',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: weekStart.add(const Duration(days: 1)),
          type: SessionType.recoveryRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 6,
          durationMinutes: 35,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'mobility-1',
          date: weekStart.add(const Duration(days: 1, hours: 4)),
          weekNumber: 1,
          type: SupplementalSessionType.mobility,
          status: SupportSessionStatus.planned,
          durationMinutes: 30,
        ),
      ],
      paceZones: null,
      raceGuidance: null,
    );

    await tester.pumpWidget(wrapWithPlan(plan, const WeeklyPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WeeklyPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(1));
    expect(
      rows.map((row) => row.title),
      isNot(contains(l10n.planSupportMobilityLabel)),
    );
  });

  testWidgets('full plan race day row reads in Spanish', (tester) async {
    final plan = TrainingPlan(
      id: 'full-plan-es',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 1),
          type: SessionType.raceDay,
          status: SessionStatus.upcoming,
          weekNumber: 1,
        ),
      ],
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Mantén ritmo controlado en el primer tramo.',
      ),
    );

    await tester.pumpWidget(
      wrapWithPlan(plan, const FullPlanScreen(), locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.raceDayInfoTitle), findsOneWidget);
    expect(find.text(l10n.raceDayInfoSubtitle), findsOneWidget);
  });
}
