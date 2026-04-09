import 'package:running_app/features/integrations/domain/models/device_connection.dart';

DeviceConnection buildDeviceConnection({
  required String id,
  required IntegrationVendor vendor,
  DeviceConnectionKind kind = DeviceConnectionKind.wearable,
  DeviceConnectionState state = DeviceConnectionState.connected,
  Set<IntegrationCapability> capabilities = const {
    IntegrationCapability.autoImport,
    IntegrationCapability.distance,
    IntegrationCapability.heartRate,
  },
  DateTime? connectedAt,
  DateTime? lastSyncedAt,
  bool seededFromOnboarding = false,
}) {
  return DeviceConnection(
    id: id,
    kind: kind,
    vendor: vendor,
    state: state,
    capabilities: capabilities,
    connectedAt: connectedAt,
    lastSyncedAt: lastSyncedAt,
    seededFromOnboarding: seededFromOnboarding,
  );
}

DeviceConnection buildGarminWearableConnection({
  String id = 'watch_garmin',
  DateTime? connectedAt,
  DateTime? lastSyncedAt,
  bool seededFromOnboarding = false,
}) {
  return buildDeviceConnection(
    id: id,
    vendor: IntegrationVendor.garmin,
    kind: DeviceConnectionKind.wearable,
    state: DeviceConnectionState.connected,
    connectedAt: connectedAt,
    lastSyncedAt: lastSyncedAt,
    seededFromOnboarding: seededFromOnboarding,
  );
}

DeviceConnection buildAppleHealthConnection({
  String id = 'apple_health',
  DateTime? connectedAt,
  DateTime? lastSyncedAt,
}) {
  return buildDeviceConnection(
    id: id,
    vendor: IntegrationVendor.appleHealth,
    kind: DeviceConnectionKind.healthPlatform,
    state: DeviceConnectionState.connected,
    capabilities: {
      IntegrationCapability.autoImport,
      IntegrationCapability.distance,
      IntegrationCapability.heartRate,
      IntegrationCapability.pace,
    },
    connectedAt: connectedAt,
    lastSyncedAt: lastSyncedAt,
  );
}
