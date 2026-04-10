import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/device_connection.dart';
import 'device_connection_repository.dart';

class SupabaseDeviceConnectionRepository
    implements AsyncDeviceConnectionRepository {
  SupabaseDeviceConnectionRepository(
    this._client, {
    DeviceConnectionRepository? localCache,
  }) : _localCache = localCache;

  final SupabaseClient _client;
  final DeviceConnectionRepository? _localCache;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<List<DeviceConnection>> loadConnections() async {
    final uid = _uid;
    if (uid == null) return _loadCachedConnections();

    try {
      final response = await _client
          .from('device_connections')
          .select('id, vendor, kind, state, connected_at, last_synced_at, data')
          .eq('user_id', uid)
          .order('connected_at', ascending: false);

      final connections = _sortDeviceConnections(
        _rowsFromResponse(
          response,
        ).map(_connectionFromRow).whereType<DeviceConnection>(),
      );
      await _localCache?.saveConnections(connections);
      return connections;
    } catch (_) {
      return _loadCachedConnections(rethrowIfUnavailable: true);
    }
  }

  @override
  Future<DeviceConnection?> loadConnectionById(String id) async {
    if (id.isEmpty) return null;

    final uid = _uid;
    if (uid == null) {
      return _localCache?.loadConnectionById(id);
    }

    try {
      final response = await _client
          .from('device_connections')
          .select('id, vendor, kind, state, connected_at, last_synced_at, data')
          .eq('user_id', uid)
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return _connectionFromRow(_rowFromDynamic(response));
    } catch (_) {
      if (_localCache != null) return _localCache.loadConnectionById(id);
      rethrow;
    }
  }

  @override
  Future<DeviceConnection?> loadConnectionByVendor(
    IntegrationVendor vendor,
  ) async {
    final uid = _uid;
    if (uid == null) {
      return _localCache?.loadConnectionByVendor(vendor);
    }

    try {
      final response = await _client
          .from('device_connections')
          .select('id, vendor, kind, state, connected_at, last_synced_at, data')
          .eq('user_id', uid)
          .eq('vendor', vendor.key)
          .maybeSingle();
      if (response == null) return null;
      return _connectionFromRow(_rowFromDynamic(response));
    } catch (_) {
      if (_localCache != null) {
        return _localCache.loadConnectionByVendor(vendor);
      }
      rethrow;
    }
  }

  @override
  Future<void> saveConnection(DeviceConnection connection) async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) {
        return _localCache.saveConnection(connection);
      }
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client
        .from('device_connections')
        .upsert(_connectionRow(uid, connection), onConflict: 'id');
    await _localCache?.saveConnection(connection);
  }

  @override
  Future<void> saveConnections(List<DeviceConnection> connections) async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.saveConnections(connections);
      throw const PostgrestException(message: 'No authenticated user');
    }

    final uniqueConnections = <String, DeviceConnection>{
      for (final connection in connections) connection.id: connection,
    }.values.toList(growable: false);

    if (uniqueConnections.isEmpty) {
      await clearConnections();
      return;
    }

    final existingResponse = await _client
        .from('device_connections')
        .select('id')
        .eq('user_id', uid);
    final existingIds = _rowsFromResponse(
      existingResponse,
    ).map((row) => row['id'] as String?).whereType<String>().toSet();
    final nextIds = uniqueConnections
        .map((connection) => connection.id)
        .toSet();

    for (final staleId in existingIds.difference(nextIds)) {
      await _client
          .from('device_connections')
          .delete()
          .eq('user_id', uid)
          .eq('id', staleId);
    }

    await _client
        .from('device_connections')
        .upsert(
          uniqueConnections
              .map((connection) => _connectionRow(uid, connection))
              .toList(),
          onConflict: 'id',
        );
    await _localCache?.saveConnections(uniqueConnections);
  }

  @override
  Future<void> deleteConnection(String id) async {
    if (id.isEmpty) return;

    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.deleteConnection(id);
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client
        .from('device_connections')
        .delete()
        .eq('user_id', uid)
        .eq('id', id);
    await _localCache?.deleteConnection(id);
  }

  @override
  Future<void> clearConnections() async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.clearConnections();
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client.from('device_connections').delete().eq('user_id', uid);
    await _localCache?.clearConnections();
  }

  Future<List<DeviceConnection>> _loadCachedConnections({
    bool rethrowIfUnavailable = false,
  }) async {
    if (_localCache != null) return _localCache.loadConnections();
    if (rethrowIfUnavailable) {
      throw StateError('No local device connection cache available.');
    }
    return const [];
  }

  List<Map<String, dynamic>> _rowsFromResponse(dynamic response) {
    if (response is! List) return const [];
    return response.map(_rowFromDynamic).toList(growable: false);
  }

  Map<String, dynamic> _rowFromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', entry));
    }
    return const {};
  }

  DeviceConnection? _connectionFromRow(Map<String, dynamic> row) {
    final rawData = row['data'];
    if (rawData is! Map) return null;

    final data = rawData.map((key, value) => MapEntry('$key', value));
    if (row.containsKey('id')) data['id'] = row['id'];
    if (row.containsKey('vendor')) data['vendor'] = row['vendor'];
    if (row.containsKey('kind')) data['kind'] = row['kind'];
    if (row.containsKey('state')) data['state'] = row['state'];
    if (row.containsKey('connected_at')) {
      data['connectedAt'] = row['connected_at'];
    }
    if (row.containsKey('last_synced_at')) {
      data['lastSyncedAt'] = row['last_synced_at'];
    }
    return DeviceConnection.fromJson(data);
  }

  Map<String, dynamic> _connectionRow(String uid, DeviceConnection connection) {
    return {
      'id': connection.id,
      'user_id': uid,
      'vendor': connection.vendor.key,
      'kind': connection.kind.key,
      'state': connection.state.key,
      'connected_at': connection.connectedAt?.toUtc().toIso8601String(),
      'last_synced_at': connection.lastSyncedAt?.toUtc().toIso8601String(),
      'data': connection.toJson(),
    };
  }
}

final supabaseDeviceConnectionRepositoryProvider =
    Provider<AsyncDeviceConnectionRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      final localCache = ref.watch(deviceConnectionRepositoryProvider);
      return SupabaseDeviceConnectionRepository(client, localCache: localCache);
    });

List<DeviceConnection> _sortDeviceConnections(
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
