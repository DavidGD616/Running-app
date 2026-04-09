abstract interface class CanonicalKeyed {
  String get key;
}

T? _enumByKey<T extends Enum>(
  String? key,
  List<T> values,
  String Function(T value) keyOf,
) {
  if (key == null || key.isEmpty) return null;
  for (final value in values) {
    if (keyOf(value) == key) return value;
  }
  return null;
}

String? _stringOrNull(Object? value) => value is String ? value : null;

DateTime? _dateTimeFromJson(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

Set<T> _enumSetByKeys<T extends Enum>(
  Object? raw,
  List<T> values,
  String Function(T value) keyOf,
) {
  final keys = switch (raw) {
    List<dynamic> list => list.whereType<String>(),
    _ => const <String>[],
  };
  final result = <T>{};
  for (final key in keys) {
    final value = _enumByKey(key, values, keyOf);
    if (value != null) result.add(value);
  }
  return result;
}

enum DeviceConnectionKind implements CanonicalKeyed {
  wearable('wearable'),
  healthPlatform('health_platform');

  const DeviceConnectionKind(this.key);

  @override
  final String key;

  static DeviceConnectionKind? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum IntegrationVendor implements CanonicalKeyed {
  garmin('device_garmin'),
  appleWatch('device_apple_watch'),
  coros('device_coros'),
  polar('device_polar'),
  suunto('device_suunto'),
  fitbit('device_fitbit'),
  other('device_other'),
  appleHealth('integration_apple_health'),
  healthConnect('integration_health_connect');

  const IntegrationVendor(this.key);

  @override
  final String key;

  static IntegrationVendor? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum DeviceConnectionState implements CanonicalKeyed {
  connected('connected'),
  disconnected('disconnected');

  const DeviceConnectionState(this.key);

  @override
  final String key;

  static DeviceConnectionState? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum IntegrationCapability implements CanonicalKeyed {
  autoImport('capability_auto_import'),
  heartRate('capability_heart_rate'),
  heartRateZones('capability_heart_rate_zones'),
  pace('capability_pace'),
  distance('capability_distance'),
  cadence('capability_cadence'),
  elevation('capability_elevation'),
  trainingLoad('capability_training_load'),
  recoveryTime('capability_recovery_time');

  const IntegrationCapability(this.key);

  @override
  final String key;

  static IntegrationCapability? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

class DeviceConnection {
  const DeviceConnection({
    required this.id,
    required this.kind,
    required this.vendor,
    required this.state,
    this.capabilities = const {},
    this.connectedAt,
    this.lastSyncedAt,
    this.seededFromOnboarding = false,
  });

  static const schemaVersion = 1;

  final String id;
  final DeviceConnectionKind kind;
  final IntegrationVendor vendor;
  final DeviceConnectionState state;
  final Set<IntegrationCapability> capabilities;
  final DateTime? connectedAt;
  final DateTime? lastSyncedAt;
  final bool seededFromOnboarding;

  bool get isConnected => state == DeviceConnectionState.connected;
  bool get isWearable => kind == DeviceConnectionKind.wearable;
  bool get isHealthPlatform => kind == DeviceConnectionKind.healthPlatform;
  bool supports(IntegrationCapability capability) =>
      capabilities.contains(capability);

  DeviceConnection copyWith({
    String? id,
    DeviceConnectionKind? kind,
    IntegrationVendor? vendor,
    DeviceConnectionState? state,
    Set<IntegrationCapability>? capabilities,
    DateTime? connectedAt,
    DateTime? lastSyncedAt,
    bool? seededFromOnboarding,
  }) {
    return DeviceConnection(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      vendor: vendor ?? this.vendor,
      state: state ?? this.state,
      capabilities: capabilities ?? this.capabilities,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      seededFromOnboarding: seededFromOnboarding ?? this.seededFromOnboarding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'kind': kind.key,
      'vendor': vendor.key,
      'state': state.key,
      'capabilities':
          capabilities
              .map((capability) => capability.key)
              .toList(growable: false)
            ..sort(),
      'connectedAt': connectedAt?.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'seededFromOnboarding': seededFromOnboarding,
    };
  }

  static DeviceConnection? fromJson(Map<String, dynamic> json) {
    final id = _stringOrNull(json['id']);
    final kind = DeviceConnectionKind.fromKey(_stringOrNull(json['kind']));
    final vendor = IntegrationVendor.fromKey(_stringOrNull(json['vendor']));
    final state = DeviceConnectionState.fromKey(_stringOrNull(json['state']));
    if (id == null || kind == null || vendor == null || state == null) {
      return null;
    }

    return DeviceConnection(
      id: id,
      kind: kind,
      vendor: vendor,
      state: state,
      capabilities: _enumSetByKeys(
        json['capabilities'],
        IntegrationCapability.values,
        (value) => value.key,
      ),
      connectedAt: _dateTimeFromJson(json['connectedAt']),
      lastSyncedAt: _dateTimeFromJson(json['lastSyncedAt']),
      seededFromOnboarding: json['seededFromOnboarding'] == true,
    );
  }
}
