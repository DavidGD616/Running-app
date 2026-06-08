enum GoalKind { race, time, consistency, generalFitness }

enum GoalStatus { active, completed, archived }

abstract final class GoalJsonKeys {
  static const kind = 'kind';
  static const status = 'status';
  static const targetRace = 'targetRace';
  static const eventDate = 'eventDate';
  static const raceEvent = 'raceEvent';
  static const raceType = 'raceType';
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
    required this.targetRace,
    this.eventDate,
  });

  final GoalKind kind;
  final GoalStatus status;
  final GoalRaceType targetRace;
  final DateTime? eventDate;

  bool get isRaceGoal => kind == GoalKind.race;
  bool get isTimeGoal => kind == GoalKind.time;
  bool get hasEventDate => eventDate != null;

  RaceEvent? get raceEvent => null;

  Goal copyWith({
    GoalKind? kind,
    GoalStatus? status,
    GoalRaceType? targetRace,
    DateTime? eventDate,
  }) {
    return Goal(
      kind: kind ?? this.kind,
      status: status ?? this.status,
      targetRace: targetRace ?? this.targetRace,
      eventDate: eventDate ?? this.eventDate,
    );
  }

  Map<String, dynamic> toJson() {
    final event = raceEvent;
    return {
      GoalJsonKeys.kind: kind.name,
      GoalJsonKeys.status: status.name,
      GoalJsonKeys.targetRace: targetRace.key,
      GoalJsonKeys.eventDate: eventDate?.toIso8601String(),
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
    final targetRace = GoalRaceType.fromKey(
      json[GoalJsonKeys.targetRace] as String?,
    );
    if (kind == null || status == null || targetRace == null) {
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
      ),
      GoalKind.time => TimeGoal(
        targetRace: targetRace,
        event: inferredEvent,
        status: status,
        eventDate: eventDate ?? inferredEvent.eventDate,
      ),
      _ => Goal(
        kind: kind,
        status: status,
        targetRace: targetRace,
        eventDate: eventDate,
      ),
    };
  }
}

class RaceGoal extends Goal {
  RaceGoal({
    this.event,
    required super.status,
    super.kind = GoalKind.race,
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
    required super.targetRace,
    this.event,
    DateTime? eventDate,
  }) : super(kind: GoalKind.time, eventDate: eventDate ?? event?.eventDate);

  final RaceEvent? event;

  @override
  RaceEvent? get raceEvent => event;
}
