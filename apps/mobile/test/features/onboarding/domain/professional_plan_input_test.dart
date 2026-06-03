import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/onboarding/domain/models/professional_plan_input.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';

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
  });
}

ProfessionalPlanInput _baseInput({
  required FitnessSource fitnessSource,
  required StravaCoachingProfile? stravaCoachingProfile,
  required ManualFitnessInput? manualFitness,
}) {
  return ProfessionalPlanInput(
    goal: GoalProfile(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: DateTime.utc(2026, 10, 18),
      priority: GoalPriority.improveTime,
      currentTime: const Duration(hours: 2, minutes: 1),
      targetTime: const Duration(hours: 1, minutes: 55),
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
    schedule: const ScheduleProfile(
      trainingDays: 4,
      longRunDay: WeekdayChoice.sunday,
      weekdayTime: TimeSlot.min45,
      weekendTime: TimeSlot.min90,
      hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      preferredTimeOfDay: PreferredTimeOfDay.morning,
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
    raceCourseTerrain: RaceCourseTerrain.rolling,
  );
}

StravaCoachingProfile _stravaProfile({
  required StravaDataConfidence confidence,
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
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 21.097,
        primaryTime: const Duration(hours: 1, minutes: 55),
        confidence: confidence,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_consistency',
      summary: 'Build consistent volume and threshold durability.',
    ),
  );
}
