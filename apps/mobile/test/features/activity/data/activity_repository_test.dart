import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/activity/data/activity_repository.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';

import '../../../helpers/activity_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RunActivity JSON round-trips canonical values', () {
    final activity = buildRunActivity(
      id: 'activity-1',
      recordedAt: DateTime(2026, 4, 7, 7, 45),
      linkedSessionId: 'w4-tue',
      source: ActivitySource.plannedSession,
      startedAt: DateTime(2026, 4, 7, 7, 3),
      endedAt: DateTime(2026, 4, 7, 7, 45),
      actualDuration: const Duration(minutes: 42),
      actualDistanceKm: 8.4,
      actualElevationGainMeters: 110,
      perceivedEffort: ActivityPerceivedEffort.hard,
      notes: 'Tempo effort',
    );

    final restored = ActivityRecord.fromJson(activity.toJson());

    expect(restored, isA<RunActivity>());
    final run = restored! as RunActivity;
    expect(run.id, 'activity-1');
    expect(run.kind, ActivityKind.run);
    expect(run.source, ActivitySource.plannedSession);
    expect(run.completionStatus, ActivityCompletionStatus.completed);
    expect(run.recordedAt, DateTime(2026, 4, 7, 7, 45));
    expect(run.startedAt, DateTime(2026, 4, 7, 7, 3));
    expect(run.endedAt, DateTime(2026, 4, 7, 7, 45));
    expect(run.derivedDuration, const Duration(minutes: 42));
    expect(run.actualDistanceKm, 8.4);
    expect(run.actualElevationGainMeters, 110);
    expect(run.perceivedEffort, ActivityPerceivedEffort.hard);
    expect(run.linkedSessionId, 'w4-tue');
    expect(run.notes, 'Tempo effort');
  });

  test('repository saves, orders, and filters linked activities', () async {
    final older = buildRunActivity(
      id: 'activity-older',
      recordedAt: DateTime(2026, 4, 6, 7, 45),
      startedAt: DateTime(2026, 4, 6, 7, 10),
      endedAt: DateTime(2026, 4, 6, 7, 45),
      actualDuration: const Duration(minutes: 35),
      actualDistanceKm: 6.2,
      actualElevationGainMeters: 80,
    );
    final linked = buildRunActivity(
      id: 'activity-linked',
      recordedAt: DateTime(2026, 4, 7, 7, 45),
      linkedSessionId: 'w4-tue',
      source: ActivitySource.plannedSession,
      startedAt: DateTime(2026, 4, 7, 7, 3),
      endedAt: DateTime(2026, 4, 7, 7, 45),
      actualDuration: const Duration(minutes: 42),
      actualDistanceKm: 8.4,
      actualElevationGainMeters: 110,
    );

    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesActivityRepository(prefs);

    await repository.saveActivities([older, linked]);

    final reloaded = repository.loadAllActivities();
    expect(reloaded, hasLength(2));
    expect(reloaded.first.id, 'activity-linked');
    expect(reloaded.last.id, 'activity-older');
    expect(repository.loadRecentActivities(limit: 1), hasLength(1));
    expect(repository.loadRecentActivities(limit: 1).first.id, 'activity-linked');
    expect(repository.loadActivityById('activity-linked'), isNotNull);
    expect(repository.loadActivitiesByLinkedSessionId('w4-tue'), hasLength(1));
    expect(
      repository.loadActivitiesByLinkedSessionId('w4-tue').single.id,
      'activity-linked',
    );

    final raw = prefs.getString(SharedPreferencesActivityRepository.storageKey);
    expect(raw, isNotNull);
    expect(jsonDecode(raw!) as List, hasLength(2));
  });
}
