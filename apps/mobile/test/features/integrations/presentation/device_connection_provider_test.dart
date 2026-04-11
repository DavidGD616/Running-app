import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/integrations/domain/models/device_connection.dart';
import 'package:running_app/features/integrations/presentation/device_connection_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TargetPlatform? previousPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test(
    'device connections provider reloads persisted state after recreation',
    () async {
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(deviceConnectionsProvider.notifier)
          .setPlatformConnection(
            vendor: IntegrationVendor.appleHealth,
            enabled: true,
          );

      await container.read(deviceConnectionsProvider.future);
      expect(
        container
            .read(deviceConnectionsProvider)
            .maybeWhen(
              data: (connections) => connections,
              orElse: () => const [],
            ),
        hasLength(1),
      );
      expect(
        container.read(
          connectionForVendorProvider(IntegrationVendor.appleHealth),
        ),
        isNotNull,
      );

      final recreated = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(recreated.dispose);

      final reloaded = await recreated.read(deviceConnectionsProvider.future);
      expect(reloaded, hasLength(1));
      expect(
        recreated.read(
          connectionForVendorProvider(IntegrationVendor.appleHealth),
        ),
        isNotNull,
      );
      expect(recreated.read(connectedWearableConnectionsProvider), isEmpty);
    },
  );

  test('available platform integrations reflect the current platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final integrations = container.read(availablePlatformIntegrationsProvider);

    expect(integrations, hasLength(1));
    expect(integrations.single.vendor, IntegrationVendor.appleHealth);
    expect(
      integrations.single.supportedCapabilities,
      containsAll([
        IntegrationCapability.autoImport,
        IntegrationCapability.heartRate,
        IntegrationCapability.distance,
        IntegrationCapability.pace,
      ]),
    );
  });
}
