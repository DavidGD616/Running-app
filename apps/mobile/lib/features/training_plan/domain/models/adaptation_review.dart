import 'model_json_utils.dart';
import 'adaptation_patch.dart';
import 'weekly_training_summary.dart';

enum AdaptationReviewStatus implements CanonicalKeyed {
  pending('pending'),
  accepted('accepted'),
  dismissed('dismissed'),
  failed('failed');

  const AdaptationReviewStatus(this.key);

  @override
  final String key;

  static AdaptationReviewStatus? fromKey(String? key) {
    return switch (key) {
      'review_proposed' || 'proposed' => AdaptationReviewStatus.pending,
      'review_applied' || 'applied' => AdaptationReviewStatus.accepted,
      'review_dismissed' => AdaptationReviewStatus.dismissed,
      _ => enumFromKey(key, values, (value) => value.key),
    };
  }
}

enum AdaptationReviewClassification implements CanonicalKeyed {
  onTrack('on_track'),
  tooAggressive('too_aggressive'),
  tooEasy('too_easy'),
  recoveryNeeded('recovery_needed'),
  scheduleMismatch('schedule_mismatch'),
  insufficientData('insufficient_data');

  const AdaptationReviewClassification(this.key);

  @override
  final String key;

  static AdaptationReviewClassification? fromKey(String? key) {
    return switch (key) {
      'classification_maintain' => AdaptationReviewClassification.onTrack,
      'classification_reduce_load' =>
        AdaptationReviewClassification.tooAggressive,
      'classification_increase_load' => AdaptationReviewClassification.tooEasy,
      _ => enumFromKey(key, values, (value) => value.key),
    };
  }
}

enum AdaptationReviewSeverity implements CanonicalKeyed {
  info('info'),
  caution('caution'),
  high('high');

  const AdaptationReviewSeverity(this.key);

  @override
  final String key;

  static AdaptationReviewSeverity? fromKey(String? key) {
    return switch (key) {
      'severity_low' || 'low' => AdaptationReviewSeverity.info,
      'severity_medium' || 'medium' => AdaptationReviewSeverity.caution,
      'severity_high' => AdaptationReviewSeverity.high,
      _ => enumFromKey(key, values, (value) => value.key),
    };
  }
}

class AdaptationReview {
  const AdaptationReview({
    required this.id,
    required this.createdAt,
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.classification,
    required this.severity,
    required this.summaryKey,
    this.sourcePlanVersionId,
    this.proposedPlanVersionId,
    this.summaryArgs = const {},
    this.reasonKeys = const [],
    this.weeklySummary,
    this.patches = const [],
    this.loadBefore,
    this.loadAfter,
  });

  static const schemaVersion = 1;

  final String id;
  final DateTime createdAt;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String? sourcePlanVersionId;
  final String? proposedPlanVersionId;
  final AdaptationReviewStatus status;
  final AdaptationReviewClassification classification;
  final AdaptationReviewSeverity severity;
  final String summaryKey;
  final Map<String, String> summaryArgs;
  final List<String> reasonKeys;
  final WeeklyTrainingSummary? weeklySummary;
  final List<AdaptationPatch> patches;
  final double? loadBefore;
  final double? loadAfter;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'sourcePlanVersionId': sourcePlanVersionId,
      'proposedPlanVersionId': proposedPlanVersionId,
      'status': status.key,
      'classification': classification.key,
      'severity': severity.key,
      'summaryKey': summaryKey,
      'summaryArgs': summaryArgs,
      'reasonKeys': reasonKeys,
      if (weeklySummary != null) 'weeklySummary': weeklySummary!.toJson(),
      'patches': patches.map((patch) => patch.toJson()).toList(growable: false),
      if (loadBefore != null) 'loadBefore': loadBefore,
      if (loadAfter != null) 'loadAfter': loadAfter,
    };
  }

  static AdaptationReview? fromJson(Map<String, dynamic> json) {
    final id = stringOrNull(json['id']);
    final createdAt = requiredDateTime(
      json,
      'createdAt',
      context: 'adaptation review',
    );
    final weekStart = requiredDateTime(
      json,
      'weekStart',
      context: 'adaptation review',
    );
    final weekEnd = requiredDateTime(
      json,
      'weekEnd',
      context: 'adaptation review',
    );
    if (id == null || id.isEmpty) {
      return null;
    }

    final status = AdaptationReviewStatus.fromKey(stringOrNull(json['status']));
    final classification = AdaptationReviewClassification.fromKey(
      stringOrNull(json['classification']),
    );
    final severity = AdaptationReviewSeverity.fromKey(
      stringOrNull(json['severity']),
    );
    final summaryKey = stringOrNull(json['summaryKey']);
    if (status == null || classification == null || severity == null) {
      return null;
    }

    final patchesRaw = json['patches'];
    final patches = <AdaptationPatch>[];
    if (patchesRaw is List) {
      for (final item in patchesRaw) {
        if (item is Map<String, dynamic>) {
          final parsed = AdaptationPatch.fromJson(item);
          if (parsed != null) {
            patches.add(parsed);
          }
        } else if (item is Map) {
          final parsed = AdaptationPatch.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          );
          if (parsed != null) {
            patches.add(parsed);
          }
        }
      }
    }

    return AdaptationReview(
      id: id,
      createdAt: createdAt,
      weekStart: weekStart,
      weekEnd: weekEnd,
      sourcePlanVersionId: stringOrNull(json['sourcePlanVersionId']),
      proposedPlanVersionId: stringOrNull(json['proposedPlanVersionId']),
      status: status,
      classification: classification,
      severity: severity,
      summaryKey: summaryKey ?? '',
      summaryArgs: _summaryArgs(json['summaryArgs']),
      reasonKeys: _stringList(json['reasonKeys']),
      weeklySummary: _weeklySummary(json['weeklySummary']),
      patches: patches,
      loadBefore: optionalDouble(json['loadBefore']),
      loadAfter: optionalDouble(json['loadAfter']),
    );
  }

  double? get loadDelta {
    final before = loadBefore;
    final after = loadAfter;
    if (before == null || after == null) return null;
    return after - before;
  }

  bool get hasLoadDecrease =>
      loadDelta != null && loadDelta! < 0 ? true : false;

  bool get hasLoadIncrease =>
      loadDelta != null && loadDelta! > 0 ? true : false;

  AdaptationReview copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? weekStart,
    DateTime? weekEnd,
    String? sourcePlanVersionId,
    String? proposedPlanVersionId,
    AdaptationReviewStatus? status,
    AdaptationReviewClassification? classification,
    AdaptationReviewSeverity? severity,
    String? summaryKey,
    Map<String, String>? summaryArgs,
    List<String>? reasonKeys,
    WeeklyTrainingSummary? weeklySummary,
    List<AdaptationPatch>? patches,
    double? loadBefore,
    double? loadAfter,
  }) {
    return AdaptationReview(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      sourcePlanVersionId: sourcePlanVersionId ?? this.sourcePlanVersionId,
      proposedPlanVersionId:
          proposedPlanVersionId ?? this.proposedPlanVersionId,
      status: status ?? this.status,
      classification: classification ?? this.classification,
      severity: severity ?? this.severity,
      summaryKey: summaryKey ?? this.summaryKey,
      summaryArgs: summaryArgs ?? this.summaryArgs,
      reasonKeys: reasonKeys ?? this.reasonKeys,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      patches: patches ?? this.patches,
      loadBefore: loadBefore ?? this.loadBefore,
      loadAfter: loadAfter ?? this.loadAfter,
    );
  }
}

Map<String, String> _summaryArgs(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, arg) => MapEntry('$key', arg is String ? arg : '$arg'),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

WeeklyTrainingSummary? _weeklySummary(Object? value) {
  if (value is Map<String, dynamic>) {
    return WeeklyTrainingSummary.fromJson(value);
  }
  if (value is Map) {
    return WeeklyTrainingSummary.fromJson(
      value.map((key, item) => MapEntry('$key', item)),
    );
  }
  return null;
}
