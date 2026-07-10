import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../domain/models/adaptation_patch.dart';
import '../../domain/models/session_type.dart';
import '../../domain/models/training_session.dart';
import '../adaptation_actions_provider.dart';
import '../training_plan_provider.dart';

class AdaptationDiffScreen extends ConsumerWidget {
  const AdaptationDiffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final review = ref.watch(pendingAdaptationReviewProvider);
    final actionState = ref.watch(adaptationActionsProvider);
    final isLoading = actionState is AdaptationActionLoading;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final plan = ref.watch(trainingPlanProvider).value;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.adaptationPlanDiffTitle),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              Expanded(
                child: review == null || review.patches.isEmpty
                    ? Center(
                        child: Text(
                          l10n.adaptationNoChanges,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: review.patches.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) => _PatchCard(
                          patch: review.patches[index],
                          sourceSession: _sourceSession(
                            review.patches[index],
                            plan?.sessions ?? const [],
                          ),
                          unitSystem: unitSystem,
                        ),
                      ),
              ),
              if (actionState is AdaptationActionFailure) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.adaptationActionError,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: l10n.adaptationApplyChanges,
                isLoading: isLoading,
                onPressed: review == null || isLoading
                    ? null
                    : () async {
                        final succeeded = await ref
                            .read(adaptationActionsProvider.notifier)
                            .acceptReview(review);
                        if (succeeded && context.mounted) {
                          context.go(RouteNames.today);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatchCard extends StatelessWidget {
  const _PatchCard({
    required this.patch,
    required this.sourceSession,
    required this.unitSystem,
  });

  final AdaptationPatch patch;
  final TrainingSession? sourceSession;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final source = sourceSession;
    final targetDate = patch.date;
    final targetType = patch.afterSessionType;
    final targetDistance = patch.afterDistanceKm;
    final targetDuration = patch.afterDurationMinutes;
    final showsDate =
        patch.type == AdaptationPatchType.moveSession &&
        source != null &&
        targetDate != null &&
        !_sameDate(source.date, targetDate);
    final showsType =
        patch.type == AdaptationPatchType.replaceSession &&
        source != null &&
        targetType != null &&
        source.type != targetType;
    final showsDistance =
        source?.distanceKm != null &&
        targetDistance != null &&
        source!.distanceKm != targetDistance;
    final showsDuration =
        source?.durationMinutes != null &&
        targetDuration != null &&
        source!.durationMinutes != targetDuration;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _patchTypeLabel(patch.type, l10n),
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (showsDate)
            _ChangeLine(
              value: l10n.adaptationBeforeAfter(
                _dateLabel(source.date, context),
                _dateLabel(targetDate, context),
              ),
            ),
          if (showsType)
            _ChangeLine(
              value: l10n.adaptationBeforeAfter(
                _sessionTypeLabel(source.type, l10n),
                _sessionTypeLabel(targetType, l10n),
              ),
            ),
          if (showsDistance)
            _ChangeLine(
              value: l10n.adaptationBeforeAfter(
                _distanceLabel(source.distanceKm!, unitSystem, l10n),
                _distanceLabel(targetDistance, unitSystem, l10n),
              ),
            ),
          if (showsDuration)
            _ChangeLine(
              value: l10n.adaptationBeforeAfter(
                _durationLabel(source.durationMinutes!, l10n),
                _durationLabel(targetDuration, l10n),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _reasonLabel(patch.reasonKey, l10n),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

TrainingSession? _sourceSession(
  AdaptationPatch patch,
  List<TrainingSession> sessions,
) {
  final sessionId = patch.sessionId;
  if (sessionId == null) return null;
  for (final session in sessions) {
    if (session.id == sessionId) return session;
  }
  return null;
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _dateLabel(DateTime value, BuildContext context) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).format(value);
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(value, style: AppTypography.bodyMedium),
    );
  }
}

String _patchTypeLabel(AdaptationPatchType type, AppLocalizations l10n) {
  return switch (type) {
    AdaptationPatchType.noChange => l10n.adaptationPatchNoChange,
    AdaptationPatchType.reduceSession => l10n.adaptationPatchReduceSession,
    AdaptationPatchType.replaceSession => l10n.adaptationPatchReplaceSession,
    AdaptationPatchType.moveSession => l10n.adaptationPatchMoveSession,
    AdaptationPatchType.shortenLongRun => l10n.adaptationPatchShortenLongRun,
    AdaptationPatchType.repeatWeek => l10n.adaptationPatchRepeatWeek,
    AdaptationPatchType.progressSlightly =>
      l10n.adaptationPatchProgressSlightly,
  };
}

String _sessionTypeLabel(SessionType? type, AppLocalizations l10n) {
  return switch (type) {
    SessionType.restDay => l10n.sessionTypeRestDay,
    SessionType.raceDay => l10n.raceDayInfoTitle,
    SessionType.easyRun => l10n.weeklyPlanSessionEasyRun,
    SessionType.longRun => l10n.weeklyPlanSessionLongRun,
    SessionType.progressionRun => l10n.sessionTypeProgressionRun,
    SessionType.intervals => l10n.weeklyPlanSessionIntervals,
    SessionType.hillRepeats => l10n.sessionTypeHillRepeats,
    SessionType.fartlek => l10n.sessionTypeFartlek,
    SessionType.tempoRun => l10n.sessionTypeTempoRun,
    SessionType.thresholdRun => l10n.sessionTypeThresholdRun,
    SessionType.racePaceRun => l10n.sessionTypeRacePaceRun,
    SessionType.recoveryRun => l10n.weeklyPlanSessionRecoveryRun,
    SessionType.crossTraining => l10n.sessionTypeCrossTraining,
    null => '-',
  };
}

String _distanceLabel(
  double value,
  UnitSystem unitSystem,
  AppLocalizations l10n,
) {
  return UnitFormatter.formatDistanceLabel(value, unitSystem, l10n);
}

String _durationLabel(int value, AppLocalizations l10n) {
  return UnitFormatter.formatDuration(value, l10n);
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
