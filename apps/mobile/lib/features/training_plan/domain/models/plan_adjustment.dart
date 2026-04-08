String? _adjustmentStringOrNull(Object? value) => value is String ? value : null;

DateTime? _adjustmentDateTimeOrNull(Object? value) {
  final raw = _adjustmentStringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

T? _adjustmentEnumByKey<T extends Enum>(
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

abstract interface class PlanAdjustmentKeyed {
  String get key;
}

enum PlanAdjustmentTrigger implements PlanAdjustmentKeyed {
  skippedSession('trigger_skipped_session'),
  completedSessionFeedback('trigger_completed_session_feedback');

  const PlanAdjustmentTrigger(this.key);

  @override
  final String key;

  static PlanAdjustmentTrigger? fromKey(String? key) =>
      _adjustmentEnumByKey(key, values, (value) => value.key);
}

enum PlanAdjustmentReason implements PlanAdjustmentKeyed {
  skippedByRunner('reason_skipped_by_runner'),
  fatigueConcern('reason_fatigue_concern'),
  painConcern('reason_pain_concern'),
  scheduleConflict('reason_schedule_conflict');

  const PlanAdjustmentReason(this.key);

  @override
  final String key;

  static PlanAdjustmentReason? fromKey(String? key) =>
      _adjustmentEnumByKey(key, values, (value) => value.key);
}

enum PlanAdjustmentStatus implements PlanAdjustmentKeyed {
  pending('pending'),
  applied('applied'),
  dismissed('dismissed');

  const PlanAdjustmentStatus(this.key);

  @override
  final String key;

  static PlanAdjustmentStatus? fromKey(String? key) =>
      _adjustmentEnumByKey(key, values, (value) => value.key);
}

class PlanAdjustment {
  const PlanAdjustment({
    required this.id,
    required this.plannedSessionId,
    required this.createdAt,
    required this.trigger,
    required this.reason,
    this.status = PlanAdjustmentStatus.pending,
    this.notes,
  });

  static const schemaVersion = 1;

  final String id;
  final String plannedSessionId;
  final DateTime createdAt;
  final PlanAdjustmentTrigger trigger;
  final PlanAdjustmentReason reason;
  final PlanAdjustmentStatus status;
  final String? notes;

  PlanAdjustment copyWith({
    String? id,
    String? plannedSessionId,
    DateTime? createdAt,
    PlanAdjustmentTrigger? trigger,
    PlanAdjustmentReason? reason,
    PlanAdjustmentStatus? status,
    String? notes,
  }) {
    return PlanAdjustment(
      id: id ?? this.id,
      plannedSessionId: plannedSessionId ?? this.plannedSessionId,
      createdAt: createdAt ?? this.createdAt,
      trigger: trigger ?? this.trigger,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'plannedSessionId': plannedSessionId,
      'createdAt': createdAt.toIso8601String(),
      'trigger': trigger.key,
      'reason': reason.key,
      'status': status.key,
      'notes': notes,
    };
  }

  static PlanAdjustment? fromJson(Map<String, dynamic> json) {
    final id = _adjustmentStringOrNull(json['id']);
    final plannedSessionId = _adjustmentStringOrNull(json['plannedSessionId']);
    final createdAt = _adjustmentDateTimeOrNull(json['createdAt']);
    final trigger = PlanAdjustmentTrigger.fromKey(
      _adjustmentStringOrNull(json['trigger']),
    );
    final reason = PlanAdjustmentReason.fromKey(
      _adjustmentStringOrNull(json['reason']),
    );
    final status = PlanAdjustmentStatus.fromKey(
      _adjustmentStringOrNull(json['status']),
    );
    if (id == null ||
        id.isEmpty ||
        plannedSessionId == null ||
        plannedSessionId.isEmpty ||
        createdAt == null ||
        trigger == null ||
        reason == null) {
      return null;
    }

    return PlanAdjustment(
      id: id,
      plannedSessionId: plannedSessionId,
      createdAt: createdAt,
      trigger: trigger,
      reason: reason,
      status: status ?? PlanAdjustmentStatus.pending,
      notes: _adjustmentStringOrNull(json['notes']),
    );
  }
}
