import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/goals/domain/models/goal.dart';

import '../../../../helpers/goal_fixtures.dart';

void main() {
  test('RaceEvent JSON round-trips canonical values', () {
    final event = RaceEvent(
      raceType: GoalRaceType.halfMarathon,
      eventDate: DateTime(2026, 10, 18),
    );

    final restored = RaceEvent.fromJson(event.toJson());

    expect(restored, isNotNull);
    expect(restored!.raceType, GoalRaceType.halfMarathon);
    expect(restored.eventDate, DateTime(2026, 10, 18));
  });

  test('Goal JSON round-trips kind, priority, and targets', () {
    final goal = buildHalfMarathonTimeGoal();

    final restored = Goal.fromJson(goal.toJson());

    expect(restored, isNotNull);
    expect(restored!.kind, GoalKind.time);
    expect(restored.status, GoalStatus.active);
    expect(restored.priority, GoalPriorityType.improveTime);
    expect(restored.raceEvent, isNotNull);
    expect(restored.raceEvent!.raceType, GoalRaceType.halfMarathon);
    expect(
      restored.currentTime,
      const Duration(hours: 2, minutes: 1, seconds: 30),
    );
    expect(restored.targetTime, const Duration(hours: 1, minutes: 55));
  });

  test('Goal.fromJson returns null for invalid payloads', () {
    expect(Goal.fromJson(const {}), isNull);
    expect(
      Goal.fromJson({
        'kind': 'time',
        'status': 'active',
        'priority': 'priority_improve_time',
        'raceEvent': {'raceType': 'race_not_real'},
      }),
      isNull,
    );
  });
}
