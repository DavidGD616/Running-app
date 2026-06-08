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
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

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

    expect(find.text(l10n.sessionDetailWorkoutStructure), findsOneWidget);
    expect(find.text(l10n.sessionDetailWarmUp), findsOneWidget);
    expect(find.text(l10n.sessionDetailCoolDown), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseIntervalsMainNote(6, '400 m')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.sessionPhaseIntervalsMainRecovery(90)),
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

    expect(find.text(l10n.sessionDetailWorkoutStructure), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseTempoRunWarmDuration(10)),
      findsNWidgets(2),
    );
    expect(find.text(l10n.sessionPhaseTempoRunMainNote), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseTempoRunCoolDuration(10)),
      findsNWidgets(2),
    );
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

      expect(find.text(l10n.workoutTargetGuidanceLabel), findsOneWidget);
      expect(
        find.textContaining(l10n.sessionDetailTargetRangeLabel),
        findsOneWidget,
      );
      expect(find.textContaining('6:30 - 7:30'), findsOneWidget);
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

    expect(
      find.text(
        '${l10n.sessionDetailEffortCueLabel}: Controlled strong effort',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(l10n.sessionDetailTargetGuidanceNote),
      findsOneWidget,
      reason: 'Effort cue should appear with target guidance.',
    );
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

      expect(find.textContaining('5:30/km'), findsOneWidget);
      expect(
        find.textContaining(l10n.sessionDetailTargetRangeLabel),
        findsNothing,
      );
      expect(
        find.textContaining(l10n.sessionDetailEffortCueLabel),
        findsNothing,
      );
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

    final note = find.text(l10n.sessionDetailTargetGuidanceNote);
    expect(note, findsOneWidget);
    expect(find.textContaining('once your run is active'), findsOneWidget);
  });

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
