import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/support_session.dart';
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

  Widget wrapWithPlanAndSupport(
    TrainingPlan plan,
    SupportSession supportSession,
  ) {
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
        home: SessionDetailScreen(
          supportSession: supportSession,
          showStartWorkout: false,
        ),
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

  testWidgets('support session detail localizes fields and hides canonical notes', (
    tester,
  ) async {
    final supportSession = SupportSession(
      id: 'support-session-id',
      date: DateTime(2026, 4, 16, 9, 30),
      weekNumber: 4,
      type: SupplementalSessionType.strength,
      status: SupportSessionStatus.planned,
      durationMinutes: 25,
      load: 'moderate',
      timingGuidance: 'on_off_days',
      interferenceRule: 'avoid_day_before_long_run',
      taperAdjustment: 'reduce_load',
      notes: 'seed_strength_session',
    );

    final plan = buildTestTrainingPlan(sessions: []);
    final planWithSupport = TrainingPlan(
      id: plan.id,
      raceType: plan.raceType,
      totalWeeks: plan.totalWeeks,
      currentWeekNumber: plan.currentWeekNumber,
      sessions: const [],
      supportSessions: [supportSession],
    );

    await tester.pumpWidget(
      wrapWithPlanAndSupport(planWithSupport, supportSession),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.sessionDetailSupportTitle), findsOneWidget);
    expect(
      find.textContaining(
        '${l10n.sessionDetailSupportTypeLabel}: ${l10n.planSupportStrengthLabel}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.sessionDetailSupportStatusLabel}: ${l10n.supportSessionStatusPlanned}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.planSupportSessionLoadLabel}: ${l10n.supportSessionLoadModerate}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.planSupportSessionTimingLabel}: ${l10n.supportSessionTimingOnOffDays}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.planSupportSessionInterferenceLabel}: ${l10n.supportSessionInterferenceAvoidDayBeforeLongRun}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.planSupportSessionTaperLabel}: ${l10n.supportSessionTaperReduceLoad}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('seed_strength_session'), findsNothing);
    expect(
      find.textContaining(l10n.sessionDetailEstDurationLabel.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets(
    'support session detail hides unknown metadata values and canonical keys',
    (tester) async {
      final supportSession = SupportSession(
        id: 'support-session-id-2',
        date: DateTime(2026, 4, 17, 9, 30),
        weekNumber: 4,
        type: SupplementalSessionType.strength,
        status: SupportSessionStatus.planned,
        durationMinutes: 25,
        load: 'avoid_race_week',
        timingGuidance: 'skip_next_session',
        interferenceRule: 'avoid_race_week',
        taperAdjustment: 'reduce_when_available',
        notes: 'seed_strength_session',
      );

      final plan = buildTestTrainingPlan(sessions: []);
      final planWithSupport = TrainingPlan(
        id: plan.id,
        raceType: plan.raceType,
        totalWeeks: plan.totalWeeks,
        currentWeekNumber: plan.currentWeekNumber,
        sessions: const [],
        supportSessions: [supportSession],
      );

      await tester.pumpWidget(
        wrapWithPlanAndSupport(planWithSupport, supportSession),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SessionDetailScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.sessionDetailSupportTitle), findsOneWidget);
      expect(
        find.textContaining(
          '${l10n.sessionDetailSupportTypeLabel}: ${l10n.planSupportStrengthLabel}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('avoid_race_week'), findsNothing);
      expect(find.textContaining('Avoid race week'), findsNothing);
      expect(
        find.textContaining(l10n.sessionDetailSupportMetadataLabel),
        findsNothing,
      );
      expect(find.textContaining('seed_strength_session'), findsNothing);
      expect(
        find.textContaining(l10n.sessionDetailEstDurationLabel.toUpperCase()),
        findsOneWidget,
      );
    },
  );
}
