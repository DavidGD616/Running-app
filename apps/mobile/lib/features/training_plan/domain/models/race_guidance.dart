class RaceGuidance {
  const RaceGuidance({
    required this.raceDayExecution,
    this.warmup,
    this.primaryTarget,
    this.stretchTarget,
    this.splitPlan,
    this.whenToPress,
    this.whatToAvoid,
    this.coachingNotes,
    this.sleepNotes,
    this.fuelingNotes,
    this.hydrationNotes,
    this.taperReminders,
    this.weatherCourseNotes,
  });

  final String raceDayExecution;
  final String? warmup;
  final Duration? primaryTarget;
  final Duration? stretchTarget;
  final String? splitPlan;
  final String? whenToPress;
  final String? whatToAvoid;
  final String? coachingNotes;
  final String? sleepNotes;
  final String? fuelingNotes;
  final String? hydrationNotes;
  final String? taperReminders;
  final String? weatherCourseNotes;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'raceDayExecution': raceDayExecution,
      if (warmup != null) 'warmup': warmup,
      if (primaryTarget != null) 'primaryTargetSec': primaryTarget!.inSeconds,
      if (stretchTarget != null) 'stretchTargetSec': stretchTarget!.inSeconds,
      if (splitPlan != null) 'splitPlan': splitPlan,
      if (whenToPress != null) 'whenToPress': whenToPress,
      if (whatToAvoid != null) 'whatToAvoid': whatToAvoid,
      if (coachingNotes != null) 'coachingNotes': coachingNotes,
      if (sleepNotes != null) 'sleepNotes': sleepNotes,
      if (fuelingNotes != null) 'fuelingNotes': fuelingNotes,
      if (hydrationNotes != null) 'hydrationNotes': hydrationNotes,
      if (taperReminders != null) 'taperReminders': taperReminders,
      if (weatherCourseNotes != null) 'weatherCourseNotes': weatherCourseNotes,
    };
  }

  factory RaceGuidance.fromJson(Map<String, dynamic> json) {
    const context = 'race guidance';
    final raceDayExecution = _requiredString(
      json,
      'raceDayExecution',
      context: context,
    );
    final primaryTarget = _optionalDurationSeconds(
      json,
      'primaryTargetSec',
      context: context,
    );
    final stretchTarget = _optionalDurationSeconds(
      json,
      'stretchTargetSec',
      context: context,
    );

    if (primaryTarget != null && primaryTarget <= Duration.zero) {
      throw const FormatException(
        'Invalid race guidance: primaryTargetSec must be > 0 when present.',
      );
    }
    if (stretchTarget != null && stretchTarget <= Duration.zero) {
      throw const FormatException(
        'Invalid race guidance: stretchTargetSec must be > 0 when present.',
      );
    }

    return RaceGuidance(
      raceDayExecution: raceDayExecution,
      warmup: _optionalString(json, 'warmup', context: context),
      primaryTarget: primaryTarget,
      stretchTarget: stretchTarget,
      splitPlan: _optionalString(json, 'splitPlan', context: context),
      whenToPress: _optionalString(json, 'whenToPress', context: context),
      whatToAvoid: _optionalString(json, 'whatToAvoid', context: context),
      coachingNotes: _optionalString(json, 'coachingNotes', context: context),
      sleepNotes: _optionalString(json, 'sleepNotes', context: context),
      fuelingNotes: _optionalString(json, 'fuelingNotes', context: context),
      hydrationNotes: _optionalString(json, 'hydrationNotes', context: context),
      taperReminders: _optionalString(json, 'taperReminders', context: context),
      weatherCourseNotes: _optionalString(
        json,
        'weatherCourseNotes',
        context: context,
      ),
    );
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

Duration? _optionalDurationSeconds(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is int) return Duration(seconds: raw);
  if (raw is double && raw.isFinite && raw == raw.roundToDouble()) {
    return Duration(seconds: raw.toInt());
  }
  if (raw is String && raw.isNotEmpty) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return Duration(seconds: parsed);
  }
  throw FormatException('Invalid $context: $key must be an int duration.');
}
