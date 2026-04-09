enum GoalKind { race, time, consistency, generalFitness }

enum GoalStatus { active, completed, archived }

abstract final class GoalJsonKeys {
  static const kind = 'kind';
  static const status = 'status';
  static const priority = 'priority';
  static const targetRace = 'targetRace';
  static const eventDate = 'eventDate';
  static const currentTimeMs = 'currentTimeMs';
  static const targetTimeMs = 'targetTimeMs';
  static const raceEvent = 'raceEvent';
  static const raceType = 'raceType';
}

enum GoalPriorityType {
  justFinish('priority_just_finish'),
  finishStrong('priority_finish_strong'),
  improveTime('priority_improve_time'),
  consistency('priority_consistency'),
  generalFitness('priority_general_fitness');

  const GoalPriorityType(this.key);

  final String key;

  static GoalPriorityType? fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

enum GoalRaceType {
  fiveK('race_5k'),
  tenK('race_10k'),
  halfMarathon('race_half_marathon'),
  marathon('race_marathon'),
  other('race_other');

  const GoalRaceType(this.key);

  final String key;

  static GoalRaceType? fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

T? _enumFromName<T extends Enum>(String? name, List<T> values) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, nestedValue) => MapEntry('$key', nestedValue));
}

RaceEvent? _raceEventFromJson(Object? value) {
  final map = _mapOrEmpty(value);
  if (map.isEmpty) return null;
  return RaceEvent.fromJson(map);
}

Duration? _durationFromJson(Object? value) {
  if (value is int) return Duration(milliseconds: value);
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return Duration(milliseconds: parsed);
  }
  return null;
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class RaceEvent {
  const RaceEvent({required this.raceType, this.eventDate});

  final GoalRaceType raceType;
  final DateTime? eventDate;

  Map<String, dynamic> toJson() {
    return {
      GoalJsonKeys.raceType: raceType.key,
      GoalJsonKeys.eventDate: eventDate?.toIso8601String(),
    };
  }

  static RaceEvent? fromJson(Map<String, dynamic> json) {
    final raceType = GoalRaceType.fromKey(
      json[GoalJsonKeys.raceType] as String? ??
          json[GoalJsonKeys.targetRace] as String?,
    );
    if (raceType == null) return null;

    return RaceEvent(
      raceType: raceType,
      eventDate: _dateTimeFromJson(json[GoalJsonKeys.eventDate]),
    );
  }
}

class Goal {
  const Goal({
    required this.kind,
    required this.status,
    required this.priority,
    required this.targetRace,
    this.eventDate,
    this.currentTime,
    this.targetTime,
  });

  final GoalKind kind;
  final GoalStatus status;
  final GoalPriorityType priority;
  final GoalRaceType targetRace;
  final DateTime? eventDate;
  final Duration? currentTime;
  final Duration? targetTime;

  bool get isRaceGoal => kind == GoalKind.race;
  bool get isTimeGoal => kind == GoalKind.time;
  bool get hasEventDate => eventDate != null;
  bool get hasTargetTime => targetTime != null;

  RaceEvent? get raceEvent => null;

  Goal copyWith({
    GoalKind? kind,
    GoalStatus? status,
    GoalPriorityType? priority,
    GoalRaceType? targetRace,
    DateTime? eventDate,
    Duration? currentTime,
    Duration? targetTime,
  }) {
    return Goal(
      kind: kind ?? this.kind,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      targetRace: targetRace ?? this.targetRace,
      eventDate: eventDate ?? this.eventDate,
      currentTime: currentTime ?? this.currentTime,
      targetTime: targetTime ?? this.targetTime,
    );
  }

  Map<String, dynamic> toJson() {
    final event = raceEvent;
    return {
      GoalJsonKeys.kind: kind.name,
      GoalJsonKeys.status: status.name,
      GoalJsonKeys.priority: priority.key,
      GoalJsonKeys.targetRace: targetRace.key,
      GoalJsonKeys.eventDate: eventDate?.toIso8601String(),
      GoalJsonKeys.currentTimeMs: currentTime?.inMilliseconds,
      GoalJsonKeys.targetTimeMs: targetTime?.inMilliseconds,
      if (event is RaceEvent) GoalJsonKeys.raceEvent: event.toJson(),
    };
  }

  static Goal? fromJson(Map<String, dynamic> json) {
    final kind = _enumFromName(
      json[GoalJsonKeys.kind] as String?,
      GoalKind.values,
    );
    final status = _enumFromName(
      json[GoalJsonKeys.status] as String?,
      GoalStatus.values,
    );
    final priority = GoalPriorityType.fromKey(
      json[GoalJsonKeys.priority] as String?,
    );
    final targetRace = GoalRaceType.fromKey(
      json[GoalJsonKeys.targetRace] as String?,
    );
    if (kind == null ||
        status == null ||
        priority == null ||
        targetRace == null) {
      return null;
    }

    final eventDate = _dateTimeFromJson(json[GoalJsonKeys.eventDate]);
    final rawRaceEvent = json[GoalJsonKeys.raceEvent];
    final raceEvent = _raceEventFromJson(rawRaceEvent);
    if (rawRaceEvent != null && raceEvent == null) {
      return null;
    }
    final inferredEvent =
        raceEvent ?? RaceEvent(raceType: targetRace, eventDate: eventDate);

    return switch (kind) {
      GoalKind.race => RaceGoal(
        event: inferredEvent,
        targetRace: targetRace,
        status: status,
        priority: priority,
        currentTime: _durationFromJson(json[GoalJsonKeys.currentTimeMs]),
        targetTime: _durationFromJson(json[GoalJsonKeys.targetTimeMs]),
      ),
      GoalKind.time => TimeGoal(
        targetRace: targetRace,
        event: inferredEvent,
        status: status,
        priority: priority,
        eventDate: eventDate ?? inferredEvent.eventDate,
        currentTime: _durationFromJson(json[GoalJsonKeys.currentTimeMs]),
        targetTime: _durationFromJson(json[GoalJsonKeys.targetTimeMs]),
      ),
      _ => Goal(
        kind: kind,
        status: status,
        priority: priority,
        targetRace: targetRace,
        eventDate: eventDate,
        currentTime: _durationFromJson(json[GoalJsonKeys.currentTimeMs]),
        targetTime: _durationFromJson(json[GoalJsonKeys.targetTimeMs]),
      ),
    };
  }
}

class RaceGoal extends Goal {
  RaceGoal({
    this.event,
    required super.status,
    required super.priority,
    super.kind = GoalKind.race,
    super.currentTime,
    super.targetTime,
    GoalRaceType? targetRace,
  }) : super(
         targetRace: targetRace ?? event?.raceType ?? GoalRaceType.other,
         eventDate: event?.eventDate,
       );

  final RaceEvent? event;

  @override
  RaceEvent? get raceEvent => event;
}

class TimeGoal extends Goal {
  TimeGoal({
    required super.status,
    required super.priority,
    super.currentTime,
    super.targetTime,
    required super.targetRace,
    this.event,
    DateTime? eventDate,
  }) : super(
         kind: GoalKind.time,
         eventDate: eventDate ?? event?.eventDate,
       );

  final RaceEvent? event;

  @override
  RaceEvent? get raceEvent => event;
}
