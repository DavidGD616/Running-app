import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/core/utils/unit_formatter.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

import '../../../helpers/activity_fixtures.dart';
import '../../../helpers/workout_fixtures.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.fixedPlan);

  final TrainingPlan fixedPlan;

  @override
  Future<TrainingPlan> build() async => fixedPlan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithPlan(TrainingPlan plan, TrainingSession session) {
    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: SessionDetailScreen(session: session, showStartWorkout: false),
      ),
    );
  }

  testWidgets('structured session detail renders typed workout steps', (
    tester,
  ) async {
    final session = buildStructuredIntervalSession();
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.workoutGuidanceTodaysPrescription), findsOneWidget);
    expect(find.text(l10n.workoutGuidancePaceEffort), findsOneWidget);
    expect(find.text(l10n.sessionDetailWarmUp), findsOneWidget);
    expect(find.text(l10n.sessionDetailCoolDown), findsOneWidget);
    expect(
      find.text(l10n.workoutGuidanceRepeatMeasure(6, '400 m', '90 s')),
      findsOneWidget,
    );
  });

  testWidgets('legacy session detail still renders without structured data', (
    tester,
  ) async {
    final session = buildLegacyTempoSession();
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.workoutGuidanceTodaysPrescription), findsOneWidget);
    expect(find.text(l10n.sessionTypeTempoRun), findsWidgets);
    expect(find.text(l10n.workoutGuidancePaceEffort), findsOneWidget);
    expect(find.textContaining('20 min'), findsOneWidget);
  });

  testWidgets(
    'run session shows structured target range from numeric workout target',
    (tester) async {
      final session = TrainingSession(
        id: 'run-target-range',
        date: DateTime(2026, 4, 12, 7, 30),
        type: SessionType.longRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 20,
        durationMinutes: 120,
        workoutTarget: const WorkoutTarget.pace(
          TargetZone.longRun,
          paceMinSecPerKm: 390,
          paceMaxSecPerKm: 450,
        ),
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.workoutGuidancePaceEffort), findsOneWidget);
      expect(find.textContaining('6:30-7:30'), findsOneWidget);
      expect(
        find.textContaining(l10n.sessionDetailEffortCueLabel),
        findsNothing,
      );
    },
  );

  testWidgets('run session shows explicit effort cue from target', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'run-effort-cue',
      date: DateTime(2026, 4, 13, 7, 30),
      type: SessionType.intervals,
      status: SessionStatus.completed,
      weekNumber: 4,
      distanceKm: 8,
      durationMinutes: 50,
      effort: TrainingSessionEffort.moderate,
      workoutTarget: const WorkoutTarget.effort(
        TargetZone.interval,
        effortCue: 'Controlled strong effort',
      ),
    );
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.textContaining('Controlled strong effort'), findsOneWidget);
    expect(find.text(l10n.workoutGuidancePaceEffort), findsOneWidget);
  });

  testWidgets(
    'description text does not drive target rendering without structured pace',
    (tester) async {
      final session = TrainingSession(
        id: 'run-fake-pace',
        date: DateTime(2026, 4, 14, 7, 30),
        type: SessionType.easyRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 8,
        durationMinutes: 45,
        description: 'Stay around 5:30/km and easy for the first 20 min.',
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(find.textContaining('5:30/km'), findsWidgets);
      expect(
        find.textContaining(l10n.sessionDetailTargetRangeLabel),
        findsNothing,
      );
      expect(
        find.textContaining(l10n.sessionDetailEffortCueLabel),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Stay around 5:30/km and easy for the first 20 min.',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.workoutGuidanceFocus), findsOneWidget);
      expect(find.text('How to run it'), findsNothing);
    },
  );

  testWidgets('target guidance note is shown before active run starts', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'run-guidance-note',
      date: DateTime(2026, 4, 15, 7, 30),
      type: SessionType.longRun,
      status: SessionStatus.upcoming,
      weekNumber: 4,
      distanceKm: 16,
      durationMinutes: 100,
      workoutTarget: const WorkoutTarget.pace(
        TargetZone.longRun,
        paceMinSecPerKm: 360,
        paceMaxSecPerKm: 420,
      ),
    );
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.workoutGuidancePaceEffort), findsOneWidget);
    expect(find.textContaining('6:00-7:00'), findsOneWidget);
  });

  testWidgets('progression run renders Easy -> Steady -> Firm phases', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'progression-guidance',
      date: DateTime(2026, 4, 16, 7, 30),
      type: SessionType.progressionRun,
      status: SessionStatus.completed,
      weekNumber: 4,
      distanceKm: 9,
      durationMinutes: 45,
      workoutSteps: const [
        WorkoutStep.work(
          duration: Duration(minutes: 15),
          target: WorkoutTarget.effort(TargetZone.easy),
        ),
        WorkoutStep.work(
          duration: Duration(minutes: 15),
          target: WorkoutTarget.effort(TargetZone.steady),
        ),
        WorkoutStep.work(
          duration: Duration(minutes: 15),
          target: WorkoutTarget.effort(TargetZone.tempo),
        ),
      ],
    );
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.activeRunEasyBlock), findsWidgets);
    expect(find.text(l10n.activeRunSteadyBlock), findsOneWidget);
    expect(find.text(l10n.workoutGuidanceFirm), findsOneWidget);
  });

  testWidgets(
    'progression steps with duration estimate show session distance measures',
    (tester) async {
      final session = TrainingSession(
        id: 'progression-distance-measure',
        date: DateTime(2026, 4, 16, 7, 30),
        type: SessionType.progressionRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 9,
        durationMinutes: 45,
        workoutSteps: const [
          WorkoutStep.work(
            duration: Duration(minutes: 15),
            target: WorkoutTarget.effort(TargetZone.easy),
          ),
          WorkoutStep.work(
            duration: Duration(minutes: 15),
            target: WorkoutTarget.effort(TargetZone.steady),
          ),
          WorkoutStep.work(
            duration: Duration(minutes: 15),
            target: WorkoutTarget.effort(TargetZone.tempo),
          ),
        ],
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;
      final expectedDistanceMeasure = UnitFormatter.formatWorkoutRepDistance(
        3_000,
        UnitSystem.km,
        l10n,
      );

      expect(find.text(l10n.activeRunEasyBlock), findsWidgets);
      expect(find.text(l10n.activeRunSteadyBlock), findsOneWidget);
      expect(find.text(l10n.workoutGuidanceFirm), findsOneWidget);
      expect(find.text(expectedDistanceMeasure), findsNWidgets(3));
      expect(find.textContaining('15 min'), findsNothing);
    },
  );

  testWidgets(
    'race-pace run with duration-only work step shows session distance measure',
    (tester) async {
      final session = TrainingSession(
        id: 'race-pace-distance-measure',
        date: DateTime(2026, 4, 16, 7, 30),
        type: SessionType.racePaceRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 8,
        durationMinutes: 50,
        workoutSteps: const [
          WorkoutStep.warmUp(
            duration: Duration(minutes: 10),
            target: WorkoutTarget.effort(TargetZone.easy),
          ),
          WorkoutStep.work(
            duration: Duration(minutes: 35),
            target: WorkoutTarget.effort(TargetZone.racePace),
          ),
          WorkoutStep.coolDown(
            duration: Duration(minutes: 5),
            target: WorkoutTarget.effort(TargetZone.recovery),
          ),
        ],
      );
      final plan = buildTestTrainingPlan(sessions: [session]);

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;
      final expectedDistanceMeasure = UnitFormatter.formatWorkoutRepDistance(
        8_000,
        UnitSystem.km,
        l10n,
      );

      expect(find.text(l10n.sessionTypeRacePaceRun), findsOneWidget);
      expect(find.text(expectedDistanceMeasure), findsOneWidget);
      expect(find.textContaining('35 min'), findsNothing);
    },
  );

  testWidgets(
    'distance-based session shows estimated duration from pace zones',
    (tester) async {
      final session = TrainingSession(
        id: 'distance-estimate',
        date: DateTime(2026, 4, 17, 7, 30),
        type: SessionType.easyRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 10,
        workoutTarget: const WorkoutTarget.effort(TargetZone.easy),
      );
      final plan = TrainingPlan(
        id: 'distance-estimate-plan',
        raceType: TrainingPlanRaceType.tenK,
        totalWeeks: 12,
        currentWeekNumber: 4,
        sessions: [session],
        paceZones: const StravaPaceZones(
          recovery: StravaPaceZone(),
          easy: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
          longRun: StravaPaceZone(),
          steady: StravaPaceZone(),
          tempo: StravaPaceZone(),
          threshold: StravaPaceZone(),
          racePace: StravaPaceZone(),
          intervals: StravaPaceZone(),
          strides: StravaPaceZone(),
        ),
      );

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.text(
          l10n.workoutGuidanceDistanceBasedWithEstimate(
            l10n.workoutGuidanceDistanceBased,
            l10n.workoutGuidanceEstimatedDurationRange(60, 70),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'distance-based estimate includes structured warm and cool blocks',
    (tester) async {
      final session = TrainingSession(
        id: 'race-pace-estimate',
        date: DateTime(2026, 4, 17, 7, 30),
        type: SessionType.racePaceRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 5,
        workoutTarget: const WorkoutTarget.effort(TargetZone.racePace),
        workoutSteps: const [
          WorkoutStep.warmUp(
            duration: Duration(minutes: 10),
            target: WorkoutTarget.effort(TargetZone.easy),
          ),
          WorkoutStep.work(
            distanceMeters: 5000,
            target: WorkoutTarget.effort(TargetZone.racePace),
          ),
          WorkoutStep.coolDown(
            duration: Duration(minutes: 5),
            target: WorkoutTarget.effort(TargetZone.recovery),
          ),
        ],
      );
      final plan = TrainingPlan(
        id: 'race-pace-estimate-plan',
        raceType: TrainingPlanRaceType.tenK,
        totalWeeks: 12,
        currentWeekNumber: 4,
        sessions: [session],
        paceZones: const StravaPaceZones(
          recovery: StravaPaceZone(paceMinSecPerKm: 420, paceMaxSecPerKm: 480),
          easy: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
          longRun: StravaPaceZone(),
          steady: StravaPaceZone(),
          tempo: StravaPaceZone(),
          threshold: StravaPaceZone(),
          racePace: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 330),
          intervals: StravaPaceZone(),
          strides: StravaPaceZone(),
        ),
      );

      await tester.pumpWidget(wrapWithPlan(plan, session));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.text(
          l10n.workoutGuidanceDistanceBasedWithEstimate(
            l10n.workoutGuidanceDistanceBased,
            l10n.workoutGuidanceEstimatedDurationRange(40, 43),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('race day detail is info-only and hides workout controls', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'race-day-info',
      date: DateTime(2026, 4, 18, 7, 30),
      type: SessionType.raceDay,
      status: SessionStatus.today,
      weekNumber: 4,
    );
    final plan = TrainingPlan(
      id: 'race-day-plan',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 4,
      sessions: [session],
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Start controlled, finish strong.',
      ),
    );

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.raceDayInfoTitle), findsWidgets);
    expect(find.text('Start controlled, finish strong.'), findsOneWidget);
    expect(find.text(l10n.sessionDetailStartWorkout), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });
}
