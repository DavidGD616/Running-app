import '../../profile/domain/models/runner_profile.dart';
import '../../training_plan/domain/models/session_type.dart';
import '../../training_plan/domain/models/training_plan.dart';

class EditGoalDraft {
  const EditGoalDraft({
    required this.race,
    required this.hasRaceDate,
    required this.raceDate,
    required this.targetTime,
  });

  factory EditGoalDraft.fromProfile({
    required RunnerProfile profile,
    required AcceptedRaceTarget acceptedRaceTarget,
  }) {
    return EditGoalDraft(
      race: profile.goal.race,
      hasRaceDate: profile.goal.hasRaceDate,
      raceDate: profile.goal.hasRaceDate ? profile.goal.raceDate : null,
      targetTime: acceptedRaceTarget.primaryTime,
    );
  }

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
  final Duration targetTime;

  EditGoalDraft copyWith({
    RunnerGoalRace? race,
    bool? hasRaceDate,
    DateTime? raceDate,
    bool clearRaceDate = false,
    Duration? targetTime,
  }) {
    final nextHasRaceDate = hasRaceDate ?? this.hasRaceDate;
    return EditGoalDraft(
      race: race ?? this.race,
      hasRaceDate: nextHasRaceDate,
      raceDate: nextHasRaceDate
          ? (clearRaceDate ? null : raceDate ?? this.raceDate)
          : null,
      targetTime: targetTime ?? this.targetTime,
    );
  }

  Map<String, dynamic> previewPayload({
    required String sourcePlanVersionId,
    required DateTime localDate,
    required String locale,
  }) {
    return {
      'action': 'preview',
      'sourcePlanVersionId': sourcePlanVersionId,
      'race': race.key,
      'hasRaceDate': hasRaceDate,
      'raceDate': hasRaceDate ? _dateOnly(raceDate) : null,
      'targetTimeSeconds': targetTime.inSeconds,
      'localDate': _dateOnly(localDate),
      'locale': locale == 'es' ? 'es' : 'en',
    };
  }
}

enum GoalEditWarning {
  shortNotice('short_notice'),
  aggressiveTarget('aggressive_target');

  const GoalEditWarning(this.key);
  final String key;

  static GoalEditWarning parse(Object? value) {
    for (final warning in values) {
      if (warning.key == value) return warning;
    }
    throw const FormatException('Unsupported goal edit warning.');
  }
}

class GoalEditGoal {
  const GoalEditGoal({
    required this.race,
    required this.hasRaceDate,
    required this.raceDate,
    required this.targetTime,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
  final Duration targetTime;

  factory GoalEditGoal.fromJson(Object? value) {
    final json = _strictMap(value, 'goal');
    final race = RunnerGoalRace.fromKey(_requiredString(json, 'race'));
    final hasRaceDate = json['hasRaceDate'];
    final targetSeconds = _requiredPositiveInt(json, 'targetTimeSeconds');
    if (race == null || race == RunnerGoalRace.other || hasRaceDate is! bool) {
      throw const FormatException('Invalid goal edit goal.');
    }
    final rawRaceDate = json['raceDate'];
    final raceDate = rawRaceDate == null ? null : _parseDateOnly(rawRaceDate);
    if ((hasRaceDate && raceDate == null) ||
        (!hasRaceDate && rawRaceDate != null)) {
      throw const FormatException('Invalid goal edit race date.');
    }
    return GoalEditGoal(
      race: race,
      hasRaceDate: hasRaceDate,
      raceDate: raceDate,
      targetTime: Duration(seconds: targetSeconds),
    );
  }
}

class GoalEditSessionChange {
  const GoalEditSessionChange({
    required this.localDate,
    required this.beforeSessionType,
    required this.afterSessionType,
    required this.beforeDurationMinutes,
    required this.afterDurationMinutes,
    required this.beforeDistanceKm,
    required this.afterDistanceKm,
  });

  final DateTime localDate;
  final SessionType? beforeSessionType;
  final SessionType? afterSessionType;
  final int? beforeDurationMinutes;
  final int? afterDurationMinutes;
  final double? beforeDistanceKm;
  final double? afterDistanceKm;

  factory GoalEditSessionChange._fromJson(
    Object? value,
    _GoalEditChangeKind kind,
  ) {
    final json = _strictMap(value, 'session change');
    final beforeType = _nullableSessionType(json, 'beforeSessionType');
    final afterType = _nullableSessionType(json, 'afterSessionType');
    final beforeDuration = _nullableNonNegativeInt(
      json,
      'beforeDurationMinutes',
    );
    final afterDuration = _nullableNonNegativeInt(json, 'afterDurationMinutes');
    final beforeDistance = _nullableNonNegativeDouble(json, 'beforeDistanceKm');
    final afterDistance = _nullableNonNegativeDouble(json, 'afterDistanceKm');
    final hasBefore = beforeType != null;
    final hasAfter = afterType != null;
    final validSides = switch (kind) {
      _GoalEditChangeKind.added => !hasBefore && hasAfter,
      _GoalEditChangeKind.removed => hasBefore && !hasAfter,
      _GoalEditChangeKind.changed => hasBefore && hasAfter,
    };
    if (!validSides ||
        (!hasBefore && (beforeDuration != null || beforeDistance != null)) ||
        (!hasAfter && (afterDuration != null || afterDistance != null))) {
      throw const FormatException('Invalid goal edit session change sides.');
    }
    return GoalEditSessionChange(
      localDate: _parseDateOnly(json['localDate']),
      beforeSessionType: beforeType,
      afterSessionType: afterType,
      beforeDurationMinutes: beforeDuration,
      afterDurationMinutes: afterDuration,
      beforeDistanceKm: beforeDistance,
      afterDistanceKm: afterDistance,
    );
  }
}

enum _GoalEditChangeKind { added, removed, changed }

class GoalEditChangeSummary {
  const GoalEditChangeSummary({
    required this.preservedCount,
    required this.addedUpcomingCount,
    required this.removedUpcomingCount,
    required this.materiallyChangedUpcomingCount,
    required this.addedUpcomingSessions,
    required this.removedUpcomingSessions,
    required this.materiallyChangedUpcomingSessions,
    required this.totalWeeks,
    required this.endDate,
  });

  final int preservedCount;
  final int addedUpcomingCount;
  final int removedUpcomingCount;
  final int materiallyChangedUpcomingCount;
  final List<GoalEditSessionChange> addedUpcomingSessions;
  final List<GoalEditSessionChange> removedUpcomingSessions;
  final List<GoalEditSessionChange> materiallyChangedUpcomingSessions;
  final int totalWeeks;
  final DateTime? endDate;

  factory GoalEditChangeSummary.fromJson(Object? value) {
    final json = _strictMap(value, 'summary');
    final endDate = json['endDate'] == null
        ? null
        : _parseDateOnly(json['endDate']);
    final addedCount = _requiredNonNegativeInt(json, 'addedUpcomingCount');
    final removedCount = _requiredNonNegativeInt(json, 'removedUpcomingCount');
    final changedCount = _requiredNonNegativeInt(
      json,
      'materiallyChangedUpcomingCount',
    );
    final added = _sessionChanges(
      json,
      'addedUpcomingSessions',
      _GoalEditChangeKind.added,
      addedCount,
    );
    final removed = _sessionChanges(
      json,
      'removedUpcomingSessions',
      _GoalEditChangeKind.removed,
      removedCount,
    );
    final changed = _sessionChanges(
      json,
      'materiallyChangedUpcomingSessions',
      _GoalEditChangeKind.changed,
      changedCount,
    );
    return GoalEditChangeSummary(
      preservedCount: _requiredNonNegativeInt(json, 'preservedCount'),
      addedUpcomingCount: addedCount,
      removedUpcomingCount: removedCount,
      materiallyChangedUpcomingCount: changedCount,
      addedUpcomingSessions: added,
      removedUpcomingSessions: removed,
      materiallyChangedUpcomingSessions: changed,
      totalWeeks: _requiredPositiveInt(json, 'totalWeeks'),
      endDate: endDate,
    );
  }
}

List<GoalEditSessionChange> _sessionChanges(
  Map<String, dynamic> json,
  String key,
  _GoalEditChangeKind kind,
  int expectedCount,
) {
  if (!json.containsKey(key)) return const [];
  final raw = json[key];
  if (raw is! List) throw FormatException('Invalid $key.');
  final changes = raw
      .map((item) => GoalEditSessionChange._fromJson(item, kind))
      .toList(growable: false);
  if (changes.length != expectedCount) {
    throw FormatException('Invalid $key count.');
  }
  for (var index = 1; index < changes.length; index++) {
    if (changes[index].localDate.isBefore(changes[index - 1].localDate)) {
      throw FormatException('Invalid $key ordering.');
    }
  }
  return changes;
}

class GoalEditProposal {
  const GoalEditProposal({
    required this.id,
    required this.sourcePlanVersionId,
    required this.expiresAt,
    required this.currentGoal,
    required this.proposedGoal,
    required this.candidatePlan,
    required this.summary,
    required this.warnings,
    required this.suggestedTargetTime,
  });

  final String id;
  final String sourcePlanVersionId;
  final DateTime expiresAt;
  final GoalEditGoal currentGoal;
  final GoalEditGoal proposedGoal;
  final TrainingPlan candidatePlan;
  final GoalEditChangeSummary summary;
  final List<GoalEditWarning> warnings;
  final Duration? suggestedTargetTime;

  factory GoalEditProposal.fromJson(Object? value) {
    final json = _strictMap(value, 'proposal');
    final id = _requiredString(json, 'proposalId');
    final sourceId = _requiredString(json, 'sourcePlanVersionId');
    final expiresAt = DateTime.tryParse(_requiredString(json, 'expiresAt'));
    final planJson = _strictMap(json['candidatePlan'], 'candidatePlan');
    final plan = TrainingPlan.fromJson(planJson);
    final rawSessions = planJson['sessions'];
    final rawWarnings = json['warnings'];
    if (expiresAt == null ||
        plan == null ||
        rawSessions is! List ||
        plan.sessions.length != rawSessions.length ||
        rawWarnings is! List) {
      throw const FormatException('Invalid goal edit proposal.');
    }
    final suggestedSeconds = json['suggestedTargetTimeSeconds'];
    if (suggestedSeconds != null &&
        (suggestedSeconds is! int || suggestedSeconds <= 0)) {
      throw const FormatException('Invalid suggested target time.');
    }
    return GoalEditProposal(
      id: id,
      sourcePlanVersionId: sourceId,
      expiresAt: expiresAt,
      currentGoal: GoalEditGoal.fromJson(json['currentGoal']),
      proposedGoal: GoalEditGoal.fromJson(json['proposedGoal']),
      candidatePlan: plan,
      summary: GoalEditChangeSummary.fromJson(json['summary']),
      warnings: rawWarnings.map(GoalEditWarning.parse).toList(growable: false),
      suggestedTargetTime: suggestedSeconds == null
          ? null
          : Duration(seconds: suggestedSeconds),
    );
  }
}

class GoalEditAcceptance {
  const GoalEditAcceptance({
    required this.versionId,
    required this.plan,
    required this.profile,
    required this.acceptedRaceTarget,
  });

  final String versionId;
  final TrainingPlan plan;
  final RunnerProfile profile;
  final AcceptedRaceTarget acceptedRaceTarget;

  factory GoalEditAcceptance.fromJson(Object? value) {
    final json = _strictMap(value, 'acceptance');
    final versionId = _requiredString(json, 'versionId');
    final planJson = _strictMap(json['plan'], 'plan');
    final plan = TrainingPlan.fromJson(planJson);
    final rawSessions = planJson['sessions'];
    final profileJson = _strictMap(json['profile'], 'profile');
    final profile = RunnerProfile.fromJson(profileJson);
    final acceptedTarget = AcceptedRaceTarget.fromJson(
      _strictMap(profileJson['acceptedRaceTarget'], 'acceptedRaceTarget'),
    );
    if (plan == null ||
        plan.id != versionId ||
        rawSessions is! List ||
        plan.sessions.length != rawSessions.length ||
        profile == null) {
      throw const FormatException('Invalid accepted goal edit response.');
    }
    return GoalEditAcceptance(
      versionId: versionId,
      plan: plan,
      profile: profile,
      acceptedRaceTarget: acceptedTarget,
    );
  }
}

String _dateOnly(DateTime? value) {
  if (value == null) throw const FormatException('Missing date.');
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime _parseDateOnly(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid date.');
  }
  final parts = value.split('-').map(int.parse).toList(growable: false);
  final date = DateTime(parts[0], parts[1], parts[2]);
  if (_dateOnly(date) != value) throw const FormatException('Invalid date.');
  return date;
}

Map<String, dynamic> _strictMap(Object? value, String name) {
  if (value is! Map) throw FormatException('Invalid $name.');
  return value.map((key, item) => MapEntry('$key', item));
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) throw FormatException('Invalid $key.');
  return value;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key.');
  return value;
}

SessionType? _nullableSessionType(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) throw FormatException('Missing $key.');
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key.');
  for (final type in SessionType.values) {
    if (type.name == value) return type;
  }
  throw FormatException('Invalid $key.');
}

int? _nullableNonNegativeInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) throw FormatException('Missing $key.');
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value < 0) throw FormatException('Invalid $key.');
  return value;
}

double? _nullableNonNegativeDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) throw FormatException('Missing $key.');
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid $key.');
  }
  return value.toDouble();
}
