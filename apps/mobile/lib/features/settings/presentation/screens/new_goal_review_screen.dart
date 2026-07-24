import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../training_plan/domain/models/plan_week.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../domain/new_goal_models.dart';
import '../new_goal_provider.dart';

enum NewGoalReviewMode {
  recommendation,
  fitness,
  proposal,
  success,
}

class NewGoalReviewScreen extends ConsumerStatefulWidget {
  const NewGoalReviewScreen({super.key, this.mode = NewGoalReviewMode.recommendation});

  final NewGoalReviewMode mode;

  @override
  ConsumerState<NewGoalReviewScreen> createState() => _NewGoalReviewScreenState();
}

class _NewGoalReviewScreenState extends ConsumerState<NewGoalReviewScreen> {
  NewGoalProposal? _cachedProposal;
  bool _isActionRunning = false;
  bool _isRefreshing = false;

  Future<void> _recommend() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    await ref.read(newGoalProvider.notifier).recommend();
    if (mounted) {
      setState(() => _isActionRunning = false);
    }
  }

  Future<void> _preview() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    await ref.read(newGoalProvider.notifier).preview();
    if (mounted) {
      setState(() => _isActionRunning = false);
    }
  }

  Future<void> _refreshAndPreview() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await ref.read(newGoalProvider.notifier).refreshAndPreview();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _apply() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    await ref.read(newGoalProvider.notifier).apply();
    if (mounted) {
      setState(() => _isActionRunning = false);
    }
  }

  Future<void> _useSuggestedActivity(NewGoalFitnessSuggestedActivity activity) async {
    ref.read(newGoalProvider.notifier).useFitnessResult(
      NewGoalFitnessResult(
        source: NewGoalFitnessSource.manual,
        distanceKm: activity.distanceKm,
        elapsed: activity.elapsed,
        recordedOn: activity.recordedOn,
        hardEffort: true,
      ),
    );
    await _recommend();
  }

  Future<void> _scheduleFirstSafeDate(NewGoalFitnessCheck check) async {
    if (check.safeDates.isEmpty) return;
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    await ref
        .read(newGoalProvider.notifier)
        .scheduleAssessment(check, check.safeDates.first);
    if (mounted) {
      setState(() => _isActionRunning = false);
    }
  }

  Future<void> _confirmApply(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editGoalApplyChanges),
        content: Text(l10n.editGoalKeepCurrent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _apply();
    }
  }

  bool _requiresFreshPreview(NewGoalState state, NewGoalProposal? proposal, DateTime now) {
    if (proposal == null) return false;
    if (proposal.expiresAt.isBefore(now)) return true;
    if (state is NewGoalFailure) {
      return state.reason == NewGoalFailureReason.expired ||
          state.reason == NewGoalFailureReason.stale ||
          state.reason == NewGoalFailureReason.conflict;
    }
    return false;
  }

  String _failureText(NewGoalState state, AppLocalizations l10n) {
    if (state is NewGoalFailure) {
      if (state.reason == NewGoalFailureReason.auth) return l10n.editGoalErrorAuth;
      if (state.reason == NewGoalFailureReason.invalidInput) {
        return l10n.editGoalErrorInvalid;
      }
      if (state.reason == NewGoalFailureReason.timeout) {
        return l10n.editGoalErrorTimeout;
      }
      if (state.reason == NewGoalFailureReason.stale) {
        return l10n.editGoalErrorStale;
      }
      if (state.reason == NewGoalFailureReason.expired) {
        return l10n.editGoalErrorExpired;
      }
      if (state.reason == NewGoalFailureReason.conflict) {
        return l10n.editGoalErrorConflict;
      }
      if (state.reason == NewGoalFailureReason.parse) {
        return l10n.editGoalErrorParse;
      }
      return l10n.editGoalErrorGeneric;
    }

    return l10n.editGoalErrorParse;
  }

  bool _isLoadingState(NewGoalState state) {
    return state is NewGoalLoading ||
        state is NewGoalRecommendationLoading ||
        state is NewGoalProposalLoading ||
        state is NewGoalApplying;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(newGoalProvider);
    final now = ref.watch(newGoalClockProvider)();
    final draft = _draftFromState(state);
    final proposal = _proposalFromState(state);

    if (proposal != null) {
      _cachedProposal = proposal;
    }

    final activeProposal = _cachedProposal;
    final isBusy = _isLoadingState(state) || _isActionRunning || _isRefreshing;

    if (state is NewGoalSuccess) {
      return _SuccessScreen(
        acceptance: state.acceptance,
        proposal: state.proposal,
      );
    }

    if (widget.mode == NewGoalReviewMode.success) {
      if (state is NewGoalSuccess) {
        return _SuccessScreen(
          acceptance: state.acceptance,
          proposal: state.proposal,
        );
      }
      return _ProposalScreen(
        l10n: l10n,
        state: state,
        proposal: activeProposal,
        draft: draft,
        needsFreshPreview: _requiresFreshPreview(state, activeProposal, now),
        isBusy: isBusy,
        onPrimary: () async {
          if (_requiresFreshPreview(state, activeProposal, now)) {
            await _refreshAndPreview();
          } else {
            await _confirmApply(context, l10n);
          }
        },
        onSecondary: () {
          if (state is NewGoalFailure && state.reason == NewGoalFailureReason.invalidInput) {
            _recommend();
          } else {
            context.pop();
          }
        },
        failureText: state is NewGoalFailure ? _failureText(state, l10n) : null,
      );
    }

    if (widget.mode == NewGoalReviewMode.proposal) {
      return _ProposalScreen(
        l10n: l10n,
        state: state,
        proposal: activeProposal,
        draft: draft,
        needsFreshPreview: _requiresFreshPreview(state, activeProposal, now),
        isBusy: isBusy,
        onPrimary: () async {
          if (_requiresFreshPreview(state, activeProposal, now)) {
            await _refreshAndPreview();
          } else {
            await _confirmApply(context, l10n);
          }
        },
        onSecondary: () {
          if (_requiresFreshPreview(state, activeProposal, now)) {
            _recommend();
          } else {
            context.pop();
          }
        },
        failureText: state is NewGoalFailure ? _failureText(state, l10n) : null,
      );
    }

    if (widget.mode == NewGoalReviewMode.fitness && state is NewGoalFitnessCheckRequired) {
      return _FitnessCheckScreen(
        l10n: l10n,
        check: state.fitnessCheck,
        draft: draft,
        isBusy: isBusy,
        onUseResult: _useSuggestedActivity,
        onSchedule: () => _scheduleFirstSafeDate(state.fitnessCheck),
        onRetry: _recommend,
      );
    }

    if (state is NewGoalAssessmentPending) {
      return _AssessmentPendingScreen(
        l10n: l10n,
        draft: draft,
        isBusy: isBusy,
        onCancel: () {
          ref.read(newGoalProvider.notifier).cancelAssessment();
          context.pop();
        },
      );
    }

    if (state is NewGoalRecommendationReady) {
      return _RecommendationReadyScreen(
        l10n: l10n,
        recommendation: state.recommendation,
        isBusy: isBusy,
        onPrimary: _preview,
      );
    }

    if (state is NewGoalFitnessCheckRequired) {
      return _FitnessCheckScreen(
        l10n: l10n,
        check: state.fitnessCheck,
        draft: draft,
        isBusy: isBusy,
        onUseResult: _useSuggestedActivity,
        onSchedule: () => _scheduleFirstSafeDate(state.fitnessCheck),
        onRetry: _recommend,
      );
    }

    if (state is NewGoalProposalReady ||
        state is NewGoalApplying ||
        (state is NewGoalFailure && proposal != null)) {
      return _ProposalScreen(
        l10n: l10n,
        state: state,
        proposal: activeProposal,
        draft: draft,
        needsFreshPreview: _requiresFreshPreview(state, activeProposal, now),
        isBusy: isBusy,
        onPrimary: () async {
          if (_requiresFreshPreview(state, activeProposal, now)) {
            await _refreshAndPreview();
          } else {
            await _confirmApply(context, l10n);
          }
        },
        onSecondary: () {
          if (state is NewGoalFailure &&
              (state.reason == NewGoalFailureReason.stale ||
                  state.reason == NewGoalFailureReason.expired ||
                  state.reason == NewGoalFailureReason.conflict)) {
            _recommend();
          } else {
            context.pop();
          }
        },
        failureText: state is NewGoalFailure ? _failureText(state, l10n) : null,
      );
    }

    if (state is NewGoalLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (draft == null && state is NewGoalFailure) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppDetailHeaderBar(title: l10n.editGoalPreviewTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Text(
              _failureText(state, l10n),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ),
      );
    }

    if (draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _DraftSummaryScreen(
      l10n: l10n,
      draft: draft,
      state: state,
      isBusy: isBusy,
      onPrimary: _recommend,
      failureText: state is NewGoalFailure ? _failureText(state, l10n) : null,
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _DraftSummaryScreen extends StatelessWidget {
  const _DraftSummaryScreen({
    required this.l10n,
    required this.draft,
    required this.state,
    required this.isBusy,
    required this.onPrimary,
    this.failureText,
  });

  final AppLocalizations l10n;
  final NewGoalDraft draft;
  final NewGoalState state;
  final bool isBusy;
  final Future<void> Function() onPrimary;
  final String? failureText;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final hasFailure = failureText != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalPreviewTitle),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsReviewChangesSubtitle(l10n.settingsNewGoal),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.settingsSummaryGoalSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _LoadingRow(
                            label: l10n.goalRaceLabel,
                            value: _goalLabel(draft.effectiveGoal, l10n),
                          ),
                          _LoadingRow(
                            label: l10n.raceDateLabel,
                            value: draft.effectiveGoal.hasRaceDate &&
                                    draft.effectiveGoal.raceDate != null
                                ? dateFormat.format(draft.effectiveGoal.raceDate!)
                                : l10n.editGoalNoDate,
                          ),
                          _LoadingRow(
                            label: l10n.scheduleStartDateLabel,
                            value: draft.planStartDate == null
                                ? l10n.editGoalNoDate
                                : dateFormat.format(draft.planStartDate!),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.settingsSummaryTrainingSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _LoadingRow(
                            label: l10n.trainingDaysLabel,
                            value: '${draft.schedule.trainingDays}',
                          ),
                          _LoadingRow(
                            label: l10n.longRunDayLabel,
                            value: OnboardingValues.localizeDay(
                              draft.schedule.longRunDay.key,
                              l10n,
                            ),
                          ),
                          _LoadingRow(
                            label: l10n.weekdayTimeLabel,
                            value: OnboardingValues.localizeTimeSlot(
                              draft.schedule.weekdayTime.key,
                              l10n,
                            ),
                          ),
                          _LoadingRow(
                            label: l10n.weekendTimeLabel,
                            value: OnboardingValues.localizeTimeSlot(
                              draft.schedule.weekendTime.key,
                              l10n,
                            ),
                          ),
                          _LoadingRow(
                            label: l10n.hardDaysLabel,
                            value: draft.schedule.hardDays.isEmpty
                                ? '—'
                                : draft.schedule.hardDays
                                    .map(
                                      (day) => OnboardingValues.localizeDay(
                                        day.key,
                                        l10n,
                                      ),
                                    )
                                    .toList(growable: false)
                                    .join(', '),
                          ),
                          _LoadingRow(
                            label: l10n.planPreferenceLabel,
                            value: OnboardingValues.localizePlanPreference(
                              draft.planPreference.key,
                              l10n,
                            ),
                          ),
                        ],
                      ),
                      if (hasFailure) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          failureText!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: state is NewGoalRecommendationLoading
                    ? l10n.editGoalPreviewLoading
                    : l10n.editGoalPreviewChanges,
                isLoading: isBusy,
                onPressed: isBusy ? null : onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationReadyScreen extends StatelessWidget {
  const _RecommendationReadyScreen({
    required this.l10n,
    required this.recommendation,
    required this.isBusy,
    required this.onPrimary,
  });

  final AppLocalizations l10n;
  final NewGoalRecommendation recommendation;
  final bool isBusy;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final startDate = dateFormat.format(recommendation.timelineDate);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsReviewChangesTitle),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(label: l10n.settingsSummaryGoalSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _LoadingRow(
                            label: l10n.goalRaceLabel,
                            value: _goalLabel(recommendation.sourceGoal, l10n),
                          ),
                          _LoadingRow(
                            label: l10n.raceDateLabel,
                            value: recommendation.sourceGoal.hasRaceDate &&
                                    recommendation.sourceGoal.raceDate != null
                                ? dateFormat.format(recommendation.sourceGoal.raceDate!)
                                : l10n.editGoalNoFixedDate,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.editGoalComparisonSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _LoadingRow(
                            label: l10n.scheduleStartDateLabel,
                            value: startDate,
                          ),
                          _LoadingRow(
                            label: l10n.editGoalEndsOn(dateFormat.format(recommendation.timelineEndDate)),
                            value: l10n.editGoalTotalWeeks(recommendation.timelineWeeks),
                          ),
                        ],
                      ),
                      if (recommendation.estimate != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                          Text(
                            l10n.editGoalEstimatedFinishRange(
                              _formatDuration(
                                recommendation.estimate!.fasterTime,
                                l10n,
                              ),
                              _formatDuration(
                                recommendation.estimate!.slowerTime,
                                l10n,
                              ),
                            ),
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.editGoalEstimateConfidence(
                            _estimateConfidence(recommendation.estimate!.confidence, l10n),
                          ),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.editGoalPreviewChanges,
                isLoading: isBusy,
                onPressed: isBusy ? null : onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FitnessCheckScreen extends StatelessWidget {
  const _FitnessCheckScreen({
    required this.l10n,
    required this.check,
    required this.draft,
    required this.isBusy,
    required this.onUseResult,
    required this.onSchedule,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final NewGoalFitnessCheck check;
  final NewGoalDraft? draft;
  final bool isBusy;
  final Future<void> Function(NewGoalFitnessSuggestedActivity) onUseResult;
  final Future<void> Function() onSchedule;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final safeDates = check.safeDates
        .map((date) => DateFormat.MMMd(locale).format(date))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalFitnessCheckTitle),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.editGoalFitnessCheckSubtitle,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (check.suggestedActivities.isNotEmpty) ...[
                        SectionLabel(label: l10n.editGoalRecommendedResult),
                        const SizedBox(height: AppSpacing.sm),
                        ...check.suggestedActivities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _SuggestedActivityCard(
                              l10n: l10n,
                              locale: locale,
                              activity: activity,
                              onUse: () => onUseResult(activity),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      SectionLabel(label: l10n.editGoalSafeDatesLabel),
                      const SizedBox(height: AppSpacing.md),
                      if (safeDates.isEmpty)
                        Text(l10n.editGoalNoSafeDates)
                      else
                        ...safeDates
                            .map(
                              (date) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: _InfoCard(text: date, color: AppColors.backgroundCard),
                              ),
                            ),
                      const SizedBox(height: AppSpacing.xl),
                      if (draft?.hasRaceDate == false)
                        Text(
                          l10n.editGoalNoDateNote,
                          style: AppTypography.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: l10n.editGoalScheduleAssessmentButton,
                isLoading: isBusy,
                onPressed: isBusy || safeDates.isEmpty
                    ? null
                    : () => onSchedule(),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.editGoalRetry,
                variant: AppButtonVariant.secondary,
                isLoading: isBusy,
                onPressed: isBusy ? null : () => onRetry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentPendingScreen extends StatelessWidget {
  const _AssessmentPendingScreen({
    required this.l10n,
    required this.draft,
    required this.isBusy,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  final NewGoalDraft? draft;
  final bool isBusy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalFitnessCheckTitle),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.editGoalInProgressTitle,
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.editGoalInProgressSubtitle,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                label: l10n.continueButton,
                isLoading: isBusy,
                onPressed: isBusy ? null : onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalScreen extends StatelessWidget {
  const _ProposalScreen({
    required this.l10n,
    required this.state,
    required this.proposal,
    required this.draft,
    required this.needsFreshPreview,
    required this.isBusy,
    required this.onPrimary,
    required this.onSecondary,
    this.failureText,
  });

  final AppLocalizations l10n;
  final NewGoalState state;
  final NewGoalProposal? proposal;
  final NewGoalDraft? draft;
  final bool needsFreshPreview;
  final bool isBusy;
  final Future<void> Function() onPrimary;
  final VoidCallback onSecondary;
  final String? failureText;

  @override
  Widget build(BuildContext context) {
    final resolvedDraft = draft;
    if (proposal == null) {
      if (resolvedDraft == null) {
        return const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return _DraftSummaryScreen(
        l10n: l10n,
        draft: resolvedDraft,
        state: state,
        isBusy: isBusy,
        onPrimary: onPrimary,
        failureText: failureText,
      );
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final weeks = _proposalWeeks(proposal!);
    final previewWeeks = weeks.take(2).toList(growable: false);
    final extraWeeks = weeks.skip(2).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalPreviewTitle),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(label: l10n.editGoalComparisonSection),
                      const SizedBox(height: AppSpacing.md),
                      _GoalPairRow(
                        l10n: l10n,
                        proposal: proposal!,
                        dateFormat: dateFormat,
                      ),
                      if (proposal!.warnings.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ...proposal!.warnings.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _WarningRow(
                              l10n: l10n,
                              warning: warning,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.editGoalImpactSection),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoCard(
                        color: AppColors.accentMuted,
                        text: l10n.editGoalTotalWeeks(proposal!.candidatePlan.totalWeeks),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SectionLabel(label: l10n.editGoalNextTwoWeeks),
                      const SizedBox(height: AppSpacing.sm),
                      ...previewWeeks
                          .map(
                            (week) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _WeekExpansion(
                                l10n: l10n,
                                dateFormat: dateFormat,
                                week: week,
                                initiallyExpanded: true,
                              ),
                            ),
                          ),
                      if (extraWeeks.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ExpansionTile(
                          title: Text(l10n.editGoalFullProposedPlan),
                          children: extraWeeks
                              .map(
                                (week) => _WeekExpansion(
                                  l10n: l10n,
                                  dateFormat: dateFormat,
                                  week: week,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (needsFreshPreview) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.editGoalPreviewExpired,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      if (failureText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          failureText!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: needsFreshPreview
                    ? l10n.editGoalFreshPreview
                    : l10n.editGoalApplyChanges,
                isLoading: isBusy,
                onPressed: isBusy ? null : onPrimary,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: needsFreshPreview ? l10n.editGoalRetry : l10n.editGoalKeepCurrent,
                variant: AppButtonVariant.secondary,
                isLoading: isBusy,
                onPressed: isBusy ? null : onSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({required this.acceptance, required this.proposal});

  final NewGoalAcceptance acceptance;
  final NewGoalProposal proposal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalSuccessTitle),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.editGoalSuccessSubtitle,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '${l10n.goalRaceLabel}: ${_goalLabel(proposal.proposedGoal, l10n)}',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                acceptance.versionId,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                label: l10n.editGoalViewPlan,
                onPressed: () => context.go(RouteNames.plan),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.settingsViewPlan,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(RouteNames.plan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPairRow extends StatelessWidget {
  const _GoalPairRow({
    required this.l10n,
    required this.proposal,
    required this.dateFormat,
  });

  final AppLocalizations l10n;
  final NewGoalProposal proposal;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GoalCard(
            label: l10n.editGoalCurrentGoalLabel,
            goal: proposal.currentGoal,
            dateFormat: dateFormat,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _GoalCard(
            label: l10n.editGoalProposedLabel,
            goal: proposal.proposedGoal,
            dateFormat: dateFormat,
            highlighted: true,
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.label,
    required this.goal,
    required this.dateFormat,
    this.highlighted = false,
  });

  final String label;
  final NewGoalGoal goal;
  final DateFormat dateFormat;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentMuted : AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: highlighted ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_goalLabel(goal, AppLocalizations.of(context)!), style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            goal.hasRaceDate && goal.raceDate != null
                ? dateFormat.format(goal.raceDate!)
                : l10n(context).editGoalNoDate,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context)!;
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.l10n, required this.warning});

  final AppLocalizations l10n;
  final String warning;

  @override
  Widget build(BuildContext context) {
    final warningContent = _warningContent(warning, l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderLg,
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(warningContent.$1, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(warningContent.$2, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _WeekExpansion extends StatelessWidget {
  const _WeekExpansion({
    required this.l10n,
    required this.dateFormat,
    required this.week,
    this.initiallyExpanded = false,
  });

  final AppLocalizations l10n;
  final DateFormat dateFormat;
  final PlanWeek week;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final sessionCount = week.sessions.length;
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(l10n.editGoalWeekLabel(week.weekNumber)),
      subtitle: Text(
        l10n.editGoalPreservedCount(sessionCount),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      children: week.sessions.isEmpty
          ? [
              const SizedBox(
                height: 8,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.base),
                child: Text(
                  l10n.no,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ]
          : week.sessions
              .map(
                (session) => _SessionLineItem(
                  dateFormat: dateFormat,
                  session: session,
                  l10n: l10n,
                ),
              )
              .toList(growable: false),
    );
  }
}

class _SessionLineItem extends StatelessWidget {
  const _SessionLineItem({
    required this.dateFormat,
    required this.session,
    required this.l10n,
  });

  final DateFormat dateFormat;
  final TrainingSession session;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final baseLine = '${dateFormat.format(session.date)} · ${_sessionLabel(session.type, l10n)}';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final details = _sessionDetails(
      session: session,
      locale: locale,
      l10n: l10n,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _InfoCard(
        text: details.isEmpty ? baseLine : '$baseLine · $details',
        color: AppColors.backgroundCard,
      ),
    );
  }
}

class _SuggestedActivityCard extends StatelessWidget {
  const _SuggestedActivityCard({
    required this.l10n,
    required this.locale,
    required this.activity,
    required this.onUse,
  });

  final AppLocalizations l10n;
  final String locale;
  final NewGoalFitnessSuggestedActivity activity;
  final Future<void> Function() onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            l10n.editGoalSuggestedActivity(
              DateFormat.yMMMd(locale).format(activity.recordedOn),
              NumberFormat('0.0', locale).format(activity.distanceKm),
              _formatDuration(activity.elapsed, l10n),
            ),
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.editGoalUseThisActivity,
            variant: AppButtonVariant.secondary,
            onPressed: () => onUse(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(text, style: AppTypography.bodyMedium),
    );
  }
}

String _sessionLabel(SessionType type, AppLocalizations l10n) {
  if (type == SessionType.easyRun) return l10n.weeklyPlanSessionEasyRun;
  if (type == SessionType.longRun) return l10n.weeklyPlanSessionLongRun;
  if (type == SessionType.progressionRun) return l10n.sessionTypeProgressionRun;
  if (type == SessionType.intervals) return l10n.weeklyPlanSessionIntervals;
  if (type == SessionType.hillRepeats) return l10n.sessionTypeHillRepeats;
  if (type == SessionType.fartlek) return l10n.sessionTypeFartlek;
  if (type == SessionType.tempoRun) return l10n.sessionTypeTempoRun;
  if (type == SessionType.thresholdRun) return l10n.sessionTypeThresholdRun;
  if (type == SessionType.racePaceRun) return l10n.sessionTypeRacePaceRun;
  if (type == SessionType.recoveryRun) return l10n.weeklyPlanSessionRecoveryRun;
  if (type == SessionType.crossTraining) return l10n.sessionTypeCrossTraining;
  if (type == SessionType.restDay) return l10n.sessionTypeRestDay;
  return l10n.raceDayInfoTitle;
}

String _sessionDetails({
  required TrainingSession session,
  required String locale,
  required AppLocalizations l10n,
}) {
  final values = <String>[];
  if (session.distanceKm != null) {
    final distanceFormatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 1;
    values.add('${distanceFormatter.format(session.distanceKm)} ${l10n.unitKm}');
  }
  if (session.durationMinutes != null) {
    values.add(UnitFormatter.formatDuration(session.durationMinutes!, l10n));
  }
  return values.join(' · ');
}

String _estimateConfidence(String confidence, AppLocalizations l10n) {
  if (confidence == 'high') return l10n.editGoalConfidenceHigh;
  if (confidence == 'medium') return l10n.editGoalConfidenceMedium;
  return l10n.editGoalConfidenceLimited;
}

String _formatDuration(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$seconds' : '$hours${l10n.progressHourUnit} $minutes:$seconds';
}

List<PlanWeek> _proposalWeeks(NewGoalProposal proposal) {
  final currentWeek = proposal.candidatePlan.currentWeekNumber;
  return proposal.candidatePlan.allWeeks
      .where((week) => week.weekNumber >= currentWeek)
      .toList(growable: false);
}

NewGoalDraft? _draftFromState(NewGoalState state) {
  if (state is NewGoalLoading) return null;
  if (state is NewGoalEditing) return state.draft;
  if (state is NewGoalRecommendationLoading) return state.draft;
  if (state is NewGoalRecommendationReady) return state.draft;
  if (state is NewGoalFitnessCheckRequired) return state.draft;
  if (state is NewGoalProposalLoading) return state.draft;
  if (state is NewGoalProposalReady) return state.draft;
  if (state is NewGoalAssessmentPending) return state.draft;
  if (state is NewGoalApplying) return state.draft;
  if (state is NewGoalFailure) return state.draft;
  return null;
}

NewGoalProposal? _proposalFromState(NewGoalState state) {
  if (state is NewGoalProposalReady) return state.proposal;
  if (state is NewGoalApplying) return state.proposal;
  if (state is NewGoalFailure) return state.proposal;
  return null;
}

(String, String) _warningContent(String warning, AppLocalizations l10n) {
  if (warning == 'short_notice') {
    return (l10n.editGoalWarningShortNoticeTitle, l10n.editGoalWarningShortNoticeBody);
  }
  if (warning == 'race_week') {
    return (l10n.editGoalWarningRaceWeekTitle, l10n.editGoalWarningRaceWeekBody);
  }
  if (warning == 'readiness_gap') {
    return (l10n.editGoalWarningReadinessGapTitle, l10n.editGoalWarningReadinessGapBody);
  }
  if (warning == 'limited_evidence') {
    return (l10n.editGoalWarningLimitedEvidenceTitle, l10n.editGoalWarningLimitedEvidenceBody);
  }
  if (warning == 'no_fixed_date') {
    return (l10n.editGoalWarningNoFixedDateTitle, l10n.editGoalWarningNoFixedDateBody);
  }
  return (warning, warning);
}

String _goalLabel(NewGoalGoal goal, AppLocalizations l10n) {
  if (goal.race == RunnerGoalRace.fiveK) return l10n.race5K;
  if (goal.race == RunnerGoalRace.tenK) return l10n.race10K;
  if (goal.race == RunnerGoalRace.halfMarathon) return l10n.raceHalfMarathon;
  if (goal.race == RunnerGoalRace.marathon) return l10n.raceMarathon;
  return l10n.raceOther;
}
