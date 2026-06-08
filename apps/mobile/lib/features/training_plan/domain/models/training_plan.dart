import 'model_json_utils.dart';
import 'plan_week.dart';
import 'professional_plan_metadata.dart';
import 'race_guidance.dart';
import 'session_type.dart';
import 'support_session.dart';
import 'training_session.dart';
import '../../../strava/domain/models/strava_coaching_profile.dart';

enum TrainingPlanRaceType { fiveK, tenK, halfMarathon, marathon, other }

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.raceType,
    required this.totalWeeks,
    required this.currentWeekNumber,
    required this.sessions,
    this.supportSessions = const [],
    this.paceZones,
    this.raceGuidance,
    this.generatedLocale = 'en',
    this.coachingBriefSnapshot,
    this.planRationale = const [],
    this.evidenceTarget,
    this.ambitiousTarget,
    this.confidence,
    this.phaseStrategy = const [],
    this.stravaCoachingProfileSnapshot,
  });

  final String id;
  final TrainingPlanRaceType raceType;
  final int totalWeeks;
  final int currentWeekNumber;
  final List<TrainingSession> sessions;
  final List<SupportSession> supportSessions;
  final StravaPaceZones? paceZones;
  final RaceGuidance? raceGuidance;
  final String generatedLocale;
  final CoachingBriefSnapshot? coachingBriefSnapshot;
  final List<String> planRationale;
  final CoachingTarget? evidenceTarget;
  final CoachingTarget? ambitiousTarget;
  final CoachingConfidence? confidence;
  final List<PhaseStrategy> phaseStrategy;
  final StravaCoachingProfile? stravaCoachingProfileSnapshot;

  /// Sessions belonging to the current ISO week (Mon–Sun).
  List<TrainingSession> get currentWeekSessions {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return sessions
        .where((s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Support sessions belonging to the current ISO week (Mon–Sun).
  List<SupportSession> get currentWeekSupportSessions => const [];

  /// The session scheduled for today (status == today).
  TrainingSession? get todaySession {
    for (final s in sessions) {
      if (s.status == SessionStatus.today) return s;
    }
    return null;
  }

  /// First upcoming session after today (future dates only).
  TrainingSession? get nextUpcomingSession {
    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    final candidates =
        sessions
            .where(
              (s) =>
                  s.status == SessionStatus.upcoming &&
                  !s.date.isBefore(todayDay),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// All weeks in the plan, grouped by weekNumber and sorted ascending.
  List<PlanWeek> get allWeeks {
    final grouped = <int, List<TrainingSession>>{};
    for (final s in sessions) {
      grouped.putIfAbsent(s.weekNumber, () => []).add(s);
    }
    final weekNumbers = grouped.keys.toList()..sort();
    return weekNumbers.map((n) {
      final sorted = List<TrainingSession>.from(grouped[n] ?? const []);
      sorted.sort((a, b) => a.date.compareTo(b.date));
      return PlanWeek(weekNumber: n, sessions: sorted);
    }).toList();
  }

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'raceType': raceType.name,
    'totalWeeks': totalWeeks,
    'currentWeekNumber': currentWeekNumber,
    'sessions': sessions.map((s) => s.toJson()).toList(),
    if (paceZones != null) 'paceZones': paceZones!.toJson(),
    if (raceGuidance != null) 'raceGuidance': raceGuidance!.toJson(),
    'generatedLocale': generatedLocale,
    if (coachingBriefSnapshot != null)
      'coachingBriefSnapshot': coachingBriefSnapshot!.toJson(),
    if (planRationale.isNotEmpty) 'planRationale': planRationale,
    if (evidenceTarget != null) 'evidenceTarget': evidenceTarget!.toJson(),
    if (ambitiousTarget != null) 'ambitiousTarget': ambitiousTarget!.toJson(),
    if (confidence != null) 'confidence': confidence!.key,
    if (phaseStrategy.isNotEmpty)
      'phaseStrategy': phaseStrategy.map((phase) => phase.toJson()).toList(),
    if (stravaCoachingProfileSnapshot != null)
      'stravaCoachingProfileSnapshot': stravaCoachingProfileSnapshot!.toJson(),
  };

  static TrainingPlan? fromJson(Map<String, dynamic> json) {
    final id = stringOrNull(json['id']);
    final raceType = _raceTypeFromName(stringOrNull(json['raceType']));
    final totalWeeks = intOrNull(json['totalWeeks']);
    final currentWeekNumber = intOrNull(json['currentWeekNumber']);
    if (id == null ||
        id.isEmpty ||
        raceType == null ||
        totalWeeks == null ||
        currentWeekNumber == null) {
      return null;
    }

    final sessions = <TrainingSession>[];
    final rawSessions = json['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        if (item is Map<String, dynamic>) {
          final s = TrainingSession.fromJson(item);
          if (s != null) sessions.add(s);
        }
      }
    }

    StravaPaceZones? paceZones;
    final rawPaceZones = json['paceZones'];
    if (rawPaceZones is Map<String, dynamic>) {
      paceZones = StravaPaceZones.fromJson(rawPaceZones);
    } else if (rawPaceZones is Map) {
      paceZones = StravaPaceZones.fromJson(
        rawPaceZones.map((key, value) => MapEntry('$key', value)),
      );
    }

    RaceGuidance? raceGuidance;
    final rawRaceGuidance = json['raceGuidance'];
    if (rawRaceGuidance is Map<String, dynamic>) {
      raceGuidance = RaceGuidance.fromJson(rawRaceGuidance);
    } else if (rawRaceGuidance is Map) {
      raceGuidance = RaceGuidance.fromJson(
        rawRaceGuidance.map((key, value) => MapEntry('$key', value)),
      );
    }

    StravaCoachingProfile? stravaCoachingProfileSnapshot;
    final rawStravaCoachingProfileSnapshot =
        json['stravaCoachingProfileSnapshot'];
    if (rawStravaCoachingProfileSnapshot is Map<String, dynamic>) {
      try {
        stravaCoachingProfileSnapshot = StravaCoachingProfile.fromJson(
          rawStravaCoachingProfileSnapshot,
        );
      } on FormatException {
        stravaCoachingProfileSnapshot = null;
      }
    } else if (rawStravaCoachingProfileSnapshot is Map) {
      try {
        stravaCoachingProfileSnapshot = StravaCoachingProfile.fromJson(
          rawStravaCoachingProfileSnapshot.map(
            (key, value) => MapEntry('$key', value),
          ),
        );
      } on FormatException {
        stravaCoachingProfileSnapshot = null;
      }
    }

    return TrainingPlan(
      id: id,
      raceType: raceType,
      totalWeeks: totalWeeks,
      currentWeekNumber: currentWeekNumber,
      sessions: sessions,
      supportSessions: const [],
      paceZones: paceZones,
      raceGuidance: raceGuidance,
      generatedLocale: stringOrNull(json['generatedLocale']) ?? 'en',
      coachingBriefSnapshot: coachingBriefSnapshotOrNull(
        json['coachingBriefSnapshot'],
      ),
      planRationale: stringListOrEmpty(json['planRationale']),
      evidenceTarget: coachingTargetOrNull(json['evidenceTarget']),
      ambitiousTarget: coachingTargetOrNull(json['ambitiousTarget']),
      confidence: CoachingConfidence.fromKey(stringOrNull(json['confidence'])),
      phaseStrategy: phaseStrategyListOrEmpty(json['phaseStrategy']),
      stravaCoachingProfileSnapshot: stravaCoachingProfileSnapshot,
    );
  }

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday; // 1 = Mon, 7 = Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}

TrainingPlanRaceType? _raceTypeFromName(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final v in TrainingPlanRaceType.values) {
    if (v.name == name) return v;
  }
  return null;
}
