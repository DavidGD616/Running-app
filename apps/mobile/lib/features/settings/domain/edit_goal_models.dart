import '../../profile/domain/models/runner_profile.dart';
import '../../training_plan/domain/models/session_type.dart';
import '../../training_plan/domain/models/training_plan.dart';

class EditGoalDraft {
  const EditGoalDraft({
    required this.originalGoal,
    required this.race,
    required this.hasRaceDate,
    required this.raceDate,
    this.changes = const {},
    this.fitnessResult,
    this.assessment,
  });

  factory EditGoalDraft.fromProfile({required RunnerProfile profile}) {
    final originalGoal = GoalEditGoal.fromProfile(profile);
    return EditGoalDraft(
      originalGoal: originalGoal,
      race: originalGoal.race,
      hasRaceDate: originalGoal.hasRaceDate,
      raceDate: originalGoal.raceDate,
    );
  }

  final GoalEditGoal originalGoal;
  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
  final Set<EditGoalChange> changes;
  final EditGoalFitnessResult? fitnessResult;
  final EditGoalAssessment? assessment;

  bool get isChangeSelected => changes.isNotEmpty;

  EditGoalDraft copyWith({
    GoalEditGoal? originalGoal,
    RunnerGoalRace? race,
    bool? hasRaceDate,
    DateTime? raceDate,
    bool clearRaceDate = false,
    Set<EditGoalChange>? changes,
    EditGoalFitnessResult? fitnessResult,
    bool clearFitnessResult = false,
    EditGoalAssessment? assessment,
    bool clearAssessment = false,
  }) {
    final nextHasRaceDate = hasRaceDate ?? this.hasRaceDate;
    return EditGoalDraft(
      originalGoal: originalGoal ?? this.originalGoal,
      race: race ?? this.race,
      hasRaceDate: nextHasRaceDate,
      raceDate: nextHasRaceDate
          ? (clearRaceDate ? null : raceDate ?? this.raceDate)
          : null,
      changes: changes ?? this.changes,
      fitnessResult: clearFitnessResult
          ? null
          : fitnessResult ?? this.fitnessResult,
      assessment: clearAssessment ? null : assessment ?? this.assessment,
    );
  }

  EditGoalDraft toggleChange(EditGoalChange change) {
    final nextChanges = {...changes};
    final selected = nextChanges.add(change);
    if (!selected) nextChanges.remove(change);

    return copyWith(
      changes: nextChanges,
      race: !selected && change == EditGoalChange.distance
          ? originalGoal.race
          : race,
      hasRaceDate: !selected && change == EditGoalChange.raceDate
          ? originalGoal.hasRaceDate
          : hasRaceDate,
      raceDate: !selected && change == EditGoalChange.raceDate
          ? originalGoal.raceDate
          : raceDate,
      clearRaceDate:
          !selected &&
          change == EditGoalChange.raceDate &&
          !originalGoal.hasRaceDate,
      clearFitnessResult: true,
      clearAssessment: true,
    );
  }

  EditGoalDraft withOriginalGoal(GoalEditGoal value) {
    return copyWith(originalGoal: value);
  }

  GoalEditGoal get effectiveGoal {
    final changesDistance = changes.contains(EditGoalChange.distance);
    final changesRaceDate = changes.contains(EditGoalChange.raceDate);
    return GoalEditGoal(
      race: changesDistance ? race : originalGoal.race,
      hasRaceDate: changesRaceDate ? hasRaceDate : originalGoal.hasRaceDate,
      raceDate: changesRaceDate ? raceDate : originalGoal.raceDate,
    );
  }

  Map<String, dynamic> previewPayload({
    required String sourcePlanVersionId,
    required DateTime localDate,
    required String locale,
  }) {
    final goal = effectiveGoal;
    return {
      'action': 'preview',
      'sourcePlanVersionId': sourcePlanVersionId,
      'race': goal.race.key,
      'hasRaceDate': goal.hasRaceDate,
      'raceDate': goal.hasRaceDate ? _dateOnly(goal.raceDate) : null,
      if (fitnessResult != null) 'fitnessResult': fitnessResult!.toJson(),
      'localDate': _dateOnly(localDate),
      'locale': locale == 'es' ? 'es' : 'en',
    };
  }

  Map<String, dynamic> toJson() => {
    'originalGoal': originalGoal.toJson(),
    'race': race.key,
    'hasRaceDate': hasRaceDate,
    'raceDate': hasRaceDate ? _dateOnly(raceDate) : null,
    'changes': changes.map((change) => change.key).toList(growable: false),
    if (fitnessResult != null) 'fitnessResult': fitnessResult!.toJson(),
    if (assessment != null) 'assessment': assessment!.toJson(),
  };

  factory EditGoalDraft.fromJson(Map<String, dynamic> json) {
    final race = RunnerGoalRace.fromKey(_requiredString(json, 'race'));
    final hasRaceDate = json['hasRaceDate'];
    if (race == null || race == RunnerGoalRace.other || hasRaceDate is! bool) {
      throw const FormatException('Invalid Edit Goal draft.');
    }
    final rawDate = json['raceDate'];
    final raceDate = rawDate == null ? null : _parseDateOnly(rawDate);
    if ((hasRaceDate && raceDate == null) ||
        (!hasRaceDate && rawDate != null)) {
      throw const FormatException('Invalid Edit Goal draft date.');
    }
    final rawChanges = json['changes'];
    if (rawChanges is! List) {
      throw const FormatException('Invalid Edit Goal changes.');
    }
    final changes = rawChanges.map(EditGoalChange.parse).toSet();
    final rawFitness = json['fitnessResult'];
    final rawAssessment = json['assessment'];
    final currentGoal = GoalEditGoal(
      race: race,
      hasRaceDate: hasRaceDate,
      raceDate: raceDate,
    );
    final rawOriginalGoal = json['originalGoal'];
    return EditGoalDraft(
      originalGoal: rawOriginalGoal == null
          ? currentGoal
          : GoalEditGoal.fromJson(rawOriginalGoal),
      race: race,
      hasRaceDate: hasRaceDate,
      raceDate: raceDate,
      changes: changes,
      fitnessResult: rawFitness == null
          ? null
          : EditGoalFitnessResult.fromJson(
              _strictMap(rawFitness, 'fitness result'),
            ),
      assessment: rawAssessment == null
          ? null
          : EditGoalAssessment.fromJson(
              _strictMap(rawAssessment, 'assessment'),
            ),
    );
  }
}

enum EditGoalChange {
  distance('distance'),
  raceDate('race_date');

  const EditGoalChange(this.key);
  final String key;

  static EditGoalChange parse(Object? value) {
    for (final change in values) {
      if (change.key == value) return change;
    }
    throw const FormatException('Invalid Edit Goal change.');
  }
}

enum EditGoalFitnessSource {
  manual('manual'),
  assessment('assessment');

  const EditGoalFitnessSource(this.key);
  final String key;

  static EditGoalFitnessSource parse(Object? value) {
    for (final source in values) {
      if (source.key == value) return source;
    }
    throw const FormatException('Invalid Edit Goal fitness source.');
  }
}

class EditGoalFitnessResult {
  const EditGoalFitnessResult({
    required this.source,
    required this.distanceKm,
    required this.elapsed,
    required this.recordedOn,
    required this.hardEffort,
  });

  final EditGoalFitnessSource source;
  final double distanceKm;
  final Duration elapsed;
  final DateTime recordedOn;
  final bool hardEffort;

  Map<String, dynamic> toJson() => {
    'source': source.key,
    'distanceKm': distanceKm,
    'elapsedSeconds': elapsed.inSeconds,
    'recordedOn': _dateOnly(recordedOn),
    'hardEffort': hardEffort,
  };

  factory EditGoalFitnessResult.fromJson(Map<String, dynamic> json) {
    final distanceKm = json['distanceKm'];
    final elapsedSeconds = json['elapsedSeconds'];
    final hardEffort = json['hardEffort'];
    if (distanceKm is! num ||
        !distanceKm.isFinite ||
        distanceKm <= 0 ||
        elapsedSeconds is! int ||
        elapsedSeconds <= 0 ||
        hardEffort is! bool) {
      throw const FormatException('Invalid Edit Goal fitness result.');
    }
    return EditGoalFitnessResult(
      source: EditGoalFitnessSource.parse(json['source']),
      distanceKm: distanceKm.toDouble(),
      elapsed: Duration(seconds: elapsedSeconds),
      recordedOn: _parseDateOnly(json['recordedOn']),
      hardEffort: hardEffort,
    );
  }
}

class EditGoalAssessment {
  const EditGoalAssessment({
    required this.id,
    required this.kind,
    required this.scheduledFor,
    required this.safeDates,
  });

  final String id;
  final String kind;
  final DateTime scheduledFor;
  final List<DateTime> safeDates;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'scheduledFor': _dateOnly(scheduledFor),
    'safeDates': safeDates.map(_dateOnly).toList(growable: false),
  };

  factory EditGoalAssessment.fromJson(Map<String, dynamic> json) {
    final rawSafeDates = json['safeDates'];
    if (rawSafeDates is! List) {
      throw const FormatException('Invalid safe dates.');
    }
    return EditGoalAssessment(
      id: _requiredString(json, 'id'),
      kind: _requiredString(json, 'kind'),
      scheduledFor: _parseDateOnly(json['scheduledFor']),
      safeDates: rawSafeDates.map(_parseDateOnly).toList(growable: false),
    );
  }
}

enum GoalEditWarning {
  shortNotice('short_notice'),
  raceWeek('race_week'),
  readinessGap('readiness_gap'),
  limitedEvidence('limited_evidence'),
  noFixedDate('no_fixed_date');

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
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;

  factory GoalEditGoal.fromProfile(RunnerProfile profile) {
    return GoalEditGoal(
      race: profile.goal.race,
      hasRaceDate: profile.goal.hasRaceDate,
      raceDate: profile.goal.hasRaceDate ? profile.goal.raceDate : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'race': race.key,
    'hasRaceDate': hasRaceDate,
    'raceDate': hasRaceDate ? _dateOnly(raceDate) : null,
  };

  factory GoalEditGoal.fromJson(Object? value) {
    final json = _strictMap(value, 'goal');
    final race = RunnerGoalRace.fromKey(_requiredString(json, 'race'));
    final hasRaceDate = json['hasRaceDate'];
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
    );
  }
}

class GoalEditRaceEstimate {
  const GoalEditRaceEstimate({
    required this.centerTime,
    required this.fasterTime,
    required this.slowerTime,
    required this.confidence,
    required this.evidence,
  });

  final Duration centerTime;
  final Duration fasterTime;
  final Duration slowerTime;
  final String confidence;
  final List<GoalEditEstimateEvidence> evidence;

  factory GoalEditRaceEstimate.fromJson(Object? value) {
    final json = _strictMap(value, 'race estimate');
    final confidence = _requiredString(json, 'confidence');
    if (!const {'high', 'medium', 'limited'}.contains(confidence)) {
      throw const FormatException('Invalid race estimate confidence.');
    }
    final rawEvidence = json['evidence'];
    if (rawEvidence is! List) {
      throw const FormatException('Invalid race evidence.');
    }
    final center = _requiredPositiveInt(json, 'centerTimeSeconds');
    final faster = _requiredPositiveInt(json, 'fasterTimeSeconds');
    final slower = _requiredPositiveInt(json, 'slowerTimeSeconds');
    if (faster >= center || slower <= center) {
      throw const FormatException('Invalid race estimate range.');
    }
    return GoalEditRaceEstimate(
      centerTime: Duration(seconds: center),
      fasterTime: Duration(seconds: faster),
      slowerTime: Duration(seconds: slower),
      confidence: confidence,
      evidence: rawEvidence
          .map((item) => GoalEditEstimateEvidence.fromJson(item))
          .toList(growable: false),
    );
  }
}

enum GoalEditEvidenceReason {
  manualRecentHardResult('manual_recent_hard_result'),
  completedAssessment('completed_assessment');

  const GoalEditEvidenceReason(this.key);
  final String key;

  static GoalEditEvidenceReason parse(Object? value) {
    for (final reason in values) {
      if (reason.key == value) return reason;
    }
    throw const FormatException('Invalid race evidence reason.');
  }
}

class GoalEditEstimateEvidence {
  const GoalEditEstimateEvidence({
    required this.source,
    required this.recordedOn,
    required this.reason,
  });

  final String source;
  final DateTime? recordedOn;
  final GoalEditEvidenceReason reason;

  factory GoalEditEstimateEvidence.fromJson(Object? value) {
    final json = _strictMap(value, 'race estimate evidence');
    final source = _requiredString(json, 'source');
    if (!const {'strava', 'manual', 'assessment'}.contains(source)) {
      throw const FormatException('Invalid race evidence source.');
    }
    final rawDate = json['recordedOn'];
    return GoalEditEstimateEvidence(
      source: source,
      recordedOn: rawDate == null ? null : _parseDateOnly(rawDate),
      reason: GoalEditEvidenceReason.parse(json['reason']),
    );
  }
}

class GoalEditFitnessCheck {
  const GoalEditFitnessCheck({
    required this.suggestedActivities,
    required this.benchmarkKind,
    required this.safeDates,
  });

  final List<GoalEditSuggestedActivity> suggestedActivities;
  final String benchmarkKind;
  final List<DateTime> safeDates;

  factory GoalEditFitnessCheck.fromJson(Object? value) {
    final json = _strictMap(value, 'fitness check');
    final rawActivities = json['suggestedActivities'];
    final benchmark = _strictMap(json['benchmark'], 'fitness benchmark');
    final rawSafeDates = benchmark['safeDates'];
    if (rawActivities is! List || rawSafeDates is! List) {
      throw const FormatException('Invalid fitness check.');
    }
    final kind = _requiredString(benchmark, 'kind');
    if (!const {'one_km_run', 'five_k_run'}.contains(kind)) {
      throw const FormatException('Invalid fitness benchmark kind.');
    }
    return GoalEditFitnessCheck(
      suggestedActivities: rawActivities
          .map((item) => GoalEditSuggestedActivity.fromJson(item))
          .toList(growable: false),
      benchmarkKind: kind,
      safeDates: rawSafeDates.map(_parseDateOnly).toList(growable: false),
    );
  }
}

class GoalEditSuggestedActivity {
  const GoalEditSuggestedActivity({
    required this.recordedOn,
    required this.distanceKm,
    required this.elapsed,
  });

  final DateTime recordedOn;
  final double distanceKm;
  final Duration elapsed;

  factory GoalEditSuggestedActivity.fromJson(Object? value) {
    final json = _strictMap(value, 'suggested activity');
    final distance = json['distanceKm'];
    final seconds = json['elapsedSeconds'];
    if (distance is! num ||
        !distance.isFinite ||
        distance <= 0 ||
        seconds is! int ||
        seconds <= 0) {
      throw const FormatException('Invalid suggested activity.');
    }
    return GoalEditSuggestedActivity(
      recordedOn: _parseDateOnly(json['recordedOn']),
      distanceKm: distance.toDouble(),
      elapsed: Duration(seconds: seconds),
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
    required this.raceEstimate,
  });

  final String id;
  final String sourcePlanVersionId;
  final DateTime expiresAt;
  final GoalEditGoal currentGoal;
  final GoalEditGoal proposedGoal;
  final TrainingPlan candidatePlan;
  final GoalEditChangeSummary summary;
  final List<GoalEditWarning> warnings;
  final GoalEditRaceEstimate raceEstimate;

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
    return GoalEditProposal(
      id: id,
      sourcePlanVersionId: sourceId,
      expiresAt: expiresAt,
      currentGoal: GoalEditGoal.fromJson(json['currentGoal']),
      proposedGoal: GoalEditGoal.fromJson(json['proposedGoal']),
      candidatePlan: plan,
      summary: GoalEditChangeSummary.fromJson(json['summary']),
      warnings: rawWarnings.map(GoalEditWarning.parse).toList(growable: false),
      raceEstimate: GoalEditRaceEstimate.fromJson(json['raceEstimate']),
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
