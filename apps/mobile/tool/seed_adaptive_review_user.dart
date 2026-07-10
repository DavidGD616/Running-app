import 'dart:convert';
import 'dart:io';

import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/training_plan/data/training_plan_seed_data.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_patch.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/weekly_training_summary.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

const _defaultEmail = 'adaptive.runner@example.test';
const _defaultPassword = 'AdaptiveTest123!';
const _defaultEnvFile = 'config/dart_defines.env';
const _defaultSupabaseEnvFile = '../../supabase/.env.local';

Future<void> main(List<String> args) async {
  try {
    final cli = CliArgs.parse(args);
    if (cli.help) {
      stdout.writeln(_usage);
      return;
    }

    final config = SeedConfig.fromCli(cli);
    final client = SupabaseRestClient(
      supabaseUrl: config.supabaseUrl,
      anonKey: config.anonKey,
      serviceRoleKey: config.serviceRoleKey,
    );

    final user = await ensureAuthUser(client, config);
    final seed = buildAdaptiveSeed(config);

    await resetSeededRows(client, user.id);
    await seedRunnerProfile(client, user.id);
    await seedUserPreferences(client, user.id);
    await seedActivePlan(client, user.id, seed.plan);
    await seedActivities(client, user.id, seed.activities);
    await seedFeedback(client, user.id, seed.feedback);
    if (seed.review != null) {
      await seedPendingReview(client, user.id, seed.review!);
    }

    stdout.writeln('Seeded adaptive local test user.');
    stdout.writeln('Email: ${config.email}');
    stdout.writeln('Password: ${config.password}');
    stdout.writeln('Scenario: ${config.scenario.cliKey}');
    stdout.writeln('Review: ${config.reviewMode.cliKey}');
    stdout.writeln('Plan version: ${seed.plan.id}');
    stdout.writeln('Activities: ${seed.activities.length}');
    stdout.writeln('Feedback entries: ${seed.feedback.length}');
    if (seed.review != null) {
      stdout.writeln('Pending review: ${seed.review!.id}');
    }
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    stderr.writeln(_usage);
    exitCode = 64;
  } on SupabaseRequestException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

enum AdaptiveSeedScenario {
  tooAggressive('too-aggressive'),
  pain('pain'),
  onTrack('on-track');

  const AdaptiveSeedScenario(this.cliKey);

  final String cliKey;

  static AdaptiveSeedScenario parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');
    for (final scenario in values) {
      if (scenario.cliKey == normalized) return scenario;
    }
    throw UsageException(
      'Unsupported scenario "$value". Use too-aggressive, pain, or on-track.',
    );
  }
}

enum SeedReviewMode {
  pending('pending'),
  none('none');

  const SeedReviewMode(this.cliKey);

  final String cliKey;

  static SeedReviewMode parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final mode in values) {
      if (mode.cliKey == normalized) return mode;
    }
    throw UsageException(
      'Unsupported review mode "$value". Use pending or none.',
    );
  }
}

class SeedConfig {
  const SeedConfig({
    required this.supabaseUrl,
    required this.anonKey,
    required this.serviceRoleKey,
    required this.email,
    required this.password,
    required this.scenario,
    required this.reviewMode,
  });

  final Uri supabaseUrl;
  final String anonKey;
  final String serviceRoleKey;
  final String email;
  final String password;
  final AdaptiveSeedScenario scenario;
  final SeedReviewMode reviewMode;

  static SeedConfig fromCli(CliArgs cli) {
    final env = <String, String>{
      ...readEnvFile(cli.option('env-file') ?? _defaultEnvFile),
      ...readEnvFile(
        cli.option('supabase-env-file') ?? _defaultSupabaseEnvFile,
      ),
      ...Platform.environment,
    };

    final supabaseUrlRaw =
        cli.option('supabase-url') ??
        env['SUPABASE_SEED_URL'] ??
        env['SUPABASE_URL'];
    final anonKey = cli.option('anon-key') ?? env['SUPABASE_ANON_KEY'];
    final serviceRoleKey =
        cli.option('service-role-key') ?? env['SUPABASE_SERVICE_ROLE_KEY'];
    final email =
        cli.option('email') ?? env['ADAPTIVE_TEST_EMAIL'] ?? _defaultEmail;
    final password =
        cli.option('password') ??
        env['ADAPTIVE_TEST_PASSWORD'] ??
        _defaultPassword;
    final scenario = AdaptiveSeedScenario.parse(
      cli.option('scenario') ??
          env['ADAPTIVE_TEST_SCENARIO'] ??
          AdaptiveSeedScenario.tooAggressive.cliKey,
    );
    final reviewMode = SeedReviewMode.parse(
      cli.option('review') ??
          env['ADAPTIVE_TEST_REVIEW'] ??
          SeedReviewMode.pending.cliKey,
    );

    if (supabaseUrlRaw == null || supabaseUrlRaw.trim().isEmpty) {
      throw UsageException('Missing SUPABASE_URL or --supabase-url.');
    }
    if (anonKey == null || anonKey.trim().isEmpty) {
      throw UsageException('Missing SUPABASE_ANON_KEY or --anon-key.');
    }
    if (serviceRoleKey == null || serviceRoleKey.trim().isEmpty) {
      throw UsageException(
        'Missing SUPABASE_SERVICE_ROLE_KEY or --service-role-key. '
        'For local testing, copy it from `supabase status`.',
      );
    }
    if (password.length < 6) {
      throw UsageException('Password must be at least 6 characters.');
    }

    final supabaseUrl = Uri.parse(supabaseUrlRaw.trim());
    if (!isLocalSupabaseUrl(supabaseUrl)) {
      throw UsageException(
        'Refusing to seed non-local Supabase URL "$supabaseUrl". '
        'Use a local URL such as http://127.0.0.1:54321.',
      );
    }

    return SeedConfig(
      supabaseUrl: supabaseUrl,
      anonKey: anonKey.trim(),
      serviceRoleKey: serviceRoleKey.trim(),
      email: email.trim(),
      password: password,
      scenario: scenario,
      reviewMode: reviewMode,
    );
  }
}

bool isLocalSupabaseUrl(Uri uri) {
  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '0.0.0.0' ||
      uri.host == '::1' ||
      uri.host == '10.0.2.2';
}

class AdaptiveSeed {
  const AdaptiveSeed({
    required this.plan,
    required this.activities,
    required this.feedback,
    required this.review,
  });

  final TrainingPlan plan;
  final List<RunActivity> activities;
  final List<SessionFeedback> feedback;
  final AdaptationReview? review;
}

AdaptiveSeed buildAdaptiveSeed(SeedConfig config) {
  final plan = buildScenarioPlan(config.scenario);
  final activities = buildActivities(plan, config.scenario);
  final feedback = buildFeedback(activities, config.scenario);
  final review = config.reviewMode == SeedReviewMode.pending
      ? buildPendingReview(plan, activities, feedback, config.scenario)
      : null;

  return AdaptiveSeed(
    plan: plan,
    activities: activities,
    feedback: feedback,
    review: review,
  );
}

TrainingPlan buildScenarioPlan(AdaptiveSeedScenario scenario) {
  final base = buildSeedTrainingPlan();
  final statusById = switch (scenario) {
    AdaptiveSeedScenario.tooAggressive => const {
      'w4-tue': SessionStatus.completed,
      'w4-wed': SessionStatus.completed,
      'w4-thu': SessionStatus.completed,
      'w4-sat': SessionStatus.upcoming,
      'w4-sun': SessionStatus.upcoming,
    },
    AdaptiveSeedScenario.pain => const {
      'w4-tue': SessionStatus.completed,
      'w4-wed': SessionStatus.completed,
      'w4-thu': SessionStatus.upcoming,
      'w4-sat': SessionStatus.upcoming,
      'w4-sun': SessionStatus.upcoming,
    },
    AdaptiveSeedScenario.onTrack => const {
      'w4-tue': SessionStatus.completed,
      'w4-wed': SessionStatus.completed,
      'w4-thu': SessionStatus.completed,
      'w4-sat': SessionStatus.completed,
      'w4-sun': SessionStatus.completed,
    },
  };
  final sessions = base.sessions
      .map(
        (session) =>
            session.copyWith(status: statusById[session.id] ?? session.status),
      )
      .toList(growable: false);
  final planId = 'local-adaptive-plan-${scenario.cliKey}';

  return TrainingPlan(
    id: planId,
    raceType: base.raceType,
    totalWeeks: base.totalWeeks,
    currentWeekNumber: base.currentWeekNumber,
    sessions: sessions,
    supportSessions: base.supportSessions,
    paceZones: base.paceZones,
    raceGuidance: base.raceGuidance,
    generatedLocale: base.generatedLocale,
    coachingBriefSnapshot: base.coachingBriefSnapshot,
    planRationale: base.planRationale,
    evidenceTarget: base.evidenceTarget,
    ambitiousTarget: base.ambitiousTarget,
    confidence: base.confidence,
    phaseStrategy: base.phaseStrategy,
    stravaCoachingProfileSnapshot: base.stravaCoachingProfileSnapshot,
  );
}

List<RunActivity> buildActivities(
  TrainingPlan plan,
  AdaptiveSeedScenario scenario,
) {
  return plan.sessions
      .where(
        (session) =>
            session.weekNumber == 4 &&
            session.countsAsRun &&
            session.status == SessionStatus.completed,
      )
      .map((session) {
        final actualDistanceKm = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive =>
            (session.distanceKm ?? 0) * 1.02,
          AdaptiveSeedScenario.pain => (session.distanceKm ?? 0) * 0.9,
          AdaptiveSeedScenario.onTrack => session.distanceKm ?? 0,
        };
        final durationMinutes = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive =>
            (session.durationMinutes ?? 30) + 6,
          AdaptiveSeedScenario.pain => (session.durationMinutes ?? 30) + 4,
          AdaptiveSeedScenario.onTrack => session.durationMinutes ?? 30,
        };
        final startedAt = DateTime(
          session.date.year,
          session.date.month,
          session.date.day,
          7,
          15,
        );
        final endedAt = startedAt.add(Duration(minutes: durationMinutes));
        return RunActivity(
          id: 'local-adaptive-activity-${session.id}',
          source: ActivitySource.plannedSession,
          completionStatus: ActivityCompletionStatus.completed,
          recordedAt: endedAt.add(const Duration(minutes: 2)),
          startedAt: startedAt,
          endedAt: endedAt,
          actualDuration: Duration(minutes: durationMinutes),
          actualDistanceKm: double.parse(actualDistanceKm.toStringAsFixed(2)),
          actualElevationGainMeters: session.elevationGainMeters,
          perceivedEffort: perceivedEffortFor(session.id, scenario),
          linkedSessionId: session.id,
          notes: 'Local adaptive seed fixture.',
        );
      })
      .toList(growable: false);
}

ActivityPerceivedEffort perceivedEffortFor(
  String sessionId,
  AdaptiveSeedScenario scenario,
) {
  return switch (scenario) {
    AdaptiveSeedScenario.tooAggressive =>
      sessionId == 'w4-thu'
          ? ActivityPerceivedEffort.veryHard
          : ActivityPerceivedEffort.hard,
    AdaptiveSeedScenario.pain => ActivityPerceivedEffort.hard,
    AdaptiveSeedScenario.onTrack => ActivityPerceivedEffort.moderate,
  };
}

List<SessionFeedback> buildFeedback(
  List<RunActivity> activities,
  AdaptiveSeedScenario scenario,
) {
  return activities
      .map((activity) {
        final sessionId = activity.linkedSessionId ?? activity.id;
        final recordedAt = activity.recordedAt.add(const Duration(minutes: 5));
        final difficulty = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive =>
            sessionId == 'w4-thu'
                ? SessionFeedbackDifficulty.hard
                : SessionFeedbackDifficulty.veryHard,
          AdaptiveSeedScenario.pain => SessionFeedbackDifficulty.hard,
          AdaptiveSeedScenario.onTrack => SessionFeedbackDifficulty.manageable,
        };
        final recoveryStatus = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive => SessionRecoveryStatus.fatigued,
          AdaptiveSeedScenario.pain =>
            sessionId == 'w4-tue'
                ? SessionRecoveryStatus.fatigued
                : SessionRecoveryStatus.okay,
          AdaptiveSeedScenario.onTrack => SessionRecoveryStatus.fresh,
        };
        final sleep = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive => SessionFeedbackSleep.poor,
          AdaptiveSeedScenario.pain => SessionFeedbackSleep.okay,
          AdaptiveSeedScenario.onTrack => SessionFeedbackSleep.great,
        };
        final legs = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive => SessionFeedbackLegs.heavy,
          AdaptiveSeedScenario.pain =>
            sessionId == 'w4-tue'
                ? SessionFeedbackLegs.heavy
                : SessionFeedbackLegs.normal,
          AdaptiveSeedScenario.onTrack => SessionFeedbackLegs.fresh,
        };
        final pain = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive => SessionFeedbackPain.none,
          AdaptiveSeedScenario.pain =>
            sessionId == 'w4-tue'
                ? SessionFeedbackPain.moderate
                : SessionFeedbackPain.none,
          AdaptiveSeedScenario.onTrack => SessionFeedbackPain.none,
        };
        final motivation = switch (scenario) {
          AdaptiveSeedScenario.tooAggressive => SessionFeedbackMotivation.low,
          AdaptiveSeedScenario.pain => SessionFeedbackMotivation.mixed,
          AdaptiveSeedScenario.onTrack => SessionFeedbackMotivation.ready,
        };
        return SessionFeedback(
          id: 'local-adaptive-feedback-$sessionId',
          recordedAt: recordedAt,
          plannedSessionId: sessionId,
          activityId: activity.id,
          difficulty: difficulty,
          recoveryStatus: recoveryStatus,
          sleep: sleep,
          legs: legs,
          pain: pain,
          motivation: motivation,
          notes: 'Local adaptive seed feedback.',
        );
      })
      .toList(growable: false);
}

AdaptationReview buildPendingReview(
  TrainingPlan plan,
  List<RunActivity> activities,
  List<SessionFeedback> feedback,
  AdaptiveSeedScenario scenario,
) {
  final now = DateTime.now();
  final weekStart = mondayOf(now);
  final summary = weeklyTrainingSummaryFromPlanAndActivityData(
    sessions: plan.sessions,
    completedActivities: activities,
    feedbacks: feedback,
    referenceDate: now,
  );
  final target = plan.sessions.firstWhere(
    (session) => session.id == 'w5-tue',
    orElse: () => plan.sessions.firstWhere((session) => session.countsAsRun),
  );
  final classification = switch (scenario) {
    AdaptiveSeedScenario.tooAggressive =>
      AdaptationReviewClassification.tooAggressive,
    AdaptiveSeedScenario.pain => AdaptationReviewClassification.recoveryNeeded,
    AdaptiveSeedScenario.onTrack => AdaptationReviewClassification.onTrack,
  };
  final severity = switch (scenario) {
    AdaptiveSeedScenario.tooAggressive => AdaptationReviewSeverity.caution,
    AdaptiveSeedScenario.pain => AdaptationReviewSeverity.high,
    AdaptiveSeedScenario.onTrack => AdaptationReviewSeverity.info,
  };
  final summaryKey = switch (scenario) {
    AdaptiveSeedScenario.tooAggressive => 'adapt_summary_too_aggressive',
    AdaptiveSeedScenario.pain => 'adapt_summary_recovery_needed',
    AdaptiveSeedScenario.onTrack => 'adapt_summary_on_track',
  };
  final reasonKey = switch (scenario) {
    AdaptiveSeedScenario.tooAggressive => 'adapt_reason_high_effort_recovery',
    AdaptiveSeedScenario.pain => 'adapt_reason_pain_reported',
    AdaptiveSeedScenario.onTrack => 'adapt_reason_on_track',
  };
  final patches = scenario == AdaptiveSeedScenario.onTrack
      ? const [
          AdaptationPatch(
            type: AdaptationPatchType.noChange,
            reasonKey: 'adapt_reason_no_change',
          ),
        ]
      : [
          AdaptationPatch(
            type: scenario == AdaptiveSeedScenario.pain
                ? AdaptationPatchType.replaceSession
                : AdaptationPatchType.reduceSession,
            sessionId: target.id,
            date: target.date,
            beforeSessionType: target.type,
            afterSessionType: scenario == AdaptiveSeedScenario.pain
                ? SessionType.recoveryRun
                : target.type,
            beforeDistanceKm: target.distanceKm,
            afterDistanceKm: ((target.distanceKm ?? 5) * 0.82),
            beforeDurationMinutes: target.durationMinutes,
            afterDurationMinutes: ((target.durationMinutes ?? 30) * 0.85)
                .round(),
            reasonKey: reasonKey,
          ),
        ];

  return AdaptationReview(
    id: 'local-adaptive-review-${scenario.cliKey}',
    createdAt: now.toUtc(),
    weekStart: weekStart,
    weekEnd: weekStart.add(const Duration(days: 6)),
    sourcePlanVersionId: plan.id,
    status: AdaptationReviewStatus.pending,
    classification: classification,
    severity: severity,
    summaryKey: summaryKey,
    reasonKeys: [reasonKey],
    weeklySummary: summary,
    patches: patches,
    loadBefore: summary.plannedDurationMinutes.toDouble(),
    loadAfter: scenario == AdaptiveSeedScenario.onTrack
        ? summary.plannedDurationMinutes.toDouble()
        : summary.plannedDurationMinutes * 0.9,
  );
}

Future<void> seedRunnerProfile(SupabaseRestClient client, String userId) async {
  final now = DateTime.now();
  final completedAt = now.subtract(const Duration(days: 28));
  final profile = buildRunnerProfile(
    seedTime: now,
    completedOnboardingAt: completedAt,
  );

  await client.upsert('runner_profiles', {
    'user_id': userId,
    'schema_version': profile.schemaVersion,
    'updated_at': profile.updatedAt.toUtc().toIso8601String(),
    'completed_onboarding_at': completedAt.toIso8601String(),
    'data': profile.toJson(),
  }, onConflict: 'user_id');
}

Future<void> seedUserPreferences(SupabaseRestClient client, String userId) {
  return client.upsert('user_preferences', {
    'user_id': userId,
    'unit_system': UnitSystem.km.name,
    'elevation_unit': ShortDistanceUnit.meters.name,
    'display_name': 'Adaptive Runner',
    'gender': ProfileGender.female.name,
    'date_of_birth_ms': DateTime(1993, 5, 12).millisecondsSinceEpoch,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'user_id');
}

Future<void> seedActivePlan(
  SupabaseRestClient client,
  String userId,
  TrainingPlan plan,
) {
  return client.upsert('plan_versions', {
    'id': plan.id,
    'user_id': userId,
    'generated_at': DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 28))
        .toIso8601String(),
    'requested_by': 'local_adaptive_seed',
    'is_active': true,
    'schema_version': TrainingPlan.schemaVersion,
    'data': plan.toJson(),
  }, onConflict: 'id');
}

Future<void> seedActivities(
  SupabaseRestClient client,
  String userId,
  List<RunActivity> activities,
) async {
  if (activities.isEmpty) return;

  await client.upsert(
    'activity_records',
    activities
        .map(
          (activity) => {
            'id': activity.id,
            'user_id': userId,
            'recorded_at': activity.recordedAt.toUtc().toIso8601String(),
            'linked_session_id': activity.linkedSessionId,
            'activity_type': activity.kind.key,
            'data': activity.toJson(),
          },
        )
        .toList(growable: false),
    onConflict: 'id',
  );
}

Future<void> seedFeedback(
  SupabaseRestClient client,
  String userId,
  List<SessionFeedback> feedback,
) async {
  if (feedback.isEmpty) return;

  await client.upsert(
    'session_feedback',
    feedback
        .map(
          (item) => {
            'id': item.id,
            'user_id': userId,
            'linked_session_id': item.plannedSessionId,
            'recorded_at': item.recordedAt.toUtc().toIso8601String(),
            'data': item.toJson(),
          },
        )
        .toList(growable: false),
    onConflict: 'id',
  );
}

Future<void> seedPendingReview(
  SupabaseRestClient client,
  String userId,
  AdaptationReview review,
) {
  final data = review.toJson();
  final patchMaps = data['patches'];
  if (patchMaps is List) {
    for (var index = 0; index < review.patches.length; index++) {
      if (index >= patchMaps.length || patchMaps[index] is! Map) continue;
      final patchMap = patchMaps[index] as Map;
      final patch = review.patches[index];
      patchMap['beforeSessionType'] = patch.beforeSessionType?.name;
      patchMap['beforeDistanceKm'] = patch.beforeDistanceKm;
      patchMap['beforeDurationMinutes'] = patch.beforeDurationMinutes;
      patchMap.removeWhere((key, value) => value == null);
    }
  }
  data['updatedAt'] = review.createdAt.toUtc().toIso8601String();

  return client.upsert('adaptation_reviews', {
    'id': review.id,
    'user_id': userId,
    'status': review.status.key,
    'classification': review.classification.key,
    'severity': review.severity.key,
    'week_start': dateOnly(review.weekStart),
    'week_end': dateOnly(review.weekEnd),
    'source_plan_version_id': review.sourcePlanVersionId,
    'proposed_plan_version_id': review.proposedPlanVersionId,
    'created_at': review.createdAt.toUtc().toIso8601String(),
    'updated_at': review.createdAt.toUtc().toIso8601String(),
    'load_before': review.loadBefore,
    'load_after': review.loadAfter,
    'data': data,
  }, onConflict: 'id');
}

RunnerProfile buildRunnerProfile({
  required DateTime seedTime,
  required DateTime completedOnboardingAt,
}) {
  return RunnerProfileDraft(
    goal: GoalProfileDraft(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: seededRaceDate(seedTime),
    ),
    acceptedRaceTarget: AcceptedRaceTarget(
      distanceKm: 21.097,
      primaryTime: const Duration(hours: 1, minutes: 55),
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
      fitnessSource: 'manual',
    ),
    schedule: ScheduleProfileDraft(
      trainingDays: 4,
      longRunDay: WeekdayChoice.sunday,
      weekdayTime: TimeSlot.min45,
      weekendTime: TimeSlot.min90,
      hardDays: const {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      preferredTimeOfDay: PreferredTimeOfDay.morning,
      planStartDate: mondayOf(
        completedOnboardingAt,
      ).subtract(const Duration(days: 21)),
    ),
    health: const HealthProfileDraft(
      painLevel: PainLevelChoice.none,
      injuryHistory: InjuryHistoryChoice.once,
      hasHealthConditions: BinaryChoice.no,
    ),
    strength: const StrengthProfileDraft(
      lifts: true,
      weeklyFrequency: 2,
      categories: {StrengthCategory.lowerBody, StrengthCategory.coreMobility},
      preferredDays: {WeekdayChoice.monday, WeekdayChoice.thursday},
      sameDayOrder: SameDayOrderPreference.runFirst,
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
  ).toRunnerProfile(
    gender: ProfileGender.female,
    dateOfBirth: DateTime(1993, 5, 12),
    completedOnboardingAt: completedOnboardingAt,
    clock: seedTime,
  )!;
}

DateTime seededRaceDate(DateTime seedTime) {
  final seedDate = DateTime(seedTime.year, seedTime.month, seedTime.day);
  final october18ThisYear = DateTime(seedTime.year, 10, 18);
  if (!october18ThisYear.isAfter(seedDate)) {
    return DateTime(seedTime.year + 1, 10, 18);
  }
  return october18ThisYear;
}

Future<AuthUser> ensureAuthUser(
  SupabaseRestClient client,
  SeedConfig config,
) async {
  final existing = await findAuthUserByEmail(client, config.email);
  if (existing != null) {
    await updateAuthUser(client, existing.id, config.password);
    return existing;
  }

  try {
    return await createAuthUser(client, config);
  } on SupabaseRequestException catch (error) {
    if (error.statusCode != 422 && error.statusCode != 409) rethrow;
    final user = await findAuthUserByEmail(client, config.email);
    if (user == null) rethrow;
    await updateAuthUser(client, user.id, config.password);
    return user;
  }
}

Future<AuthUser?> findAuthUserByEmail(
  SupabaseRestClient client,
  String email,
) async {
  final response = await client.request(
    'GET',
    '/auth/v1/admin/users',
    query: {'page': '1', 'per_page': '1000'},
  );
  final users = switch (response) {
    {'users': final List rawUsers} => rawUsers,
    final List rawUsers => rawUsers,
    _ => const [],
  };
  final normalizedEmail = email.toLowerCase();
  for (final item in users) {
    if (item is! Map) continue;
    final user = AuthUser.fromJson(item);
    if (user != null && user.email.toLowerCase() == normalizedEmail) {
      return user;
    }
  }
  return null;
}

Future<AuthUser> createAuthUser(
  SupabaseRestClient client,
  SeedConfig config,
) async {
  final response = await client.request(
    'POST',
    '/auth/v1/admin/users',
    body: {
      'email': config.email,
      'password': config.password,
      'email_confirm': true,
      'user_metadata': {'name': 'Adaptive Local Runner'},
    },
  );
  final user = AuthUser.fromDynamic(response);
  if (user == null) {
    throw UsageException(
      'Auth user was created, but the response was invalid.',
    );
  }
  return user;
}

Future<void> updateAuthUser(
  SupabaseRestClient client,
  String userId,
  String password,
) async {
  await client.request(
    'PUT',
    '/auth/v1/admin/users/$userId',
    body: {
      'password': password,
      'email_confirm': true,
      'user_metadata': {'name': 'Adaptive Local Runner'},
    },
  );
}

Future<void> resetSeededRows(SupabaseRestClient client, String userId) async {
  const tables = [
    'adaptation_reviews',
    'plan_revisions',
    'plan_adjustments',
    'session_feedback',
    'activity_records',
    'plan_versions',
    'runner_profile_drafts',
  ];
  for (final table in tables) {
    await client.deleteWhere(table, {'user_id': 'eq.$userId'});
  }
}

class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  static AuthUser? fromDynamic(Object? value) {
    if (value is Map) {
      final nestedUser = value['user'];
      if (nestedUser is Map) return fromJson(nestedUser);
      return fromJson(value);
    }
    return null;
  }

  static AuthUser? fromJson(Map<dynamic, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || id.isEmpty || email is! String || email.isEmpty) {
      return null;
    }
    return AuthUser(id: id, email: email);
  }
}

class SupabaseRestClient {
  SupabaseRestClient({
    required Uri supabaseUrl,
    required this.anonKey,
    required this.serviceRoleKey,
  }) : _supabaseUrl = supabaseUrl;

  final Uri _supabaseUrl;
  final String anonKey;
  final String serviceRoleKey;
  final HttpClient _http = HttpClient();

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
    bool useServiceRole = true,
  }) async {
    final uri = _supabaseUrl.resolve(path.replaceFirst(RegExp(r'^/'), ''));
    final requestUri = query == null
        ? uri
        : uri.replace(queryParameters: query);
    final request = await _http.openUrl(method, requestUri);
    final authKey = useServiceRole ? serviceRoleKey : anonKey;
    request.headers.set('apikey', authKey);
    request.headers.set('Authorization', 'Bearer $authKey');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    headers?.forEach(request.headers.set);

    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseBody.trim().isEmpty) return null;
      return jsonDecode(responseBody);
    }

    throw SupabaseRequestException(
      method: method,
      uri: requestUri,
      statusCode: response.statusCode,
      body: responseBody,
    );
  }

  Future<void> upsert(
    String table,
    Object rows, {
    required String onConflict,
  }) async {
    await request(
      'POST',
      '/rest/v1/$table',
      query: {'on_conflict': onConflict},
      body: rows,
      headers: {'Prefer': 'resolution=merge-duplicates,return=minimal'},
    );
  }

  Future<void> deleteWhere(String table, Map<String, String> filters) async {
    await request(
      'DELETE',
      '/rest/v1/$table',
      query: filters,
      headers: {'Prefer': 'return=minimal'},
    );
  }
}

class SupabaseRequestException implements Exception {
  const SupabaseRequestException({
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.body,
  });

  final String method;
  final Uri uri;
  final int statusCode;
  final String body;

  @override
  String toString() {
    final suffix = body.trim().isEmpty ? '' : '\n$body';
    return '$method $uri failed with HTTP $statusCode.$suffix';
  }
}

class CliArgs {
  const CliArgs({required this.options, required this.flags});

  final Map<String, String> options;
  final Set<String> flags;

  bool get help => flags.contains('help');

  bool hasFlag(String name) => flags.contains(name);

  String? option(String name) => options[name];

  static CliArgs parse(List<String> args) {
    final options = <String, String>{};
    final flags = <String>{};
    const boolFlags = {'help'};
    const optionNames = {
      'anon-key',
      'email',
      'env-file',
      'password',
      'review',
      'scenario',
      'service-role-key',
      'supabase-env-file',
      'supabase-url',
    };

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '-h' || arg == '--help') {
        flags.add('help');
        continue;
      }
      if (!arg.startsWith('--')) {
        throw UsageException('Unexpected argument "$arg".');
      }

      final withoutPrefix = arg.substring(2);
      final equalsIndex = withoutPrefix.indexOf('=');
      final name = equalsIndex == -1
          ? withoutPrefix
          : withoutPrefix.substring(0, equalsIndex);
      final inlineValue = equalsIndex == -1
          ? null
          : withoutPrefix.substring(equalsIndex + 1);

      if (boolFlags.contains(name)) {
        if (inlineValue != null) {
          throw UsageException('Flag --$name does not accept a value.');
        }
        flags.add(name);
        continue;
      }

      if (!optionNames.contains(name)) {
        throw UsageException('Unknown option --$name.');
      }

      if (inlineValue != null) {
        options[name] = inlineValue;
        continue;
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        throw UsageException('Missing value for --$name.');
      }
      options[name] = args[++index];
    }

    return CliArgs(options: options, flags: flags);
  }
}

class UsageException implements Exception {
  const UsageException(this.message);

  final String message;
}

Map<String, String> readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};

  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    env[key] = stripQuotes(value);
  }
  return env;
}

String stripQuotes(String value) {
  if (value.length < 2) return value;
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

DateTime mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

String dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

const _usage = '''
Seeds a local Supabase user with completed profile, active plan, current-week
activity, current-week feedback, and optionally a pending coach review.

Run from apps/mobile:
  dart run tool/seed_adaptive_review_user.dart

Options:
  --scenario <too-aggressive|pain|on-track>
  --review <pending|none>
  --email <email>
  --password <password>
  --supabase-url <url>
  --anon-key <key>
  --service-role-key <key>
  --env-file <path>                 Defaults to config/dart_defines.env
  --supabase-env-file <path>        Defaults to ../../supabase/.env.local
  --supabase-url must be local; remote URLs are rejected.

Environment overrides:
  SUPABASE_SEED_URL, SUPABASE_URL, SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY, ADAPTIVE_TEST_EMAIL, ADAPTIVE_TEST_PASSWORD,
  ADAPTIVE_TEST_SCENARIO, ADAPTIVE_TEST_REVIEW
''';
