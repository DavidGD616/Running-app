import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class WeeklyCalendarCard extends StatelessWidget {
  const WeeklyCalendarCard({
    super.key,
    required this.currentWeek,
    required this.totalWeeks,
    required this.sessionsCompleted,
    required this.totalSessions,
    required this.activeDayIndices,
    this.selectedDayIndex,
    this.onDayTap,
  });

  final int currentWeek;
  final int totalWeeks;
  final int sessionsCompleted;
  final int totalSessions;
  /// 0 = Monday, 6 = Sunday
  final List<int> activeDayIndices;
  final int? selectedDayIndex;
  final ValueChanged<int>? onDayTap;

  double get _progress =>
      totalSessions == 0 ? 0 : sessionsCompleted / totalSessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabels = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weeklyPlanTitle(
              currentWeek.toString(),
              totalWeeks.toString(),
            ),
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) => _DayDot(
              label: dayLabels[i],
              isActive: activeDayIndices.contains(i),
              isSelected: selectedDayIndex == i,
              onTap: onDayTap != null ? () => onDayTap!(i) : null,
            )),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.borderDefault, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.weeklyCalendarSessionsDone(
                  sessionsCompleted.toString(),
                  totalSessions.toString(),
                ),
                style: AppTypography.bodyMedium,
              ),
              Text(
                '${(_progress * 100).round()}%',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.borderFull,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.borderDefault,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.isActive,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.accentPrimary
                  : isActive
                      ? AppColors.accentMuted
                      : Colors.transparent,
              border: isActive && !isSelected
                  ? Border.all(color: AppColors.accentPrimary, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.backgroundPrimary
                    : isActive
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPrimary,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
