import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/activity/data/activity_repository.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/progress/presentation/progress_provider.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';

import '../../../helpers/activity_fixtures.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.value);

  final TrainingPlan value;

  @override
  TrainingPlan build() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'progress providers count one linked activity instead of double-counting the planned session',
    () async {
      final plannedSession = buildPlannedRunSession(
        id: 'w4-tue',
        date: DateTime(2026, 4, 7),
        status: SessionStatus.completed,
        type: SessionType.intervals,
        distanceKm: 8.0,
        durationMinutes: 40,
        weekNumber: 4,
      );
      final plan = buildTestTrainingPlan(sessions: [plannedSession]);
      final linkedActivity = buildRunActivity(
        id: 'activity-linked',
        recordedAt: DateTime(2026, 4, 7, 7, 45),
        linkedSessionId: plannedSession.id,
        source: ActivitySource.plannedSession,
        startedAt: DateTime(2026, 4, 7, 7, 1),
        endedAt: DateTime(2026, 4, 7, 7, 46),
        actualDuration: const Duration(minutes: 45),
        actualDistanceKm: 8.6,
        actualElevationGainMeters: 108,
        perceivedEffort: ActivityPerceivedEffort.moderate,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPreferencesActivityRepository.storageKey,
        jsonEncode([linkedActivity.toJson()]),
      );

      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          trainingPlanProvider.overrideWith(
            () => _TestTrainingPlanNotifier(plan),
          ),
        ],
      );
      addTearDown(container.dispose);

      final completedSessions = container.read(completedSessionsProvider);
      expect(completedSessions, hasLength(1));
      expect(completedSessions.single.id, plannedSession.id);
      expect(completedSessions.single.type, SessionType.intervals);
      expect(completedSessions.single.distanceKm, closeTo(8.6, 0.001));
      expect(completedSessions.single.durationMinutes, 45);

      final stats = container.read(userStatsProvider);
      expect(stats.totalRuns, 1);

      final recentSessions = container.read(recentSessionsProvider);
      expect(recentSessions, hasLength(1));
      expect(recentSessions.single.id, plannedSession.id);
      expect(recentSessions.single.type, SessionType.intervals);
      expect(recentSessions.single.distanceKm, closeTo(8.6, 0.001));
    },
  );

  test('support sessions do not count as runs in progress stats', () async {
    final supportSession = TrainingSession(
      id: 'support-strength',
      date: DateTime(2026, 4, 8),
      type: SessionType.crossTraining,
      status: SessionStatus.completed,
      supplementalType: SupplementalSessionType.strength,
      durationMinutes: 30,
      weekNumber: 4,
    );
    final plan = buildTestTrainingPlan(sessions: [supportSession]);
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        trainingPlanProvider.overrideWith(() => _TestTrainingPlanNotifier(plan)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(completedSessionsProvider), isEmpty);
    expect(container.read(userStatsProvider).totalRuns, 0);
  });
}
