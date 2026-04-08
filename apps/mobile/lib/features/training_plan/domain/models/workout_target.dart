enum TargetType { pace, effort, heartRate }

enum TargetZone {
  recovery,
  easy,
  steady,
  tempo,
  threshold,
  interval,
  racePace,
  longRun,
}

class WorkoutTarget {
  const WorkoutTarget({
    required this.type,
    required this.zone,
  });

  static const int schemaVersion = 1;

  final TargetType type;
  final TargetZone zone;

  const WorkoutTarget.pace(this.zone) : type = TargetType.pace;

  const WorkoutTarget.effort(this.zone) : type = TargetType.effort;

  const WorkoutTarget.heartRate(this.zone) : type = TargetType.heartRate;

  WorkoutTarget copyWith({
    TargetType? type,
    TargetZone? zone,
  }) {
    return WorkoutTarget(
      type: type ?? this.type,
      zone: zone ?? this.zone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'type': type.name,
      'zone': zone.name,
    };
  }

  static WorkoutTarget? fromJson(Map<String, dynamic> json) {
    final type = _targetTypeFromKey(json['type'] as String?);
    final zone = _targetZoneFromKey(json['zone'] as String?);
    if (type == null || zone == null) return null;
    return WorkoutTarget(type: type, zone: zone);
  }
}

TargetType? _targetTypeFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in TargetType.values) {
    if (value.name == key) return value;
  }
  return null;
}

TargetZone? _targetZoneFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in TargetZone.values) {
    if (value.name == key) return value;
  }
  return null;
}
