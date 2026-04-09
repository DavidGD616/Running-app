import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/integrations/domain/models/device_connection.dart';

void main() {
  test('device connection JSON round-trips canonical values', () {
    final connection = DeviceConnection(
      id: 'watch_garmin',
      kind: DeviceConnectionKind.wearable,
      vendor: IntegrationVendor.garmin,
      state: DeviceConnectionState.connected,
      capabilities: {
        IntegrationCapability.autoImport,
        IntegrationCapability.distance,
        IntegrationCapability.heartRate,
        IntegrationCapability.pace,
      },
      connectedAt: DateTime(2026, 4, 7, 10, 15),
      lastSyncedAt: DateTime(2026, 4, 7, 11, 5),
      seededFromOnboarding: true,
    );

    final restored = DeviceConnection.fromJson(connection.toJson());

    expect(restored, isNotNull);
    expect(restored!.id, connection.id);
    expect(restored.kind, DeviceConnectionKind.wearable);
    expect(restored.vendor, IntegrationVendor.garmin);
    expect(restored.state, DeviceConnectionState.connected);
    expect(restored.capabilities, {
      IntegrationCapability.autoImport,
      IntegrationCapability.distance,
      IntegrationCapability.heartRate,
      IntegrationCapability.pace,
    });
    expect(restored.connectedAt, DateTime(2026, 4, 7, 10, 15));
    expect(restored.lastSyncedAt, DateTime(2026, 4, 7, 11, 5));
    expect(restored.seededFromOnboarding, isTrue);
  });

  test('device connection parsing rejects incomplete payloads', () {
    expect(
      DeviceConnection.fromJson({
        'id': 'missing-vendor',
        'kind': 'wearable',
        'state': 'connected',
      }),
      isNull,
    );
  });
}
