import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/models/runner_profile.dart';
import '../domain/models/device_connection.dart';
import '../domain/models/integration_account.dart';
import '../data/device_connection_repository.dart';

class DeviceConnectionsNotifier extends Notifier<List<DeviceConnection>> {
  @override
  List<DeviceConnection> build() {
    return ref.watch(deviceConnectionRepositoryProvider).loadConnections();
  }

  void reloadFromStorage() {
    state = ref.read(deviceConnectionRepositoryProvider).loadConnections();
  }

  Future<void> upsertConnection(DeviceConnection connection) async {
    final repo = ref.read(deviceConnectionRepositoryProvider);
    await repo.saveConnection(connection);
    state = repo.loadConnections();
  }

  Future<void> removeConnection(String id) async {
    if (id.isEmpty) return;
    final repo = ref.read(deviceConnectionRepositoryProvider);
    await repo.deleteConnection(id);
    state = repo.loadConnections();
  }

  Future<void> clearConnections() async {
    state = const [];
    await ref.read(deviceConnectionRepositoryProvider).clearConnections();
  }

  Future<void> setPlatformConnection({
    required IntegrationVendor vendor,
    required bool enabled,
  }) async {
    final existing = _connectionForVendor(vendor);
    await upsertConnection(
      DeviceConnection(
        id: existing?.id ?? vendor.key,
        kind: DeviceConnectionKind.healthPlatform,
        vendor: vendor,
        state: enabled
            ? DeviceConnectionState.connected
            : DeviceConnectionState.disconnected,
        capabilities: _platformCapabilitiesFor(vendor),
        connectedAt: enabled ? (existing?.connectedAt ?? DateTime.now()) : null,
        lastSyncedAt: enabled ? existing?.lastSyncedAt : null,
        seededFromOnboarding: false,
      ),
    );
  }

  Future<void> seedWatchFromDeviceProfileIfAbsent(DeviceProfile device) async {
    if (device.hasWatch != BinaryChoice.yes || device.device == null) return;
    if (state.any(
      (connection) => connection.kind == DeviceConnectionKind.wearable,
    )) {
      return;
    }
    await syncOnboardingDeviceProfile(device);
  }

  Future<void> syncOnboardingDeviceProfile(DeviceProfile device) async {
    if (device.hasWatch != BinaryChoice.yes || device.device == null) {
      final wearableIds = state
          .where(
            (connection) => connection.kind == DeviceConnectionKind.wearable,
          )
          .map((connection) => connection.id)
          .toList(growable: false);
      final next = state
          .where((connection) => !wearableIds.contains(connection.id))
          .toList(growable: false);
      await _save(next);
      return;
    }

    await upsertConnection(
      DeviceConnection(
        id: 'watch_${device.device!.key}',
        kind: DeviceConnectionKind.wearable,
        vendor: _vendorFromWatchDevice(device.device!),
        state: DeviceConnectionState.connected,
        capabilities: _capabilitiesFromDeviceProfile(device),
        connectedAt: DateTime.now(),
        seededFromOnboarding: true,
      ),
    );
  }

  DeviceConnection? _connectionForVendor(IntegrationVendor vendor) {
    for (final connection in state) {
      if (connection.vendor == vendor) return connection;
    }
    return null;
  }

  Future<void> _save(List<DeviceConnection> next) async {
    final repo = ref.read(deviceConnectionRepositoryProvider);
    await repo.saveConnections(next);
    state = repo.loadConnections();
  }
}

Set<IntegrationCapability> _platformCapabilitiesFor(IntegrationVendor vendor) {
  return switch (vendor) {
    IntegrationVendor.appleHealth || IntegrationVendor.healthConnect => {
      IntegrationCapability.autoImport,
      IntegrationCapability.heartRate,
      IntegrationCapability.distance,
      IntegrationCapability.pace,
    },
    _ => const {},
  };
}

Set<IntegrationCapability> _capabilitiesFromDeviceProfile(
  DeviceProfile device,
) {
  final capabilities = <IntegrationCapability>{};
  if (device.dataUsage == DataUsagePreference.importAuto ||
      device.dataUsage == DataUsagePreference.all) {
    capabilities.add(IntegrationCapability.autoImport);
  }
  if (device.dataUsage == DataUsagePreference.paceDistance ||
      device.dataUsage == DataUsagePreference.all ||
      device.metrics.contains(WatchMetric.distance)) {
    capabilities.add(IntegrationCapability.distance);
  }
  if (device.dataUsage == DataUsagePreference.paceDistance ||
      device.dataUsage == DataUsagePreference.all ||
      device.metrics.contains(WatchMetric.pace) ||
      device.paceRecommendations == BinaryChoice.yes) {
    capabilities.add(IntegrationCapability.pace);
  }
  if (device.dataUsage == DataUsagePreference.hrOnly ||
      device.dataUsage == DataUsagePreference.all ||
      device.metrics.contains(WatchMetric.heartRate)) {
    capabilities.add(IntegrationCapability.heartRate);
  }
  if (device.metrics.contains(WatchMetric.heartRateZones) ||
      device.hrZones == BinaryChoice.yes) {
    capabilities.add(IntegrationCapability.heartRateZones);
  }
  if (device.metrics.contains(WatchMetric.cadence)) {
    capabilities.add(IntegrationCapability.cadence);
  }
  if (device.metrics.contains(WatchMetric.elevation)) {
    capabilities.add(IntegrationCapability.elevation);
  }
  if (device.metrics.contains(WatchMetric.trainingLoad)) {
    capabilities.add(IntegrationCapability.trainingLoad);
  }
  if (device.metrics.contains(WatchMetric.recoveryTime)) {
    capabilities.add(IntegrationCapability.recoveryTime);
  }
  return capabilities;
}

IntegrationVendor _vendorFromWatchDevice(WatchDeviceType device) {
  return switch (device) {
    WatchDeviceType.garmin => IntegrationVendor.garmin,
    WatchDeviceType.appleWatch => IntegrationVendor.appleWatch,
    WatchDeviceType.coros => IntegrationVendor.coros,
    WatchDeviceType.polar => IntegrationVendor.polar,
    WatchDeviceType.suunto => IntegrationVendor.suunto,
    WatchDeviceType.fitbit => IntegrationVendor.fitbit,
    WatchDeviceType.other => IntegrationVendor.other,
  };
}

final deviceConnectionsProvider =
    NotifierProvider<DeviceConnectionsNotifier, List<DeviceConnection>>(
      DeviceConnectionsNotifier.new,
    );

final currentWearableConnectionProvider = Provider<DeviceConnection?>((ref) {
  final connections = ref.watch(deviceConnectionsProvider);
  for (final connection in connections) {
    if (connection.kind == DeviceConnectionKind.wearable &&
        connection.isConnected) {
      return connection;
    }
  }
  return null;
});

final connectedWearableConnectionsProvider = Provider<List<DeviceConnection>>((
  ref,
) {
  return ref
      .watch(deviceConnectionsProvider)
      .where(
        (connection) =>
            connection.kind == DeviceConnectionKind.wearable &&
            connection.isConnected,
      )
      .toList(growable: false);
});

final connectionForVendorProvider =
    Provider.family<DeviceConnection?, IntegrationVendor>((ref, vendor) {
      for (final connection in ref.watch(deviceConnectionsProvider)) {
        if (connection.vendor == vendor) return connection;
      }
      return null;
    });

final availablePlatformIntegrationsProvider =
    Provider<List<IntegrationAccount>>((ref) {
      return switch (defaultTargetPlatform) {
        TargetPlatform.iOS => const [
          IntegrationAccount(
            vendor: IntegrationVendor.appleHealth,
            kind: DeviceConnectionKind.healthPlatform,
            supportedCapabilities: {
              IntegrationCapability.autoImport,
              IntegrationCapability.heartRate,
              IntegrationCapability.distance,
              IntegrationCapability.pace,
            },
          ),
        ],
        TargetPlatform.android => const [
          IntegrationAccount(
            vendor: IntegrationVendor.healthConnect,
            kind: DeviceConnectionKind.healthPlatform,
            supportedCapabilities: {
              IntegrationCapability.autoImport,
              IntegrationCapability.heartRate,
              IntegrationCapability.distance,
              IntegrationCapability.pace,
            },
          ),
        ],
        _ => const [],
      };
    });
