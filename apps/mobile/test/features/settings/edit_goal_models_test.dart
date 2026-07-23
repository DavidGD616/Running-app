import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/domain/edit_goal_models.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';

void main() {
  test('race estimate parses only canonical evidence reason keys', () {
    final estimate = GoalEditRaceEstimate.fromJson({
      'centerTimeSeconds': 1500,
      'fasterTimeSeconds': 1450,
      'slowerTimeSeconds': 1550,
      'confidence': 'high',
      'evidence': [
        {
          'source': 'manual',
          'recordedOn': '2026-07-10',
          'reason': 'manual_recent_hard_result',
        },
      ],
    });

    expect(
      estimate.evidence.single.reason,
      GoalEditEvidenceReason.manualRecentHardResult,
    );
    expect(
      () => GoalEditRaceEstimate.fromJson({
        'centerTimeSeconds': 1500,
        'fasterTimeSeconds': 1450,
        'slowerTimeSeconds': 1550,
        'confidence': 'high',
        'evidence': [
          {
            'source': 'manual',
            'recordedOn': '2026-07-10',
            'description': 'Recent hard running result',
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('deselecting a goal field restores its original value and payload', () {
    final originalGoal = GoalEditGoal(
      race: RunnerGoalRace.halfMarathon,
      hasRaceDate: true,
      raceDate: DateTime(2026, 10, 18),
    );
    final changed = EditGoalDraft(
      originalGoal: originalGoal,
      race: RunnerGoalRace.marathon,
      hasRaceDate: false,
      raceDate: null,
      changes: const {EditGoalChange.distance, EditGoalChange.raceDate},
    );

    final distanceDeselected = changed.toggleChange(EditGoalChange.distance);
    final allDeselected = distanceDeselected.toggleChange(
      EditGoalChange.raceDate,
    );

    expect(distanceDeselected.race, RunnerGoalRace.halfMarathon);
    expect(distanceDeselected.hasRaceDate, isFalse);
    expect(allDeselected.race, RunnerGoalRace.halfMarathon);
    expect(allDeselected.hasRaceDate, isTrue);
    expect(allDeselected.raceDate, DateTime(2026, 10, 18));
    expect(
      allDeselected.previewPayload(
        sourcePlanVersionId: 'plan-1',
        localDate: DateTime(2026, 7, 13),
        locale: 'en',
      ),
      containsPair('race', 'race_half_marathon'),
    );
  });

  test('preview payload ignores stale values for unselected fields', () {
    final draft = EditGoalDraft(
      originalGoal: GoalEditGoal(
        race: RunnerGoalRace.halfMarathon,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
      ),
      race: RunnerGoalRace.marathon,
      hasRaceDate: false,
      raceDate: null,
      changes: const {EditGoalChange.raceDate},
    );

    final payload = draft.previewPayload(
      sourcePlanVersionId: 'plan-1',
      localDate: DateTime(2026, 7, 13),
      locale: 'en',
    );

    expect(payload['race'], 'race_half_marathon');
    expect(payload['hasRaceDate'], isFalse);
  });

  test('summary strictly parses canonical chronological session details', () {
    final summary = GoalEditChangeSummary.fromJson(_summary());

    expect(summary.addedUpcomingSessions, hasLength(2));
    expect(
      summary.addedUpcomingSessions.first.afterSessionType,
      SessionType.intervals,
    );
    expect(
      summary.removedUpcomingSessions.single.beforeSessionType,
      SessionType.longRun,
    );
    final changed = summary.materiallyChangedUpcomingSessions.single;
    expect(changed.beforeSessionType, SessionType.easyRun);
    expect(changed.afterSessionType, SessionType.intervals);
    expect(changed.beforeDurationMinutes, 30);
    expect(changed.afterDistanceKm, 6);
  });

  test('summary remains backward compatible when detail arrays are absent', () {
    final legacy = _summary()
      ..removeWhere((key, _) => key.endsWith('Sessions'));

    final summary = GoalEditChangeSummary.fromJson(legacy);

    expect(summary.addedUpcomingCount, 2);
    expect(summary.addedUpcomingSessions, isEmpty);
    expect(summary.removedUpcomingSessions, isEmpty);
    expect(summary.materiallyChangedUpcomingSessions, isEmpty);
  });

  test('summary rejects malformed session detail rows', () {
    final unknownType = _summary();
    (unknownType['addedUpcomingSessions'] as List).first['afterSessionType'] =
        'localized easy run';
    expect(
      () => GoalEditChangeSummary.fromJson(unknownType),
      throwsFormatException,
    );

    final invalidSides = _summary();
    (invalidSides['removedUpcomingSessions'] as List)
            .first['afterSessionType'] =
        'easyRun';
    expect(
      () => GoalEditChangeSummary.fromJson(invalidSides),
      throwsFormatException,
    );

    final countMismatch = _summary();
    countMismatch['addedUpcomingCount'] = 1;
    expect(
      () => GoalEditChangeSummary.fromJson(countMismatch),
      throwsFormatException,
    );

    final unordered = _summary();
    unordered['addedUpcomingSessions'] = [
      _row(date: '2026-07-20', afterType: 'recoveryRun'),
      _row(date: '2026-07-14', afterType: 'intervals'),
    ];
    expect(
      () => GoalEditChangeSummary.fromJson(unordered),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _summary() => {
  'preservedCount': 4,
  'addedUpcomingCount': 2,
  'removedUpcomingCount': 1,
  'materiallyChangedUpcomingCount': 1,
  'addedUpcomingSessions': [
    _row(
      date: '2026-07-14',
      afterType: 'intervals',
      afterDuration: 25,
      afterDistance: 6.5,
    ),
    _row(
      date: '2026-07-20',
      afterType: 'recoveryRun',
      afterDuration: 30,
      afterDistance: 4,
    ),
  ],
  'removedUpcomingSessions': [
    _row(
      date: '2026-07-15',
      beforeType: 'longRun',
      beforeDuration: 60,
      beforeDistance: 12,
    ),
  ],
  'materiallyChangedUpcomingSessions': [
    _row(
      date: '2026-07-16',
      beforeType: 'easyRun',
      afterType: 'intervals',
      beforeDuration: 30,
      afterDuration: 35,
      beforeDistance: 5,
      afterDistance: 6,
    ),
  ],
  'totalWeeks': 12,
  'endDate': '2026-10-18',
};

Map<String, dynamic> _row({
  required String date,
  String? beforeType,
  String? afterType,
  int? beforeDuration,
  int? afterDuration,
  double? beforeDistance,
  double? afterDistance,
}) => {
  'localDate': date,
  'beforeSessionType': beforeType,
  'afterSessionType': afterType,
  'beforeDurationMinutes': beforeDuration,
  'afterDurationMinutes': afterDuration,
  'beforeDistanceKm': beforeDistance,
  'afterDistanceKm': afterDistance,
};
