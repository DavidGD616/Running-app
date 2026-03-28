import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/router/route_names.dart';
import '../../../../l10n/app_localizations.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.sessionDetailTitle,
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.md,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Session type badge ─────────────────────────
                  _TypeBadge(label: l10n.sessionDetailSessionType),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Session name ───────────────────────────────
                  Text(
                    l10n.sessionDetailSessionName,
                    style: AppTypography.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Description ────────────────────────────────
                  Text(
                    l10n.sessionDetailDescription,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Stat tiles ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          iconAsset: 'assets/icons/route.svg',
                          label: l10n.sessionDetailTotalDistanceLabel,
                          value: l10n.sessionDetailDistanceValue,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatTile(
                          iconAsset: 'assets/icons/stopwatch.svg',
                          label: l10n.sessionDetailEstDurationLabel,
                          value: l10n.sessionDetailDurationValue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Workout Structure ──────────────────────────
                  Text(
                    l10n.sessionDetailWorkoutStructure,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Timeline ───────────────────────────────────
                  _PhaseItem(
                    iconAsset: 'assets/icons/flame.svg',
                    iconBgColor: AppColors.warning.withValues(alpha: 0.08),
                    iconColor: AppColors.warning,
                    title: l10n.sessionDetailWarmUp,
                    duration: l10n.sessionDetailWarmUpDuration,
                    note: l10n.sessionDetailWarmUpNote,
                  ),
                  _PhaseItem(
                    iconAsset: 'assets/icons/activity.svg',
                    iconBgColor: AppColors.error.withValues(alpha: 0.08),
                    iconColor: AppColors.error,
                    title: l10n.sessionDetailIntervals,
                    duration: l10n.sessionDetailIntervalsDuration,
                    note: l10n.sessionDetailIntervalsNote,
                    recoveryNote: l10n.sessionDetailIntervalsRecovery,
                    cardBorderColor: AppColors.error.withValues(alpha: 0.5),
                  ),
                  _PhaseItem(
                    iconAsset: 'assets/icons/heart_rate.svg',
                    iconBgColor: AppColors.info.withValues(alpha: 0.08),
                    iconColor: AppColors.info,
                    title: l10n.sessionDetailCoolDown,
                    duration: l10n.sessionDetailCoolDownDuration,
                    note: l10n.sessionDetailCoolDownNote,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Start Workout button ───────────────────────────────
          _StartButton(
            label: l10n.sessionDetailStartWorkout,
            onTap: () => context.push(RouteNames.logRun),
          ),
        ],
      ),
    );
  }
}

// ── Session type badge ────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.accentPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textDisabled,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.headlineMedium,
          ),
        ],
      ),
    );
  }
}

// ── Timeline phase item ───────────────────────────────────────────────────────

class _PhaseItem extends StatelessWidget {
  const _PhaseItem({
    required this.iconAsset,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.duration,
    required this.note,
    this.recoveryNote,
    this.cardBorderColor,
    this.isLast = false,
  });

  final String iconAsset;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String duration;
  final String note;
  final String? recoveryNote;
  final Color? cardBorderColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: icon circle + connecting line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColors.surfaceElevated,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Right: card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(
                    color: cardBorderColor ?? AppColors.borderDefault,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      duration,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                    if (recoveryNote != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(height: 1, color: AppColors.surfaceElevated),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        recoveryNote!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start Workout button ──────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundPrimary.withValues(alpha: 0),
            AppColors.backgroundPrimary,
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen, AppSpacing.md,
        AppSpacing.screen, AppSpacing.xl,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.borderLg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/play.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.backgroundPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.backgroundPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
