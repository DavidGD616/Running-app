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

  test('Goal JSON round-trips kind and event', () {
    final goal = buildHalfMarathonTimeGoal();

    final restored = Goal.fromJson(goal.toJson());

    expect(restored, isNotNull);
    expect(restored!.kind, GoalKind.time);
    expect(restored.status, GoalStatus.active);
    expect(restored.raceEvent, isNotNull);
    expect(restored.raceEvent!.raceType, GoalRaceType.halfMarathon);
  });

  test('Goal.fromJson returns null for invalid payloads', () {
    expect(Goal.fromJson(const {}), isNull);
    expect(
      Goal.fromJson({
        'kind': 'time',
        'status': 'active',
        'raceEvent': {'raceType': 'race_not_real'},
      }),
      isNull,
    );
  });
}
