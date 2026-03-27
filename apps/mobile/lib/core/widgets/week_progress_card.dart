import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

class WeekProgressCard extends StatelessWidget {
  const WeekProgressCard({
    super.key,
    required this.sessionsCompleted,
    required this.totalSessions,
    required this.volumeCompleted,
    required this.totalVolume,
    required this.volumeUnit,
    this.footerMessage,
  });

  final int sessionsCompleted;
  final int totalSessions;
  final double volumeCompleted;
  final double totalVolume;
  final String volumeUnit;
  final String? footerMessage;

  double get _progress =>
      totalSessions == 0 ? 0 : sessionsCompleted / totalSessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Runs / Volume row ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Runs — left aligned
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.weekProgressRunsLabel.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$sessionsCompleted ',
                          style: AppTypography.headlineLarge,
                        ),
                        TextSpan(
                          text: '/ $totalSessions',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Volume — right aligned
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.weekProgressVolumeLabel.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${volumeCompleted.toStringAsFixed(1)} ',
                          style: AppTypography.headlineLarge,
                        ),
                        TextSpan(
                          text: volumeUnit,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Progress bar ───────────────────────────────────
          ClipRRect(
            borderRadius: AppRadius.borderFull,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.backgroundCard,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Footer ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  footerMessage ??
                      l10n.weekProgressFooter(totalVolume.toStringAsFixed(1), volumeUnit),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
              Text(
                '${(_progress * 100).round()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
