import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../domain/models/device_connection.dart';
import 'supabase_device_connection_repository.dart';

abstract interface class DeviceConnectionRepository {
  List<DeviceConnection> loadConnections();
  DeviceConnection? loadConnectionById(String id);
  DeviceConnection? loadConnectionByVendor(IntegrationVendor vendor);
  Future<void> saveConnection(DeviceConnection connection);
  Future<void> saveConnections(List<DeviceConnection> connections);
  Future<void> deleteConnection(String id);
  Future<void> clearConnections();
}

abstract interface class AsyncDeviceConnectionRepository {
  Future<List<DeviceConnection>> loadConnections();
  Future<DeviceConnection?> loadConnectionById(String id);
  Future<DeviceConnection?> loadConnectionByVendor(IntegrationVendor vendor);
  Future<void> saveConnection(DeviceConnection connection);
  Future<void> saveConnections(List<DeviceConnection> connections);
  Future<void> deleteConnection(String id);
  Future<void> clearConnections();
}

class DeviceConnectionRepositoryAsyncAdapter
    implements AsyncDeviceConnectionRepository {
  DeviceConnectionRepositoryAsyncAdapter(this._repository);

  final DeviceConnectionRepository _repository;

  @override
  Future<List<DeviceConnection>> loadConnections() async {
    return _repository.loadConnections();
  }

  @override
  Future<DeviceConnection?> loadConnectionById(String id) async {
    return _repository.loadConnectionById(id);
  }

  @override
  Future<DeviceConnection?> loadConnectionByVendor(
    IntegrationVendor vendor,
  ) async {
    return _repository.loadConnectionByVendor(vendor);
  }

  @override
  Future<void> saveConnection(DeviceConnection connection) {
    return _repository.saveConnection(connection);
  }

  @override
  Future<void> saveConnections(List<DeviceConnection> connections) {
    return _repository.saveConnections(connections);
  }

  @override
  Future<void> deleteConnection(String id) {
    return _repository.deleteConnection(id);
  }

  @override
  Future<void> clearConnections() {
    return _repository.clearConnections();
  }
}

/// Local cache implementation backed by [SharedPreferences].
///
/// SharedPreferences is retained as the explicit local cache layer for the
/// Supabase implementations. This provides offline read access and reduces
/// cold-start latency. A future sprint may replace SP with SQLite/Drift for
/// structured cache, but for now SP is the locked cache strategy.
class SharedPreferencesDeviceConnectionRepository
    implements DeviceConnectionRepository {
  SharedPreferencesDeviceConnectionRepository(this._prefs);

  static const storageKey = 'device_connections_v1';

  final SharedPreferences _prefs;

  @override
  List<DeviceConnection> loadConnections() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final connections = <DeviceConnection>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final connection = DeviceConnection.fromJson(item);
          if (connection != null) connections.add(connection);
        } else if (item is Map) {
          final connection = DeviceConnection.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          );
          if (connection != null) connections.add(connection);
        }
      }
      return _sortConnections(connections);
    } catch (_) {
      return const [];
    }
  }

  @override
  DeviceConnection? loadConnectionById(String id) {
    if (id.isEmpty) return null;
    for (final connection in loadConnections()) {
      if (connection.id == id) return connection;
    }
    return null;
  }

  @override
  DeviceConnection? loadConnectionByVendor(IntegrationVendor vendor) {
    for (final connection in loadConnections()) {
      if (connection.vendor == vendor) return connection;
    }
    return null;
  }

  @override
  Future<void> saveConnection(DeviceConnection connection) async {
    final updated = [
      connection,
      ...loadConnections().where((existing) => existing.id != connection.id),
    ];
    await _writeConnections(updated);
  }

  @override
  Future<void> saveConnections(List<DeviceConnection> connections) async {
    await _writeConnections(connections);
  }

  @override
  Future<void> deleteConnection(String id) async {
    if (id.isEmpty) return;
    final updated = loadConnections()
        .where((connection) => connection.id != id)
        .toList(growable: false);
    await _writeConnections(updated);
  }

  @override
  Future<void> clearConnections() async {
    await _prefs.remove(storageKey);
  }

  Future<void> _writeConnections(List<DeviceConnection> connections) async {
    final sorted = _sortConnections(connections);
    await _prefs.setString(
      storageKey,
      jsonEncode(sorted.map((connection) => connection.toJson()).toList()),
    );
  }
}

List<DeviceConnection> _sortConnections(
  Iterable<DeviceConnection> connections,
) {
  final sorted = connections.toList(growable: false);
  sorted.sort((a, b) {
    final stateCmp = switch ((a.isConnected, b.isConnected)) {
      (true, false) => -1,
      (false, true) => 1,
      _ => 0,
    };
    if (stateCmp != 0) return stateCmp;

    final connectedAtCmp =
        (b.connectedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.connectedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
    if (connectedAtCmp != 0) return connectedAtCmp;

    final kindCmp = a.kind.key.compareTo(b.kind.key);
    if (kindCmp != 0) return kindCmp;

    return a.vendor.key.compareTo(b.vendor.key);
  });
  return sorted;
}

final deviceConnectionRepositoryProvider = Provider<DeviceConnectionRepository>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SharedPreferencesDeviceConnectionRepository(prefs);
  },
);

/// Switching provider: returns [SupabaseDeviceConnectionRepository] when a
/// user is authenticated, otherwise falls back to the local
/// [SharedPreferencesDeviceConnectionRepository] via
/// [DeviceConnectionRepositoryAsyncAdapter].
final asyncDeviceConnectionRepositoryProvider =
    Provider<AsyncDeviceConnectionRepository>((ref) {
      final repository = ref.watch(deviceConnectionRepositoryProvider);

      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return DeviceConnectionRepositoryAsyncAdapter(repository);
      }

      return ref.watch(supabaseDeviceConnectionRepositoryProvider);
    });
