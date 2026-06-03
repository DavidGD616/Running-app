import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/features/goals/domain/models/goal.dart';
import 'package:running_app/features/goals/presentation/goal_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/plan_ready_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/goal_fixtures.dart';
import '../../../helpers/runner_profile_fixtures.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(this.value);

  final RunnerProfileDraft value;

  @override
  Future<RunnerProfileDraft> build() async => value;

  @override
  Future<bool> saveProfile({
    bool markOnboardingComplete = false,
    DateTime? clock,
  }) async {
    return true;
  }
}

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.plan);

  final TrainingPlan plan;

  @override
  Future<TrainingPlan> build() async => plan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({
    required TrainingPlan plan,
    required RunnerProfileDraft draft,
    required Goal? goal,
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        onboardingProvider.overrideWith(() => _TestOnboardingNotifier(draft)),
        onboardingGoalProvider.overrideWithValue(goal),
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: const Scaffold(body: PlanReadyScreen()),
      ),
    );
  }

  testWidgets('plan ready renders race guidance and pace zones when present', (
    tester,
  ) async {
    final goal = buildHalfMarathonTimeGoal();
    final draft = buildRunnerProfileDraft();
    final plan = TrainingPlan(
      id: 'plan-ready-with-guidance',
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
        ),
      ],
      paceZones: const StravaPaceZones(
        recovery: StravaPaceZone(paceMinSecPerKm: null, paceMaxSecPerKm: 420),
        easy: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
        longRun: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 300),
        steady: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 285),
        tempo: StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
        threshold: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 250),
        racePace: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 230),
        intervals: StravaPaceZone(paceMinSecPerKm: 200, paceMaxSecPerKm: 215),
        strides: StravaPaceZone(paceMinSecPerKm: 180, paceMaxSecPerKm: 190),
      ),
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Start controlled, finish strong.',
        warmup: '15-minute warm-up and strides.',
        primaryTarget: Duration(hours: 1, minutes: 30),
        coachingNotes: 'Keep cadence smooth through the second half.',
      ),
    );

    await tester.pumpWidget(wrap(plan: plan, draft: draft, goal: goal));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PlanReadyScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.text(l10n.planGuidancePaceZonesTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.textContaining('7:00'), findsOneWidget);
    expect(
      find.text(l10n.planGuidanceRaceGuidanceTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(plan.raceGuidance!.raceDayExecution), findsOneWidget);
    expect(find.text(plan.raceGuidance!.coachingNotes!), findsOneWidget);
  });

  testWidgets(
    'plan ready renders without guidance sections when they are missing',
    (tester) async {
      final goal = buildHalfMarathonTimeGoal();
      final draft = buildRunnerProfileDraft();
      final plan = TrainingPlan(
        id: 'plan-ready-without-guidance',
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
          ),
        ],
      );

      await tester.pumpWidget(wrap(plan: plan, draft: draft, goal: goal));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PlanReadyScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.text(l10n.planGuidancePaceZonesTitle.toUpperCase()),
        findsNothing,
      );
      expect(
        find.text(l10n.planGuidanceRaceGuidanceTitle.toUpperCase()),
        findsNothing,
      );
      expect(
        find.text(plan.raceGuidance?.raceDayExecution ?? ''),
        findsNothing,
      );
    },
  );

  testWidgets('plan ready pace-zone guidance reads in Spanish', (tester) async {
    final goal = buildHalfMarathonTimeGoal();
    final draft = buildRunnerProfileDraft();
    final plan = TrainingPlan(
      id: 'plan-ready-es',
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
        ),
      ],
      paceZones: const StravaPaceZones(
        recovery: StravaPaceZone(paceMinSecPerKm: null, paceMaxSecPerKm: 420),
        easy: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
        longRun: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 300),
        steady: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 285),
        tempo: StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
        threshold: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 250),
        racePace: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 230),
        intervals: StravaPaceZone(paceMinSecPerKm: 200, paceMaxSecPerKm: 215),
        strides: StravaPaceZone(paceMinSecPerKm: 180, paceMaxSecPerKm: 190),
      ),
    );

    await tester.pumpWidget(
      wrap(plan: plan, draft: draft, goal: goal, locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PlanReadyScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.text(l10n.planGuidancePaceZonesTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(l10n.onboardingStravaAnalysisPaceZoneRecovery),
      findsOneWidget,
    );
    expect(find.textContaining('7:00'), findsOneWidget);
  });
}
