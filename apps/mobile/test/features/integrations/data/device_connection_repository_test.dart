import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/integrations/data/device_connection_repository.dart';
import 'package:running_app/features/integrations/domain/models/device_connection.dart';

import '../../../helpers/integration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'repository saves, loads, and clears typed device connections',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesDeviceConnectionRepository(prefs);
      final wearable = buildGarminWearableConnection(
        connectedAt: DateTime(2026, 4, 7, 10, 15),
        lastSyncedAt: DateTime(2026, 4, 7, 11, 5),
        seededFromOnboarding: true,
      );
      final platform = buildAppleHealthConnection(
        connectedAt: DateTime(2026, 4, 6, 9, 0),
        lastSyncedAt: DateTime(2026, 4, 7, 8, 30),
      );

      await repository.saveConnections([wearable, platform]);

      final raw = prefs.getString(
        SharedPreferencesDeviceConnectionRepository.storageKey,
      );
      expect(raw, isNotNull);
      expect(jsonDecode(raw!) as List, hasLength(2));

      final restored = repository.loadConnections();
      expect(restored, hasLength(2));
      expect(restored.first.vendor, IntegrationVendor.garmin);
      expect(restored.first.seededFromOnboarding, isTrue);
      expect(restored.last.vendor, IntegrationVendor.appleHealth);

      await repository.clearConnections();

      expect(repository.loadConnections(), isEmpty);
      expect(
        prefs.getString(SharedPreferencesDeviceConnectionRepository.storageKey),
        isNull,
      );
    },
  );
}
