import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';

// ── Session data model ────────────────────────────────────────────────────────

enum _SessionType { rest, easyRun, intervals, longRun, recoveryRun }

enum _SessionStatus { completed, skipped, today, upcoming }

class _SessionData {
  const _SessionData({
    required this.dayLabel,
    required this.dateNumber,
    required this.type,
    required this.status,
    this.distance,
    this.duration,
  });

  final String Function(AppLocalizations) dayLabel;
  final String dateNumber;
  final _SessionType type;
  final _SessionStatus status;
  final String? distance;
  final String? duration;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WeeklyPlanScreen extends StatelessWidget {
  const WeeklyPlanScreen({super.key});

  String _sessionTitle(_SessionType type, AppLocalizations l10n) {
    switch (type) {
      case _SessionType.rest:         return l10n.weeklyPlanRestTitle;
      case _SessionType.easyRun:      return l10n.weeklyPlanSessionEasyRun;
      case _SessionType.intervals:    return l10n.weeklyPlanSessionIntervals;
      case _SessionType.longRun:      return l10n.weeklyPlanSessionLongRun;
      case _SessionType.recoveryRun:  return l10n.weeklyPlanSessionRecoveryRun;
    }
  }

  String _trailingIcon(_SessionType type) {
    switch (type) {
      case _SessionType.rest:         return 'assets/icons/coffee.svg';
      case _SessionType.easyRun:      return 'assets/icons/route.svg';
      case _SessionType.intervals:    return 'assets/icons/activity.svg';
      case _SessionType.longRun:      return 'assets/icons/target.svg';
      case _SessionType.recoveryRun:  return 'assets/icons/stopwatch.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final sessions = [
      _SessionData(dayLabel: (l) => l.weeklyPlanDayMon,   dateNumber: '12', type: _SessionType.rest,        status: _SessionStatus.upcoming),
      _SessionData(dayLabel: (l) => l.weeklyPlanDayTue,   dateNumber: '13', type: _SessionType.easyRun,     status: _SessionStatus.completed, distance: '5 km',  duration: '30 min'),
      _SessionData(dayLabel: (l) => l.weeklyPlanDayWed,   dateNumber: '14', type: _SessionType.easyRun,     status: _SessionStatus.skipped,   distance: '4 km',  duration: '25 min'),
      _SessionData(dayLabel: (l) => l.weeklyPlanDayToday, dateNumber: '15', type: _SessionType.intervals,   status: _SessionStatus.today,     distance: '6 km',  duration: '45 min'),
      _SessionData(dayLabel: (l) => l.weeklyPlanDayFri,   dateNumber: '16', type: _SessionType.rest,        status: _SessionStatus.upcoming),
      _SessionData(dayLabel: (l) => l.weeklyPlanDaySat,   dateNumber: '17', type: _SessionType.longRun,     status: _SessionStatus.upcoming,  distance: '12 km', duration: '1h 15m'),
      _SessionData(dayLabel: (l) => l.weeklyPlanDaySun,   dateNumber: '18', type: _SessionType.recoveryRun, status: _SessionStatus.upcoming,  distance: '3 km',  duration: '20 min'),
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
              // ── Title ─────────────────────────────────────────────
              Text(
                l10n.weeklyPlanTitle('1', '12'),
                style: AppTypography.titleLarge,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Week stats card
              _WeekStatsSummary(l10n: l10n),

              const SizedBox(height: AppSpacing.xl),

              // Schedule section label
              SectionLabel(label: l10n.weeklyPlanScheduleLabel),

              const SizedBox(height: AppSpacing.md),

              // Session rows
              ...sessions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SessionRow(
                  dayLabel: s.dayLabel(l10n),
                  dateNumber: s.dateNumber,
                  title: _sessionTitle(s.type, l10n),
                  subtitle: s.type == _SessionType.rest
                      ? l10n.weeklyPlanRestSubtitle
                      : null,
                  distance: s.distance,
                  duration: s.duration,
                  status: s.status,
                  isRest: s.type == _SessionType.rest,
                  trailingIcon: _trailingIcon(s.type),
                  nowLabel: l10n.weeklyPlanNowBadge,
                ),
              )),

              const SizedBox(height: AppSpacing.md),

              // View Full Plan button
              _ViewFullPlanButton(label: l10n.weeklyPlanViewFullPlan),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Week stats summary card ───────────────────────────────────────────────────

class _WeekStatsSummary extends StatelessWidget {
  const _WeekStatsSummary({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.backgroundCard),
      ),
      child: Row(
        children: [
          _StatColumn(label: l10n.weeklyPlanDistanceLabel, value: '26 km'),
          _StatColumn(
            label: l10n.weeklyPlanTimeLabel,
            value: '2h 50m',
            hasDivider: true,
          ),
          _StatColumn(
            label: l10n.weeklyPlanRunsLabel,
            value: '4',
            hasDivider: true,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.hasDivider = false,
  });

  final String label;
  final String value;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Expanded(
      child: hasDivider
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.backgroundCard),
                ),
              ),
              child: content,
            )
          : content,
    );
  }
}

// ── Session row ───────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.dayLabel,
    required this.dateNumber,
    required this.title,
    this.subtitle,
    this.distance,
    this.duration,
    required this.status,
    required this.isRest,
    required this.trailingIcon,
    required this.nowLabel,
  });

  final String dayLabel;
  final String dateNumber;
  final String title;
  final String? subtitle;
  final String? distance;
  final String? duration;
  final _SessionStatus status;
  final bool isRest;
  final String trailingIcon;
  final String nowLabel;

  @override
  Widget build(BuildContext context) {
    final bool isToday = status == _SessionStatus.today;
    final bool isSkipped = status == _SessionStatus.skipped;
    final Color rowBg;
    final Color rowBorder;
    final Color dateBg;
    final Color dayTextColor;
    final Color dateTextColor;
    final Color titleColor;

    if (isToday) {
      rowBg = AppColors.accentPrimary.withValues(alpha: 0.06);
      rowBorder = AppColors.accentPrimary;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.accentPrimary;
      dateTextColor = AppColors.accentPrimary;
      titleColor = AppColors.accentPrimary;
    } else if (isRest) {
      rowBg = Colors.transparent;
      rowBorder = const Color(0xFF222222);
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = const Color(0xFF444444);
      dateTextColor = AppColors.textDisabled;
      titleColor = const Color(0xFF555555);
    } else if (status == _SessionStatus.completed) {
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;        // #666
      titleColor = const Color(0xFF888888);          // #888 — dimmed, run is done
    } else if (isSkipped) {
      rowBg = Colors.transparent;
      rowBorder = const Color(0xFF222222);
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;        // #666
      titleColor = AppColors.textDisabled;           // #666 + strikethrough applied below
    } else {
      // upcoming
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textPrimary;
      titleColor = AppColors.textPrimary;
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: rowBorder),
      ),
      child: Row(
        children: [
          // ── Date badge ──────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dateBg,
              borderRadius: AppRadius.borderMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayLabel.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: dayTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  dateNumber,
                  style: AppTypography.titleMedium.copyWith(
                    color: dateTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + optional Now badge
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isSkipped ? TextDecoration.lineThrough : null,
                        decorationColor: isSkipped ? AppColors.textDisabled : null,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 7),
                      _NowBadge(label: nowLabel),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Subtitle (rest day) or meta (distance + duration)
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: const Color(0xFF444444),
                    ),
                  )
                else if (distance != null || duration != null)
                  Row(
                    children: [
                      if (distance != null) ...[
                        SvgPicture.asset(
                          'assets/icons/route.svg',
                          width: 12,
                          height: 12,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textDisabled,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance!,
                          style: AppTypography.caption.copyWith(
                            color: isSkipped ? const Color(0xFF555555) : AppColors.textDisabled,
                            fontSize: 12,
                            letterSpacing: 0.1,
                            decoration: isSkipped ? TextDecoration.lineThrough : null,
                            decorationColor: isSkipped ? const Color(0xFF555555) : null,
                          ),
                        ),
                      ],
                      if (distance != null && duration != null)
                        const SizedBox(width: 10),
                      if (duration != null) ...[
                        SvgPicture.asset(
                          'assets/icons/clock.svg',
                          width: 12,
                          height: 12,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textDisabled,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration!,
                          style: AppTypography.caption.copyWith(
                            color: isSkipped ? const Color(0xFF555555) : AppColors.textDisabled,
                            fontSize: 12,
                            letterSpacing: 0.1,
                            decoration: isSkipped ? TextDecoration.lineThrough : null,
                            decorationColor: isSkipped ? const Color(0xFF555555) : null,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),

          // ── Trailing icon ────────────────────────────────────
          _TrailingIcon(
            iconAsset: trailingIcon,
            status: status,
            isRest: isRest,
          ),
        ],
      ),
    );
  }
}

// ── "Now" badge ───────────────────────────────────────────────────────────────

class _NowBadge extends StatelessWidget {
  const _NowBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.accentPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Trailing icon container ───────────────────────────────────────────────────

class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({
    required this.iconAsset,
    required this.status,
    required this.isRest,
  });

  final String iconAsset;
  final _SessionStatus status;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    // Completed — muted green bg + green checkmark
    if (status == _SessionStatus.completed) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderMd,
        ),
        child: Icon(Icons.check, color: AppColors.accentPrimary, size: 18),
      );
    }

    // Skipped — dark rounded square with X
    if (status == _SessionStatus.skipped) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: AppRadius.borderMd,
        ),
        child: Icon(Icons.close, color: AppColors.textDisabled, size: 18),
      );
    }

    // Today / upcoming / rest — SVG icon
    final bool isToday = status == _SessionStatus.today;
    final Color boxBg;
    final Color iconColor;
    final double opacity;
    final Border? border;

    if (isToday) {
      boxBg = AppColors.accentPrimary.withValues(alpha: 0.15);
      iconColor = AppColors.accentPrimary;
      opacity = 1.0;
      border = Border.all(
        color: AppColors.accentPrimary.withValues(alpha: 0.25),
      );
    } else if (isRest) {
      boxBg = Colors.transparent;
      iconColor = AppColors.textDisabled;
      opacity = 0.4;
      border = null;
    } else {
      boxBg = const Color(0xFF222222);
      iconColor = AppColors.textDisabled;
      opacity = 1.0;
      border = null;
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: boxBg,
          borderRadius: AppRadius.borderMd,
          border: border,
        ),
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

// ── View Full Plan button ─────────────────────────────────────────────────────

class _ViewFullPlanButton extends StatelessWidget {
  const _ViewFullPlanButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/calendar.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.accentPrimary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
