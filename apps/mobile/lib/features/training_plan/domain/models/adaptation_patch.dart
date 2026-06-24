import 'model_json_utils.dart';
import 'session_type.dart';

enum AdaptationPatchType implements CanonicalKeyed {
  noChange('noChange'),
  reduceSession('reduceSession'),
  replaceSession('replaceSession'),
  moveSession('moveSession'),
  shortenLongRun('shortenLongRun'),
  repeatWeek('repeatWeek'),
  progressSlightly('progressSlightly');

  const AdaptationPatchType(this.key);

  @override
  final String key;

  static AdaptationPatchType? fromKey(String? key) {
    return switch (key) {
      'patch_skip_session' => AdaptationPatchType.reduceSession,
      'patch_modify_session_type' => AdaptationPatchType.replaceSession,
      'patch_adjust_distance' => AdaptationPatchType.reduceSession,
      'patch_adjust_duration' => AdaptationPatchType.reduceSession,
      'patch_reschedule_session' => AdaptationPatchType.moveSession,
      _ => enumFromKey(key, values, (value) => value.key),
    };
  }
}

class AdaptationPatch {
  const AdaptationPatch({
    required this.type,
    required this.reasonKey,
    this.sessionId,
    this.date,
    this.beforeSessionType,
    this.afterSessionType,
    this.beforeDistanceKm,
    this.afterDistanceKm,
    this.beforeDurationMinutes,
    this.afterDurationMinutes,
  });

  static const schemaVersion = 1;

  final AdaptationPatchType type;
  final String reasonKey;
  final String? sessionId;
  final DateTime? date;
  final SessionType? beforeSessionType;
  final SessionType? afterSessionType;
  final double? beforeDistanceKm;
  final double? afterDistanceKm;
  final int? beforeDurationMinutes;
  final int? afterDurationMinutes;

  Map<String, dynamic> toJson() {
    return {
      'type': type.key,
      'reasonKey': reasonKey,
      if (sessionId != null) 'sessionId': sessionId,
      if (date != null) 'targetDate': date!.toIso8601String(),
      if (afterSessionType != null) 'targetType': afterSessionType!.name,
      if (afterDistanceKm != null) 'targetDistanceKm': afterDistanceKm,
      if (afterDurationMinutes != null)
        'targetDurationMinutes': afterDurationMinutes,
    };
  }

  static AdaptationPatch? fromJson(Map<String, dynamic> json) {
    final type = AdaptationPatchType.fromKey(stringOrNull(json['type']));
    final reasonKey = stringOrNull(json['reasonKey']);
    if (type == null || reasonKey == null || reasonKey.isEmpty) {
      return null;
    }

    return AdaptationPatch(
      type: type,
      reasonKey: reasonKey,
      sessionId: stringOrNull(json['sessionId']),
      date: _dateTimeOrNull(json['date'] ?? json['targetDate']),
      beforeSessionType: _sessionTypeFromName(
        stringOrNull(json['beforeSessionType']),
      ),
      afterSessionType: _sessionTypeFromName(
        stringOrNull(json['afterSessionType'] ?? json['targetType']),
      ),
      beforeDistanceKm: optionalDouble(json['beforeDistanceKm']),
      afterDistanceKm: optionalDouble(
        json['afterDistanceKm'] ?? json['targetDistanceKm'],
      ),
      beforeDurationMinutes: optionalInt(json['beforeDurationMinutes']),
      afterDurationMinutes: optionalInt(
        json['afterDurationMinutes'] ?? json['targetDurationMinutes'],
      ),
    );
  }
}

SessionType? _sessionTypeFromName(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final value in SessionType.values) {
    if (value.name == name) return value;
  }
  return null;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
