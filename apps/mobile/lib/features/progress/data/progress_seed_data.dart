import '../domain/models/user_stats.dart';
import '../domain/models/recent_session.dart';
import '../../training_plan/domain/models/session_type.dart';

const kSeedUserStats = UserStats(
  streakWeeks: 5,
  totalDistanceKm: 65.2,
  totalTimeMinutes: 375, // 6h 15m
  totalRuns: 10,
  avgPacePerKm: '6:15',
  distanceTrendPct: 14.0,
  timeTrendPct: 5.0,
  longestRunKm: 12.0,
  longestRunImprovementKm: 4.0,
);

const kSeedRecentSessions = [
  RecentSession(
    id: 'recent-1',
    title: 'Tempo Run',
    dateLabel: 'Yesterday',
    distanceKm: 8.0,
    durationMinutes: 45,
    type: SessionType.tempoRun,
  ),
  RecentSession(
    id: 'recent-2',
    title: 'Easy Run',
    dateLabel: 'Tuesday',
    distanceKm: 5.0,
    durationMinutes: 30,
    type: SessionType.easyRun,
  ),
  RecentSession(
    id: 'recent-3',
    title: 'Long Run',
    dateLabel: 'Last Sunday',
    distanceKm: 12.0,
    durationMinutes: 75,
    type: SessionType.longRun,
  ),
];
