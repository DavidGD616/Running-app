import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/onboarding/domain/models/professional_plan_input.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  group('ProfessionalPlanInput', () {
    test('strong Strava input supports null manual fitness', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.high,
        ),
        manualFitness: null,
      );

      final restored = ProfessionalPlanInput.fromJson(input.toJson());

      expect(restored.fitnessSource, FitnessSource.strava);
      expect(restored.stravaCoachingProfile, isNotNull);
      expect(
        restored.stravaCoachingProfile!.dataConfidence,
        StravaDataConfidence.high,
      );
      expect(restored.manualFitness, isNull);
      expect(restored.schedule.trainingDays, 4);
    });

    test('weak Strava input supports Strava and manual fitness together', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.medium,
        ),
        manualFitness: const ManualFitnessInput(
          experience: RunnerExperience.intermediate,
          weeklyVolume: WeeklyVolumeRange.volume3,
          longestRun: LongestRunRange.run3,
          canCompleteGoalDistance: TernaryChoice.notSure,
          raceDistanceBefore: RaceDistanceExperience.never,
          benchmark: BenchmarkType.skip,
        ),
      );

      final restored = ProfessionalPlanInput.fromJson(input.toJson());

      expect(restored.fitnessSource, FitnessSource.strava);
      expect(restored.stravaCoachingProfile, isNotNull);
      expect(
        restored.stravaCoachingProfile!.dataConfidence,
        StravaDataConfidence.medium,
      );
      expect(restored.manualFitness, isNotNull);
      expect(restored.manualFitness!.experience, RunnerExperience.intermediate);
    });

    test('manual-only input supports null Strava coaching profile', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.manual,
        stravaCoachingProfile: null,
        manualFitness: const ManualFitnessInput(
          experience: RunnerExperience.beginner,
          weeklyVolume: WeeklyVolumeRange.volume2,
          longestRun: LongestRunRange.run2,
          canCompleteGoalDistance: TernaryChoice.yes,
          raceDistanceBefore: RaceDistanceExperience.once,
          benchmark: BenchmarkType.oneKmRun,
          benchmarkTime: Duration(minutes: 6, seconds: 2),
        ),
      );

      final restored = ProfessionalPlanInput.fromJson(input.toJson());

      expect(restored.fitnessSource, FitnessSource.manual);
      expect(restored.stravaCoachingProfile, isNull);
      expect(restored.manualFitness, isNotNull);
      expect(restored.manualFitness!.benchmark, BenchmarkType.oneKmRun);
    });

    test('JSON round-trip remains stable for professional plan input', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.medium,
        ),
        manualFitness: const ManualFitnessInput(
          experience: RunnerExperience.intermediate,
          weeklyVolume: WeeklyVolumeRange.volume4,
          longestRun: LongestRunRange.run3,
          canCompleteGoalDistance: TernaryChoice.notSure,
          raceDistanceBefore: RaceDistanceExperience.once,
          benchmark: BenchmarkType.fiveK,
          benchmarkTime: Duration(minutes: 25, seconds: 30),
        ),
      );

      final restored = ProfessionalPlanInput.fromJson(input.toJson());

      expect(restored.toJson(), input.toJson());
      expect(restored.toJson()['fitnessSource'], FitnessSource.strava.key);
      expect(restored.toJson()['planIntensity'], PlanIntensity.balanced.key);
      expect(
        restored.toJson()['raceCourseTerrain'],
        RaceCourseTerrain.rolling.key,
      );
    });

    test(
      'planStartDate uses date-only serialization when included in schedule',
      () {
        final expectedPlanStartDate = DateTime(2026, 6, 11, 17, 42);
        final input = _baseInput(
          fitnessSource: FitnessSource.strava,
          stravaCoachingProfile: _stravaProfile(
            confidence: StravaDataConfidence.high,
          ),
          manualFitness: null,
          planStartDate: expectedPlanStartDate,
        );

        final json = input.toJson();
        final scheduleJson = Map<String, dynamic>.from(json['schedule'] as Map);
        expect(scheduleJson['planStartDate'], '2026-06-11');

        final restored = ProfessionalPlanInput.fromJson(json);
        expect(restored.schedule.planStartDate, DateTime(2026, 6, 11));
      },
    );

    test(
      'professional payload accepts date-only schedule.planStartDate when present',
      () {
        final input = _baseInput(
          fitnessSource: FitnessSource.strava,
          stravaCoachingProfile: _stravaProfile(
            confidence: StravaDataConfidence.medium,
          ),
          manualFitness: null,
        );
        final json = input.toJson();
        final scheduleJson = Map<String, dynamic>.from(json['schedule'] as Map)
          ..['planStartDate'] = '2026-06-25';

        json['schedule'] = scheduleJson;

        final restored = ProfessionalPlanInput.fromJson(json);
        expect(restored.schedule.planStartDate, DateTime(2026, 6, 25));
      },
    );

    test('professional payload rejects non-date-only planStartDate values', () {
      final input =
          _baseInput(
            fitnessSource: FitnessSource.strava,
            stravaCoachingProfile: _stravaProfile(
              confidence: StravaDataConfidence.medium,
            ),
            manualFitness: null,
          ).toJson()..update('schedule', (value) {
            final schedule = Map<String, dynamic>.from(value as Map);
            schedule['planStartDate'] = '2026-06-25T10:00:00Z';
            return schedule;
          }, ifAbsent: () => {'planStartDate': '2026-06-25T10:00:00Z'});

      expect(
        () => ProfessionalPlanInput.fromJson(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('onboarding draft schedule planStartDate is forwarded to input', () {
      final draft =
          _withAcceptedSuggestedRaceTarget(
            _nonTimeStravaDraftWithoutTargets(),
          ).copyWith(
            schedule: ScheduleProfileDraft(
              trainingDays: 4,
              longRunDay: WeekdayChoice.sunday,
              weekdayTime: TimeSlot.min45,
              weekendTime: TimeSlot.min90,
              hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
              preferredTimeOfDay: PreferredTimeOfDay.morning,
              planStartDate: DateTime(2026, 6, 13, 8, 15),
            ),
          );

      final input = buildProfessionalPlanInputFromOnboardingDraft(
        draft: draft,
        preferences: const UserPreferences(unitSystem: UnitSystem.km),
        locale: 'en',
      )!;

      final json = input.toJson();
      final scheduleJson = Map<String, dynamic>.from(json['schedule'] as Map);

      expect(scheduleJson['planStartDate'], '2026-06-13');
      expect(input.schedule.planStartDate, DateTime(2026, 6, 13));
    });

    test(
      'non-onboarding generation can omit planStartDate while keeping schedule draft',
      () {
        final draft =
            _withAcceptedSuggestedRaceTarget(
              _nonTimeStravaDraftWithoutTargets(),
            ).copyWith(
              schedule: ScheduleProfileDraft(
                trainingDays: 4,
                longRunDay: WeekdayChoice.sunday,
                weekdayTime: TimeSlot.min45,
                weekendTime: TimeSlot.min90,
                hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
                preferredTimeOfDay: PreferredTimeOfDay.morning,
                planStartDate: DateTime(2026, 6, 13, 8, 15),
              ),
            );

        final input = buildProfessionalPlanInputFromOnboardingDraft(
          draft: draft,
          preferences: const UserPreferences(unitSystem: UnitSystem.km),
          locale: 'en',
          includePlanStartDate: false,
        )!;

        final scheduleJson = Map<String, dynamic>.from(
          input.toJson()['schedule'] as Map,
        );
        expect(scheduleJson.containsKey('planStartDate'), isFalse);
        expect(input.schedule.planStartDate, isNull);
      },
    );

    test('Strava professional payload omits nullable optional fields', () {
      final draft = _withAcceptedSuggestedRaceTarget(
        _nonTimeStravaDraftWithoutTargets(),
      );
      final input = buildProfessionalPlanInputFromOnboardingDraft(
        draft: draft,
        preferences: const UserPreferences(unitSystem: UnitSystem.km),
        locale: 'en',
      )!.toJson();

      expect(input['fitnessSource'], FitnessSource.strava.key);
      expect(input.containsKey('stravaCoachingProfile'), isTrue);
      expect(input.containsKey('manualFitness'), isFalse);

      final acceptedRaceTarget =
          input['acceptedRaceTarget'] as Map<String, dynamic>;
      expect(acceptedRaceTarget.containsKey('stretchTimeMs'), isFalse);
      expect(acceptedRaceTarget.containsKey('confidence'), isFalse);

      final coaching =
          _baseInput(
                fitnessSource: FitnessSource.strava,
                stravaCoachingProfile: _stravaProfile(
                  confidence: StravaDataConfidence.high,
                ),
                manualFitness: null,
              ).toJson()['stravaCoachingProfile']
              as Map<String, dynamic>;
      final firstTarget = (coaching['raceTargets'] as List).first as Map;
      expect(firstTarget.containsKey('stretchTimeSec'), isFalse);

      expect(input.containsKey('goal'), isTrue);
      expect(input.containsKey('schedule'), isTrue);
      expect(input.containsKey('health'), isTrue);
      expect(input.containsKey('strengthPreferences'), isTrue);
      expect(input.containsKey('planIntensity'), isTrue);
      expect(input.containsKey('locale'), isTrue);
      expect(input['locale'], 'en');
    });

    test('manual professional payload omits optional race terrain', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.manual,
        stravaCoachingProfile: null,
        manualFitness: const ManualFitnessInput(
          experience: RunnerExperience.beginner,
          weeklyVolume: WeeklyVolumeRange.volume2,
          longestRun: LongestRunRange.run2,
          canCompleteGoalDistance: TernaryChoice.yes,
          raceDistanceBefore: RaceDistanceExperience.once,
          benchmark: BenchmarkType.oneKmRun,
          benchmarkTime: Duration(minutes: 6, seconds: 2),
        ),
        raceCourseTerrain: null,
      ).toJson();

      expect(input.containsKey('raceCourseTerrain'), isFalse);
      expect(input.containsKey('stravaCoachingProfile'), isFalse);
      expect(input['manualFitness'], isNotNull);
      final manualFitness = input['manualFitness'] as Map<String, dynamic>;
      expect(manualFitness.containsKey('benchmarkTimeMs'), isTrue);
      expect(manualFitness['experience'], RunnerExperience.beginner.key);
    });

    test('manual onboarding payload includes richer training snapshot', () {
      final base = buildRunnerProfileDraft();
      final fitness = base.fitness;
      final draft = base.copyWith(
        fitness: FitnessProfileDraft(
          experience: fitness.experience,
          canRun10Min: fitness.canRun10Min,
          runningDays: fitness.runningDays,
          weeklyVolume: fitness.weeklyVolume,
          longestRun: fitness.longestRun,
          canCompleteGoalDistance: fitness.canCompleteGoalDistance,
          raceDistanceBefore: fitness.raceDistanceBefore,
          benchmark: fitness.benchmark,
          benchmarkTime: fitness.benchmarkTime,
          fitnessSource: FitnessSource.manual.key,
        ),
      );

      final input = buildProfessionalPlanInputFromOnboardingDraft(
        draft: draft,
        preferences: const UserPreferences(unitSystem: UnitSystem.km),
        locale: 'en',
      )!;
      final json = input.toJson();

      expect(json['fitnessSource'], FitnessSource.manual.key);
      expect(json.containsKey('stravaCoachingProfile'), isFalse);
      final manualFitness = json['manualFitness'] as Map<String, dynamic>;
      expect(manualFitness['weeklyVolume'], fitness.weeklyVolume!.key);
      expect(manualFitness['longestRun'], fitness.longestRun!.key);
      expect(manualFitness['benchmark'], fitness.benchmark!.key);
      expect(
        manualFitness['benchmarkTimeMs'],
        fitness.benchmarkTime!.inMilliseconds,
      );

      final snapshot =
          manualFitness['trainingSnapshot'] as Map<String, dynamic>;
      expect(snapshot['estimatedWeeklyVolume'], fitness.weeklyVolume!.key);
      expect(snapshot['estimatedLongestRun'], fitness.longestRun!.key);
      expect(snapshot['runsPerWeek'], fitness.runningDays);
      expect(snapshot['benchmark'], fitness.benchmark!.key);
      expect(
        snapshot['benchmarkTimeMs'],
        fitness.benchmarkTime!.inMilliseconds,
      );
      expect(snapshot['painLevel'], base.health.painLevel!.key);
      expect(snapshot['injuryHistory'], base.health.injuryHistory!.key);
      expect(
        snapshot['hasHealthConditions'],
        base.health.hasHealthConditions!.key,
      );
    });

    test('invalid JSON throws FormatException', () {
      final json = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.high,
        ),
        manualFitness: null,
      ).toJson();

      json['manualFitness'] = const ManualFitnessInput(
        experience: RunnerExperience.intermediate,
      ).toJson();

      expect(
        () => ProfessionalPlanInput.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('Strava limited confidence without manualFitness is valid', () {
      final input = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.limited,
        ),
        manualFitness: null,
      );

      final restored = ProfessionalPlanInput.fromJson(input.toJson());

      expect(restored.fitnessSource, FitnessSource.strava);
      expect(
        restored.stravaCoachingProfile?.dataConfidence,
        StravaDataConfidence.limited,
      );
      expect(restored.manualFitness, isNull);
    });

    test('manual source with no manualFitness throws', () {
      final json = _baseInput(
        fitnessSource: FitnessSource.manual,
        stravaCoachingProfile: null,
        manualFitness: null,
      ).toJson();

      expect(
        () => ProfessionalPlanInput.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('strava source with no stravaCoachingProfile throws', () {
      final json = _baseInput(
        fitnessSource: FitnessSource.strava,
        stravaCoachingProfile: _stravaProfile(
          confidence: StravaDataConfidence.medium,
        ),
        manualFitness: null,
      ).toJson()..remove('stravaCoachingProfile');

      expect(
        () => ProfessionalPlanInput.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'suggests a race target for Strava onboarding draft without race targets',
      () {
        final draft = _nonTimeStravaDraftWithoutTargets();
        final acceptedRaceTarget = suggestedRaceTargetFromDraft(draft);

        expect(acceptedRaceTarget, isNotNull);
        expect(acceptedRaceTarget!.distanceKm, 21.097);
        expect(
          acceptedRaceTarget.primaryTime,
          _projectDuration(
            sourceSeconds: 1572, // 26:12 benchmark.
            sourceDistanceKm: 5.0,
            targetDistanceKm: acceptedRaceTarget.distanceKm,
          ),
        );
        expect(acceptedRaceTarget.stretchTime, isNull);
        expect(acceptedRaceTarget.confidence, isNull);
      },
    );

    test('suggested race target matches the selected goal distance', () {
      final base = buildRunnerProfileDraft();
      final baseFitness = base.fitness;
      final draft = buildRunnerProfileDraft().copyWith(
        clearAcceptedRaceTarget: true,
        fitness: FitnessProfileDraft(
          experience: baseFitness.experience,
          canRun10Min: baseFitness.canRun10Min,
          runningDays: baseFitness.runningDays,
          weeklyVolume: baseFitness.weeklyVolume,
          longestRun: baseFitness.longestRun,
          canCompleteGoalDistance: baseFitness.canCompleteGoalDistance,
          raceDistanceBefore: baseFitness.raceDistanceBefore,
          benchmark: baseFitness.benchmark,
          benchmarkTime: baseFitness.benchmarkTime,
          fitnessSource: 'strava',
          stravaCoachingProfile: _stravaProfile(
            confidence: StravaDataConfidence.high,
            raceTargets: const [
              StravaRaceTargetEstimate(
                distanceKm: 5,
                primaryTime: Duration(minutes: 24),
                confidence: StravaDataConfidence.high,
                evidence: [],
              ),
              StravaRaceTargetEstimate(
                distanceKm: 21.097,
                primaryTime: Duration(hours: 1, minutes: 55),
                confidence: StravaDataConfidence.high,
                evidence: [],
              ),
            ],
          ),
        ),
      );

      final acceptedRaceTarget = suggestedRaceTargetFromDraft(draft);

      expect(acceptedRaceTarget, isNotNull);
      expect(acceptedRaceTarget!.distanceKm, 21.097);
      expect(
        acceptedRaceTarget.primaryTime,
        const Duration(hours: 1, minutes: 55),
      );
    });

    test(
      'professional input rejects accepted race target distance mismatch',
      () {
        final draft = _nonTimeStravaDraftWithoutTargets().copyWith(
          acceptedRaceTarget: const AcceptedRaceTarget(
            distanceKm: 5,
            primaryTime: Duration(minutes: 24),
            confidence: StravaDataConfidence.high,
          ),
        );

        final input = buildProfessionalPlanInputFromOnboardingDraft(
          draft: draft,
          preferences: const UserPreferences(unitSystem: UnitSystem.km),
          locale: 'en',
        );

        expect(input, isNull);
      },
    );

    test('requires an explicitly accepted race target for plan input', () {
      final draft = _nonTimeStravaDraftWithoutTargets().copyWith(
        clearAcceptedRaceTarget: true,
      );
      final input = buildProfessionalPlanInputFromOnboardingDraft(
        draft: draft,
        preferences: const UserPreferences(unitSystem: UnitSystem.km),
        locale: 'en',
      );

      expect(input, isNull);
    });
  });
}

ProfessionalPlanInput _baseInput({
  required FitnessSource fitnessSource,
  required StravaCoachingProfile? stravaCoachingProfile,
  required ManualFitnessInput? manualFitness,
  RaceCourseTerrain? raceCourseTerrain = RaceCourseTerrain.rolling,
  DateTime? planStartDate,
}) {
  return ProfessionalPlanInput(
    goal: GoalProfile(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: DateTime.utc(2026, 10, 18),
    ),
    fitnessSource: fitnessSource,
    stravaCoachingProfile: stravaCoachingProfile,
    manualFitness: manualFitness,
    acceptedRaceTarget: AcceptedRaceTarget(
      distanceKm: 21.097,
      primaryTime: const Duration(hours: 1, minutes: 55),
      stretchTime: const Duration(hours: 1, minutes: 52),
      confidence: StravaDataConfidence.medium,
      evidence: [
        StravaEvidencePoint(
          metric: 'speed_marker_10k_pace',
          date: DateTime.utc(2026, 6, 1),
          value: 305,
          unit: 'sec_per_km',
        ),
      ],
    ),
    schedule: ScheduleProfile(
      trainingDays: 4,
      longRunDay: WeekdayChoice.sunday,
      weekdayTime: TimeSlot.min45,
      weekendTime: TimeSlot.min90,
      hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      preferredTimeOfDay: PreferredTimeOfDay.morning,
      planStartDate: planStartDate,
    ),
    health: const HealthProfile(
      painLevel: PainLevelChoice.none,
      injuryHistory: InjuryHistoryChoice.none,
      hasHealthConditions: BinaryChoice.no,
    ),
    strengthPreferences: const StrengthPreferences(
      lifts: true,
      weeklyFrequency: 2,
      categories: {StrengthCategory.lowerBody, StrengthCategory.coreMobility},
      preferredDays: {WeekdayChoice.monday, WeekdayChoice.wednesday},
      sameDayOrder: SameDayOrderPreference.runFirst,
    ),
    planIntensity: PlanIntensity.balanced,
    unitPreference: 'metric',
    locale: 'en',
    raceCourseTerrain: raceCourseTerrain,
  );
}

StravaCoachingProfile _stravaProfile({
  required StravaDataConfidence confidence,
  bool includeRaceTargets = true,
  List<StravaRaceTargetEstimate>? raceTargets,
}) {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 42,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime.utc(2026, 6, 2, 8),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime.utc(2026, 3, 10),
      dataThroughDate: DateTime.utc(2026, 6, 2),
      activityCount: 40,
      runActivityCount: 32,
      confidence: confidence,
    ),
    dataConfidence: confidence,
    trainingBase: [evidence],
    endurance: [
      StravaEvidencePoint(
        metric: 'endurance_long_run_km',
        date: DateTime.utc(2026, 5, 31),
        value: 18,
        unit: 'km',
      ),
    ],
    speedMarkers: [
      StravaEvidencePoint(
        metric: 'speed_marker_10k_pace',
        date: DateTime.utc(2026, 5, 30),
        value: 305,
        unit: 'sec_per_km',
      ),
    ],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 380, paceMaxSecPerKm: 430),
      easy: StravaPaceZone(paceMinSecPerKm: 350, paceMaxSecPerKm: 380),
      longRun: StravaPaceZone(paceMinSecPerKm: 345, paceMaxSecPerKm: 375),
      steady: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 345),
      tempo: StravaPaceZone(paceMinSecPerKm: 310, paceMaxSecPerKm: 330),
      threshold: StravaPaceZone(paceMinSecPerKm: 295, paceMaxSecPerKm: 310),
      racePace: StravaPaceZone(paceMinSecPerKm: 290, paceMaxSecPerKm: 300),
      intervals: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 290),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 260),
    ),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 1,
        category: 'recovery_spacing',
        message: 'Keep at least one easy day between hard sessions.',
      ),
    ],
    raceTargets:
        raceTargets ??
        (includeRaceTargets
            ? [
                StravaRaceTargetEstimate(
                  distanceKm: 21.097,
                  primaryTime: const Duration(hours: 1, minutes: 55),
                  confidence: confidence,
                  evidence: [evidence],
                ),
              ]
            : const []),
    planFocus: const StravaPlanFocus(
      category: 'focus_consistency',
      summary: 'Build consistent volume and threshold durability.',
    ),
  );
}

RunnerProfileDraft _withAcceptedSuggestedRaceTarget(RunnerProfileDraft draft) {
  return draft.copyWith(
    acceptedRaceTarget: suggestedRaceTargetFromDraft(draft),
  );
}

RunnerProfileDraft _nonTimeStravaDraftWithoutTargets() {
  final base = buildRunnerProfileDraft();
  final baseFitness = base.fitness;
  final baseGoal = base.goal;

  return base.copyWith(
    goal: GoalProfileDraft(
      race: baseGoal.race,
      hasRaceDate: baseGoal.hasRaceDate,
      raceDate: baseGoal.raceDate,
    ),
    clearAcceptedRaceTarget: true,
    fitness: FitnessProfileDraft(
      experience: baseFitness.experience,
      canRun10Min: baseFitness.canRun10Min,
      runningDays: baseFitness.runningDays,
      weeklyVolume: baseFitness.weeklyVolume,
      longestRun: baseFitness.longestRun,
      canCompleteGoalDistance: baseFitness.canCompleteGoalDistance,
      raceDistanceBefore: baseFitness.raceDistanceBefore,
      benchmark: baseFitness.benchmark,
      benchmarkTime: baseFitness.benchmarkTime,
      fitnessSource: 'strava',
      stravaCoachingProfile: _stravaProfile(
        confidence: StravaDataConfidence.medium,
        includeRaceTargets: false,
      ),
    ),
  );
}

Duration _projectDuration({
  required int sourceSeconds,
  required double sourceDistanceKm,
  required double targetDistanceKm,
}) {
  const riegelExponent = 1.06;
  final projected =
      sourceSeconds *
      math.pow(targetDistanceKm / sourceDistanceKm, riegelExponent);
  return Duration(seconds: projected.round());
}
