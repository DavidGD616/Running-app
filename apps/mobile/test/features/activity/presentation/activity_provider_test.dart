import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/activity/presentation/activity_provider.dart';

import '../../../helpers/activity_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'activities provider reloads persisted activities after recreation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final saved = buildRunActivity(
        id: 'activity-linked',
        recordedAt: DateTime(2026, 4, 7, 7, 45),
        linkedSessionId: 'w4-tue',
        source: ActivitySource.plannedSession,
        startedAt: DateTime(2026, 4, 7, 7, 3),
        endedAt: DateTime(2026, 4, 7, 7, 45),
        actualDuration: const Duration(minutes: 42),
        actualDistanceKm: 8.4,
      );
      final manual = buildRunActivity(
        id: 'activity-manual',
        recordedAt: DateTime(2026, 4, 6, 7, 45),
        startedAt: DateTime(2026, 4, 6, 7, 0),
        endedAt: DateTime(2026, 4, 6, 7, 45),
        actualDuration: const Duration(minutes: 45),
        actualDistanceKm: 6.0,
      );

      await container.read(activitiesProvider.notifier).saveActivity(manual);
      await container.read(activitiesProvider.notifier).saveActivity(saved);
      await container.read(activitiesProvider.future);

      final activities = container.read(activitiesProvider).value;
      expect(activities, hasLength(2));
      expect(activities!.first.id, 'activity-linked');
      expect(
        container.read(activitiesByLinkedSessionIdProvider('w4-tue')),
        hasLength(1),
      );

      final recreated = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(recreated.dispose);

      await recreated.read(activitiesProvider.future);

      final reloaded = recreated.read(activitiesProvider).value;
      expect(reloaded, hasLength(2));
      expect(reloaded!.first.id, 'activity-linked');
      expect(
        recreated.read(activitiesByLinkedSessionIdProvider('w4-tue')),
        hasLength(1),
      );
      expect(
        recreated.read(activitiesByLinkedSessionIdProvider('w4-tue')).single.id,
        'activity-linked',
      );
    },
  );
}
