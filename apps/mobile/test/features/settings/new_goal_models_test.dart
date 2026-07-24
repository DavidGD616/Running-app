import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/domain/new_goal_models.dart';

void main() {
  test(
    'recommendation payload includes strict contract and canonical keys',
    () {
      final draft = NewGoalDraft(
        race: RunnerGoalRace.halfMarathon,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
        planStartDate: DateTime(2026, 7, 16),
        schedule: const NewGoalSchedule(
          trainingDays: 4,
          longRunDay: WeekdayChoice.sunday,
          weekdayTime: TimeSlot.min45,
          weekendTime: TimeSlot.min90,
          hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
        ),
        planPreference: PlanPreferenceChoice.balanced,
        healthChanged: false,
      );
      final payload = draft.recommendationPayload(
        sourcePlanVersionId: 'plan-1',
        action: 'preview',
        localDate: DateTime(2026, 7, 18),
        locale: 'es',
      );

      expect(payload, {
        'action': 'preview',
        'sourcePlanVersionId': 'plan-1',
        'race': 'race_half_marathon',
        'hasRaceDate': true,
        'raceDate': '2026-10-18',
        'planStartDate': '2026-07-16',
        'schedule': {
          'trainingDays': 4,
          'longRunDay': 'day_sun',
          'weekdayTime': 'time_45_min',
          'weekendTime': 'time_90_min',
          'hardDays': ['day_thu', 'day_tue'],
          'planStartDate': '2026-07-16',
        },
        'trainingPreferences': {'planPreference': 'plan_balanced'},
        'healthChanged': false,
        'locale': 'es',
        'localDate': '2026-07-18',
      });
      expect(payload.containsKey('targetTime'), isFalse);
      expect(payload.containsKey('handler'), isFalse);
      expect(payload.containsKey('arbitraryData'), isFalse);
    },
  );

  test(
    'health payload is sent only when health changed and excludes recordedOn',
    () {
      final snapshot = NewGoalHealthSnapshot(
        painLevel: PainLevelChoice.mild,
        injuryHistory: InjuryHistoryChoice.none,
        hasHealthConditions: BinaryChoice.no,
        recordedOn: DateTime(2026, 7, 10),
      );

      final draft = NewGoalDraft(
        race: RunnerGoalRace.tenK,
        hasRaceDate: false,
        raceDate: null,
        planStartDate: DateTime(2026, 7, 17),
        schedule: const NewGoalSchedule(
          trainingDays: 4,
          longRunDay: WeekdayChoice.sunday,
          weekdayTime: TimeSlot.min45,
          weekendTime: TimeSlot.min90,
          hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
        ),
        planPreference: PlanPreferenceChoice.performance,
        healthChanged: false,
        health: snapshot,
      ).withHealthChanged(true);

      expect(draft.healthChanged, isTrue);
      expect(draft.health, same(snapshot));

      final payload = draft.recommendationPayload(
        sourcePlanVersionId: 'plan-1',
        action: 'recommend',
        localDate: DateTime(2026, 7, 18),
        locale: 'en',
      );

      expect(payload['health'], {
        'painLevel': 'pain_mild',
        'injuryHistory': 'injury_no',
        'hasHealthConditions': 'no',
      });
      expect(payload['health'], isNot(contains('recordedOn')));
    },
  );

  test(
    'recommendation parser reads server-shaped timeline and estimate source',
    () {
      final recommendation = NewGoalRecommendation.fromJson({
        'sourceGoal': {
          'race': 'race_half_marathon',
          'hasRaceDate': true,
          'raceDate': '2026-10-18',
        },
        'proposedGoal': {
          'race': 'race_half_marathon',
          'hasRaceDate': true,
          'raceDate': '2026-10-18',
        },
        'recommendation': {
          'mode': 'long_term',
          'startDate': '2026-07-23',
          'endDate': '2026-10-15',
          'weeks': 12,
          'hasRaceDate': true,
          'raceDate': '2026-10-18',
          'daysToRace': 87,
        },
        'raceEstimate': {
          'centerTimeSeconds': 3600,
          'fasterTimeSeconds': 3500,
          'slowerTimeSeconds': 3900,
          'confidence': 'high',
          'evidence': [
            {
              'source': 'race_estimator',
              'recordedOn': '2026-07-20',
              'reason': 'model_derived',
            },
          ],
        },
      });

      expect(recommendation.timelineMode, 'long_term');
      expect(recommendation.timelineWeeks, 12);
      expect(recommendation.timelineDate, DateTime(2026, 7, 23));
      expect(recommendation.timelineEndDate, DateTime(2026, 10, 15));
      expect(recommendation.timelineHasRaceDate, isTrue);
      expect(recommendation.timelineRaceDate, DateTime(2026, 10, 18));
      expect(recommendation.daysToRace, 87);
      expect(recommendation.estimate?.source, 'race_estimator');
      expect(recommendation.estimate?.confidence, 'high');
    },
  );

  test('proposal parser aligns sourceGoal and tolerates missing summary', () {
    final proposal = NewGoalProposal.fromJson(_proposalJson());
    expect(proposal.sourceGoal.race, RunnerGoalRace.halfMarathon);
    expect(proposal.currentGoal.race, RunnerGoalRace.halfMarathon);
    expect(proposal.summary, isEmpty);
    expect(proposal.warnings, isEmpty);
  });

  test('fitness result payloads persist without target time', () {
    final result = NewGoalFitnessResult(
      source: NewGoalFitnessSource.assessment,
      distanceKm: 5.0,
      elapsed: const Duration(minutes: 25),
      recordedOn: DateTime(2026, 7, 10),
      hardEffort: true,
    );
    final draft = NewGoalDraft(
      race: RunnerGoalRace.tenK,
      hasRaceDate: false,
      raceDate: null,
      schedule: const NewGoalSchedule(
        trainingDays: 4,
        longRunDay: WeekdayChoice.sunday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      ),
      planPreference: PlanPreferenceChoice.performance,
      healthChanged: true,
      health: NewGoalHealthSnapshot(
        painLevel: PainLevelChoice.mild,
        injuryHistory: InjuryHistoryChoice.once,
        hasHealthConditions: BinaryChoice.yes,
        recordedOn: DateTime(2026, 7, 10),
      ),
      fitnessResult: result,
    );

    expect(draft.toJson()['fitnessResult'], {
      'source': 'assessment',
      'distanceKm': 5.0,
      'elapsedSeconds': 1500,
      'recordedOn': '2026-07-10',
      'hardEffort': true,
    });
    expect(draft.toJson().containsKey('targetTime'), isFalse);
  });

  test('new goal draft parses stable JSON and rejects unsupported values', () {
    final json = NewGoalDraft(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: DateTime(2026, 10, 18),
      planStartDate: DateTime(2026, 7, 16),
      schedule: const NewGoalSchedule(
        trainingDays: 4,
        longRunDay: WeekdayChoice.sunday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      ),
      planPreference: PlanPreferenceChoice.balanced,
      healthChanged: false,
      fitnessResult: NewGoalFitnessResult(
        source: NewGoalFitnessSource.manual,
        distanceKm: 5,
        elapsed: const Duration(minutes: 24, seconds: 30),
        recordedOn: DateTime(2026, 7, 10),
        hardEffort: true,
      ),
    ).toJson();

    expect(
      NewGoalDraft.fromJson(json).planPreference,
      PlanPreferenceChoice.balanced,
    );
    final malformed = Map<String, dynamic>.from(json)..['race'] = 'race_other';
    expect(() => NewGoalDraft.fromJson(malformed), throwsFormatException);
  });

  test('fitness check enforces canonical benchmark and date structure', () {
    expect(
      NewGoalFitnessCheck.fromJson(_fitnessCheckResponse()['fitnessCheck']),
      isA<NewGoalFitnessCheck>(),
    );
    expect(
      () => NewGoalFitnessCheck.fromJson({
        'suggestedActivities': <dynamic>[],
        'benchmark': {'kind': 'five_k_run', 'safeDates': null},
      }),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _proposalJson() => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': 'active-plan',
  'expiresAt': '2099-12-31T23:59:59Z',
  'sourceGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'proposedGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'candidatePlan': {
    'schemaVersion': 1,
    'id': 'candidate-plan',
    'raceType': 'halfMarathon',
    'totalWeeks': 12,
    'currentWeekNumber': 1,
    'sessions': <Map<String, dynamic>>[],
  },
};

Map<String, dynamic> _fitnessCheckResponse() => {
  'state': 'fitness_check_required',
  'sourcePlanVersionId': 'plan-1',
  'fitnessCheck': {
    'suggestedActivities': <dynamic>[],
    'benchmark': {
      'kind': 'five_k_run',
      'safeDates': ['2026-07-16'],
    },
  },
};
