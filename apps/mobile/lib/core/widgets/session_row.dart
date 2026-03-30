import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../features/training_plan/domain/models/session_type.dart';

// ── Session row ───────────────────────────────────────────────────────────────

class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.dayLabel,
    required this.dateNumber,
    required this.sessionDate,
    required this.title,
    this.subtitle,
    this.distance,
    this.duration,
    required this.status,
    required this.isRest,
    required this.trailingIcon,
    required this.nowLabel,
    this.onTap,
  });

  final String dayLabel;
  final String dateNumber;
  final DateTime sessionDate;
  final String title;
  final String? subtitle;
  final String? distance;
  final String? duration;
  final SessionStatus status;
  final bool isRest;
  final String trailingIcon;
  final String nowLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isToday =
        sessionDate.year == now.year &&
        sessionDate.month == now.month &&
        sessionDate.day == now.day;
    final bool isSkipped = status == SessionStatus.skipped;
    final bool isTodaySkipped = isToday && isSkipped;
    final Color rowBg;
    final Color rowBorder;
    final Color dateBg;
    final Color dayTextColor;
    final Color dateTextColor;
    final Color titleColor;

    if (isTodaySkipped) {
      rowBg = AppColors.warning.withValues(alpha: 0.06);
      rowBorder = AppColors.warning;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.warning;
      dateTextColor = AppColors.warning;
      titleColor = AppColors.warning;
    } else if (isToday) {
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
    } else if (status == SessionStatus.completed) {
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;
      titleColor = const Color(0xFF888888);
    } else if (isSkipped) {
      rowBg = Colors.transparent;
      rowBorder = const Color(0xFF222222);
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;
      titleColor = AppColors.textDisabled;
    } else {
      // upcoming
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textPrimary;
      titleColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: isSkipped
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: isSkipped
                                ? isTodaySkipped
                                      ? AppColors.warning
                                      : AppColors.textDisabled
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.only(right: 8),
                          child: NowBadge(
                            label: nowLabel,
                            color: isTodaySkipped
                                ? AppColors.warning
                                : AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
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
                              color: isSkipped
                                  ? const Color(0xFF555555)
                                  : AppColors.textDisabled,
                              fontSize: 12,
                              letterSpacing: 0.1,
                              decoration: isSkipped
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: isSkipped
                                  ? const Color(0xFF555555)
                                  : null,
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
                              color: isSkipped
                                  ? const Color(0xFF555555)
                                  : AppColors.textDisabled,
                              fontSize: 12,
                              letterSpacing: 0.1,
                              decoration: isSkipped
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: isSkipped
                                  ? const Color(0xFF555555)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),

            // ── Trailing icon ────────────────────────────────────
            TrailingIcon(
              iconAsset: trailingIcon,
              status: status,
              isRest: isRest,
            ),
          ],
        ),
      ),
    );
  }
}

// ── "Now" badge ───────────────────────────────────────────────────────────────

class NowBadge extends StatelessWidget {
  const NowBadge({super.key, required this.label, this.color = AppColors.accentPrimary});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
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

class TrailingIcon extends StatelessWidget {
  const TrailingIcon({
    super.key,
    required this.iconAsset,
    required this.status,
    required this.isRest,
  });

  final String iconAsset;
  final SessionStatus status;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    if (status == SessionStatus.completed) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderMd,
        ),
        child: const Icon(
          Icons.check,
          color: AppColors.accentPrimary,
          size: 18,
        ),
      );
    }

    if (status == SessionStatus.skipped) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: AppRadius.borderMd,
        ),
        child: const Icon(Icons.close, color: AppColors.textDisabled, size: 18),
      );
    }

    final bool isToday = status == SessionStatus.today;
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
