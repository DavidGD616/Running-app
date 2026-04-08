import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/activity/activity.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/training_plan/data/adaptation_repository.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_provider.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('skipSession records a pending adjustment and revision', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(trainingPlanProvider.notifier).skipSession('w4-thu');
    await Future<void>.delayed(Duration.zero);

    final adjustments = container.read(planAdjustmentsProvider);
    final revisions = container.read(planRevisionsProvider);
    expect(adjustments, hasLength(1));
    expect(adjustments.single.plannedSessionId, 'w4-thu');
    expect(adjustments.single.trigger, PlanAdjustmentTrigger.skippedSession);
    expect(adjustments.single.reason, PlanAdjustmentReason.skippedByRunner);
    expect(adjustments.single.status, PlanAdjustmentStatus.pending);
    expect(revisions, hasLength(1));
    expect(revisions.single.reason, PlanRevisionReason.skippedSession);
    expect(revisions.single.summaryKey, 'revision_skipped_session');
    expect(revisions.single.adjustmentIds, [adjustments.single.id]);
    expect(
      container.read(sessionAdjustmentRequestsForSessionProvider('w4-thu')),
      hasLength(1),
    );

    final repository = SharedPreferencesAdaptationRepository(prefs);
    expect(repository.loadPlanAdjustments(), hasLength(1));
    expect(repository.loadPlanRevisions(), hasLength(1));

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(planAdjustmentsProvider), hasLength(1));
    expect(restarted.read(planRevisionsProvider), hasLength(1));
  });

  test('support sessions survive training plan recomposition', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final initialPlan = container.read(trainingPlanProvider);
    expect(initialPlan.supportSessions, isNotEmpty);

    container.read(trainingPlanProvider.notifier).skipSession('w4-thu');
    await Future<void>.delayed(Duration.zero);

    final recomposedPlan = container.read(trainingPlanProvider);
    expect(recomposedPlan.supportSessions, isNotEmpty);
    expect(
      recomposedPlan.supportSessions.map((session) => session.id),
      orderedEquals(initialPlan.supportSessions.map((session) => session.id)),
    );
  });

  test('repeated skip events create distinct adjustment and revision records', () async {
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

    final adjustments = container.read(planAdjustmentsProvider);
    final revisions = container.read(planRevisionsProvider);

    expect(adjustments, hasLength(2));
    expect(adjustments.map((item) => item.id).toSet(), hasLength(2));
    expect(revisions, hasLength(2));
    expect(revisions.map((item) => item.id).toSet(), hasLength(2));
  });

  test('restoreSession dismisses pending adjustment requests for that session', () async {
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

    final adjustments = container.read(planAdjustmentsProvider);
    expect(adjustments, hasLength(1));
    expect(adjustments.single.plannedSessionId, 'w4-thu');
    expect(adjustments.single.status, PlanAdjustmentStatus.dismissed);

    final repository = SharedPreferencesAdaptationRepository(prefs);
    expect(repository.loadPlanAdjustments(), hasLength(1));
    expect(
      repository.loadPlanAdjustments().single.status,
      PlanAdjustmentStatus.dismissed,
    );
  });

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

    final feedback = container.read(sessionFeedbackProvider);
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

    expect(restarted.read(sessionFeedbackProvider), hasLength(1));
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

    final feedback = container.read(sessionFeedbackProvider);
    expect(feedback, hasLength(2));
    expect(feedback.map((item) => item.id).toSet(), hasLength(2));
    expect(feedback.first.notes, 'Second note');
  });
}
