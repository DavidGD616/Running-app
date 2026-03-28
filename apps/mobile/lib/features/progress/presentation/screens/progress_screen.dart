import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/streak_banner.dart';
import '../../../../l10n/app_localizations.dart';

// ── Recent session data ───────────────────────────────────────────────────────

class _RecentSession {
  const _RecentSession({
    required this.title,
    required this.meta,
    required this.duration,
    required this.iconAsset,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String meta;
  final String duration;
  final String iconAsset;
  final Color iconBg;
  final Color iconColor;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final sessions = [
      _RecentSession(
        title: l10n.progressSessionTempoRun,
        meta: '${l10n.progressYesterday} • 8.0 km',
        duration: '45 min',
        iconAsset: 'assets/icons/activity.svg',
        iconBg: AppColors.accentPrimary.withValues(alpha: 0.1),
        iconColor: AppColors.accentPrimary,
      ),
      _RecentSession(
        title: l10n.weeklyPlanSessionEasyRun,
        meta: '${l10n.progressTuesdayLabel} • 5.0 km',
        duration: '30 min',
        iconAsset: 'assets/icons/heart.svg',
        iconBg: AppColors.info.withValues(alpha: 0.1),
        iconColor: AppColors.info,
      ),
      _RecentSession(
        title: l10n.weeklyPlanSessionLongRun,
        meta: '${l10n.progressLastSunday} • 12.0 km',
        duration: '1h 15m',
        iconAsset: 'assets/icons/target.svg',
        iconBg: AppColors.warning.withValues(alpha: 0.1),
        iconColor: AppColors.warning,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg,
            AppSpacing.screen, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + subtitle ──────────────────────────────────
              Text(l10n.progressTitle, style: AppTypography.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.progressSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Streak banner ─────────────────────────────────────
              StreakBanner(
                streakWeeks: 5,
                subtitle: l10n.progressStreakBannerSubtitle,
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Weekly volume chart ───────────────────────────────
              _VolumeChartCard(l10n: l10n),

              const SizedBox(height: AppSpacing.md),

              // ── Stats 2×2 grid ────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ProgressStatTile(
                        iconAsset: 'assets/icons/route.svg',
                        iconColor: AppColors.accentPrimary,
                        label: l10n.progressDistanceLabel,
                        value: '65.2',
                        unit: 'km',
                        trend: l10n.progressTrendUp('14'),
                        trendColor: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _ProgressStatTile(
                        iconAsset: 'assets/icons/clock.svg',
                        iconColor: AppColors.info,
                        label: l10n.progressTimeLabel,
                        timeHours: '6',
                        timeMinutes: '15',
                        hourUnit: l10n.progressHourUnit,
                        minuteUnit: l10n.progressMinuteUnit,
                        trend: l10n.progressTrendUp('5'),
                        trendColor: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ProgressStatTile(
                        iconAsset: 'assets/icons/flame.svg',
                        iconColor: AppColors.warning,
                        label: l10n.progressStreakLabel,
                        value: '4',
                        unit: ' ${l10n.progressWeeksUnit}',
                        valueColor: AppColors.warning,
                        trend: l10n.progressStreakSubtitle('4'),
                        trendColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _ProgressStatTile(
                        iconAsset: 'assets/icons/circle_check.svg',
                        iconColor: const Color(0xFFAB47BC),
                        label: l10n.progressRunsLabel,
                        value: '10',
                        trend: l10n.progressRunsCompleted,
                        trendColor: const Color(0xFFAB47BC),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Longest run card ──────────────────────────────────
              _LongestRunCard(l10n: l10n),

              const SizedBox(height: AppSpacing.md),

              // ── Recent sessions ───────────────────────────────────
              _RecentSessionsCard(sessions: sessions, l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Weekly volume chart card ──────────────────────────────────────────────────

class _VolumeChartCard extends StatelessWidget {
  const _VolumeChartCard({required this.l10n});

  final AppLocalizations l10n;

  static const _weeklyData = [23.0, 27.0, 22.0, 25.0, 28.0, 24.0];
  static const _selectedIndex = 5;
  static const _maxVal = 46.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1E1E), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.base,
            ),
            child: Row(
              children: [
                Text(
                  l10n.progressWeeklyVolumeTitle,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(width: AppSpacing.sm),
                SvgPicture.asset(
                  'assets/icons/trending_up.svg',
                  width: 12,
                  height: 12,
                  colorFilter: const ColorFilter.mode(
                    AppColors.accentPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.progressTrendingUp,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),

          // ── Current week stats card ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progressCurrentWeek,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _WeekStatItem(
                            iconAsset: 'assets/icons/compass.svg',
                            iconColor: AppColors.accentPrimary,
                            label: l10n.progressDistanceLabel,
                            value: '28',
                            unit: ' km',
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: const Color(0xFF2A2A2A),
                        ),
                        Expanded(
                          child: _WeekStatItem(
                            iconAsset: 'assets/icons/clock.svg',
                            iconColor: AppColors.info,
                            label: l10n.progressTimeLabel,
                            value: '2${l10n.progressHourUnit} 30${l10n.progressMinuteUnit}',
                            unit: '',
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: const Color(0xFF2A2A2A),
                        ),
                        Expanded(
                          child: _WeekStatItem(
                            iconAsset: 'assets/icons/mountain.svg',
                            iconColor: AppColors.warning,
                            label: l10n.progressElevationLabel,
                            value: '150',
                            unit: ' m',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.base),

          // ── Chart with Y-axis labels ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('46 km', style: AppTypography.caption.copyWith(color: const Color(0xFF666666), fontSize: 11, letterSpacing: 0)),
                      Text('23 km', style: AppTypography.caption.copyWith(color: const Color(0xFF666666), fontSize: 11, letterSpacing: 0)),
                      Text('0 km', style: AppTypography.caption.copyWith(color: const Color(0xFF666666), fontSize: 11, letterSpacing: 0)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomPaint(
                      painter: _ChartPainter(
                        data: _weeklyData,
                        selectedIndex: _selectedIndex,
                        maxVal: _maxVal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.base),

          // ── See Full Data footer ────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/bar_chart.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.accentPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.progressSeeFullData,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                SvgPicture.asset(
                  'assets/icons/chevron_right.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.accentPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week stat item ────────────────────────────────────────────────────────────

class _WeekStatItem extends StatelessWidget {
  const _WeekStatItem({
    required this.iconAsset,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String iconAsset;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 11,
                height: 11,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFF888888),
                  fontSize: 11,
                  letterSpacing: 0.06,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.31,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      color: Color(0xFFB3B3B3),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.maxVal,
  });

  final List<double> data;
  final int selectedIndex;
  final double maxVal;

  @override
  void paint(Canvas canvas, Size size) {
    double yFor(double v) => size.height * (1.0 - v / maxVal);
    double xFor(int i) => size.width * i / (data.length - 1);

    final points = List.generate(data.length, (i) => Offset(xFor(i), yFor(data[i])));

    // 1. Dashed grid lines at 0 km, 23 km, 46 km (bottom, middle, top)
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 0.5;
    for (final y in [0.0, size.height / 2, size.height]) {
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Gradient fill below line
    final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          AppColors.accentPrimary.withValues(alpha: 0.25),
          AppColors.accentPrimary.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    // 3. Line
    final linePaint = Paint()
      ..color = AppColors.accentPrimary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // 4. Vertical dashed line from selected point to bottom
    final selectedPoint = points[selectedIndex];
    final dashLinePaint = Paint()
      ..color = AppColors.accentPrimary.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    _drawDashedLine(
      canvas,
      Offset(selectedPoint.dx, selectedPoint.dy),
      Offset(selectedPoint.dx, size.height),
      dashLinePaint,
    );

    // 5. Dots
    for (int i = 0; i < data.length; i++) {
      final isSelected = i == selectedIndex;
      final center = points[i];

      if (isSelected) {
        canvas.drawCircle(center, 5.5, Paint()..color = AppColors.accentPrimary);
      } else {
        // Hollow dot: dark fill + green stroke
        canvas.drawCircle(center, 4.0, Paint()..color = const Color(0xFF1A1A1A));
        canvas.drawCircle(
          center,
          4.0,
          Paint()
            ..color = AppColors.accentPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double distance = 0;
    while (distance < totalLength) {
      final dashEnd = math.min(distance + dashWidth, totalLength);
      canvas.drawLine(
        start + direction * distance,
        start + direction * dashEnd,
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.data != data || old.selectedIndex != selectedIndex || old.maxVal != maxVal;
}

// ── Progress stat tile ────────────────────────────────────────────────────────

class _ProgressStatTile extends StatelessWidget {
  const _ProgressStatTile({
    required this.iconAsset,
    required this.iconColor,
    required this.label,
    required this.trend,
    required this.trendColor,
    this.value,
    this.unit,
    this.valueColor,
    this.timeHours,
    this.timeMinutes,
    this.hourUnit,
    this.minuteUnit,
  });

  final String iconAsset;
  final Color iconColor;
  final String label;
  final String? value;
  final String? unit;
  final Color? valueColor;
  final String? timeHours;
  final String? timeMinutes;
  final String? hourUnit;
  final String? minuteUnit;
  final String trend;
  final Color trendColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + label
          Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Value
          _buildValue(),

          const SizedBox(height: AppSpacing.xs),

          // Trend
          Text(
            trend,
            style: AppTypography.caption.copyWith(
              color: trendColor,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValue() {
    if (timeHours != null) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: timeHours,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: hourUnit ?? 'h',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: ' $timeMinutes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: minuteUnit ?? 'm',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value ?? '',
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unit != null)
            TextSpan(
              text: unit,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Longest run card ──────────────────────────────────────────────────────────

class _LongestRunCard extends StatelessWidget {
  const _LongestRunCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242424), Color(0xFF1E1E1E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Star icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.25),
              ),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/star.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.base),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.progressLongestRunTitle,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.progressLongestRunImproved('4.0'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Value
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '12.0',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' km',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent sessions card ──────────────────────────────────────────────────────

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard({
    required this.sessions,
    required this.l10n,
  });

  final List<_RecentSession> sessions;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.progressRecentSessionsTitle,
                style: AppTypography.titleMedium.copyWith(fontSize: 18),
              ),
              Text(
                l10n.progressViewAll,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.accentPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Session rows
          ...sessions.asMap().entries.map((entry) {
            final isLast = entry.key == sessions.length - 1;
            final s = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: s.iconBg,
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            s.iconAsset,
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              s.iconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.meta,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textDisabled,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s.duration,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: AppColors.borderDefault.withValues(alpha: 0.6),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
