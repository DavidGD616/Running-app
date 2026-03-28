import '../domain/models/user_stats.dart';
import '../domain/models/weekly_volume_data.dart';
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

const kSeedWeeklyVolume = [
  WeeklyVolumeData(distanceKm: 23, timeHours: 2, timeMinutes: 10, elevationMeters: 120, dateRange: 'FEB 16 - FEB 22'),
  WeeklyVolumeData(distanceKm: 27, timeHours: 2, timeMinutes: 35, elevationMeters: 145, dateRange: 'FEB 23 - MAR 01'),
  WeeklyVolumeData(distanceKm: 22, timeHours: 2, timeMinutes: 05, elevationMeters: 110, dateRange: 'MAR 02 - MAR 08'),
  WeeklyVolumeData(distanceKm: 25, timeHours: 2, timeMinutes: 20, elevationMeters: 135, dateRange: 'MAR 09 - MAR 15'),
  WeeklyVolumeData(distanceKm: 28, timeHours: 2, timeMinutes: 45, elevationMeters: 155, dateRange: 'MAR 16 - MAR 22'),
  WeeklyVolumeData(distanceKm: 24, timeHours: 2, timeMinutes: 30, elevationMeters: 150),
];

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
