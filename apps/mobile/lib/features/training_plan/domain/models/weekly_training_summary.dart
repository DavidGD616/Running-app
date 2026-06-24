import '../../../activity/domain/models/activity_record.dart';
import 'model_json_utils.dart';
import 'session_feedback.dart';
import 'session_type.dart';
import 'training_session.dart';

enum WeeklySummarySignal {
  lowCompletion,
  skippedSessions,
  painConcern,
  poorRecovery,
  veryHardLoad,
}

class WeeklyTrainingSummary {
  const WeeklyTrainingSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.plannedSessions,
    required this.completedSessions,
    required this.plannedDistanceKm,
    required this.completedDistanceKm,
    required this.plannedDurationMinutes,
    required this.completedDurationMinutes,
    required this.hardSessionCount,
    required this.skippedSessionCount,
    required this.veryHardSessionCount,
    required this.poorRecoveryCount,
    required this.painCount,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int plannedSessions;
  final int completedSessions;
  final double plannedDistanceKm;
  final double completedDistanceKm;
  final int plannedDurationMinutes;
  final int completedDurationMinutes;
  final int hardSessionCount;
  final int skippedSessionCount;
  final int veryHardSessionCount;
  final int poorRecoveryCount;
  final int painCount;

  double get completionRate =>
      plannedSessions == 0 ? 0.0 : completedSessions / plannedSessions;

  bool get hasGoodCompletion => completionRate >= 1.0;

  bool get hasLoadSignals => hasPainOrRecoverySignals || hasHighLoadSignals;

  bool get hasPainOrRecoverySignals =>
      painCount > 0 || poorRecoveryCount > 0 || skippedSessionCount > 0;

  bool get hasHighLoadSignals =>
      veryHardSessionCount > 0 ||
      hardSessionCount >= 4 ||
      skippedSessionCount > 1;

  bool get shouldTriggerAdaptationReview =>
      hasLoadSignals || (plannedSessions > 0 && completionRate < 0.65);

  List<WeeklySummarySignal> get signals {
    final detected = <WeeklySummarySignal>[];
    if (plannedSessions > 0 && completionRate < 0.65) {
      detected.add(WeeklySummarySignal.lowCompletion);
    }
    if (skippedSessionCount > 0) {
      detected.add(WeeklySummarySignal.skippedSessions);
    }
    if (painCount > 0) detected.add(WeeklySummarySignal.painConcern);
    if (poorRecoveryCount > 0) {
      detected.add(WeeklySummarySignal.poorRecovery);
    }
    if (veryHardSessionCount > 0) {
      detected.add(WeeklySummarySignal.veryHardLoad);
    }
    return detected;
  }

  static WeeklyTrainingSummary forWeek({
    required List<TrainingSession> sessions,
    required List<ActivityRecord> completedActivities,
    required List<SessionFeedback> feedbacks,
    required DateTime weekStart,
    required DateTime referenceDate,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dueCutoff = _dateOnly(referenceDate);
    final allWeekSessions = sessions
        .where((session) {
          final date = _dateOnly(session.date);
          return !date.isBefore(weekStart) && date.isBefore(weekEnd);
        })
        .where((session) => session.countsAsRun)
        .toList(growable: false);

    final feedbackBySession = _feedbackBySessionId(feedbacks);
    final completedDistanceBySession = <String, double>{};
    final completedDurationBySession = <String, int>{};
    final completedSessionIds = <String>{};

    for (final activity in completedActivities) {
      final sessionId = activity.linkedSessionId;
      if (sessionId == null || sessionId.isEmpty) continue;
      completedSessionIds.add(sessionId);
      final distance = activity.actualDistanceKm;
      final duration = activity.actualDuration?.inMinutes;
      if (distance != null) {
        completedDistanceBySession[sessionId] = distance;
      }
      if (duration != null) {
        completedDurationBySession[sessionId] = duration;
      }
    }

    final weekSessions = allWeekSessions
        .where((session) {
          final date = _dateOnly(session.date);
          return date.isBefore(dueCutoff) ||
              completedSessionIds.contains(session.id) ||
              session.status == SessionStatus.completed ||
              session.status == SessionStatus.skipped;
        })
        .toList(growable: false);

    var plannedSessions = 0;
    var completedSessions = 0;
    var plannedDistanceKm = 0.0;
    var completedDistanceKm = 0.0;
    var plannedDurationMinutes = 0;
    var completedDurationMinutes = 0;
    var hardSessionCount = 0;
    var veryHardSessionCount = 0;
    var skippedSessionCount = 0;
    var poorRecoveryCount = 0;
    var painCount = 0;

    for (final session in weekSessions) {
      plannedSessions++;
      plannedDistanceKm += session.distanceKm ?? 0.0;
      plannedDurationMinutes += session.durationMinutes ?? 0;

      if (_isHard(session, feedbackBySession[session.id])) {
        hardSessionCount++;
      }

      final feedback = feedbackBySession[session.id];
      if (feedback?.recoveryStatus == SessionRecoveryStatus.fatigued) {
        poorRecoveryCount++;
      }
      final pain = feedback?.pain;
      if (pain != null && pain != SessionFeedbackPain.none) {
        painCount++;
      }
      if (feedback?.difficulty == SessionFeedbackDifficulty.veryHard) {
        veryHardSessionCount++;
      }
      if (feedback?.difficulty == SessionFeedbackDifficulty.hard) {
        hardSessionCount++;
      }

      if (session.status == SessionStatus.completed) {
        completedSessions++;

        completedDistanceKm +=
            completedDistanceBySession[session.id] ??
            (session.distanceKm ?? 0.0);

        completedDurationMinutes +=
            completedDurationBySession[session.id] ??
            (session.durationMinutes ?? 0);
      }

      if (session.status == SessionStatus.skipped) {
        skippedSessionCount++;
      }
    }

    return WeeklyTrainingSummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      plannedSessions: plannedSessions,
      completedSessions: completedSessions,
      plannedDistanceKm: plannedDistanceKm,
      completedDistanceKm: completedDistanceKm,
      plannedDurationMinutes: plannedDurationMinutes,
      completedDurationMinutes: completedDurationMinutes,
      hardSessionCount: hardSessionCount,
      skippedSessionCount: skippedSessionCount,
      veryHardSessionCount: veryHardSessionCount,
      poorRecoveryCount: poorRecoveryCount,
      painCount: painCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'plannedSessions': plannedSessions,
      'completedSessions': completedSessions,
      'skippedSessions': skippedSessionCount,
      'plannedDistanceKm': plannedDistanceKm,
      'completedDistanceKm': completedDistanceKm,
      'plannedDurationMinutes': plannedDurationMinutes,
      'completedDurationMinutes': completedDurationMinutes,
      'plannedHardSessions': hardSessionCount,
      'completedHardSessions': 0,
      'veryHardFeedbackCount': veryHardSessionCount,
      'poorRecoveryCount': poorRecoveryCount,
      'painFeedbackCount': painCount,
      'completionRatio': completionRate,
      'distanceRatio': plannedDistanceKm <= 0
          ? 0.0
          : completedDistanceKm / plannedDistanceKm,
    };
  }

  static WeeklyTrainingSummary? fromJson(Map<String, dynamic> json) {
    try {
      return WeeklyTrainingSummary(
        weekStart: requiredDateTime(
          json,
          'weekStart',
          context: 'weekly training summary',
        ),
        weekEnd: requiredDateTime(
          json,
          'weekEnd',
          context: 'weekly training summary',
        ),
        plannedSessions:
            optionalInt(
              json['plannedSessions'] ?? json['plannedSessionCount'],
            ) ??
            0,
        completedSessions: optionalInt(json['completedSessions']) ?? 0,
        plannedDistanceKm: optionalDouble(json['plannedDistanceKm']) ?? 0.0,
        completedDistanceKm: optionalDouble(json['completedDistanceKm']) ?? 0.0,
        plannedDurationMinutes:
            optionalInt(json['plannedDurationMinutes']) ?? 0,
        completedDurationMinutes:
            optionalInt(json['completedDurationMinutes']) ?? 0,
        hardSessionCount:
            optionalInt(
              json['plannedHardSessions'] ?? json['hardSessionCount'],
            ) ??
            0,
        skippedSessionCount:
            optionalInt(
              json['skippedSessions'] ?? json['skippedSessionCount'],
            ) ??
            0,
        veryHardSessionCount:
            optionalInt(
              json['veryHardFeedbackCount'] ?? json['veryHardSessionCount'],
            ) ??
            0,
        poorRecoveryCount: optionalInt(json['poorRecoveryCount']) ?? 0,
        painCount:
            optionalInt(json['painFeedbackCount'] ?? json['painCount']) ?? 0,
      );
    } on FormatException {
      return null;
    }
  }

  static Map<String, SessionFeedback?> _feedbackBySessionId(
    List<SessionFeedback> feedbacks,
  ) {
    final map = <String, SessionFeedback?>{};
    for (final feedback in feedbacks) {
      final sessionId = feedback.plannedSessionId;
      if (sessionId == null || sessionId.isEmpty) continue;
      map[sessionId] = feedback;
    }
    return map;
  }

  static bool _isHard(TrainingSession session, SessionFeedback? feedback) {
    if (feedback != null) {
      if (feedback.difficulty == SessionFeedbackDifficulty.veryHard) {
        return true;
      }
      if (feedback.difficulty == SessionFeedbackDifficulty.hard) {
        return true;
      }
    }
    return session.effort == TrainingSessionEffort.hard;
  }
}

DateTime _mondayOf(DateTime date) {
  final weekday = date.weekday;
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

WeeklyTrainingSummary weeklyTrainingSummaryFromPlanAndActivityData({
  required List<TrainingSession> sessions,
  required List<ActivityRecord> completedActivities,
  required List<SessionFeedback> feedbacks,
  required DateTime referenceDate,
}) {
  return WeeklyTrainingSummary.forWeek(
    sessions: sessions,
    completedActivities: completedActivities,
    feedbacks: feedbacks,
    weekStart: _mondayOf(referenceDate),
    referenceDate: referenceDate,
  );
}
