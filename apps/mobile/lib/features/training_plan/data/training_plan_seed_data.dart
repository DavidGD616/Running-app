import '../domain/models/session_type.dart';
import '../domain/models/support_session.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/models/workout_step.dart';
import '../domain/models/workout_target.dart';

/// Returns a [TrainingPlan] seeded with mock data for all 12 weeks.
/// The current week is week 4. Weeks 1–3 are past (completed), week 4 is
/// current (statuses derived from today), weeks 5–12 are future (upcoming).
TrainingPlan buildSeedTrainingPlan() {
  final now = DateTime.now();
  final currentMonday = _mondayOf(now);

  // Week 1 starts 3 weeks before the current week.
  final planStart = currentMonday.subtract(const Duration(days: 21));

  /// Monday of a given week number (1-based).
  DateTime weekMonday(int weekNum) =>
      planStart.add(Duration(days: (weekNum - 1) * 7));

  /// A specific day within a week (0 = Mon, 6 = Sun).
  DateTime day(int weekNum, int offset) {
    final mon = weekMonday(weekNum);
    return DateTime(mon.year, mon.month, mon.day + offset);
  }

  /// Status for past-week sessions (always completed).
  SessionStatus pastStatus(DateTime date) => SessionStatus.completed;

  /// Status for future-week sessions (always upcoming).
  SessionStatus futureStatus(DateTime date) => SessionStatus.upcoming;

  /// Status for current-week sessions based on today.
  SessionStatus currentStatus(DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isAtSameMomentAs(today)) return SessionStatus.today;
    if (d.isBefore(today)) return SessionStatus.completed;
    return SessionStatus.upcoming;
  }

  /// Current-week Wednesday is always shown as skipped to match design mock.
  SessionStatus currentStatusWed(DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(today) || d.isAtSameMomentAs(today)) {
      return SessionStatus.skipped;
    }
    return SessionStatus.upcoming;
  }

  int estimateElevationGain(SessionType type, double? distanceKm) {
    if (type == SessionType.restDay) return 0;
    final distance = distanceKm ?? 5.0;
    final perKm = switch (type) {
      SessionType.longRun => 12,
      SessionType.hillRepeats => 18,
      SessionType.intervals => 15,
      SessionType.fartlek => 14,
      SessionType.tempoRun => 11,
      SessionType.thresholdRun => 12,
      SessionType.racePaceRun => 10,
      SessionType.progressionRun => 9,
      SessionType.recoveryRun => 6,
      SessionType.crossTraining => 5,
      SessionType.easyRun => 7,
      SessionType.restDay => 0,
    };
    return (distance * perKm).round();
  }

  List<WorkoutPhase> buildStructuredWorkoutPhases(
    SessionType type, {
    required int warmUpMinutes,
    required int mainMinutes,
    required int coolDownMinutes,
    int? intervalReps,
    int? intervalRepDistanceMeters,
    int? intervalRecoverySeconds,
  }) {
    return [
      WorkoutPhase(
        type: WorkoutPhaseType.warmUp,
        iconAsset: 'assets/icons/flame.svg',
        title: 'warm_up',
        duration: warmUpMinutes.toString(),
        note: '${type.name}_warm_up',
      ),
      WorkoutPhase(
        type: WorkoutPhaseType.main,
        iconAsset: switch (type) {
          SessionType.longRun => 'assets/icons/target.svg',
          SessionType.recoveryRun => 'assets/icons/stopwatch.svg',
          SessionType.easyRun => 'assets/icons/route.svg',
          SessionType.intervals => 'assets/icons/activity.svg',
          SessionType.tempoRun => 'assets/icons/activity.svg',
          SessionType.thresholdRun => 'assets/icons/activity.svg',
          SessionType.racePaceRun => 'assets/icons/activity.svg',
          SessionType.progressionRun => 'assets/icons/route.svg',
          SessionType.hillRepeats => 'assets/icons/activity.svg',
          SessionType.fartlek => 'assets/icons/activity.svg',
          SessionType.crossTraining => 'assets/icons/activity.svg',
          SessionType.restDay => 'assets/icons/route.svg',
        },
        title: 'main',
        duration: mainMinutes.toString(),
        note:
            intervalReps != null && intervalRepDistanceMeters != null
            ? '${type.name}_${intervalReps}x${intervalRepDistanceMeters}m'
            : '${type.name}_main',
        recoveryNote:
            intervalRecoverySeconds != null
            ? 'recovery_${intervalRecoverySeconds}s'
            : null,
      ),
      WorkoutPhase(
        type: WorkoutPhaseType.coolDown,
        iconAsset: 'assets/icons/heart_rate.svg',
        title: 'cool_down',
        duration: coolDownMinutes.toString(),
        note: '${type.name}_cool_down',
      ),
    ];
  }

  WorkoutTarget? buildWorkoutTarget(SessionType type) {
    return switch (type) {
      SessionType.easyRun => const WorkoutTarget.effort(TargetZone.easy),
      SessionType.longRun => const WorkoutTarget.effort(TargetZone.longRun),
      SessionType.intervals => const WorkoutTarget.pace(TargetZone.interval),
      SessionType.tempoRun => const WorkoutTarget.effort(TargetZone.tempo),
      SessionType.thresholdRun => const WorkoutTarget.effort(
        TargetZone.threshold,
      ),
      SessionType.racePaceRun => const WorkoutTarget.pace(TargetZone.racePace),
      SessionType.recoveryRun => const WorkoutTarget.effort(TargetZone.recovery),
      SessionType.progressionRun => const WorkoutTarget.effort(TargetZone.steady),
      SessionType.hillRepeats => const WorkoutTarget.effort(TargetZone.interval),
      SessionType.fartlek => const WorkoutTarget.effort(TargetZone.interval),
      SessionType.crossTraining => const WorkoutTarget.heartRate(
        TargetZone.easy,
      ),
      SessionType.restDay => null,
    };
  }

  List<WorkoutStep> buildWorkoutSteps(
    SessionType type, {
    required int warmUpMinutes,
    required int mainMinutes,
    required int coolDownMinutes,
    int? intervalReps,
    int? intervalRepDistanceMeters,
    int? intervalRecoverySeconds,
  }) {
    if (type == SessionType.intervals &&
        intervalReps != null &&
        intervalRepDistanceMeters != null) {
      return [
        WorkoutStep.warmUp(
          duration: Duration(minutes: warmUpMinutes),
          target: WorkoutTarget.effort(TargetZone.easy),
        ),
        WorkoutStep.repeat(
          repetitions: intervalReps,
          steps: [
            WorkoutStep.work(
              distanceMeters: intervalRepDistanceMeters,
              target: const WorkoutTarget.pace(TargetZone.interval),
            ),
            WorkoutStep.recovery(
              duration: Duration(seconds: intervalRecoverySeconds ?? 90),
              target: const WorkoutTarget.effort(TargetZone.recovery),
            ),
          ],
        ),
        WorkoutStep.coolDown(
          duration: Duration(minutes: coolDownMinutes),
          target: WorkoutTarget.effort(TargetZone.recovery),
        ),
      ];
    }

    return [
      WorkoutStep.warmUp(
        duration: Duration(minutes: warmUpMinutes),
        target: const WorkoutTarget.effort(TargetZone.easy),
      ),
      WorkoutStep.work(
        duration: Duration(minutes: mainMinutes),
        target: buildWorkoutTarget(type),
      ),
      WorkoutStep.coolDown(
        duration: Duration(minutes: coolDownMinutes),
        target: const WorkoutTarget.effort(TargetZone.recovery),
      ),
    ];
  }

  // ── Helpers to build a standard week of sessions ──────────────────────────

  List<TrainingSession> buildPastWeek(
    int weekNum, {
    required double easyKm,
    required int easyMin,
    required double workoutKm,
    required int workoutMin,
    required SessionType workoutType,
    required double longKm,
    required int longMin,
    required double recoveryKm,
    required int recoveryMin,
    bool workoutIsIntervals = false,
    int? intervalReps,
    int? intervalRepDistanceMeters,
    int? intervalRecoverySeconds,
    Set<int> skippedOffsets = const {},
  }) {
    SessionStatus pastStatusForOffset(int offset) {
      if (skippedOffsets.contains(offset)) return SessionStatus.skipped;
      return pastStatus(day(weekNum, offset));
    }

    return [
      TrainingSession(
        id: 'w$weekNum-mon',
        date: day(weekNum, 0),
        type: SessionType.restDay,
        status: pastStatusForOffset(0),
        weekNumber: weekNum,
        elevationGainMeters: 0,
      ),
      TrainingSession(
        id: 'w$weekNum-tue',
        date: day(weekNum, 1),
        type: SessionType.easyRun,
        status: pastStatusForOffset(1),
        weekNumber: weekNum,
        distanceKm: easyKm,
        durationMinutes: easyMin,
        effort: TrainingSessionEffort.easy,
        warmUpMinutes: 5,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(SessionType.easyRun, easyKm),
      ),
      TrainingSession(
        id: 'w$weekNum-wed',
        date: day(weekNum, 2),
        type: workoutType,
        status: pastStatusForOffset(2),
        weekNumber: weekNum,
        distanceKm: workoutKm,
        durationMinutes: workoutMin,
        effort: workoutIsIntervals
            ? TrainingSessionEffort.hard
            : TrainingSessionEffort.moderate,
        workoutTarget: buildWorkoutTarget(workoutType),
        workoutSteps: buildWorkoutSteps(
          workoutType,
          warmUpMinutes: 10,
          mainMinutes: workoutMin,
          coolDownMinutes: 10,
          intervalReps: workoutIsIntervals ? intervalReps : null,
          intervalRepDistanceMeters: workoutIsIntervals
              ? intervalRepDistanceMeters
              : null,
          intervalRecoverySeconds: workoutIsIntervals
              ? intervalRecoverySeconds
              : null,
        ),
        phases: buildStructuredWorkoutPhases(
          workoutType,
          warmUpMinutes: 10,
          mainMinutes: workoutMin,
          coolDownMinutes: 10,
          intervalReps: intervalReps,
          intervalRepDistanceMeters: intervalRepDistanceMeters,
          intervalRecoverySeconds: intervalRecoverySeconds,
        ),
        intervalReps: workoutIsIntervals ? intervalReps : null,
        intervalRepDistanceMeters: workoutIsIntervals
            ? intervalRepDistanceMeters
            : null,
        intervalRecoverySeconds: workoutIsIntervals
            ? intervalRecoverySeconds
            : null,
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        elevationGainMeters: estimateElevationGain(workoutType, workoutKm),
      ),
      TrainingSession(
        id: 'w$weekNum-thu',
        date: day(weekNum, 3),
        type: SessionType.restDay,
        status: pastStatusForOffset(3),
        weekNumber: weekNum,
        elevationGainMeters: 0,
      ),
      TrainingSession(
        id: 'w$weekNum-fri',
        date: day(weekNum, 4),
        type: SessionType.easyRun,
        status: pastStatusForOffset(4),
        weekNumber: weekNum,
        distanceKm: easyKm - 1,
        durationMinutes: easyMin - 5,
        effort: TrainingSessionEffort.easy,
        warmUpMinutes: 5,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(
          SessionType.easyRun,
          easyKm - 1,
        ),
      ),
      TrainingSession(
        id: 'w$weekNum-sat',
        date: day(weekNum, 5),
        type: SessionType.longRun,
        status: pastStatusForOffset(5),
        weekNumber: weekNum,
        distanceKm: longKm,
        durationMinutes: longMin,
        effort: TrainingSessionEffort.easy,
        workoutTarget: buildWorkoutTarget(SessionType.longRun),
        workoutSteps: buildWorkoutSteps(
          SessionType.longRun,
          warmUpMinutes: 10,
          mainMinutes: longMin,
          coolDownMinutes: 10,
        ),
        phases: buildStructuredWorkoutPhases(
          SessionType.longRun,
          warmUpMinutes: 10,
          mainMinutes: longMin,
          coolDownMinutes: 10,
        ),
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        elevationGainMeters: estimateElevationGain(SessionType.longRun, longKm),
      ),
      TrainingSession(
        id: 'w$weekNum-sun',
        date: day(weekNum, 6),
        type: SessionType.recoveryRun,
        status: pastStatusForOffset(6),
        weekNumber: weekNum,
        distanceKm: recoveryKm,
        durationMinutes: recoveryMin,
        effort: TrainingSessionEffort.veryEasy,
        warmUpMinutes: 3,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(
          SessionType.recoveryRun,
          recoveryKm,
        ),
      ),
    ];
  }

  List<TrainingSession> buildFutureWeek(
    int weekNum, {
    required double easyKm,
    required int easyMin,
    required double workoutKm,
    required int workoutMin,
    required SessionType workoutType,
    required double longKm,
    required int longMin,
    required double recoveryKm,
    required int recoveryMin,
    bool workoutIsIntervals = false,
    int? intervalReps,
    int? intervalRepDistanceMeters,
    int? intervalRecoverySeconds,
  }) {
    return [
      TrainingSession(
        id: 'w$weekNum-mon',
        date: day(weekNum, 0),
        type: SessionType.restDay,
        status: futureStatus(day(weekNum, 0)),
        weekNumber: weekNum,
        elevationGainMeters: 0,
      ),
      TrainingSession(
        id: 'w$weekNum-tue',
        date: day(weekNum, 1),
        type: SessionType.easyRun,
        status: futureStatus(day(weekNum, 1)),
        weekNumber: weekNum,
        distanceKm: easyKm,
        durationMinutes: easyMin,
        effort: TrainingSessionEffort.easy,
        warmUpMinutes: 5,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(SessionType.easyRun, easyKm),
      ),
      TrainingSession(
        id: 'w$weekNum-wed',
        date: day(weekNum, 2),
        type: workoutType,
        status: futureStatus(day(weekNum, 2)),
        weekNumber: weekNum,
        distanceKm: workoutKm,
        durationMinutes: workoutMin,
        effort: workoutIsIntervals
            ? TrainingSessionEffort.hard
            : TrainingSessionEffort.moderate,
        workoutTarget: buildWorkoutTarget(workoutType),
        workoutSteps: buildWorkoutSteps(
          workoutType,
          warmUpMinutes: 10,
          mainMinutes: workoutMin,
          coolDownMinutes: 10,
          intervalReps: workoutIsIntervals ? intervalReps : null,
          intervalRepDistanceMeters: workoutIsIntervals
              ? intervalRepDistanceMeters
              : null,
          intervalRecoverySeconds: workoutIsIntervals
              ? intervalRecoverySeconds
              : null,
        ),
        phases: buildStructuredWorkoutPhases(
          workoutType,
          warmUpMinutes: 10,
          mainMinutes: workoutMin,
          coolDownMinutes: 10,
          intervalReps: intervalReps,
          intervalRepDistanceMeters: intervalRepDistanceMeters,
          intervalRecoverySeconds: intervalRecoverySeconds,
        ),
        intervalReps: workoutIsIntervals ? intervalReps : null,
        intervalRepDistanceMeters: workoutIsIntervals
            ? intervalRepDistanceMeters
            : null,
        intervalRecoverySeconds: workoutIsIntervals
            ? intervalRecoverySeconds
            : null,
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        elevationGainMeters: estimateElevationGain(workoutType, workoutKm),
      ),
      TrainingSession(
        id: 'w$weekNum-thu',
        date: day(weekNum, 3),
        type: SessionType.restDay,
        status: futureStatus(day(weekNum, 3)),
        weekNumber: weekNum,
        elevationGainMeters: 0,
      ),
      TrainingSession(
        id: 'w$weekNum-fri',
        date: day(weekNum, 4),
        type: SessionType.easyRun,
        status: futureStatus(day(weekNum, 4)),
        weekNumber: weekNum,
        distanceKm: easyKm - 1,
        durationMinutes: easyMin - 5,
        effort: TrainingSessionEffort.easy,
        warmUpMinutes: 5,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(
          SessionType.easyRun,
          easyKm - 1,
        ),
      ),
      TrainingSession(
        id: 'w$weekNum-sat',
        date: day(weekNum, 5),
        type: SessionType.longRun,
        status: futureStatus(day(weekNum, 5)),
        weekNumber: weekNum,
        distanceKm: longKm,
        durationMinutes: longMin,
        effort: TrainingSessionEffort.easy,
        workoutTarget: buildWorkoutTarget(SessionType.longRun),
        workoutSteps: buildWorkoutSteps(
          SessionType.longRun,
          warmUpMinutes: 10,
          mainMinutes: longMin,
          coolDownMinutes: 10,
        ),
        phases: buildStructuredWorkoutPhases(
          SessionType.longRun,
          warmUpMinutes: 10,
          mainMinutes: longMin,
          coolDownMinutes: 10,
        ),
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        elevationGainMeters: estimateElevationGain(SessionType.longRun, longKm),
      ),
      TrainingSession(
        id: 'w$weekNum-sun',
        date: day(weekNum, 6),
        type: SessionType.recoveryRun,
        status: futureStatus(day(weekNum, 6)),
        weekNumber: weekNum,
        distanceKm: recoveryKm,
        durationMinutes: recoveryMin,
        effort: TrainingSessionEffort.veryEasy,
        warmUpMinutes: 3,
        coolDownMinutes: 3,
        elevationGainMeters: estimateElevationGain(
          SessionType.recoveryRun,
          recoveryKm,
        ),
      ),
    ];
  }

  // ── Build all sessions ─────────────────────────────────────────────────────

  final sessions = <TrainingSession>[
    // ── Week 1 (past) ──────────────────────────────────────────────────────
    ...buildPastWeek(
      1,
      easyKm: 4.0,
      easyMin: 25,
      workoutType: SessionType.easyRun,
      workoutKm: 5.0,
      workoutMin: 30,
      longKm: 8.0,
      longMin: 55,
      recoveryKm: 3.0,
      recoveryMin: 20,
      skippedOffsets: {4},
    ),

    // ── Week 2 (past) ──────────────────────────────────────────────────────
    ...buildPastWeek(
      2,
      easyKm: 5.0,
      easyMin: 30,
      workoutType: SessionType.tempoRun,
      workoutKm: 6.0,
      workoutMin: 38,
      longKm: 10.0,
      longMin: 65,
      recoveryKm: 3.0,
      recoveryMin: 20,
      skippedOffsets: {1},
    ),

    // ── Week 3 (past) ──────────────────────────────────────────────────────
    ...buildPastWeek(
      3,
      easyKm: 5.0,
      easyMin: 30,
      workoutType: SessionType.intervals,
      workoutKm: 6.0,
      workoutMin: 42,
      longKm: 11.0,
      longMin: 70,
      recoveryKm: 3.0,
      recoveryMin: 20,
      workoutIsIntervals: true,
      intervalReps: 5,
      intervalRepDistanceMeters: 400,
      intervalRecoverySeconds: 90,
      skippedOffsets: {6},
    ),

    // ── Week 4 (current) ───────────────────────────────────────────────────
    TrainingSession(
      id: 'w4-mon',
      date: day(4, 0),
      type: SessionType.restDay,
      status: currentStatus(day(4, 0)),
      weekNumber: 4,
      elevationGainMeters: 0,
    ),
    TrainingSession(
      id: 'w4-tue',
      date: day(4, 1),
      type: SessionType.easyRun,
      status: currentStatus(day(4, 1)),
      weekNumber: 4,
      distanceKm: 5.0,
      durationMinutes: 30,
      effort: TrainingSessionEffort.easy,
      workoutTarget: buildWorkoutTarget(SessionType.easyRun),
      workoutSteps: buildWorkoutSteps(
        SessionType.easyRun,
        warmUpMinutes: 5,
        mainMinutes: 30,
        coolDownMinutes: 3,
      ),
      phases: buildStructuredWorkoutPhases(
        SessionType.easyRun,
        warmUpMinutes: 5,
        mainMinutes: 30,
        coolDownMinutes: 3,
      ),
      warmUpMinutes: 5,
      coolDownMinutes: 3,
      elevationGainMeters: estimateElevationGain(SessionType.easyRun, 5.0),
    ),
    TrainingSession(
      id: 'w4-wed',
      date: day(4, 2),
      type: SessionType.easyRun,
      status: currentStatusWed(day(4, 2)),
      weekNumber: 4,
      distanceKm: 4.0,
      durationMinutes: 25,
      effort: TrainingSessionEffort.easy,
      workoutTarget: buildWorkoutTarget(SessionType.easyRun),
      workoutSteps: buildWorkoutSteps(
        SessionType.easyRun,
        warmUpMinutes: 5,
        mainMinutes: 25,
        coolDownMinutes: 3,
      ),
      phases: buildStructuredWorkoutPhases(
        SessionType.easyRun,
        warmUpMinutes: 5,
        mainMinutes: 25,
        coolDownMinutes: 3,
      ),
      warmUpMinutes: 5,
      coolDownMinutes: 3,
      elevationGainMeters: estimateElevationGain(SessionType.easyRun, 4.0),
    ),
    TrainingSession(
      id: 'w4-thu',
      date: day(4, 3),
      type: SessionType.intervals,
      status: currentStatus(day(4, 3)),
      weekNumber: 4,
      distanceKm: 6.0,
      durationMinutes: 45,
      effort: TrainingSessionEffort.hard,
      workoutTarget: buildWorkoutTarget(SessionType.intervals),
      workoutSteps: buildWorkoutSteps(
        SessionType.intervals,
        warmUpMinutes: 10,
        mainMinutes: 45,
        coolDownMinutes: 10,
        intervalReps: 6,
        intervalRepDistanceMeters: 400,
        intervalRecoverySeconds: 90,
      ),
      phases: buildStructuredWorkoutPhases(
        SessionType.intervals,
        warmUpMinutes: 10,
        mainMinutes: 45,
        coolDownMinutes: 10,
        intervalReps: 6,
        intervalRepDistanceMeters: 400,
        intervalRecoverySeconds: 90,
      ),
      intervalReps: 6,
      intervalRepDistanceMeters: 400,
      intervalRecoverySeconds: 90,
      warmUpMinutes: 10,
      coolDownMinutes: 10,
      elevationGainMeters: estimateElevationGain(SessionType.intervals, 6.0),
    ),
    TrainingSession(
      id: 'w4-fri',
      date: day(4, 4),
      type: SessionType.restDay,
      status: currentStatus(day(4, 4)),
      weekNumber: 4,
      elevationGainMeters: 0,
    ),
    TrainingSession(
      id: 'w4-sat',
      date: day(4, 5),
      type: SessionType.longRun,
      status: currentStatus(day(4, 5)),
      weekNumber: 4,
      distanceKm: 12.0,
      durationMinutes: 75,
      effort: TrainingSessionEffort.easy,
      workoutTarget: buildWorkoutTarget(SessionType.longRun),
      workoutSteps: buildWorkoutSteps(
        SessionType.longRun,
        warmUpMinutes: 10,
        mainMinutes: 75,
        coolDownMinutes: 10,
      ),
      phases: buildStructuredWorkoutPhases(
        SessionType.longRun,
        warmUpMinutes: 10,
        mainMinutes: 75,
        coolDownMinutes: 10,
      ),
      warmUpMinutes: 10,
      coolDownMinutes: 10,
      elevationGainMeters: estimateElevationGain(SessionType.longRun, 12.0),
    ),
    TrainingSession(
      id: 'w4-sun',
      date: day(4, 6),
      type: SessionType.recoveryRun,
      status: currentStatus(day(4, 6)),
      weekNumber: 4,
      distanceKm: 3.0,
      durationMinutes: 20,
      effort: TrainingSessionEffort.veryEasy,
      workoutTarget: buildWorkoutTarget(SessionType.recoveryRun),
      workoutSteps: buildWorkoutSteps(
        SessionType.recoveryRun,
        warmUpMinutes: 3,
        mainMinutes: 20,
        coolDownMinutes: 3,
      ),
      phases: buildStructuredWorkoutPhases(
        SessionType.recoveryRun,
        warmUpMinutes: 3,
        mainMinutes: 20,
        coolDownMinutes: 3,
      ),
      warmUpMinutes: 3,
      coolDownMinutes: 3,
      elevationGainMeters: estimateElevationGain(SessionType.recoveryRun, 3.0),
    ),

    // ── Week 5 (future) ────────────────────────────────────────────────────
    ...buildFutureWeek(
      5,
      easyKm: 6.0,
      easyMin: 35,
      workoutType: SessionType.tempoRun,
      workoutKm: 7.0,
      workoutMin: 44,
      longKm: 13.0,
      longMin: 80,
      recoveryKm: 4.0,
      recoveryMin: 25,
    ),

    // ── Week 6 (future) ────────────────────────────────────────────────────
    ...buildFutureWeek(
      6,
      easyKm: 6.0,
      easyMin: 35,
      workoutType: SessionType.intervals,
      workoutKm: 7.0,
      workoutMin: 48,
      longKm: 14.0,
      longMin: 88,
      recoveryKm: 4.0,
      recoveryMin: 25,
      workoutIsIntervals: true,
      intervalReps: 6,
      intervalRepDistanceMeters: 600,
      intervalRecoverySeconds: 120,
    ),

    // ── Week 7 (future) — recovery week ───────────────────────────────────
    ...buildFutureWeek(
      7,
      easyKm: 5.0,
      easyMin: 30,
      workoutType: SessionType.easyRun,
      workoutKm: 6.0,
      workoutMin: 35,
      longKm: 10.0,
      longMin: 65,
      recoveryKm: 3.0,
      recoveryMin: 20,
    ),

    // ── Week 8 (future) ────────────────────────────────────────────────────
    ...buildFutureWeek(
      8,
      easyKm: 7.0,
      easyMin: 40,
      workoutType: SessionType.tempoRun,
      workoutKm: 8.0,
      workoutMin: 50,
      longKm: 16.0,
      longMin: 100,
      recoveryKm: 4.0,
      recoveryMin: 25,
    ),

    // ── Week 9 (future) ────────────────────────────────────────────────────
    ...buildFutureWeek(
      9,
      easyKm: 7.0,
      easyMin: 40,
      workoutType: SessionType.intervals,
      workoutKm: 8.0,
      workoutMin: 52,
      longKm: 18.0,
      longMin: 112,
      recoveryKm: 4.0,
      recoveryMin: 25,
      workoutIsIntervals: true,
      intervalReps: 8,
      intervalRepDistanceMeters: 400,
      intervalRecoverySeconds: 90,
    ),

    // ── Week 10 (future) ───────────────────────────────────────────────────
    ...buildFutureWeek(
      10,
      easyKm: 8.0,
      easyMin: 45,
      workoutType: SessionType.racePaceRun,
      workoutKm: 9.0,
      workoutMin: 54,
      longKm: 19.0,
      longMin: 118,
      recoveryKm: 5.0,
      recoveryMin: 30,
    ),

    // ── Week 11 (future) — taper begins ───────────────────────────────────
    ...buildFutureWeek(
      11,
      easyKm: 6.0,
      easyMin: 35,
      workoutType: SessionType.tempoRun,
      workoutKm: 6.0,
      workoutMin: 38,
      longKm: 14.0,
      longMin: 88,
      recoveryKm: 3.0,
      recoveryMin: 20,
    ),

    // ── Week 12 (future) — race week ──────────────────────────────────────
    ...buildFutureWeek(
      12,
      easyKm: 4.0,
      easyMin: 25,
      workoutType: SessionType.easyRun,
      workoutKm: 3.0,
      workoutMin: 20,
      longKm: 21.1,
      longMin: 130,
      recoveryKm: 2.0,
      recoveryMin: 15,
    ),
  ];

  final supportSessions = <SupportSession>[
    SupportSession(
      id: 'support-w4-mon-strength',
      date: day(4, 0),
      weekNumber: 4,
      type: SupplementalSessionType.strength,
      status: SupportSessionStatus.planned,
      durationMinutes: 25,
      notes: 'seed_strength_session',
    ),
    SupportSession(
      id: 'support-w6-fri-mobility',
      date: day(6, 4),
      weekNumber: 6,
      type: SupplementalSessionType.mobility,
      status: SupportSessionStatus.planned,
      durationMinutes: 15,
      notes: 'seed_mobility_session',
    ),
  ];

  return TrainingPlan(
    id: 'seed-plan',
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 4,
    sessions: sessions,
    supportSessions: supportSessions,
  );
}

DateTime _mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}
