import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/activity/activity.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/data/plan_version_repository.dart';
import 'package:running_app/features/training_plan/data/adaptation_repository.dart';
import 'package:running_app/features/training_plan/data/supabase_plan_version_repository.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/support_session.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:running_app/features/training_plan/domain/models/plan_version.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_provider.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';

class _FixedPlanVersionRepository implements PlanVersionRepository {
  _FixedPlanVersionRepository(this.plan);

  final TrainingPlan plan;

  @override
  TrainingPlan? loadActivePlanSync() => plan;

  @override
  Future<TrainingPlan?> loadActivePlanAsync() async => plan;

  @override
  Future<void> saveActivePlan(PlanVersion version) async {}

  @override
  bool hasActivePlan() => true;
}

TrainingPlan _planWithGuidanceFields() {
  return TrainingPlan(
    id: 'provider-level-fields',
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 1,
    sessions: [
      TrainingSession(
        id: 'run-1',
        date: DateTime.now().add(const Duration(days: 7)),
        type: SessionType.easyRun,
        status: SessionStatus.upcoming,
        weekNumber: 1,
        distanceKm: 8,
        durationMinutes: 42,
      ),
    ],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 420, paceMaxSecPerKm: 460),
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
    ),
    generatedLocale: 'es',
    stravaCoachingProfileSnapshot: _stravaSnapshot(),
  );
}

StravaCoachingProfile _stravaSnapshot() {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime(2026, 6, 1),
    value: 42,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime(2026, 6, 2),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime(2026, 3, 10),
      dataThroughDate: DateTime(2026, 6, 2),
      activityCount: 24,
      runActivityCount: 18,
      confidence: StravaDataConfidence.medium,
    ),
    dataConfidence: StravaDataConfidence.medium,
    trainingBase: [evidence],
    endurance: const [],
    speedMarkers: const [],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 420, paceMaxSecPerKm: 460),
      easy: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
      longRun: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 300),
      steady: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 285),
      tempo: StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
      threshold: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 250),
      racePace: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 230),
      intervals: StravaPaceZone(paceMinSecPerKm: 200, paceMaxSecPerKm: 215),
      strides: StravaPaceZone(paceMinSecPerKm: 180, paceMaxSecPerKm: 190),
    ),
    terrain: StravaTerrainProfile.flat,
    recoveryGuardrails: const [],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 21.1,
        primaryTime: const Duration(hours: 1, minutes: 38),
        stretchTime: const Duration(hours: 1, minutes: 34),
        confidence: StravaDataConfidence.medium,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_endurance',
      summary: 'Protect volume and build aerobic durability.',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('applyActivityStatus preserves plan-level guidance fields', () async {
    final prefs = await SharedPreferences.getInstance();
    final fixturePlan = _planWithGuidanceFields();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        planVersionRepositoryProvider.overrideWithValue(
          _FixedPlanVersionRepository(fixturePlan),
        ),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(trainingPlanProvider.future);

    expect(loaded.paceZones, isNotNull);
    expect(loaded.paceZones!.easy.paceMaxSecPerKm, 340);
    expect(loaded.raceGuidance, isNotNull);
    expect(
      loaded.raceGuidance!.raceDayExecution,
      fixturePlan.raceGuidance?.raceDayExecution,
    );
    expect(loaded.generatedLocale, fixturePlan.generatedLocale);
    expect(loaded.stravaCoachingProfileSnapshot, isNotNull);
    expect(
      loaded.stravaCoachingProfileSnapshot!.provenance.source,
      fixturePlan.stravaCoachingProfileSnapshot!.provenance.source,
    );
  });

  test(
    'skipSession and restoreSession keep plan-level guidance fields',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final fixturePlan = _planWithGuidanceFields();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          planVersionRepositoryProvider.overrideWithValue(
            _FixedPlanVersionRepository(fixturePlan),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(trainingPlanProvider.future);

      final notifier = container.read(trainingPlanProvider.notifier);
      notifier.skipSession('run-1');
      await Future<void>.delayed(Duration.zero);

      final skipped = container.read(trainingPlanProvider).value;
      expect(skipped?.sessions.first.status, SessionStatus.skipped);
      expect(skipped?.paceZones, isNotNull);
      expect(skipped?.raceGuidance, isNotNull);
      expect(skipped?.generatedLocale, fixturePlan.generatedLocale);
      expect(skipped?.stravaCoachingProfileSnapshot, isNotNull);

      notifier.restoreSession('run-1');
      await Future<void>.delayed(Duration.zero);

      final restored = container.read(trainingPlanProvider).value;
      expect(restored?.paceZones, isNotNull);
      expect(restored?.raceGuidance, isNotNull);
      expect(restored?.generatedLocale, fixturePlan.generatedLocale);
      expect(restored?.stravaCoachingProfileSnapshot, isNotNull);
      expect(restored?.sessions.first.status, isNot(SessionStatus.skipped));
    },
  );

  test('skipSession records a pending adjustment and revision', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(trainingPlanProvider.notifier).skipSession('run-1');
    await Future<void>.delayed(Duration.zero);

    final adjustments = await container.read(planAdjustmentsProvider.future);
    final revisions = await container.read(planRevisionsProvider.future);
    expect(adjustments, hasLength(1));
    expect(adjustments.single.plannedSessionId, 'run-1');
    expect(adjustments.single.trigger, PlanAdjustmentTrigger.skippedSession);
    expect(adjustments.single.reason, PlanAdjustmentReason.skippedByRunner);
    expect(adjustments.single.status, PlanAdjustmentStatus.pending);
    expect(revisions, hasLength(1));
    expect(revisions.single.reason, PlanRevisionReason.skippedSession);
    expect(revisions.single.summaryKey, 'revision_skipped_session');
    expect(revisions.single.adjustmentIds, [adjustments.single.id]);
    expect(
      container.read(sessionAdjustmentRequestsForSessionProvider('run-1')),
      hasLength(1),
    );

    final repository = SharedPreferencesAdaptationRepository(prefs);
    expect(repository.loadPlanAdjustments(), hasLength(1));
    expect(repository.loadPlanRevisions(), hasLength(1));

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(await restarted.read(planAdjustmentsProvider.future), hasLength(1));
    expect(await restarted.read(planRevisionsProvider.future), hasLength(1));
  });

  test('support sessions are dropped from active plan recomposition', () async {
    final prefs = await SharedPreferences.getInstance();
    final fixturePlan = TrainingPlan(
      id: 'provider-support-recompose',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 4),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 42,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'strength-1',
          date: DateTime(2026, 6, 4),
          weekNumber: 1,
          type: SupplementalSessionType.strength,
          status: SupportSessionStatus.planned,
          durationMinutes: 25,
          load: 'moderate',
          timingGuidance: 'on_off_days',
          interferenceRule: 'avoid_day_before_long_run',
          taperAdjustment: 'reduce_load_week_before_race',
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        planVersionRepositoryProvider.overrideWithValue(
          _FixedPlanVersionRepository(fixturePlan),
        ),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(trainingPlanProvider.future);
    expect(loaded.supportSessions, isEmpty);

    container.read(trainingPlanProvider.notifier).skipSession('run-1');
    await Future<void>.delayed(Duration.zero);

    final recomposedPlan = container.read(trainingPlanProvider).value;
    expect(recomposedPlan?.supportSessions ?? const [], isEmpty);
  });

  test(
    'repeated skip events create distinct adjustment and revision records',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(trainingPlanProvider.notifier);
      notifier.skipSession('w4-thu');
      notifier.restoreSession('w4-thu');
      notifier.skipSession('w4-thu');
      await Future<void>.delayed(Duration.zero);

      final adjustments = await container.read(planAdjustmentsProvider.future);
      final revisions = await container.read(planRevisionsProvider.future);

      expect(adjustments, hasLength(2));
      expect(adjustments.map((item) => item.id).toSet(), hasLength(2));
      expect(revisions, hasLength(2));
      expect(revisions.map((item) => item.id).toSet(), hasLength(2));
    },
  );

  test(
    'restoreSession dismisses pending adjustment requests for that session',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(trainingPlanProvider.notifier);
      notifier.skipSession('w4-thu');
      await Future<void>.delayed(Duration.zero);

      notifier.restoreSession('w4-thu');
      await Future<void>.delayed(Duration.zero);

      final adjustments = await container.read(planAdjustmentsProvider.future);
      expect(adjustments, hasLength(1));
      expect(adjustments.single.plannedSessionId, 'w4-thu');
      expect(adjustments.single.status, PlanAdjustmentStatus.dismissed);

      final repository = SharedPreferencesAdaptationRepository(prefs);
      expect(repository.loadPlanAdjustments(), hasLength(1));
      expect(
        repository.loadPlanAdjustments().single.status,
        PlanAdjustmentStatus.dismissed,
      );
    },
  );

  test('recordCompletedRunFeedback persists typed feedback', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(trainingPlanProvider.notifier)
        .recordCompletedRunFeedback(
          session: PreRunArgs(
            session: RunFlowSessionContext(
              sessionId: 'w4-tue',
              sessionDate: DateTime(2026, 4, 7, 7, 30),
              sessionType: SessionType.easyRun,
              weekNumber: 4,
              workoutTarget: null,
              workoutSteps: [],
              supplementalType: null,
              isRunSession: true,
              distanceKm: 8.0,
              durationMinutes: 42,
              elevationGainMeters: 96,
              intervalReps: null,
              intervalRepDistanceMeters: null,
              intervalRecoverySeconds: null,
              warmUpMinutes: 5,
              coolDownMinutes: 3,
            ),
          ).session,
          activityId: 'activity_w4-tue',
          perceivedEffort: ActivityPerceivedEffort.hard,
          checkIn: const PreRunCheckIn(
            sleep: PreRunSleepLevel.poor,
            legs: null,
            pain: null,
            readiness: null,
          ),
          notes: 'Heavy legs',
          recordedAt: DateTime(2026, 4, 7, 8, 30),
        );
    await Future<void>.delayed(Duration.zero);

    final feedback = await container.read(sessionFeedbackProvider.future);
    expect(feedback, hasLength(1));
    expect(feedback.single.plannedSessionId, 'w4-tue');
    expect(feedback.single.activityId, 'activity_w4-tue');
    expect(feedback.single.difficulty, SessionFeedbackDifficulty.hard);
    expect(feedback.single.recoveryStatus, SessionRecoveryStatus.fatigued);
    expect(
      container.read(sessionFeedbacksForSessionProvider('w4-tue')),
      hasLength(1),
    );

    final repository = SharedPreferencesAdaptationRepository(prefs);
    expect(repository.loadSessionFeedback(), hasLength(1));

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(await restarted.read(sessionFeedbackProvider.future), hasLength(1));
    expect(
      restarted.read(sessionFeedbacksForSessionProvider('w4-tue')),
      hasLength(1),
    );
  });

  test('repeated feedback events keep distinct feedback history', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(trainingPlanProvider.notifier);
    final session = PreRunArgs(
      session: RunFlowSessionContext(
        sessionId: 'w4-tue',
        sessionDate: DateTime(2026, 4, 7, 7, 30),
        sessionType: SessionType.easyRun,
        weekNumber: 4,
        workoutTarget: null,
        workoutSteps: [],
        supplementalType: null,
        isRunSession: true,
        distanceKm: 8.0,
        durationMinutes: 42,
        elevationGainMeters: 96,
        intervalReps: null,
        intervalRepDistanceMeters: null,
        intervalRecoverySeconds: null,
        warmUpMinutes: 5,
        coolDownMinutes: 3,
      ),
    ).session;

    notifier.recordCompletedRunFeedback(
      session: session,
      activityId: 'activity_w4-tue',
      perceivedEffort: ActivityPerceivedEffort.moderate,
      checkIn: null,
      notes: 'First note',
      recordedAt: DateTime(2026, 4, 7, 8, 30, 0),
    );
    notifier.recordCompletedRunFeedback(
      session: session,
      activityId: 'activity_w4-tue',
      perceivedEffort: ActivityPerceivedEffort.hard,
      checkIn: null,
      notes: 'Second note',
      recordedAt: DateTime(2026, 4, 7, 8, 45, 0),
    );
    await Future<void>.delayed(Duration.zero);

    final feedback = await container.read(sessionFeedbackProvider.future);
    expect(feedback, hasLength(2));
    expect(feedback.map((item) => item.id).toSet(), hasLength(2));
    expect(feedback.first.notes, 'Second note');
  });
}
