String? _revisionStringOrNull(Object? value) => value is String ? value : null;

DateTime? _revisionDateTimeOrNull(Object? value) {
  final raw = _revisionStringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

T? _revisionEnumByKey<T extends Enum>(
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

abstract interface class PlanRevisionKeyed {
  String get key;
}

enum PlanRevisionReason implements PlanRevisionKeyed {
  skippedSession('revision_skipped_session'),
  feedbackLogged('revision_feedback_logged'),
  manualPlanChange('revision_manual_plan_change');

  const PlanRevisionReason(this.key);

  @override
  final String key;

  static PlanRevisionReason? fromKey(String? key) =>
      _revisionEnumByKey(key, values, (value) => value.key);
}

class PlanRevision {
  const PlanRevision({
    required this.id,
    required this.createdAt,
    required this.reason,
    required this.summaryKey,
    this.plannedSessionId,
    this.adjustmentIds = const [],
  });

  static const schemaVersion = 1;

  final String id;
  final DateTime createdAt;
  final PlanRevisionReason reason;
  final String summaryKey;
  final String? plannedSessionId;
  final List<String> adjustmentIds;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'reason': reason.key,
      'summaryKey': summaryKey,
      'plannedSessionId': plannedSessionId,
      'adjustmentIds': adjustmentIds,
    };
  }

  static PlanRevision? fromJson(Map<String, dynamic> json) {
    final id = _revisionStringOrNull(json['id']);
    final createdAt = _revisionDateTimeOrNull(json['createdAt']);
    final reason = PlanRevisionReason.fromKey(
      _revisionStringOrNull(json['reason']),
    );
    final summaryKey = _revisionStringOrNull(json['summaryKey']);
    if (id == null ||
        id.isEmpty ||
        createdAt == null ||
        reason == null ||
        summaryKey == null ||
        summaryKey.isEmpty) {
      return null;
    }

    return PlanRevision(
      id: id,
      createdAt: createdAt,
      reason: reason,
      summaryKey: summaryKey,
      plannedSessionId: _revisionStringOrNull(json['plannedSessionId']),
      adjustmentIds: switch (json['adjustmentIds']) {
        List<dynamic> values => values.whereType<String>().toList(growable: false),
        _ => const [],
      },
    );
  }
}
