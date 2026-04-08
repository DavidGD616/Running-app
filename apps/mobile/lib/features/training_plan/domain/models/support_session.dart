import 'model_json_utils.dart';
import 'session_type.dart';

enum SupportSessionStatus implements CanonicalKeyed {
  planned('planned'),
  completed('completed'),
  skipped('skipped');

  const SupportSessionStatus(this.key);

  @override
  final String key;

  static SupportSessionStatus? fromKey(String? key) =>
      enumFromKey(key, values, (value) => value.key);
}

class SupportSession {
  const SupportSession({
    required this.id,
    required this.date,
    required this.weekNumber,
    required this.type,
    required this.status,
    this.durationMinutes,
    this.notes,
    this.feedbackId,
    this.revisionId,
    this.adjustmentId,
  });

  static const int schemaVersion = 1;

  final String id;
  final DateTime date;
  final int weekNumber;
  final SupplementalSessionType type;
  final SupportSessionStatus status;
  final int? durationMinutes;
  final String? notes;
  final String? feedbackId;
  final String? revisionId;
  final String? adjustmentId;

  bool get isSupportSession => true;

  bool get isRunSession => false;

  bool get isCompleted => status == SupportSessionStatus.completed;

  bool get isPlanned => status == SupportSessionStatus.planned;

  SupportSession copyWith({
    String? id,
    DateTime? date,
    int? weekNumber,
    SupplementalSessionType? type,
    SupportSessionStatus? status,
    int? durationMinutes,
    String? notes,
    String? feedbackId,
    String? revisionId,
    String? adjustmentId,
  }) {
    return SupportSession(
      id: id ?? this.id,
      date: date ?? this.date,
      weekNumber: weekNumber ?? this.weekNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      feedbackId: feedbackId ?? this.feedbackId,
      revisionId: revisionId ?? this.revisionId,
      adjustmentId: adjustmentId ?? this.adjustmentId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'date': dateTimeToJson(date),
      'weekNumber': weekNumber,
      'type': type.key,
      'status': status.key,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'feedbackId': feedbackId,
      'revisionId': revisionId,
      'adjustmentId': adjustmentId,
    };
  }

  static SupportSession? fromJson(Map<String, dynamic> json) {
    final id = stringOrNull(json['id']);
    final date = dateTimeFromJson(json['date']);
    final weekNumber = intOrNull(json['weekNumber']);
    final type = supplementalSessionTypeFromKey(stringOrNull(json['type']));
    final status = SupportSessionStatus.fromKey(stringOrNull(json['status']));
    if (id == null || id.isEmpty || date == null || weekNumber == null) {
      return null;
    }
    if (type == null || status == null) return null;

    return SupportSession(
      id: id,
      date: date,
      weekNumber: weekNumber,
      type: type,
      status: status,
      durationMinutes: intOrNull(json['durationMinutes']),
      notes: stringOrNull(json['notes']),
      feedbackId: stringOrNull(json['feedbackId']),
      revisionId: stringOrNull(json['revisionId']),
      adjustmentId: stringOrNull(json['adjustmentId']),
    );
  }
}
