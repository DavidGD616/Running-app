import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../../domain/models/adaptation_review.dart';
import '../../domain/models/weekly_training_summary.dart';
import '../adaptation_actions_provider.dart';
import '../training_plan_provider.dart';

class AdaptationReviewScreen extends ConsumerWidget {
  const AdaptationReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final actionState = ref.watch(adaptationActionsProvider);
    final pendingReview = ref.watch(pendingAdaptationReviewProvider);
    final review =
        pendingReview ??
        (actionState is AdaptationReviewReady ? actionState.review : null);
    final isLoading = actionState is AdaptationActionLoading;
    final localSummary = ref.watch(weeklyTrainingSummaryProvider);
    final summary = review?.weeklySummary ?? localSummary;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.adaptationReviewTitle),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (actionState is AdaptationActionFailure) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.adaptationActionError,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (review == null)
                _EmptyReviewState(
                  isLoading: isLoading,
                  onGenerate: () => ref
                      .read(adaptationActionsProvider.notifier)
                      .requestWeeklyReview(
                        weekStart: localSummary.weekStart,
                        weekEnd: localSummary.weekEnd,
                      ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReviewHeader(review: review),
                    const SizedBox(height: AppSpacing.md),
                    _WeeklySnapshot(summary: summary, unitSystem: unitSystem),
                    const SizedBox(height: AppSpacing.md),
                    _ReasonList(review: review),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: l10n.adaptationReviewChanges,
                      onPressed: () => context.push(RouteNames.adaptationDiff),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: l10n.adaptationKeepOriginal,
                      variant: AppButtonVariant.secondary,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () async {
                              final succeeded = await ref
                                  .read(adaptationActionsProvider.notifier)
                                  .dismissReview(review);
                              if (succeeded && context.mounted) {
                                context.go(RouteNames.today);
                              }
                            },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState({required this.isLoading, required this.onGenerate});

  final bool isLoading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adaptationNoReviewTitle,
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.adaptationNoReviewBody,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.adaptationGenerateReview,
          onPressed: isLoading ? null : onGenerate,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.review});

  final AdaptationReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _severityColor(review.severity);
    return _Surface(
      borderColor: color.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _summaryLabel(review, l10n),
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.adaptationReviewSubtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySnapshot extends StatelessWidget {
  const _WeeklySnapshot({required this.summary, required this.unitSystem});

  final WeeklyTrainingSummary summary;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final completedDistance = UnitFormatter.formatDistanceLabel(
      summary.completedDistanceKm,
      unitSystem,
      l10n,
    );
    final plannedDistance = UnitFormatter.formatDistanceLabel(
      summary.plannedDistanceKm,
      unitSystem,
      l10n,
    );
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adaptationWeeklySnapshot, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _MetricRow(
            label: l10n.adaptationSessionsLabel,
            value: l10n.adaptationCompletedSessions(
              summary.completedSessions,
              summary.plannedSessions,
            ),
          ),
          _MetricRow(
            label: l10n.progressDistanceLabel,
            value: l10n.adaptationDistanceProgress(
              completedDistance,
              plannedDistance,
            ),
          ),
          _MetricRow(
            label: l10n.adaptationRecoveryLabel,
            value: l10n.adaptationRecoveryFlags(summary.poorRecoveryCount),
          ),
          _MetricRow(
            label: l10n.adaptationPainLabel,
            value: l10n.adaptationPainFlags(summary.painCount),
          ),
        ],
      ),
    );
  }
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({required this.review});

  final AdaptationReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = review.reasonKeys.isEmpty
        ? review.summaryArgs.values.toList(growable: false)
        : review.reasonKeys;
    final reasonLabels = reasons.isEmpty
        ? [_reasonLabel(review.summaryKey, l10n)]
        : reasons.map((reason) => _reasonLabel(reason, l10n)).toList();

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reason in reasonLabels) ...[
            Text(
              reason,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (reason != reasonLabels.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: borderColor ?? AppColors.borderDefault),
      ),
      child: child,
    );
  }
}

Color _severityColor(AdaptationReviewSeverity severity) {
  return switch (severity) {
    AdaptationReviewSeverity.info => AppColors.info,
    AdaptationReviewSeverity.caution => AppColors.warning,
    AdaptationReviewSeverity.high => AppColors.error,
  };
}

String _summaryLabel(AdaptationReview review, AppLocalizations l10n) {
  return switch (review.summaryKey) {
    'adapt_summary_on_track' => l10n.adaptationSummaryOnTrack,
    'adapt_summary_too_aggressive' => l10n.adaptationSummaryTooAggressive,
    'adapt_summary_recovery_needed' => l10n.adaptationSummaryRecoveryNeeded,
    'adapt_summary_schedule_mismatch' => l10n.adaptationSummaryScheduleMismatch,
    'adapt_summary_too_easy' => l10n.adaptationSummaryTooEasy,
    'adapt_summary_failed' => l10n.adaptationSummaryFailed,
    'adapt_summary_insufficient_data' => l10n.adaptationSummaryInsufficientData,
    _ => switch (review.classification) {
      AdaptationReviewClassification.onTrack => l10n.adaptationSummaryOnTrack,
      AdaptationReviewClassification.tooAggressive =>
        l10n.adaptationSummaryTooAggressive,
      AdaptationReviewClassification.tooEasy => l10n.adaptationSummaryTooEasy,
      AdaptationReviewClassification.recoveryNeeded =>
        l10n.adaptationSummaryRecoveryNeeded,
      AdaptationReviewClassification.scheduleMismatch =>
        l10n.adaptationSummaryScheduleMismatch,
      AdaptationReviewClassification.insufficientData =>
        l10n.adaptationSummaryInsufficientData,
    },
  };
}

String _reasonLabel(String key, AppLocalizations l10n) {
  return switch (key) {
    'adapt_reason_pain_reported' => l10n.adaptationReasonPainReported,
    'adapt_reason_high_effort_recovery' =>
      l10n.adaptationReasonHighEffortRecovery,
    'adapt_reason_missed_sessions' => l10n.adaptationReasonMissedSessions,
    'adapt_reason_on_track' => l10n.adaptationReasonOnTrack,
    'adapt_reason_insufficient_data' => l10n.adaptationReasonInsufficientData,
    'adapt_reason_no_change' => l10n.adaptationReasonNoChange,
    'adapt_reason_generation_failed' => l10n.adaptationReasonGenerationFailed,
    _ => l10n.adaptationReasonInsufficientData,
  };
}
