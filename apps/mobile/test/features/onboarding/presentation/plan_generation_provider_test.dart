import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:running_app/features/onboarding/domain/models/professional_plan_input.dart';
import 'package:running_app/features/onboarding/presentation/plan_generation_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/data/plan_version_repository.dart';
import 'package:running_app/features/training_plan/data/supabase_plan_version_repository.dart';
import 'package:running_app/features/training_plan/domain/models/plan_version.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/localization/presentation/locale_provider.dart';

import '../../../helpers/runner_profile_fixtures.dart';

class _FunctionInvocation {
  const _FunctionInvocation({required this.name, this.body});

  final String name;
  final Object? body;
}

class _FakePlanVersionRepository implements PlanVersionRepository {
  PlanVersion? lastSaved;

  @override
  TrainingPlan? loadActivePlanSync() => lastSaved?.plan;

  @override
  Future<TrainingPlan?> loadActivePlanAsync() async => lastSaved?.plan;

  @override
  Future<void> saveActivePlan(PlanVersion version) async {
    lastSaved = version;
  }

  @override
  bool hasActivePlan() => lastSaved != null;
}

class _FakeLocaleNotifier extends LocaleNotifier {
  _FakeLocaleNotifier(this.value);

  final Locale value;

  @override
  Future<Locale> build() async => value;
}

Map<String, dynamic> _stravaPlanGenerationResponse() {
  return {
    'versionId': 'plan-version-001',
    'plan': {
      'id': 'generated-plan-id',
      'raceType': TrainingPlanRaceType.halfMarathon.name,
      'totalWeeks': 12,
      'currentWeekNumber': 1,
      'sessions': [
        {
          'schemaVersion': 1,
          'id': 'session-001',
          'date': DateTime(2026, 6, 4).toIso8601String(),
          'type': SessionType.easyRun.name,
          'status': SessionStatus.upcoming.name,
          'weekNumber': 1,
        },
      ],
    },
  };
}

StravaCoachingProfile _buildStravaCoachingProfile() {
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
      dataThroughDate: DateTime(2026, 6, 2),
      activityCount: 40,
      runActivityCount: 32,
      confidence: StravaDataConfidence.high,
    ),
    dataConfidence: StravaDataConfidence.high,
    trainingBase: [evidence],
    endurance: [
      StravaEvidencePoint(
        metric: 'endurance_long_run_km',
        date: DateTime.utc(2026, 5, 31),
        value: 18,
        unit: 'km',
      ),
    ],
    speedMarkers: const [],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 390, paceMaxSecPerKm: 450),
      easy: StravaPaceZone(paceMinSecPerKm: 350, paceMaxSecPerKm: 390),
      longRun: StravaPaceZone(paceMinSecPerKm: 340, paceMaxSecPerKm: 385),
      steady: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 350),
      tempo: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 325),
      threshold: StravaPaceZone(paceMinSecPerKm: 285, paceMaxSecPerKm: 305),
      racePace: StravaPaceZone(paceMinSecPerKm: 275, paceMaxSecPerKm: 290),
      intervals: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 275),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 250),
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
        confidence: StravaDataConfidence.high,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_threshold_durability',
      summary: 'Protect volume and build tempo durability.',
    ),
  );
}

RunnerProfileDraft _stravaOnboardingDraft() {
  final base = buildRunnerProfileDraft();
  final baseFitness = base.fitness;
  final coachingProfile = _buildStravaCoachingProfile();
  final raceTarget = coachingProfile.raceTargets.first;

  return base.copyWith(
    acceptedRaceTarget: AcceptedRaceTarget(
      distanceKm: raceTarget.distanceKm,
      primaryTime: raceTarget.primaryTime,
      stretchTime: raceTarget.stretchTime,
      confidence: raceTarget.confidence,
      evidence: raceTarget.evidence,
    ),
    fitness: RunnerProfileDraft.fitnessFromInput(
      experience: baseFitness.experience!.key,
      runningDays: '${baseFitness.runningDays}',
      weeklyVolume: baseFitness.weeklyVolume!.key,
      longestRun: baseFitness.longestRun!.key,
      canCompleteGoalDist: baseFitness.canCompleteGoalDistance!.key,
      raceDistanceBefore: baseFitness.raceDistanceBefore!.key,
      benchmark: baseFitness.benchmark!.key,
      benchmarkTime: baseFitness.benchmarkTime,
      fitnessSource: 'strava',
      stravaCoachingProfile: coachingProfile,
    ),
  );
}

void main() {
  group('PlanGenerationNotifier', () {
    test(
      'serializes professionalPlanInput in generate-plan request body when provided',
      () async {
        final invocations = <_FunctionInvocation>[];
        final repository = _FakePlanVersionRepository();
        final draft = _stravaOnboardingDraft();
        final expectedCoachingProfile = _buildStravaCoachingProfile();
        final professionalPlanInput =
            buildProfessionalPlanInputFromOnboardingDraft(
              draft: draft,
              preferences: const UserPreferences(unitSystem: UnitSystem.miles),
              locale: 'en',
            )!;

        final container = ProviderContainer(
          overrides: [
            localeProvider.overrideWith(
              () => _FakeLocaleNotifier(const Locale('en')),
            ),
            planVersionRepositoryProvider.overrideWithValue(repository),
            planGenerationFunctionClientProvider.overrideWithValue((
              name, {
              body,
            }) async {
              invocations.add(_FunctionInvocation(name: name, body: body));
              return FunctionResponse(
                data: _stravaPlanGenerationResponse(),
                status: 200,
              );
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(planGenerationProvider.notifier)
            .generate(
              requestedBy: 'onboarding',
              professionalPlanInput: professionalPlanInput,
            );

        expect(
          container.read(planGenerationProvider),
          isA<PlanGenerationSuccess>(),
        );
        expect(invocations, hasLength(1));
        final requestBody = invocations.single.body as Map<String, dynamic>?;
        expect(requestBody, isNotNull);
        expect(requestBody!['requestedBy'], 'onboarding');
        expect(requestBody['locale'], 'en');

        final professional =
            requestBody['professionalPlanInput'] as Map<String, dynamic>?;
        expect(professional, isNotNull);
        expect(professional!['fitnessSource'], FitnessSource.strava.key);
        expect(professional['stravaCoachingProfile'], isA<Map>());
        expect(professional['unitPreference'], 'imperial');
        expect(professional['planIntensity'], PlanIntensity.balanced.key);
        expect(
          professional['raceCourseTerrain'],
          draft.fitness.stravaCoachingProfile!.terrain.key,
        );

        final acceptedRaceTarget =
            professional['acceptedRaceTarget'] as Map<String, dynamic>?;
        expect(acceptedRaceTarget, isNotNull);
        expect(
          acceptedRaceTarget!['distanceKm'],
          expectedCoachingProfile.raceTargets.first.distanceKm,
        );
        expect(
          acceptedRaceTarget['primaryTimeMs'],
          expectedCoachingProfile.raceTargets.first.primaryTime.inMilliseconds,
        );
        expect(acceptedRaceTarget['confidence'], 'high');

        final schedule = professional['schedule'] as Map<String, dynamic>?;
        expect(schedule, isNotNull);
        expect(schedule!['trainingDays'], draft.schedule.trainingDays);
        expect(schedule['weekdayTime'], draft.schedule.weekdayTime!.key);
        expect((schedule['hardDays'] as List).length, 2);

        final health = professional['health'] as Map<String, dynamic>?;
        expect(health, isNotNull);
        expect(health!['painLevel'], draft.health.painLevel!.key);
        expect(health['injuryHistory'], draft.health.injuryHistory!.key);

        final strength =
            professional['strengthPreferences'] as Map<String, dynamic>?;
        expect(strength, isNotNull);
        expect(strength!['lifts'], isTrue);
        expect(strength['weeklyFrequency'], draft.strength.weeklyFrequency);
        expect((strength['categories'] as List).toSet(), {
          StrengthCategory.lowerBody.key,
          StrengthCategory.coreMobility.key,
        });
      },
    );

    test(
      'falls back to legacy request payload when professionalPlanInput is omitted',
      () async {
        final invocations = <_FunctionInvocation>[];
        final repository = _FakePlanVersionRepository();

        final container = ProviderContainer(
          overrides: [
            localeProvider.overrideWith(
              () => _FakeLocaleNotifier(const Locale('en')),
            ),
            planVersionRepositoryProvider.overrideWithValue(repository),
            planGenerationFunctionClientProvider.overrideWithValue((
              name, {
              body,
            }) async {
              invocations.add(_FunctionInvocation(name: name, body: body));
              return FunctionResponse(
                data: _stravaPlanGenerationResponse(),
                status: 200,
              );
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(planGenerationProvider.notifier)
            .generate(requestedBy: 'settings_update');

        expect(
          container.read(planGenerationProvider),
          isA<PlanGenerationSuccess>(),
        );
        expect(invocations, hasLength(1));
        final requestBody = invocations.single.body as Map<String, dynamic>?;
        expect(requestBody, isNotNull);
        expect(requestBody!['requestedBy'], 'settings_update');
        expect(requestBody.containsKey('professionalPlanInput'), isFalse);
      },
    );

    test(
      'does not invoke Supabase when onboarding generation lacks professional input',
      () async {
        final invocations = <_FunctionInvocation>[];
        final repository = _FakePlanVersionRepository();

        final container = ProviderContainer(
          overrides: [
            localeProvider.overrideWith(
              () => _FakeLocaleNotifier(const Locale('en')),
            ),
            planVersionRepositoryProvider.overrideWithValue(repository),
            planGenerationFunctionClientProvider.overrideWithValue((
              name, {
              body,
            }) async {
              invocations.add(_FunctionInvocation(name: name, body: body));
              return FunctionResponse(
                data: _stravaPlanGenerationResponse(),
                status: 200,
              );
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(planGenerationProvider.notifier)
            .generate(requestedBy: 'onboarding');

        expect(
          container.read(planGenerationProvider),
          isA<PlanGenerationFailure>(),
        );
        final failure =
            container.read(planGenerationProvider) as PlanGenerationFailure;
        expect(failure.reason, 'generation_input_missing');
        expect(invocations, isEmpty);
        expect(repository.lastSaved, isNull);
      },
    );
  });
}
