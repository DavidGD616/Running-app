import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/domain/models/professional_plan_metadata.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/support_plan_session.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

void main() {
  group('Professional plan schema serialization', () {
    test('TrainingPlan with all new fields round-trips correctly', () {
      final plan = TrainingPlan(
        id: 'plan-pro-1',
        raceType: TrainingPlanRaceType.halfMarathon,
        totalWeeks: 12,
        currentWeekNumber: 2,
        sessions: [
          TrainingSession(
            id: 'session-1',
            date: DateTime.utc(2026, 6, 8),
            type: SessionType.tempoRun,
            status: SessionStatus.upcoming,
          ),
        ],
        generatedLocale: 'es',
        paceZones: _paceZones(),
        coachingBriefSnapshot: _coachingBriefSnapshot(),
        planRationale: const ['Used measured training evidence.'],
        evidenceTarget: const CoachingTarget(
          distanceKm: 21.097,
          time: Duration(hours: 1, minutes: 38),
          paceSecPerKm: 279,
          confidence: CoachingConfidence.high,
          source: CoachingSource.strava,
          supported: true,
          reason: 'Backed by recent long-run and threshold evidence.',
        ),
        ambitiousTarget: const CoachingTarget(
          distanceKm: 21.097,
          time: Duration(hours: 1, minutes: 34),
          paceSecPerKm: 267,
          confidence: CoachingConfidence.limited,
          source: CoachingSource.strava,
          supported: false,
          reason: 'Too aggressive for current evidence.',
        ),
        confidence: CoachingConfidence.high,
        phaseStrategy: const [
          PhaseStrategy(phase: CoachingPhase.base, weeks: 2),
          PhaseStrategy(phase: CoachingPhase.build, weeks: 4),
          PhaseStrategy(phase: CoachingPhase.taperRace, weeks: 2),
        ],
        raceGuidance: const RaceGuidance(
          raceDayExecution: 'Start controlled, finish strong.',
          warmup: '10 min jog + strides',
          primaryTarget: Duration(hours: 1, minutes: 38),
          stretchTarget: Duration(hours: 1, minutes: 35),
          splitPlan: 'Negative split',
          whenToPress: 'After kilometer 15',
          whatToAvoid: 'Going out too fast',
          coachingNotes: 'Stay relaxed uphill',
          sleepNotes: 'Aim for 8 hours',
          fuelingNotes: 'Take gel every 30 min',
          hydrationNotes: 'Sip every aid station',
          taperReminders: 'Reduce volume race week',
          weatherCourseNotes: 'Adjust for heat and hills',
        ),
        stravaCoachingProfileSnapshot: _stravaSnapshot(),
      );

      final restored = TrainingPlan.fromJson(plan.toJson());

      expect(restored, isNotNull);
      expect(restored!.toJson(), plan.toJson());
      expect(restored.generatedLocale, 'es');
      expect(restored.coachingBriefSnapshot, isNotNull);
      expect(
        restored.coachingBriefSnapshot!.readinessLevel,
        CoachingReadinessLevel.prepared,
      );
      expect(restored.planRationale, ['Used measured training evidence.']);
      expect(restored.evidenceTarget?.supported, isTrue);
      expect(restored.ambitiousTarget?.supported, isFalse);
      expect(restored.confidence, CoachingConfidence.high);
      expect(restored.phaseStrategy.last.phase, CoachingPhase.taperRace);
      expect(restored.paceZones, isNotNull);
      expect(restored.paceZones!.tempo.paceMinSecPerKm, 270);
      expect(restored.raceGuidance, isNotNull);
      expect(
        restored.raceGuidance!.primaryTarget,
        const Duration(hours: 1, minutes: 38),
      );
      expect(restored.stravaCoachingProfileSnapshot, isNotNull);
      expect(
        restored.stravaCoachingProfileSnapshot!.dataConfidence,
        StravaDataConfidence.medium,
      );
    });

    test(
      'TrainingPlan without new fields parses correctly for backward compatibility',
      () {
        final legacyJson = {
          'schemaVersion': 1,
          'id': 'legacy-plan-1',
          'raceType': 'tenK',
          'totalWeeks': 8,
          'currentWeekNumber': 1,
          'sessions': [
            {
              'schemaVersion': 1,
              'id': 'legacy-session-1',
              'date': '2026-06-10T00:00:00.000Z',
              'type': 'easyRun',
              'status': 'upcoming',
              'weekNumber': 1,
              'workoutSteps': <Map<String, dynamic>>[],
            },
          ],
          'supportSessions': <Map<String, dynamic>>[],
        };

        final restored = TrainingPlan.fromJson(legacyJson);

        expect(restored, isNotNull);
        expect(restored!.id, 'legacy-plan-1');
        expect(restored.generatedLocale, 'en');
        expect(restored.coachingBriefSnapshot, isNull);
        expect(restored.planRationale, isEmpty);
        expect(restored.evidenceTarget, isNull);
        expect(restored.ambitiousTarget, isNull);
        expect(restored.confidence, isNull);
        expect(restored.phaseStrategy, isEmpty);
        expect(restored.paceZones, isNull);
        expect(restored.raceGuidance, isNull);
        expect(restored.stravaCoachingProfileSnapshot, isNull);
      },
    );

    test('WorkoutTarget with pace range round-trips', () {
      const target = WorkoutTarget.pace(
        TargetZone.tempo,
        paceMinSecPerKm: 270,
        paceMaxSecPerKm: 285,
        effortCue: 'comfortably hard',
      );

      final restored = WorkoutTarget.fromJson(target.toJson());

      expect(restored, isNotNull);
      expect(restored!.toJson(), target.toJson());
      expect(restored.paceMinSecPerKm, 270);
      expect(restored.paceMaxSecPerKm, 285);
      expect(restored.effortCue, 'comfortably hard');
    });

    test(
      'WorkoutTarget without pace range parses for backward compatibility',
      () {
        const target = WorkoutTarget.effort(TargetZone.easy);

        final json = target.toJson();
        final restored = WorkoutTarget.fromJson(json);

        expect(restored, isNotNull);
        expect(restored!.type, TargetType.effort);
        expect(restored.zone, TargetZone.easy);
        expect(restored.paceMinSecPerKm, isNull);
        expect(restored.paceMaxSecPerKm, isNull);
        expect(restored.effortCue, isNull);
        expect(json.containsKey('paceMinSecPerKm'), isFalse);
        expect(json.containsKey('paceMaxSecPerKm'), isFalse);
        expect(json.containsKey('effortCue'), isFalse);
      },
    );

    test('RaceGuidance round-trip', () {
      const guidance = RaceGuidance(
        raceDayExecution: 'Run your process.',
        warmup: 'Easy jog + drills',
        primaryTarget: Duration(minutes: 45, seconds: 30),
        stretchTarget: Duration(minutes: 44, seconds: 50),
        splitPlan: 'Slightly faster second half',
      );

      final restored = RaceGuidance.fromJson(guidance.toJson());

      expect(restored.toJson(), guidance.toJson());
    });

    test('SupportPlanSession round-trip', () {
      final support = SupportPlanSession(
        id: 'support-plan-1',
        date: DateTime.utc(2026, 6, 12),
        weekNumber: 2,
        category: StrengthCategory.coreMobility,
        load: 'light',
        timingGuidance: 'after_easy_run',
        interferenceRule: 'avoid_day_before_long_run',
        taperAdjustment: 'reduce_load_week_before_race',
        durationMinutes: 30,
        notes: 'Keep form strict.',
      );

      final restored = SupportPlanSession.fromJson(support.toJson());

      expect(restored.toJson(), support.toJson());
      expect(restored.category, StrengthCategory.coreMobility);
    });

    test(
      'TrainingPlan drops backend support sessions for mobile plan state',
      () {
        final restored = TrainingPlan.fromJson({
          'schemaVersion': 1,
          'id': 'backend-support-plan',
          'raceType': 'tenK',
          'totalWeeks': 8,
          'currentWeekNumber': 2,
          'sessions': <Map<String, dynamic>>[],
          'supportSessions': [
            {
              'id': 'backend-support-lower-body',
              'date': '2026-06-08T07:00:00.000Z',
              'weekNumber': 2,
              'category': 'lower_body',
              'durationMinutes': 45,
              'notes': 'Leg strength ladder.',
              'load': 'moderate',
              'timingGuidance': 'on_off_days',
              'interferenceRule': 'avoid_day_before_long_run',
              'taperAdjustment': 'reduce_load_week_before_race',
            },
          ],
        });

        expect(restored, isNotNull);
        expect(restored!.supportSessions, isEmpty);
      },
    );

    test('WorkoutStep stride round-trip', () {
      const step = WorkoutStep.stride(
        target: WorkoutTarget.pace(
          TargetZone.interval,
          paceMinSecPerKm: 180,
          paceMaxSecPerKm: 220,
          effortCue: 'relaxed fast',
        ),
        duration: Duration(seconds: 20),
        distanceMeters: 100,
      );

      final restored = WorkoutStep.fromJson(step.toJson());

      expect(restored, isNotNull);
      expect(restored!.toJson(), step.toJson());
      expect(restored.kind, WorkoutStepKind.stride);
    });

    test('Invalid pace range (min > max) throws FormatException', () {
      expect(
        () => WorkoutTarget.fromJson({
          'type': 'pace',
          'zone': 'tempo',
          'paceMinSecPerKm': 300,
          'paceMaxSecPerKm': 280,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('Invalid JSON for RaceGuidance throws FormatException', () {
      expect(
        () => RaceGuidance.fromJson({
          'raceDayExecution': 'Execute smart',
          'primaryTargetSec': 'not-an-int',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'Malformed stravaCoachingProfileSnapshot does not throw and falls back to null',
      () {
        final json = TrainingPlan(
          id: 'plan-pro-2',
          raceType: TrainingPlanRaceType.halfMarathon,
          totalWeeks: 12,
          currentWeekNumber: 1,
          sessions: const [],
          stravaCoachingProfileSnapshot: _stravaSnapshot(),
        ).toJson();

        final malformedSnapshot =
            (json['stravaCoachingProfileSnapshot'] as Map<String, dynamic>)
              ..remove('provenance');
        json['stravaCoachingProfileSnapshot'] = malformedSnapshot;

        final restored = TrainingPlan.fromJson(json);

        expect(restored, isNotNull);
        expect(restored!.stravaCoachingProfileSnapshot, isNull);
      },
    );

    test(
      'CoachingTarget ignores non-positive numeric values without rejecting metadata',
      () {
        final target = coachingTargetOrNull({
          'distanceKm': 0,
          'timeSec': -30,
          'paceSecPerKm': 0,
          'confidence': 'high',
          'source': 'strava',
          'supported': true,
          'reason': 'Target is unavailable.',
        });

        expect(target, isNotNull);
        expect(target!.distanceKm, isNull);
        expect(target.time, isNull);
        expect(target.paceSecPerKm, isNull);
        expect(target.confidence, CoachingConfidence.high);
        expect(target.source, CoachingSource.strava);
        expect(target.supported, isTrue);
        expect(target.reason, 'Target is unavailable.');
      },
    );
  });
}

CoachingBriefSnapshot _coachingBriefSnapshot() {
  const evidenceTarget = CoachingTarget(
    distanceKm: 21.097,
    time: Duration(hours: 1, minutes: 38),
    paceSecPerKm: 279,
    confidence: CoachingConfidence.high,
    source: CoachingSource.strava,
    supported: true,
    reason: 'Backed by recent long-run and threshold evidence.',
  );
  const ambitiousTarget = CoachingTarget(
    distanceKm: 21.097,
    time: Duration(hours: 1, minutes: 34),
    paceSecPerKm: 267,
    confidence: CoachingConfidence.limited,
    source: CoachingSource.strava,
    supported: false,
    reason: 'Too aggressive for current evidence.',
  );
  return const CoachingBriefSnapshot(
    raceType: 'halfMarathon',
    readinessLevel: CoachingReadinessLevel.prepared,
    confidence: CoachingConfidence.high,
    source: CoachingSource.strava,
    currentVolumeKmPerWeek: 42,
    currentRunsPerWeek: 4,
    recentLongRunKm: 18,
    planLengthWeeks: 12,
    phaseStrategy: [
      PhaseStrategy(phase: CoachingPhase.base, weeks: 2),
      PhaseStrategy(phase: CoachingPhase.build, weeks: 4),
      PhaseStrategy(phase: CoachingPhase.taperRace, weeks: 2),
    ],
    maxWeeklyVolumeKm: 55,
    longRunCeilingKm: 23,
    weeklyRunDays: 4,
    taper: CoachingTaper(
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: 'Fresh legs.',
    ),
    workoutEmphasis: ['aerobic volume', 'threshold'],
    evidenceTarget: evidenceTarget,
    ambitiousTarget: ambitiousTarget,
    constraints: ['Do not prescribe unsupported race-pace workouts.'],
    rationale: ['Used measured training evidence.'],
  );
}

StravaPaceZones _paceZones() {
  return const StravaPaceZones(
    recovery: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
    easy: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 370),
    longRun: StravaPaceZone(paceMinSecPerKm: 320, paceMaxSecPerKm: 360),
    steady: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 330),
    tempo: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 295),
    threshold: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 270),
    racePace: StravaPaceZone(paceMinSecPerKm: 250, paceMaxSecPerKm: 260),
    intervals: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 245),
    strides: StravaPaceZone(paceMinSecPerKm: 185, paceMaxSecPerKm: 215),
  );
}

StravaCoachingProfile _stravaSnapshot() {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 42,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime.utc(2026, 6, 2),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime.utc(2026, 3, 10),
      dataThroughDate: DateTime.utc(2026, 6, 2),
      activityCount: 24,
      runActivityCount: 18,
      confidence: StravaDataConfidence.medium,
    ),
    dataConfidence: StravaDataConfidence.medium,
    trainingBase: [evidence],
    endurance: const [],
    speedMarkers: const [],
    paceZones: _paceZones(),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 1,
        category: 'recovery_sleep',
        message: 'Protect sleep after hard sessions.',
      ),
    ],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 21.1,
        primaryTime: const Duration(hours: 1, minutes: 38),
        confidence: StravaDataConfidence.medium,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_endurance',
      summary: 'Extend aerobic durability.',
    ),
  );
}
