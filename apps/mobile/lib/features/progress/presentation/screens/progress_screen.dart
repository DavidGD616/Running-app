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

  static const _weeklyData = [15.0, 20.0, 24.0, 22.0, 30.0];
  static const _currentWeekIndex = 4;
  static const _completedRuns = 2;
  static const _totalRuns = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1E1E), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progressWeeklyVolumeTitle,
                    style: AppTypography.titleMedium.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
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
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_completedRuns ',
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '/ $_totalRuns',
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 18,
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.progressRunsThisWeek,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Chart ───────────────────────────────────────────
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ChartPainter(
                data: _weeklyData,
                currentIndex: _currentWeekIndex,
              ),
              size: Size.infinite,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Week labels ─────────────────────────────────────
          _WeekLabels(currentIndex: _currentWeekIndex),
        ],
      ),
    );
  }
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.data, required this.currentIndex});

  final List<double> data;
  final int currentIndex;

  static const _maxVal = 35.0;
  static const _minVal = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    double yFor(double v) =>
        size.height * (1.0 - (v - _minVal) / (_maxVal - _minVal));
    double xFor(int i) => size.width * i / (data.length - 1);

    final points = List.generate(
      data.length,
      (i) => Offset(xFor(i), yFor(data[i])),
    );

    // 1. Dashed grid lines at 16.89%, 50%, 83.11% height
    final gridPaint = Paint()
      ..color = AppColors.borderDefault
      ..strokeWidth = 0.5;
    for (final ratio in [0.1689, 0.5, 0.8311]) {
      final y = size.height * ratio;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Gradient fill below line
    final fillPath = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final topY = yFor(data.reduce((a, b) => a > b ? a : b));
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topY),
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

    // 4. Dots and value labels
    for (int i = 0; i < data.length; i++) {
      final isCurrent = i == currentIndex;
      final center = points[i];
      final outerRadius = isCurrent ? 5.5 : 4.0;

      // Dot: green outer, dark inner for current
      canvas.drawCircle(center, outerRadius, Paint()..color = AppColors.accentPrimary);
      if (isCurrent) {
        canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFF121212));
      }

      // Value label above dot
      final labelText = data[i].toInt().toString();
      final labelStyle = ui.TextStyle(
        color: isCurrent ? Colors.white : const Color(0xFFB3B3B3),
        fontSize: 10.0,
        fontWeight: isCurrent ? ui.FontWeight.w700 : ui.FontWeight.w400,
      );
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(labelStyle)
        ..addText(labelText);
      final paragraph = pb.build()..layout(const ui.ParagraphConstraints(width: 30));
      canvas.drawParagraph(
        paragraph,
        Offset(center.dx - 15, center.dy - outerRadius - paragraph.height - 2),
      );
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
      old.data != data || old.currentIndex != currentIndex;
}

// ── Week labels row ───────────────────────────────────────────────────────────

class _WeekLabels extends StatelessWidget {
  const _WeekLabels({required this.currentIndex});

  final int currentIndex;

  static const _labels = ['W1', 'W2', 'W3', 'W4', 'W5'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_labels.length, (i) {
            final isCurrent = i == currentIndex;
            return Container(
              padding: isCurrent
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                  : null,
              decoration: isCurrent
                  ? BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                _labels[i],
                style: AppTypography.caption.copyWith(
                  color: isCurrent
                      ? AppColors.accentPrimary
                      : AppColors.textDisabled,
                  fontSize: 11,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
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
