import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

RunnerProfileDraft buildRunnerProfileDraft() {
  return RunnerProfileDraft(
    goal: GoalProfileDraft(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: DateTime(2026, 10, 18),
      priority: GoalPriority.improveTime,
      currentTime: const Duration(hours: 2, minutes: 1, seconds: 30),
      targetTime: const Duration(hours: 1, minutes: 55),
    ),
    fitness: const FitnessProfileDraft(
      experience: RunnerExperience.intermediate,
      runningDays: 4,
      weeklyVolume: WeeklyVolumeRange.volume3,
      longestRun: LongestRunRange.run3,
      canCompleteGoalDistance: TernaryChoice.yes,
      raceDistanceBefore: RaceDistanceExperience.once,
      benchmark: BenchmarkType.fiveK,
      benchmarkTime: Duration(minutes: 26, seconds: 12),
    ),
    schedule: const ScheduleProfileDraft(
      trainingDays: 4,
      longRunDay: WeekdayChoice.sunday,
      weekdayTime: TimeSlot.min45,
      weekendTime: TimeSlot.min90,
      hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      preferredTimeOfDay: PreferredTimeOfDay.morning,
    ),
    health: const HealthProfileDraft(
      painLevel: PainLevelChoice.none,
      injuryHistory: InjuryHistoryChoice.once,
      hasHealthConditions: BinaryChoice.no,
    ),
    trainingPreferences: const TrainingPreferencesProfileDraft(
      planPreference: PlanPreferenceChoice.balanced,
    ),
    device: const DeviceProfileDraft(
      hasWatch: BinaryChoice.yes,
      device: WatchDeviceType.garmin,
      dataUsage: DataUsagePreference.all,
      watchMetrics: WatchMetricsPreference.ifSupported,
      metrics: {WatchMetric.heartRate, WatchMetric.pace},
      hrZones: BinaryChoice.yes,
      paceRecommendations: BinaryChoice.yes,
      autoAdjust: AutoAdjustPreference.askFirst,
    ),
  );
}

RunnerProfile buildRunnerProfile({
  ProfileGender gender = ProfileGender.female,
  DateTime? dateOfBirth,
  DateTime? clock,
}) {
  return buildRunnerProfileDraft().toRunnerProfile(
    gender: gender,
    dateOfBirth: dateOfBirth ?? DateTime(1993, 5, 12),
    clock: clock ?? DateTime(2026, 4, 7, 9, 30),
  )!;
}
