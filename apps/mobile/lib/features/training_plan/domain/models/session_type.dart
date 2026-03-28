enum SessionType {
  rest,
  easyRun,
  intervals,
  longRun,
  recoveryRun,
  tempoRun;

  String get iconAsset {
    switch (this) {
      case SessionType.rest:
        return 'assets/icons/coffee.svg';
      case SessionType.easyRun:
        return 'assets/icons/route.svg';
      case SessionType.intervals:
        return 'assets/icons/activity.svg';
      case SessionType.longRun:
        return 'assets/icons/target.svg';
      case SessionType.recoveryRun:
        return 'assets/icons/stopwatch.svg';
      case SessionType.tempoRun:
        return 'assets/icons/activity.svg';
    }
  }
}

enum SessionStatus {
  upcoming,
  today,
  completed,
  skipped,
}
