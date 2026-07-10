String? _stringOrNull(Object? value) => value is String ? value : null;

DateTime? _dateTimeOrNull(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
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

abstract interface class SessionFeedbackKeyed {
  String get key;
}

enum SessionFeedbackDifficulty implements SessionFeedbackKeyed {
  veryEasy('feedback_very_easy'),
  manageable('feedback_manageable'),
  hard('feedback_hard'),
  veryHard('feedback_very_hard');

  const SessionFeedbackDifficulty(this.key);

  @override
  final String key;

  static SessionFeedbackDifficulty? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum SessionRecoveryStatus implements SessionFeedbackKeyed {
  fresh('recovery_fresh'),
  okay('recovery_okay'),
  fatigued('recovery_fatigued');

  const SessionRecoveryStatus(this.key);

  @override
  final String key;

  static SessionRecoveryStatus? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum SessionFeedbackSleep implements SessionFeedbackKeyed {
  great('sleep_great'),
  okay('sleep_okay'),
  poor('sleep_poor');

  const SessionFeedbackSleep(this.key);

  @override
  final String key;

  static SessionFeedbackSleep? fromKey(String? key) {
    if (key == null) return null;

    if (key == 'great') return SessionFeedbackSleep.great;
    if (key == 'okay') return SessionFeedbackSleep.okay;
    if (key == 'poor') return SessionFeedbackSleep.poor;

    return _enumByKey(key, values, (value) => value.key);
  }
}

enum SessionFeedbackLegs implements SessionFeedbackKeyed {
  fresh('legs_fresh'),
  normal('legs_normal'),
  heavy('legs_heavy');

  const SessionFeedbackLegs(this.key);

  @override
  final String key;

  static SessionFeedbackLegs? fromKey(String? key) {
    if (key == null) return null;

    if (key == 'normal') return SessionFeedbackLegs.normal;

    return _enumByKey(key, values, (value) => value.key);
  }
}

enum SessionFeedbackPain implements SessionFeedbackKeyed {
  none('pain_none'),
  mild('pain_mild'),
  moderate('pain_moderate'),
  severe('pain_severe');

  const SessionFeedbackPain(this.key);

  @override
  final String key;

  static SessionFeedbackPain? fromKey(String? key) {
    if (key == null) return null;

    if (key == 'sharp') return SessionFeedbackPain.severe;

    if (key == 'none') return SessionFeedbackPain.none;

    return _enumByKey(key, values, (value) => value.key);
  }
}

enum SessionFeedbackMotivation implements SessionFeedbackKeyed {
  ready('motivation_ready'),
  mixed('motivation_mixed'),
  low('motivation_low');

  const SessionFeedbackMotivation(this.key);

  @override
  final String key;

  static SessionFeedbackMotivation? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

class SessionFeedback {
  const SessionFeedback({
    required this.id,
    required this.recordedAt,
    this.plannedSessionId,
    this.activityId,
    this.difficulty,
    this.recoveryStatus,
    this.sleep,
    this.legs,
    this.pain,
    this.motivation,
    this.notes,
  });

  static const schemaVersion = 1;

  final String id;
  final DateTime recordedAt;
  final String? plannedSessionId;
  final String? activityId;
  final SessionFeedbackDifficulty? difficulty;
  final SessionRecoveryStatus? recoveryStatus;
  final SessionFeedbackSleep? sleep;
  final SessionFeedbackLegs? legs;
  final SessionFeedbackPain? pain;
  final SessionFeedbackMotivation? motivation;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'recordedAt': recordedAt.toIso8601String(),
      'plannedSessionId': plannedSessionId,
      'activityId': activityId,
      'difficulty': difficulty?.key,
      'recoveryStatus': recoveryStatus?.key,
      'sleep': sleep?.key,
      'legs': legs?.key,
      'pain': pain?.key,
      'motivation': motivation?.key,
      'notes': notes,
    };
  }

  static SessionFeedback? fromJson(Map<String, dynamic> json) {
    final id = _stringOrNull(json['id']);
    final recordedAt = _dateTimeOrNull(json['recordedAt']);
    if (id == null || id.isEmpty || recordedAt == null) return null;

    return SessionFeedback(
      id: id,
      recordedAt: recordedAt,
      plannedSessionId: _stringOrNull(json['plannedSessionId']),
      activityId: _stringOrNull(json['activityId']),
      difficulty: SessionFeedbackDifficulty.fromKey(
        _stringOrNull(json['difficulty']),
      ),
      recoveryStatus: SessionRecoveryStatus.fromKey(
        _stringOrNull(json['recoveryStatus']),
      ),
      sleep: SessionFeedbackSleep.fromKey(_stringOrNull(json['sleep'])),
      legs: SessionFeedbackLegs.fromKey(_stringOrNull(json['legs'])),
      pain: SessionFeedbackPain.fromKey(_stringOrNull(json['pain'])),
      motivation: SessionFeedbackMotivation.fromKey(
        _stringOrNull(json['motivation']),
      ),
      notes: _stringOrNull(json['notes']),
    );
  }
}
