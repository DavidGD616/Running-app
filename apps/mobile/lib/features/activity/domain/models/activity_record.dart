abstract interface class CanonicalKeyed {
  String get key;
}

T? _enumByKey<T extends Enum>(
  String? key,
  List<T> values,
  String Function(T value) keyOf,
) {
  if (key == null) return null;
  for (final value in values) {
    if (keyOf(value) == key) return value;
  }
  return null;
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTimeFromJson(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();

int? _durationToJson(Duration? value) => value?.inMilliseconds;

Duration? _durationFromJson(Object? value) {
  final milliseconds = _intOrNull(value);
  return milliseconds == null ? null : Duration(milliseconds: milliseconds);
}

enum ActivityKind implements CanonicalKeyed {
  run('activity_run');

  const ActivityKind(this.key);

  @override
  final String key;

  static ActivityKind? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum ActivitySource implements CanonicalKeyed {
  plannedSession('planned_session'),
  manual('manual'),
  imported('imported');

  const ActivitySource(this.key);

  @override
  final String key;

  static ActivitySource? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum ActivityCompletionStatus implements CanonicalKeyed {
  completed('completed'),
  partial('partial'),
  cancelled('cancelled');

  const ActivityCompletionStatus(this.key);

  @override
  final String key;

  static ActivityCompletionStatus? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum ActivityPerceivedEffort implements CanonicalKeyed {
  veryEasy('effort_very_easy'),
  easy('effort_easy'),
  moderate('effort_moderate'),
  hard('effort_hard'),
  veryHard('effort_very_hard');

  const ActivityPerceivedEffort(this.key);

  @override
  final String key;

  static ActivityPerceivedEffort? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

abstract class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.kind,
    required this.source,
    required this.completionStatus,
    required this.recordedAt,
    this.startedAt,
    this.endedAt,
    this.actualDuration,
    this.actualDistanceKm,
    this.actualElevationGainMeters,
    this.perceivedEffort,
    this.linkedSessionId,
    this.notes,
  });

  static const int schemaVersion = 1;

  final String id;
  final ActivityKind kind;
  final ActivitySource source;
  final ActivityCompletionStatus completionStatus;
  final DateTime recordedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration? actualDuration;
  final double? actualDistanceKm;
  final int? actualElevationGainMeters;
  final ActivityPerceivedEffort? perceivedEffort;
  final String? linkedSessionId;
  final String? notes;

  bool get hasLinkedSession =>
      linkedSessionId != null && linkedSessionId!.isNotEmpty;

  bool get isCompleted =>
      completionStatus == ActivityCompletionStatus.completed;

  DateTime get sortTimestamp => endedAt ?? startedAt ?? recordedAt;

  Duration? get derivedDuration =>
      actualDuration ??
      (startedAt != null && endedAt != null
          ? endedAt!.difference(startedAt!)
          : null);

  Map<String, dynamic> toJson();

  ActivityRecord copyWith({
    String? id,
    ActivityKind? kind,
    ActivitySource? source,
    ActivityCompletionStatus? completionStatus,
    DateTime? recordedAt,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? actualDuration,
    double? actualDistanceKm,
    int? actualElevationGainMeters,
    ActivityPerceivedEffort? perceivedEffort,
    String? linkedSessionId,
    String? notes,
  });

  static ActivityRecord? fromJson(Map<String, dynamic> json) {
    final kind = ActivityKind.fromKey(_stringOrNull(json['kind']));
    if (kind == null) return null;
    return switch (kind) {
      ActivityKind.run => RunActivity.tryFromJson(json),
    };
  }
}

class RunActivity extends ActivityRecord {
  const RunActivity({
    required super.id,
    required super.source,
    required super.completionStatus,
    required super.recordedAt,
    super.startedAt,
    super.endedAt,
    super.actualDuration,
    super.actualDistanceKm,
    super.actualElevationGainMeters,
    super.perceivedEffort,
    super.linkedSessionId,
    super.notes,
  }) : super(
         kind: ActivityKind.run,
       );

  static RunActivity? tryFromJson(Map<String, dynamic> json) {
    final id = _stringOrNull(json['id']);
    final recordedAt = _dateTimeFromJson(json['recordedAt']);
    if (id == null || id.isEmpty || recordedAt == null) return null;

    return RunActivity(
      id: id,
      source:
          ActivitySource.fromKey(_stringOrNull(json['source'])) ??
          ActivitySource.manual,
      completionStatus:
          ActivityCompletionStatus.fromKey(
            _stringOrNull(json['completionStatus']),
          ) ??
          ActivityCompletionStatus.completed,
      recordedAt: recordedAt,
      startedAt: _dateTimeFromJson(json['startedAt']),
      endedAt: _dateTimeFromJson(json['endedAt']),
      actualDuration: _durationFromJson(json['actualDurationMs']),
      actualDistanceKm: _doubleOrNull(json['actualDistanceKm']),
      actualElevationGainMeters: _intOrNull(json['actualElevationGainMeters']),
      perceivedEffort: ActivityPerceivedEffort.fromKey(
        _stringOrNull(json['perceivedEffort']),
      ),
      linkedSessionId: _stringOrNull(json['linkedSessionId']),
      notes: _stringOrNull(json['notes']),
    );
  }

  @override
  RunActivity copyWith({
    String? id,
    ActivityKind? kind,
    ActivitySource? source,
    ActivityCompletionStatus? completionStatus,
    DateTime? recordedAt,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? actualDuration,
    double? actualDistanceKm,
    int? actualElevationGainMeters,
    ActivityPerceivedEffort? perceivedEffort,
    String? linkedSessionId,
    String? notes,
  }) {
    assert(kind == null || kind == ActivityKind.run);
    return RunActivity(
      id: id ?? this.id,
      source: source ?? this.source,
      completionStatus: completionStatus ?? this.completionStatus,
      recordedAt: recordedAt ?? this.recordedAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      actualDuration: actualDuration ?? this.actualDuration,
      actualDistanceKm: actualDistanceKm ?? this.actualDistanceKm,
      actualElevationGainMeters:
          actualElevationGainMeters ?? this.actualElevationGainMeters,
      perceivedEffort: perceivedEffort ?? this.perceivedEffort,
      linkedSessionId: linkedSessionId ?? this.linkedSessionId,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': ActivityRecord.schemaVersion,
      'kind': kind.key,
      'id': id,
      'source': source.key,
      'completionStatus': completionStatus.key,
      'recordedAt': _dateTimeToJson(recordedAt),
      'startedAt': _dateTimeToJson(startedAt),
      'endedAt': _dateTimeToJson(endedAt),
      'actualDurationMs': _durationToJson(actualDuration),
      'actualDistanceKm': actualDistanceKm,
      'actualElevationGainMeters': actualElevationGainMeters,
      'perceivedEffort': perceivedEffort?.key,
      'linkedSessionId': linkedSessionId,
      'notes': notes,
    };
  }
}
