enum SessionCategory {
  endurance,
  speedWork,
  threshold,
  raceSpecific,
  recovery,
  rest,
}

enum SupplementalSessionType { strength, mobility, drills }

extension SupplementalSessionTypeExtension on SupplementalSessionType {
  String get key => switch (this) {
    SupplementalSessionType.strength => 'support_strength',
    SupplementalSessionType.mobility => 'support_mobility',
    SupplementalSessionType.drills => 'support_drills',
  };
}

SupplementalSessionType? supplementalSessionTypeFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in SupplementalSessionType.values) {
    if (value.key == key) return value;
  }
  return null;
}

enum SessionType {
  // Endurance
  easyRun,
  longRun,
  progressionRun,

  // Speed Work
  intervals,
  hillRepeats,
  fartlek,

  // Threshold
  tempoRun,
  thresholdRun,

  // Race Specific
  racePaceRun,

  // Recovery
  recoveryRun,
  crossTraining,

  // Rest
  restDay,
}

extension SessionTypeExtension on SessionType {
  bool get isRunSession {
    switch (this) {
      case SessionType.easyRun:
      case SessionType.longRun:
      case SessionType.progressionRun:
      case SessionType.intervals:
      case SessionType.hillRepeats:
      case SessionType.fartlek:
      case SessionType.tempoRun:
      case SessionType.thresholdRun:
      case SessionType.racePaceRun:
      case SessionType.recoveryRun:
        return true;
      case SessionType.crossTraining:
      case SessionType.restDay:
        return false;
    }
  }

  SessionCategory get category {
    switch (this) {
      case SessionType.easyRun:
      case SessionType.longRun:
      case SessionType.progressionRun:
        return SessionCategory.endurance;
      case SessionType.intervals:
      case SessionType.hillRepeats:
      case SessionType.fartlek:
        return SessionCategory.speedWork;
      case SessionType.tempoRun:
      case SessionType.thresholdRun:
        return SessionCategory.threshold;
      case SessionType.racePaceRun:
        return SessionCategory.raceSpecific;
      case SessionType.recoveryRun:
      case SessionType.crossTraining:
        return SessionCategory.recovery;
      case SessionType.restDay:
        return SessionCategory.rest;
    }
  }

  String get iconAsset {
    switch (this) {
      case SessionType.restDay:
        return 'assets/icons/coffee.svg';
      case SessionType.easyRun:
      case SessionType.longRun:
      case SessionType.progressionRun:
        return 'assets/icons/route.svg';
      case SessionType.intervals:
      case SessionType.hillRepeats:
      case SessionType.fartlek:
      case SessionType.tempoRun:
      case SessionType.thresholdRun:
      case SessionType.racePaceRun:
        return 'assets/icons/activity.svg';
      case SessionType.recoveryRun:
      case SessionType.crossTraining:
        return 'assets/icons/stopwatch.svg';
    }
  }

  bool get isRest => this == SessionType.restDay;

  bool get countsAsRun {
    switch (this) {
      case SessionType.easyRun:
      case SessionType.longRun:
      case SessionType.progressionRun:
      case SessionType.intervals:
      case SessionType.hillRepeats:
      case SessionType.fartlek:
      case SessionType.tempoRun:
      case SessionType.thresholdRun:
      case SessionType.racePaceRun:
      case SessionType.recoveryRun:
        return true;
      case SessionType.crossTraining:
      case SessionType.restDay:
        return false;
    }
  }
}

enum SessionStatus { upcoming, today, completed, skipped }
