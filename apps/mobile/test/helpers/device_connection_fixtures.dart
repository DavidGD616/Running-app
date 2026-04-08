import 'package:running_app/features/integrations/domain/models/device_connection.dart';

DeviceConnection buildDeviceConnection({
  String id = 'watch_device_garmin',
  DeviceConnectionKind kind = DeviceConnectionKind.wearable,
  IntegrationVendor vendor = IntegrationVendor.garmin,
  DeviceConnectionState state = DeviceConnectionState.connected,
  Set<IntegrationCapability> capabilities = const {
    IntegrationCapability.autoImport,
    IntegrationCapability.heartRate,
    IntegrationCapability.pace,
    IntegrationCapability.distance,
  },
  DateTime? connectedAt,
  DateTime? lastSyncedAt,
  bool seededFromOnboarding = true,
}) {
  return DeviceConnection(
    id: id,
    kind: kind,
    vendor: vendor,
    state: state,
    capabilities: capabilities,
    connectedAt: connectedAt ?? DateTime(2026, 4, 7, 10, 15),
    lastSyncedAt: lastSyncedAt,
    seededFromOnboarding: seededFromOnboarding,
  );
}
