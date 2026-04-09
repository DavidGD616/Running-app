import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

class WorkoutHeroCard extends StatelessWidget {
  const WorkoutHeroCard({
    super.key,
    required this.sessionType,
    required this.sessionName,
    required this.duration,
    required this.distance,
    this.targetGuidance,
    this.sessionTypeIconAsset,
    this.onViewDetails,
  });

  final String sessionType;
  final String sessionName;
  final String duration;
  final String distance;
  final String? targetGuidance;
  final String? sessionTypeIconAsset;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + type + name ─────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    sessionTypeIconAsset ?? 'assets/icons/zap.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.accentPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionType.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(sessionName, style: AppTypography.titleLarge),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.base),

          // ── Stats: Duration | Distance ──────────────────────
          ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(label: l10n.workoutDurationLabel, value: duration),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.borderDefault,
                  ),
                  Expanded(
                    child: _StatCell(label: l10n.workoutDistanceLabel, value: distance),
                  ),
                ],
              ),
            ),
          ),

          // ── Target Guidance ─────────────────────────────────
          if (targetGuidance != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: const Color(0x1200E676),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: const Color(0x3300E676)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.workoutTargetGuidanceLabel.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPrimary,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(targetGuidance!, style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.base),

          // ── Button: View Workout ────────────────────────────
          _ViewDetailsButton(onTap: onViewDetails),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundElevated,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textDisabled,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewDetailsButton extends StatelessWidget {
  const _ViewDetailsButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.info),
          color: AppColors.info.withValues(alpha: 0.08),
        ),
        child: Center(
          child: Text(
            l10n.workoutViewDetailsButton,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

