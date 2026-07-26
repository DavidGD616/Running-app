import '../../profile/domain/models/runner_profile.dart';
import '../../training_plan/domain/models/training_plan.dart';

class NewGoalGoal {
  const NewGoalGoal({
    required this.race,
    required this.hasRaceDate,
    required this.raceDate,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;

  factory NewGoalGoal.fromJson(Object? value) {
    final json = _strictMap(value, 'goal');
    final race = RunnerGoalRace.fromKey(_requiredString(json, 'race'));
    final hasRaceDate = json['hasRaceDate'];
    if (race == null || race == RunnerGoalRace.other || hasRaceDate is! bool) {
      throw const FormatException('Invalid new goal goal.');
    }

    final raceDateValue = json['raceDate'];
    final raceDate = raceDateValue == null
        ? null
        : _parseDateOnly(raceDateValue);
    if ((hasRaceDate && raceDate == null) ||
        (!hasRaceDate && raceDate != null)) {
      throw const FormatException('Invalid new goal goal date.');
    }

    return NewGoalGoal(
      race: race,
      hasRaceDate: hasRaceDate,
      raceDate: raceDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'race': race.key,
    'hasRaceDate': hasRaceDate,
    'raceDate': hasRaceDate && raceDate != null ? _dateOnly(raceDate!) : null,
  };
}

class NewGoalSchedule {
  const NewGoalSchedule({
    required this.trainingDays,
    required this.longRunDay,
    required this.weekdayTime,
    required this.weekendTime,
    required this.hardDays,
    this.preferredTimeOfDay,
  });

  final int trainingDays;
  final WeekdayChoice longRunDay;
  final TimeSlot weekdayTime;
  final TimeSlot weekendTime;
  final Set<WeekdayChoice> hardDays;
  final PreferredTimeOfDay? preferredTimeOfDay;

  factory NewGoalSchedule.fromProfile(ScheduleProfile profile) =>
      NewGoalSchedule(
        trainingDays: profile.trainingDays,
        longRunDay: profile.longRunDay,
        weekdayTime: profile.weekdayTime,
        weekendTime: profile.weekendTime,
        hardDays: profile.hardDays,
        preferredTimeOfDay: profile.preferredTimeOfDay,
      );

  factory NewGoalSchedule.fromJson(Object? value) {
    final json = _strictMap(value, 'schedule');
    final trainingDays = _requiredPositiveInt(json, 'trainingDays');
    final longRunDay = WeekdayChoice.fromKey(
      _requiredString(json, 'longRunDay'),
    );
    final weekdayTime = TimeSlot.fromKey(_requiredString(json, 'weekdayTime'));
    final weekendTime = TimeSlot.fromKey(_requiredString(json, 'weekendTime'));

    if (longRunDay == null || weekdayTime == null || weekendTime == null) {
      throw const FormatException('Invalid new goal schedule.');
    }

    final rawHardDays = json['hardDays'];
    if (rawHardDays is! List) {
      throw const FormatException('Invalid hard days.');
    }
    final hardDays = <WeekdayChoice>{};
    for (final raw in rawHardDays) {
      if (raw is! String) {
        throw const FormatException('Invalid hard day value.');
      }
      final parsed = WeekdayChoice.fromKey(raw);
      if (parsed == null) {
        throw const FormatException('Invalid hard day value.');
      }
      hardDays.add(parsed);
    }

    final rawPreferredTimeOfDay = json['preferredTimeOfDay'];
    PreferredTimeOfDay? preferredTimeOfDay;
    if (rawPreferredTimeOfDay != null) {
      preferredTimeOfDay = PreferredTimeOfDay.fromKey(
        rawPreferredTimeOfDay is String ? rawPreferredTimeOfDay : null,
      );
      if (preferredTimeOfDay == null) {
        throw const FormatException('Invalid preferred time of day.');
      }
    }

    return NewGoalSchedule(
      trainingDays: trainingDays,
      longRunDay: longRunDay,
      weekdayTime: weekdayTime,
      weekendTime: weekendTime,
      hardDays: hardDays,
      preferredTimeOfDay: preferredTimeOfDay,
    );
  }

  Map<String, dynamic> toJson() => {
    'trainingDays': trainingDays,
    'longRunDay': longRunDay.key,
    'weekdayTime': weekdayTime.key,
    'weekendTime': weekendTime.key,
    'hardDays': hardDays.map((day) => day.key).toList(growable: false)..sort(),
    if (preferredTimeOfDay != null)
      'preferredTimeOfDay': preferredTimeOfDay!.key,
  };

  Map<String, dynamic> requestPayload({DateTime? planStartDate}) => {
    ...toJson(),
    if (planStartDate != null) 'planStartDate': _dateOnly(planStartDate),
  };
}

class NewGoalHealthSnapshot {
  const NewGoalHealthSnapshot({
    required this.painLevel,
    required this.injuryHistory,
    required this.hasHealthConditions,
    this.recordedOn,
  });

  final PainLevelChoice painLevel;
  final InjuryHistoryChoice injuryHistory;
  final BinaryChoice hasHealthConditions;
  final DateTime? recordedOn;

  factory NewGoalHealthSnapshot.fromJson(Object? value) {
    final json = _strictMap(value, 'health');
    final painLevel = PainLevelChoice.fromKey(
      _requiredString(json, 'painLevel'),
    );
    final injuryHistory = InjuryHistoryChoice.fromKey(
      _requiredString(json, 'injuryHistory'),
    );
    final hasHealthConditions = BinaryChoice.fromKey(
      _requiredString(json, 'hasHealthConditions'),
    );
    if (painLevel == null ||
        injuryHistory == null ||
        hasHealthConditions == null) {
      throw const FormatException('Invalid new goal health snapshot.');
    }

    final rawRecordedOn = json['recordedOn'];
    final recordedOn = rawRecordedOn == null
        ? null
        : _parseDateOnly(rawRecordedOn);

    return NewGoalHealthSnapshot(
      painLevel: painLevel,
      injuryHistory: injuryHistory,
      hasHealthConditions: hasHealthConditions,
      recordedOn: recordedOn,
    );
  }

  Map<String, dynamic> toJson() => {
    'painLevel': painLevel.key,
    'injuryHistory': injuryHistory.key,
    'hasHealthConditions': hasHealthConditions.key,
    if (recordedOn != null) 'recordedOn': _dateOnly(recordedOn!),
  };
}

enum NewGoalFitnessSource {
  manual('manual'),
  assessment('assessment');

  const NewGoalFitnessSource(this.key);
  final String key;

  static NewGoalFitnessSource? parse(Object? value) {
    for (final source in values) {
      if (source.key == value) return source;
    }
    return null;
  }
}

class NewGoalFitnessResult {
  const NewGoalFitnessResult({
    required this.source,
    required this.distanceKm,
    required this.elapsed,
    required this.recordedOn,
    required this.hardEffort,
  });

  final NewGoalFitnessSource source;
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

  factory NewGoalFitnessResult.fromJson(Object? value) {
    final json = _strictMap(value, 'fitnessResult');
    final source = NewGoalFitnessSource.parse(json['source']);
    final distance = json['distanceKm'];
    final elapsedSeconds = json['elapsedSeconds'];
    final hardEffort = json['hardEffort'];
    final recordedOn = json['recordedOn'];

    if (source == null ||
        distance is! num ||
        !distance.isFinite ||
        distance <= 0 ||
        elapsedSeconds is! int ||
        elapsedSeconds <= 0 ||
        hardEffort is! bool ||
        recordedOn is! String) {
      throw const FormatException('Invalid new goal fitness result.');
    }

    return NewGoalFitnessResult(
      source: source,
      distanceKm: distance.toDouble(),
      elapsed: Duration(seconds: elapsedSeconds),
      recordedOn: _parseDateOnly(recordedOn),
      hardEffort: hardEffort,
    );
  }
}

class NewGoalAssessment {
  const NewGoalAssessment({
    required this.id,
    required this.kind,
    required this.scheduledFor,
    required this.safeDates,
  });

  final String id;
  final String kind;
  final DateTime scheduledFor;
  final List<DateTime> safeDates;

  factory NewGoalAssessment.fromJson(Object? value) {
    final json = _strictMap(value, 'assessment');
    final id = _requiredString(json, 'id');
    final kind = _requiredString(json, 'kind');
    final scheduledFor = _parseDateOnly(_requiredString(json, 'scheduledFor'));
    final rawSafeDates = json['safeDates'];
    if (rawSafeDates is! List) {
      throw const FormatException('Invalid safe dates.');
    }

    final safeDates = <DateTime>[];
    for (final raw in rawSafeDates) {
      safeDates.add(_parseDateOnly(raw));
    }

    return NewGoalAssessment(
      id: id,
      kind: kind,
      scheduledFor: scheduledFor,
      safeDates: safeDates,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'scheduledFor': _dateOnly(scheduledFor),
    'safeDates': safeDates.map(_dateOnly).toList(growable: false),
  };
}

class NewGoalDraft {
  const NewGoalDraft({
    required this.race,
    required this.hasRaceDate,
    this.raceDate,
    this.planStartDate,
    required this.schedule,
    required this.planPreference,
    required this.healthChanged,
    this.health,
    this.fitnessResult,
    this.assessment,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
  final DateTime? planStartDate;
  final NewGoalSchedule schedule;
  final PlanPreferenceChoice planPreference;
  final bool healthChanged;
  final NewGoalHealthSnapshot? health;
  final NewGoalFitnessResult? fitnessResult;
  final NewGoalAssessment? assessment;

  NewGoalGoal get effectiveGoal =>
      NewGoalGoal(race: race, hasRaceDate: hasRaceDate, raceDate: raceDate);

  factory NewGoalDraft.fromProfile({required RunnerProfile profile}) {
    return NewGoalDraft(
      race: profile.goal.race,
      hasRaceDate: profile.goal.hasRaceDate,
      raceDate: profile.goal.hasRaceDate ? profile.goal.raceDate : null,
      planStartDate: profile.schedule.planStartDate,
      schedule: NewGoalSchedule.fromProfile(profile.schedule),
      planPreference: profile.trainingPreferences.planPreference,
      healthChanged: false,
      health: NewGoalHealthSnapshot(
        painLevel: profile.health.painLevel,
        injuryHistory: profile.health.injuryHistory,
        hasHealthConditions: profile.health.hasHealthConditions,
        recordedOn: null,
      ),
    );
  }

  factory NewGoalDraft.fromJson(Map<String, dynamic> json) {
    final race = RunnerGoalRace.fromKey(_requiredString(json, 'race'));
    final hasRaceDate = json['hasRaceDate'];
    if (race == null || race == RunnerGoalRace.other || hasRaceDate is! bool) {
      throw const FormatException('Invalid new goal draft.');
    }

    final rawRaceDate = json['raceDate'];
    final raceDate = rawRaceDate == null
        ? null
        : _parseDateOnly(_requiredString(json, 'raceDate'));
    if ((hasRaceDate && raceDate == null) ||
        (!hasRaceDate && rawRaceDate != null)) {
      throw const FormatException('Invalid new goal draft race date.');
    }

    final schedule = NewGoalSchedule.fromJson(
      _requiredMap(json['schedule'], 'schedule'),
    );
    final trainingPreferences = _requiredMap(
      json['trainingPreferences'],
      'trainingPreferences',
    );
    final planPreference = PlanPreferenceChoice.fromKey(
      _requiredString(trainingPreferences, 'planPreference'),
    );
    if (planPreference == null) {
      throw const FormatException('Invalid plan preference.');
    }

    final rawHealthChanged = json['healthChanged'];
    final healthChanged = rawHealthChanged is bool
        ? rawHealthChanged
        : throw const FormatException('Invalid health-changed flag.');

    final rawHealth = json['health'];
    final rawFitness = json['fitnessResult'];
    final rawAssessment = json['assessment'];

    return NewGoalDraft(
      race: race,
      hasRaceDate: hasRaceDate,
      raceDate: raceDate,
      planStartDate: _optionalDate(json['planStartDate']),
      schedule: schedule,
      planPreference: planPreference,
      healthChanged: healthChanged,
      health: rawHealth == null
          ? null
          : NewGoalHealthSnapshot.fromJson(rawHealth),
      fitnessResult: rawFitness == null
          ? null
          : NewGoalFitnessResult.fromJson(rawFitness),
      assessment: rawAssessment == null
          ? null
          : NewGoalAssessment.fromJson(rawAssessment),
    );
  }

  NewGoalDraft copyWith({
    RunnerGoalRace? race,
    bool? hasRaceDate,
    DateTime? raceDate,
    bool clearRaceDate = false,
    DateTime? planStartDate,
    bool clearPlanStartDate = false,
    NewGoalSchedule? schedule,
    PlanPreferenceChoice? planPreference,
    bool? healthChanged,
    NewGoalHealthSnapshot? health,
    bool clearHealth = false,
    NewGoalFitnessResult? fitnessResult,
    bool clearFitnessResult = false,
    NewGoalAssessment? assessment,
    bool clearAssessment = false,
  }) {
    final nextHasRaceDate = hasRaceDate ?? this.hasRaceDate;
    final nextRaceDate = nextHasRaceDate
        ? (clearRaceDate ? null : (raceDate ?? this.raceDate))
        : null;
    if (nextHasRaceDate && nextRaceDate == null) {
      throw const FormatException('Missing race date.');
    }

    return NewGoalDraft(
      race: race ?? this.race,
      hasRaceDate: nextHasRaceDate,
      raceDate: nextRaceDate,
      planStartDate: clearPlanStartDate
          ? null
          : (planStartDate ?? this.planStartDate),
      schedule: schedule ?? this.schedule,
      planPreference: planPreference ?? this.planPreference,
      healthChanged: healthChanged ?? this.healthChanged,
      health: clearHealth ? null : (health ?? this.health),
      fitnessResult: clearFitnessResult
          ? null
          : (fitnessResult ?? this.fitnessResult),
      assessment: clearAssessment ? null : (assessment ?? this.assessment),
    );
  }

  NewGoalDraft withHealthChanged(
    bool changed, {
    NewGoalHealthSnapshot? snapshot,
  }) {
    if (!changed) {
      return copyWith(healthChanged: false, clearHealth: true, health: null);
    }

    if (snapshot == null) {
      return copyWith(healthChanged: true, clearHealth: false);
    }
    return copyWith(healthChanged: true, health: snapshot, clearHealth: false);
  }

  Map<String, dynamic> recommendationPayload({
    required String sourcePlanVersionId,
    required String locale,
    required String action,
    required DateTime localDate,
  }) {
    if (action != 'recommend' && action != 'preview') {
      throw ArgumentError.value(
        action,
        'action',
        'must be "recommend" or "preview"',
      );
    }
    if (planStartDate == null) {
      throw const FormatException(
        'planStartDate is required for plan recommendations.',
      );
    }
    return {
      'action': action,
      'sourcePlanVersionId': sourcePlanVersionId,
      'race': race.key,
      'hasRaceDate': hasRaceDate,
      'raceDate': hasRaceDate && raceDate != null ? _dateOnly(raceDate!) : null,
      'planStartDate': _dateOnly(planStartDate!),
      'schedule': schedule.requestPayload(planStartDate: planStartDate),
      'trainingPreferences': {'planPreference': planPreference.key},
      'healthChanged': healthChanged,
      if (healthChanged && health != null) 'health': _healthForPayload(health!),
      if (fitnessResult != null) 'fitnessResult': fitnessResult!.toJson(),
      'locale': locale == 'es' ? 'es' : 'en',
      'localDate': _dateOnly(localDate),
    };
  }

  Map<String, dynamic> toJson() => {
    'race': race.key,
    'hasRaceDate': hasRaceDate,
    'raceDate': hasRaceDate && raceDate != null ? _dateOnly(raceDate!) : null,
    'planStartDate': () {
      final safePlanStartDate = planStartDate;
      return safePlanStartDate == null ? null : _dateOnly(safePlanStartDate);
    }(),
    'schedule': schedule.toJson(),
    'trainingPreferences': {'planPreference': planPreference.key},
    'healthChanged': healthChanged,
    if (health != null) 'health': health!.toJson(),
    if (fitnessResult != null) 'fitnessResult': fitnessResult!.toJson(),
    if (assessment != null) 'assessment': assessment!.toJson(),
  };
}

class NewGoalFitnessCheck {
  const NewGoalFitnessCheck({
    required this.suggestedActivities,
    required this.benchmarkKind,
    required this.safeDates,
  });

  final List<NewGoalFitnessSuggestedActivity> suggestedActivities;
  final String benchmarkKind;
  final List<DateTime> safeDates;

  factory NewGoalFitnessCheck.fromJson(Object? value) {
    final json = _strictMap(value, 'fitnessCheck');
    final rawActivities = json['suggestedActivities'];
    final benchmark = _strictMap(json['benchmark'], 'benchmark');
    if (rawActivities is! List) {
      throw const FormatException('Invalid fitness check.');
    }

    final suggestedActivities = <NewGoalFitnessSuggestedActivity>[];
    for (final activity in rawActivities) {
      suggestedActivities.add(
        NewGoalFitnessSuggestedActivity.fromJson(activity),
      );
    }

    final rawSafeDates = _requiredList(benchmark['safeDates'], 'safeDates');
    final safeDates = <DateTime>[];
    for (final raw in rawSafeDates) {
      safeDates.add(_parseDateOnly(raw));
    }

    final benchmarkKind = _requiredString(benchmark, 'kind');

    return NewGoalFitnessCheck(
      suggestedActivities: suggestedActivities,
      benchmarkKind: benchmarkKind,
      safeDates: safeDates,
    );
  }
}

class NewGoalRecommendationEstimate {
  const NewGoalRecommendationEstimate({
    this.source,
    required this.centerTime,
    required this.fasterTime,
    required this.slowerTime,
    required this.confidence,
  });

  final String? source;
  final Duration centerTime;
  final Duration fasterTime;
  final Duration slowerTime;
  final String confidence;

  factory NewGoalRecommendationEstimate.fromJson(Object? value) {
    final json = _strictMap(value, 'recommendation estimate');
    final source = _estimateSource(json);
    final center = _requiredPositiveInt(json, 'centerTimeSeconds');
    final faster = _requiredPositiveInt(json, 'fasterTimeSeconds');
    final slower = _requiredPositiveInt(json, 'slowerTimeSeconds');
    final confidence = _requiredString(json, 'confidence');
    if (!const {'high', 'medium', 'limited'}.contains(confidence)) {
      throw const FormatException(
        'Invalid recommendation estimate confidence.',
      );
    }
    return NewGoalRecommendationEstimate(
      source: source,
      centerTime: Duration(seconds: center),
      fasterTime: Duration(seconds: faster),
      slowerTime: Duration(seconds: slower),
      confidence: confidence,
    );
  }
}

class NewGoalRecommendation {
  const NewGoalRecommendation({
    required this.sourceGoal,
    required this.proposedGoal,
    required this.timelineMode,
    required this.timelineDate,
    required this.timelineEndDate,
    required this.timelineWeeks,
    required this.timelineHasRaceDate,
    this.timelineRaceDate,
    this.daysToRace,
    this.estimate,
  });

  final NewGoalGoal sourceGoal;
  final NewGoalGoal proposedGoal;
  final String timelineMode;
  final DateTime timelineDate;
  final int timelineWeeks;
  final DateTime timelineEndDate;
  final bool timelineHasRaceDate;
  final DateTime? timelineRaceDate;
  final int? daysToRace;
  final NewGoalRecommendationEstimate? estimate;

  factory NewGoalRecommendation.fromJson(Object? value) {
    final json = _strictMap(value, 'recommendation');
    final sourceGoal = NewGoalGoal.fromJson(
      _requiredMap(json['sourceGoal'] ?? json['currentGoal'], 'sourceGoal'),
    );
    final proposedGoal = NewGoalGoal.fromJson(
      _requiredMap(json['proposedGoal'], 'proposedGoal'),
    );

    final timeline = _extractTimeline(json);
    final timelineMode = _requiredString(timeline, 'mode');
    final timelineStartDate = _extractDate(timeline, 'startDate', 'date');
    final timelineEndDate = _extractDate(timeline, 'endDate');
    final timelineWeeks = _requiredPositiveInt(timeline, 'weeks');
    final timelineHasRaceDate = _requiredBool(timeline, 'hasRaceDate');
    final timelineRaceDate = timelineHasRaceDate
        ? _requiredDate(timeline, 'raceDate')
        : _optionalDate(_optionalValue(timeline, 'raceDate'));
    if (timelineHasRaceDate && timelineRaceDate == null) {
      throw const FormatException('Invalid timeline race date.');
    }
    final daysToRace = _optionalPositiveInt(timeline, 'daysToRace');

    if (timelineStartDate == null || timelineEndDate == null) {
      throw const FormatException('Invalid timeline dates.');
    }

    NewGoalRecommendationEstimate? estimate;
    final rawEstimate =
        json['estimate'] ??
        json['raceEstimate'] ??
        json['evidenceBasedEstimate'];
    if (rawEstimate != null) {
      estimate = NewGoalRecommendationEstimate.fromJson(rawEstimate);
    }

    return NewGoalRecommendation(
      sourceGoal: sourceGoal,
      proposedGoal: proposedGoal,
      timelineMode: timelineMode,
      timelineDate: timelineStartDate,
      timelineEndDate: timelineEndDate,
      timelineWeeks: timelineWeeks,
      timelineHasRaceDate: timelineHasRaceDate,
      timelineRaceDate: timelineRaceDate,
      daysToRace: daysToRace,
      estimate: estimate,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourceGoal': sourceGoal.toJson(),
    'proposedGoal': proposedGoal.toJson(),
    'timeline': {
      'mode': timelineMode,
      'date': _dateOnly(timelineDate),
      'weeks': timelineWeeks,
      'startDate': _dateOnly(timelineDate),
      'endDate': _dateOnly(timelineEndDate),
      'hasRaceDate': timelineHasRaceDate,
      if (timelineRaceDate != null) 'raceDate': _dateOnly(timelineRaceDate!),
      if (daysToRace != null) 'daysToRace': daysToRace,
    },
    if (estimate != null)
      'estimate': {
        if (estimate!.source != null) 'source': estimate!.source,
        'centerTimeSeconds': estimate!.centerTime.inSeconds,
        'fasterTimeSeconds': estimate!.fasterTime.inSeconds,
        'slowerTimeSeconds': estimate!.slowerTime.inSeconds,
        'confidence': estimate!.confidence,
      },
  };
}

class NewGoalFitnessSuggestedActivity {
  const NewGoalFitnessSuggestedActivity({
    required this.recordedOn,
    required this.distanceKm,
    required this.elapsed,
  });

  final DateTime recordedOn;
  final double distanceKm;
  final Duration elapsed;

  factory NewGoalFitnessSuggestedActivity.fromJson(Object? value) {
    final json = _strictMap(value, 'suggestedActivity');
    final distance = json['distanceKm'];
    final elapsedSeconds = json['elapsedSeconds'];
    final recordedOn = json['recordedOn'];

    if (recordedOn is! String ||
        distance is! num ||
        !distance.isFinite ||
        distance <= 0 ||
        elapsedSeconds is! int ||
        elapsedSeconds <= 0) {
      throw const FormatException('Invalid suggested activity.');
    }

    return NewGoalFitnessSuggestedActivity(
      recordedOn: _parseDateOnly(recordedOn),
      distanceKm: distance.toDouble(),
      elapsed: Duration(seconds: elapsedSeconds),
    );
  }
}

class NewGoalProposal {
  const NewGoalProposal({
    required this.id,
    required this.sourcePlanVersionId,
    required this.expiresAt,
    required this.sourceGoal,
    required this.currentGoal,
    required this.proposedGoal,
    required this.candidatePlan,
    required this.summary,
    this.warnings = const [],
    this.recommendation,
    this.raceEstimate,
  });

  final String id;
  final String sourcePlanVersionId;
  final DateTime expiresAt;
  final NewGoalGoal currentGoal;
  final NewGoalGoal proposedGoal;
  final NewGoalGoal sourceGoal;
  final TrainingPlan candidatePlan;
  final Map<String, dynamic> summary;
  final List<String> warnings;
  final NewGoalRecommendation? recommendation;
  final NewGoalRecommendationEstimate? raceEstimate;

  factory NewGoalProposal.fromJson(Object? value) {
    final json = _strictMap(value, 'proposal');
    final id = _requiredString(json, 'proposalId');
    final sourcePlanVersionId = _requiredString(json, 'sourcePlanVersionId');
    final rawExpiresAt = _requiredString(json, 'expiresAt');
    final expiresAt = DateTime.tryParse(rawExpiresAt);
    if (expiresAt == null) {
      throw const FormatException('Invalid proposal expiry.');
    }

    final rawCurrentGoal = json['sourceGoal'] ?? json['currentGoal'];
    final rawProposedGoal = json['proposedGoal'];
    final currentGoal = NewGoalGoal.fromJson(rawCurrentGoal);
    final proposedGoal = NewGoalGoal.fromJson(rawProposedGoal);
    final rawCandidatePlan = _strictMap(json['candidatePlan'], 'candidatePlan');
    final candidatePlan = TrainingPlan.fromJson(rawCandidatePlan);
    final summaryValue = json['summary'];
    final rawWarnings = json['warnings'];

    if (candidatePlan == null) {
      throw const FormatException('Invalid proposal candidate plan.');
    }

    if (summaryValue != null && summaryValue is! Map) {
      throw const FormatException('Invalid proposal summary.');
    }

    final summary = summaryValue == null
        ? const <String, dynamic>{}
        : summaryValue.map((key, value) => MapEntry('$key', value));
    final rawRecommendation = _requiredMap(
      json['recommendation'],
      'recommendation',
    );
    final recommendation = NewGoalRecommendation.fromJson({
      'sourceGoal': rawCurrentGoal,
      'proposedGoal': rawProposedGoal,
      ...rawRecommendation,
    });

    final rawRaceEstimate = json['raceEstimate'];
    final raceEstimate = rawRaceEstimate == null
        ? null
        : NewGoalRecommendationEstimate.fromJson(
            _strictMap(rawRaceEstimate, 'raceEstimate'),
          );

    if (rawWarnings != null && rawWarnings is! List) {
      throw const FormatException('Invalid proposal warnings.');
    }

    return NewGoalProposal(
      id: id,
      sourcePlanVersionId: sourcePlanVersionId,
      expiresAt: expiresAt,
      sourceGoal: currentGoal,
      currentGoal: currentGoal,
      proposedGoal: proposedGoal,
      candidatePlan: candidatePlan,
      summary: summary,
      warnings: (rawWarnings ?? const []).cast<String>(),
      recommendation: recommendation,
      raceEstimate: raceEstimate,
    );
  }
}

class NewGoalAcceptance {
  const NewGoalAcceptance({
    required this.versionId,
    required this.plan,
    required this.profile,
  });

  final String versionId;
  final TrainingPlan plan;
  final RunnerProfile profile;

  factory NewGoalAcceptance.fromJson(Object? value) {
    final json = _strictMap(value, 'acceptance');
    final versionId = _requiredString(json, 'versionId');
    final rawPlan = _strictMap(json['plan'], 'plan');
    final rawProfile = _strictMap(json['profile'], 'profile');
    final plan = TrainingPlan.fromJson(rawPlan);
    final profile = RunnerProfile.fromJson(rawProfile);
    if (plan == null || profile == null) {
      throw const FormatException('Invalid new goal acceptance.');
    }

    return NewGoalAcceptance(
      versionId: versionId,
      plan: plan,
      profile: profile,
    );
  }
}

class StoredNewGoalDraft {
  const StoredNewGoalDraft({
    required this.draft,
    required this.sourcePlanId,
    required this.status,
    required this.revision,
    required this.updatedAt,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final String status;
  final int revision;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'sourcePlanVersionId': sourcePlanId,
    'data': draft.toJson(),
    'status': status,
    'revision': revision,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoredNewGoalDraft.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final revision = json['revision'];
    final updatedAt = DateTime.tryParse(_requiredString(json, 'updatedAt'));
    if (rawData is! Map ||
        revision is! int ||
        revision <= 0 ||
        updatedAt == null) {
      throw const FormatException('Invalid stored new goal draft.');
    }

    final mapData = rawData.map((key, value) => MapEntry('$key', value));

    return StoredNewGoalDraft(
      draft: NewGoalDraft.fromJson(mapData),
      sourcePlanId: _requiredString(json, 'sourcePlanVersionId'),
      status: _normalizeStoredStatus(json['status']),
      revision: revision,
      updatedAt: updatedAt,
    );
  }
}

String _normalizeStoredStatus(Object? value) {
  if (value is String) {
    if (value == 'editing' ||
        value == 'assessment_pending' ||
        value == 'proposal_ready') {
      return value;
    }
  }
  return 'editing';
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime _parseDateOnly(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid date.');
  }
  final parts = value.split('-').map(int.parse).toList(growable: false);
  final date = DateTime(parts[0], parts[1], parts[2]);
  if (_dateOnly(date) != value) throw const FormatException('Invalid date.');
  return date;
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return _parseDateOnly(value);
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

Map<String, dynamic> _extractTimeline(Object? value) {
  if (value is Map) {
    return _extractTimelineFromMap(
      value.map((entryKey, entryValue) => MapEntry('$entryKey', entryValue)),
    );
  }
  throw const FormatException('Invalid timeline.');
}

Map<String, dynamic> _extractTimelineFromMap(Map<String, dynamic> map) {
  final nestedTimeline = map['recommendation'] ?? map['timeline'];
  if (nestedTimeline != null) {
    return _extractTimeline(nestedTimeline);
  }

  final mode = map['mode'] ?? map['timelineMode'] ?? map['planMode'];
  final startDate =
      map['startDate'] ??
      map['date'] ??
      map['timelineDate'] ??
      map['planStartDate'];
  final weeks =
      map['weeks'] ?? map['timelineWeeks'] ?? map['proposedTimelineWeeks'];
  final endDate = map['endDate'];
  final rawHasRaceDate = map['hasRaceDate'];
  final raceDate = map['raceDate'];
  final bool hasRaceDate = rawHasRaceDate == null
      ? (raceDate != null)
      : rawHasRaceDate is bool
      ? rawHasRaceDate
      : () {
          throw const FormatException('Invalid timeline hasRaceDate.');
        }();
  final daysToRace = map['daysToRace'];
  if (mode is! String || mode.isEmpty) {
    throw const FormatException('Invalid timeline mode.');
  }
  if (startDate is! String || startDate.isEmpty) {
    throw const FormatException('Invalid timeline date.');
  }
  if (weeks is! int || weeks <= 0) {
    throw const FormatException('Invalid timeline weeks.');
  }
  return {
    'mode': mode,
    'startDate': startDate,
    'date': startDate,
    'weeks': weeks,
    'endDate': endDate ?? _dateFromStartAndWeeks(startDate, weeks),
    'hasRaceDate': hasRaceDate,
    'raceDate': raceDate,
    'daysToRace': daysToRace,
  };
}

String _dateFromStartAndWeeks(String date, int weeks) {
  final parsed = _parseDateOnly(date);
  final endDate = parsed.add(Duration(days: (weeks - 1) * 7));
  return _dateOnly(endDate);
}

DateTime? _extractDate(
  Map<String, dynamic> json,
  String key, [
  String? legacyKey,
]) {
  final rawDate = json[key] ?? (legacyKey == null ? null : json[legacyKey]);
  if (rawDate == null) return null;
  if (rawDate is! String) throw const FormatException('Invalid timeline date.');
  return _parseDateOnly(rawDate);
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key.');
  return value;
}

DateTime? _requiredDate(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String) throw FormatException('Invalid $key date.');
  return _parseDateOnly(raw);
}

int? _optionalPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value < 0) throw FormatException('Invalid $key.');
  return value;
}

Object? _optionalValue(Map<String, dynamic> json, String key) {
  return json[key];
}

Map<String, dynamic> _healthForPayload(NewGoalHealthSnapshot health) => {
  'painLevel': health.painLevel.key,
  'injuryHistory': health.injuryHistory.key,
  'hasHealthConditions': health.hasHealthConditions.key,
};

String _estimateSource(Map<String, dynamic> json) {
  final directSource = json['source'];
  if (directSource is String && directSource.isNotEmpty) {
    return directSource;
  }

  final evidence = json['evidence'];
  if (evidence is List && evidence.isNotEmpty) {
    final first = evidence.first;
    if (first is Map && first['source'] is String) {
      final source = first['source'];
      if (source is String && source.isNotEmpty) {
        return source;
      }
    }
  }

  return 'server';
}

Map<String, dynamic> _requiredMap(Object? value, String key) {
  if (value is! Map) throw FormatException('Invalid $key.');
  return value.map((entryKey, entryValue) => MapEntry('$entryKey', entryValue));
}

Map<String, dynamic> _strictMap(Object? value, String name) {
  if (value is! Map) throw FormatException('Invalid $name.');
  return value.map((entryKey, entryValue) => MapEntry('$entryKey', entryValue));
}

List<dynamic> _requiredList(Object? value, String key) {
  if (value is! List) throw FormatException('Invalid $key.');
  return value;
}
