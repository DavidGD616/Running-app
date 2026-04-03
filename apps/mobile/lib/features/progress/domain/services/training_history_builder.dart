import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../models/training_history_point.dart';

List<TrainingHistoryPoint> buildTrainingHistorySeries({
  required Iterable<TrainingSession> sessions,
  required TrainingHistoryRange range,
  DateTime? clock,
  String? locale,
}) {
  final now = _startOfDay(clock ?? DateTime.now());
  final completedRuns = sessions
      .where(
        (session) =>
            !session.type.isRest && session.status == SessionStatus.completed,
      )
      .toList(growable: false);

  final buckets = switch (range) {
    TrainingHistoryRange.week => _buildDailyBuckets(now: now, locale: locale),
    TrainingHistoryRange.month => _buildRollingWeeklyBuckets(
      now: now,
      locale: locale,
      bucketCount: 4,
    ),
    TrainingHistoryRange.threeMonths => _buildFortnightBuckets(
      now: now,
      locale: locale,
      bucketCount: 6,
    ),
    TrainingHistoryRange.sixMonths => _buildMonthlyBuckets(
      now: now,
      locale: locale,
      monthCount: 6,
    ),
    TrainingHistoryRange.year => _buildMonthlyBuckets(
      now: now,
      locale: locale,
      monthCount: 12,
    ),
    TrainingHistoryRange.all => _buildQuarterBuckets(
      now: now,
      locale: locale,
      earliestCompletedRun: completedRuns.isEmpty
          ? null
          : completedRuns
                .map((session) => _startOfDay(session.date))
                .reduce((a, b) => a.isBefore(b) ? a : b),
    ),
  };

  final aggregated = buckets
      .map((bucket) {
        final matchingSessions = completedRuns.where(
          (session) =>
              !session.date.isBefore(bucket.startDate) &&
              session.date.isBefore(bucket.endDate),
        );

        final totalDistanceKm = matchingSessions.fold<double>(
          0,
          (sum, session) => sum + (session.distanceKm ?? 0),
        );
        final totalMinutes = matchingSessions.fold<int>(
          0,
          (sum, session) => sum + (session.durationMinutes ?? 0),
        );
        final totalElevation = matchingSessions.fold<int>(
          0,
          (sum, session) => sum + (session.elevationGainMeters ?? 0),
        );

        return TrainingHistoryPoint(
          startDate: bucket.startDate,
          endDate: bucket.endDate,
          label: bucket.label,
          distanceKm: totalDistanceKm,
          durationMinutes: totalMinutes,
          elevationMeters: totalElevation,
          isCurrent: bucket.isCurrent,
        );
      })
      .toList(growable: false);

  final bestDistanceKm = aggregated.fold<double>(
    0,
    (maxDistance, point) => math.max(maxDistance, point.distanceKm),
  );
  if (bestDistanceKm <= 0) return aggregated;

  final bestIndex = aggregated.indexWhere(
    (point) => point.distanceKm == bestDistanceKm,
  );
  if (bestIndex == -1) return aggregated;

  return [
    for (int index = 0; index < aggregated.length; index++)
      if (index == bestIndex)
        aggregated[index].copyWith(isBest: true)
      else
        aggregated[index],
  ];
}

List<_BucketSpec> _buildDailyBuckets({
  required DateTime now,
  required String? locale,
}) {
  final formatter = DateFormat('EEE, MMM d', locale);
  return List.generate(7, (index) {
    final startDate = now.subtract(Duration(days: 6 - index));
    return _BucketSpec(
      startDate: startDate,
      endDate: startDate.add(const Duration(days: 1)),
      label: formatter.format(startDate),
      isCurrent: index == 6,
    );
  });
}

List<_BucketSpec> _buildRollingWeeklyBuckets({
  required DateTime now,
  required String? locale,
  required int bucketCount,
}) {
  final currentWeekStart = _mondayOf(now);
  return List.generate(bucketCount, (index) {
    final startDate = currentWeekStart.subtract(
      Duration(days: (bucketCount - 1 - index) * 7),
    );
    final endDate = startDate.add(const Duration(days: 7));
    return _BucketSpec(
      startDate: startDate,
      endDate: endDate,
      label: _formatDateRange(
        startDate,
        endDate.subtract(const Duration(days: 1)),
        locale,
      ),
      isCurrent: index == bucketCount - 1,
    );
  });
}

List<_BucketSpec> _buildFortnightBuckets({
  required DateTime now,
  required String? locale,
  required int bucketCount,
}) {
  final currentWeekStart = _mondayOf(now);
  final latestBucketStart = currentWeekStart.subtract(const Duration(days: 7));

  return List.generate(bucketCount, (index) {
    final startDate = latestBucketStart.subtract(
      Duration(days: (bucketCount - 1 - index) * 14),
    );
    final endDate = startDate.add(const Duration(days: 14));
    return _BucketSpec(
      startDate: startDate,
      endDate: endDate,
      label: _formatDateRange(
        startDate,
        endDate.subtract(const Duration(days: 1)),
        locale,
      ),
      isCurrent: index == bucketCount - 1,
    );
  });
}

List<_BucketSpec> _buildMonthlyBuckets({
  required DateTime now,
  required String? locale,
  required int monthCount,
}) {
  final currentMonthStart = DateTime(now.year, now.month);
  final formatter = DateFormat('MMMM yyyy', locale);

  return List.generate(monthCount, (index) {
    final startDate = _addMonths(currentMonthStart, -(monthCount - 1 - index));
    final endDate = _addMonths(startDate, 1);
    return _BucketSpec(
      startDate: startDate,
      endDate: endDate,
      label: formatter.format(startDate),
      isCurrent: index == monthCount - 1,
    );
  });
}

List<_BucketSpec> _buildQuarterBuckets({
  required DateTime now,
  required String? locale,
  required DateTime? earliestCompletedRun,
}) {
  final currentQuarterStart = _quarterStart(now);
  final startQuarter = earliestCompletedRun == null
      ? currentQuarterStart
      : _quarterStart(earliestCompletedRun);

  final buckets = <_BucketSpec>[];
  for (
    DateTime startDate = startQuarter;
    !startDate.isAfter(currentQuarterStart);
    startDate = _addMonths(startDate, 3)
  ) {
    final endDate = _addMonths(startDate, 3);
    buckets.add(
      _BucketSpec(
        startDate: startDate,
        endDate: endDate,
        label: _formatQuarterLabel(startDate, locale),
        isCurrent: _isSameMonth(startDate, currentQuarterStart),
      ),
    );
  }
  return buckets;
}

String _formatDateRange(DateTime startDate, DateTime endDate, String? locale) {
  final sameYear = startDate.year == endDate.year;
  final sameMonth = sameYear && startDate.month == endDate.month;

  if (sameMonth) {
    final formatter = DateFormat('MMM d', locale);
    return '${formatter.format(startDate)} - ${endDate.day}';
  }

  if (sameYear) {
    final formatter = DateFormat('MMM d', locale);
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  final formatter = DateFormat('MMM d, yyyy', locale);
  return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
}

String _formatQuarterLabel(DateTime startDate, String? locale) {
  final endDate = _addMonths(startDate, 3).subtract(const Duration(days: 1));
  final startFormatter = DateFormat('MMM', locale);
  final endFormatter = DateFormat('MMM yyyy', locale);
  return '${startFormatter.format(startDate)} - ${endFormatter.format(endDate)}';
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _mondayOf(DateTime date) {
  final normalized = _startOfDay(date);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

DateTime _quarterStart(DateTime date) {
  final normalized = _startOfDay(date);
  final quarterMonth = ((normalized.month - 1) ~/ 3) * 3 + 1;
  return DateTime(normalized.year, quarterMonth);
}

DateTime _addMonths(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  return DateTime(year, month);
}

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

class _BucketSpec {
  const _BucketSpec({
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.isCurrent,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final bool isCurrent;
}
