import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Runs',
                  value: '$sessionsCompleted/$totalSessions sessions done',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.borderDefault,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.base),
                  child: _StatColumn(
                    label: 'Volume',
                    value:
                        '${volumeCompleted.toStringAsFixed(1)} $volumeUnit this week',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.borderFull,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.borderDefault,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  footerMessage ??
                      'On track to hit ${totalVolume.toStringAsFixed(1)} $volumeUnit planned',
                  style: AppTypography.caption,
                ),
              ),
              Text(
                '${(_progress * 100).round()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.bodyMedium),
      ],
    );
  }
}
