import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

enum SessionCardVariant { upcoming, completed, restDay }

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.day,
    required this.title,
    this.sessionType,
    this.duration,
    this.pace,
    this.zone,
    this.completedTime,
    this.variant = SessionCardVariant.upcoming,
    this.onTap,
  });

  final String day;
  final String title;
  final String? sessionType;
  final String? duration;
  final String? pace;
  final String? zone;
  final String? completedTime;
  final SessionCardVariant variant;
  final VoidCallback? onTap;

  Color get _accentColor {
    switch (variant) {
      case SessionCardVariant.upcoming:
        return AppColors.accentPrimary;
      case SessionCardVariant.completed:
        return AppColors.success;
      case SessionCardVariant.restDay:
        return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variant == SessionCardVariant.restDay) {
      return _RestDayCard(day: day);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: AppRadius.borderFull,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(day, style: AppTypography.caption),
                      if (sessionType != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _SessionTypeBadge(label: sessionType!, variant: variant),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (duration != null)
                        Text(duration!, style: AppTypography.bodyMedium),
                      if (duration != null && pace != null)
                        Text('  ·  ', style: AppTypography.bodyMedium),
                      if (pace != null)
                        Text(pace!, style: AppTypography.bodyMedium),
                      if (pace != null && zone != null)
                        Text('  ·  ', style: AppTypography.bodyMedium),
                      if (zone != null)
                        Text(zone!, style: AppTypography.bodyMedium),
                    ],
                  ),
                  if (variant == SessionCardVariant.completed &&
                      completedTime != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(color: AppColors.borderDefault, height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/circle_check.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                              AppColors.success, BlendMode.srcIn),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Completed · $completedTime',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (variant == SessionCardVariant.completed)
              SvgPicture.asset(
                'assets/icons/circle_check.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                    AppColors.success, BlendMode.srcIn),
              )
            else
              SvgPicture.asset(
                'assets/icons/chevron_right.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary, BlendMode.srcIn),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionTypeBadge extends StatelessWidget {
  const _SessionTypeBadge({
    required this.label,
    required this.variant,
  });

  final String label;
  final SessionCardVariant variant;

  Color get _color {
    switch (variant) {
      case SessionCardVariant.completed:
        return AppColors.success;
      case SessionCardVariant.upcoming:
        return AppColors.accentPrimary;
      case SessionCardVariant.restDay:
        return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: _color),
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({required this.day});

  final String day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.textDisabled,
              borderRadius: AppRadius.borderFull,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.weeklyPlanRestTitle, style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                )),
              ],
            ),
          ),
          SvgPicture.asset(
            'assets/icons/moon.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
                AppColors.textDisabled, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}
