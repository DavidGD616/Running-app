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
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../../training_plan/domain/models/plan_week.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../../domain/edit_goal_models.dart';
import '../edit_goal_provider.dart';

class EditGoalPreviewScreen extends ConsumerStatefulWidget {
  const EditGoalPreviewScreen({super.key});

  @override
  ConsumerState<EditGoalPreviewScreen> createState() =>
      _EditGoalPreviewScreenState();
}

class _EditGoalPreviewScreenState extends ConsumerState<EditGoalPreviewScreen> {
  GoalEditProposal? _lastProposal;
  bool _isRefreshing = false;
  bool _freshPreviewFailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(editGoalProvider);
    if (state case EditGoalSuccess(:final acceptance, :final proposal)) {
      return _EditGoalSuccessScreen(acceptance: acceptance, proposal: proposal);
    }
    final currentProposal = _proposal(state);
    if (currentProposal != null) _lastProposal = currentProposal;
    final proposal = currentProposal ?? _lastProposal;
    if (proposal == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppDetailHeaderBar(title: l10n.editGoalPreviewTitle),
        body: Center(child: Text(_stateError(state, l10n))),
      );
    }
    final failure = state is EditGoalFailure ? state : null;
    final isApplying = state is EditGoalApplying;
    final isRefreshing = _isRefreshing || state is EditGoalPreviewing;
    final expired = !proposal.expiresAt.isAfter(
      ref.watch(editGoalClockProvider)(),
    );
    final requiresFresh =
        expired ||
        failure?.reason == EditGoalFailureReason.expired ||
        failure?.reason == EditGoalFailureReason.stale ||
        failure?.reason == EditGoalFailureReason.conflict ||
        _freshPreviewFailed;
    final retryingApply = failure != null && !requiresFresh;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final upcomingWeeks = _upcomingWeeks(proposal);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.editGoalPreviewTitle,
        onBack: () {
          ref.read(editGoalProvider.notifier).cancelPreview();
          context.pop();
        },
      ),
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
                      _GoalComparison(
                        proposal: proposal,
                        dateFormat: dateFormat,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _RaceEstimateCard(estimate: proposal.raceEstimate),
                      if (proposal.warnings.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ...proposal.warnings.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _WarningBanner(warning: warning),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.editGoalImpactSection),
                      const SizedBox(height: AppSpacing.md),
                      _ImpactGrid(
                        summary: proposal.summary,
                        dateFormat: dateFormat,
                      ),
                      if (_hasChangeDetails(proposal.summary)) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ChangeDetails(
                          summary: proposal.summary,
                          dateFormat: dateFormat,
                          locale: locale,
                          unitSystem: unitSystem,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.editGoalNextTwoWeeks),
                      const SizedBox(height: AppSpacing.sm),
                      ...upcomingWeeks
                          .take(2)
                          .map(
                            (week) => _WeekExpansion(
                              weekNumber: week.weekNumber,
                              sessions: week.sessions,
                              dateFormat: dateFormat,
                            ),
                          ),
                      if (upcomingWeeks.length > 2) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _FullPlanExpansion(
                          weeks: upcomingWeeks.skip(2),
                          dateFormat: dateFormat,
                        ),
                      ],
                      if (expired) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.editGoalPreviewExpired,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      if (failure != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _stateError(state, l10n),
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
                key: const Key('editGoalApplyButton'),
                label: retryingApply
                    ? l10n.editGoalRetry
                    : l10n.editGoalApplyChanges,
                isLoading: isApplying,
                onPressed: isApplying || isRefreshing || requiresFresh
                    ? null
                    : () async {
                        final accepted = await ref
                            .read(editGoalProvider.notifier)
                            .apply();
                        if (accepted && context.mounted) setState(() {});
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: requiresFresh
                    ? l10n.editGoalFreshPreview
                    : l10n.editGoalKeepCurrent,
                variant: AppButtonVariant.secondary,
                isLoading: isRefreshing,
                onPressed: isApplying || isRefreshing
                    ? null
                    : requiresFresh
                    ? _refreshPreview
                    : () {
                        ref.read(editGoalProvider.notifier).cancelPreview();
                        context.pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPreview() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _freshPreviewFailed = false;
    });
    final ready = await ref.read(editGoalProvider.notifier).refreshAndPreview();
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      _freshPreviewFailed = !ready;
    });
  }
}

class _GoalComparison extends StatelessWidget {
  const _GoalComparison({required this.proposal, required this.dateFormat});
  final GoalEditProposal proposal;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GoalCard(
            label: l10n.editGoalCurrentLabel,
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
  final GoalEditGoal goal;
  final DateFormat dateFormat;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentMuted : AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: highlighted
              ? AppColors.accentPrimary
              : AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_raceLabel(goal.race, l10n), style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            goal.raceDate == null
                ? l10n.editGoalNoFixedDate
                : dateFormat.format(goal.raceDate!),
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.warning});
  final GoalEditWarning warning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, body) = switch (warning) {
      GoalEditWarning.shortNotice => (
        l10n.editGoalWarningShortNoticeTitle,
        l10n.editGoalWarningShortNoticeBody,
      ),
      GoalEditWarning.raceWeek => (
        l10n.editGoalWarningRaceWeekTitle,
        l10n.editGoalWarningRaceWeekBody,
      ),
      GoalEditWarning.readinessGap => (
        l10n.editGoalWarningReadinessGapTitle,
        l10n.editGoalWarningReadinessGapBody,
      ),
      GoalEditWarning.limitedEvidence => (
        l10n.editGoalWarningLimitedEvidenceTitle,
        l10n.editGoalWarningLimitedEvidenceBody,
      ),
      GoalEditWarning.noFixedDate => (
        l10n.editGoalWarningNoFixedDateTitle,
        l10n.editGoalWarningNoFixedDateBody,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _RaceEstimateCard extends StatelessWidget {
  const _RaceEstimateCard({required this.estimate});
  final GoalEditRaceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final confidence = switch (estimate.confidence) {
      'high' => l10n.editGoalConfidenceHigh,
      'medium' => l10n.editGoalConfidenceMedium,
      _ => l10n.editGoalConfidenceLimited,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.accentPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editGoalEstimateSection, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.editGoalEstimatedFinishRange(
              _formatTime(estimate.fasterTime),
              _formatTime(estimate.slowerTime),
            ),
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.editGoalEstimateConfidence(confidence),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (estimate.evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.editGoalEvidenceUsed, style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            ...estimate.evidence.map(
              (item) => Text(
                item.description,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImpactGrid extends StatelessWidget {
  const _ImpactGrid({required this.summary, required this.dateFormat});
  final GoalEditChangeSummary summary;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.editGoalPreservedCount(summary.preservedCount),
      l10n.editGoalAddedCount(summary.addedUpcomingCount),
      l10n.editGoalRemovedCount(summary.removedUpcomingCount),
      l10n.editGoalChangedCount(summary.materiallyChangedUpcomingCount),
      l10n.editGoalTotalWeeks(summary.totalWeeks),
      if (summary.endDate != null)
        l10n.editGoalEndsOn(dateFormat.format(summary.endDate!)),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(label, style: AppTypography.bodyMedium),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChangeDetails extends StatelessWidget {
  const _ChangeDetails({
    required this.summary,
    required this.dateFormat,
    required this.locale,
    required this.unitSystem,
  });

  final GoalEditChangeSummary summary;
  final DateFormat dateFormat;
  final String locale;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (summary.addedUpcomingSessions.isNotEmpty)
          _ChangeSection(
            key: const Key('editGoalAddedDetails'),
            title: l10n.editGoalAddedDetailsSection,
            kind: _ChangeDisplayKind.added,
            changes: summary.addedUpcomingSessions,
            dateFormat: dateFormat,
            locale: locale,
            unitSystem: unitSystem,
          ),
        if (summary.removedUpcomingSessions.isNotEmpty)
          _ChangeSection(
            key: const Key('editGoalRemovedDetails'),
            title: l10n.editGoalRemovedDetailsSection,
            kind: _ChangeDisplayKind.removed,
            changes: summary.removedUpcomingSessions,
            dateFormat: dateFormat,
            locale: locale,
            unitSystem: unitSystem,
          ),
        if (summary.materiallyChangedUpcomingSessions.isNotEmpty)
          _ChangeSection(
            key: const Key('editGoalChangedDetails'),
            title: l10n.editGoalChangedDetailsSection,
            kind: _ChangeDisplayKind.changed,
            changes: summary.materiallyChangedUpcomingSessions,
            dateFormat: dateFormat,
            locale: locale,
            unitSystem: unitSystem,
          ),
      ],
    );
  }
}

enum _ChangeDisplayKind { added, removed, changed }

class _ChangeSection extends StatelessWidget {
  const _ChangeSection({
    super.key,
    required this.title,
    required this.kind,
    required this.changes,
    required this.dateFormat,
    required this.locale,
    required this.unitSystem,
  });

  final String title;
  final _ChangeDisplayKind kind;
  final List<GoalEditSessionChange> changes;
  final DateFormat dateFormat;
  final String locale;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < changes.length; index++) ...[
            _ChangeRow(
              key: Key('editGoal${kind.name}Change$index'),
              kind: kind,
              change: changes[index],
              dateFormat: dateFormat,
              locale: locale,
              unitSystem: unitSystem,
            ),
            if (index != changes.length - 1)
              const Divider(color: AppColors.borderDefault),
          ],
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    super.key,
    required this.kind,
    required this.change,
    required this.dateFormat,
    required this.locale,
    required this.unitSystem,
  });

  final _ChangeDisplayKind kind;
  final GoalEditSessionChange change;
  final DateFormat dateFormat;
  final String locale;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final beforeType = change.beforeSessionType;
    final afterType = change.afterSessionType;
    final beforeMetrics = _changeMetrics(
      durationMinutes: change.beforeDurationMinutes,
      distanceKm: change.beforeDistanceKm,
      locale: locale,
      unitSystem: unitSystem,
      l10n: l10n,
    );
    final afterMetrics = _changeMetrics(
      durationMinutes: change.afterDurationMinutes,
      distanceKm: change.afterDistanceKm,
      locale: locale,
      unitSystem: unitSystem,
      l10n: l10n,
    );
    final title = switch (kind) {
      _ChangeDisplayKind.added => _sessionLabel(afterType!, l10n),
      _ChangeDisplayKind.removed => _sessionLabel(beforeType!, l10n),
      _ChangeDisplayKind.changed =>
        '${_sessionLabel(beforeType!, l10n)} → '
            '${_sessionLabel(afterType!, l10n)}',
    };
    final metrics = switch (kind) {
      _ChangeDisplayKind.added => afterMetrics,
      _ChangeDisplayKind.removed => beforeMetrics,
      _ChangeDisplayKind.changed =>
        beforeMetrics.isEmpty && afterMetrics.isEmpty
            ? ''
            : '$beforeMetrics → $afterMetrics',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, softWrap: true, style: AppTypography.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          dateFormat.format(change.localDate),
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        if (metrics.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            metrics,
            softWrap: true,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekExpansion extends StatelessWidget {
  const _WeekExpansion({
    required this.weekNumber,
    required this.sessions,
    required this.dateFormat,
  });
  final int weekNumber;
  final List<TrainingSession> sessions;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: ExpansionTile(
        key: Key('editGoalWeek$weekNumber'),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
        ),
        title: Text(l10n.editGoalWeekLabel(weekNumber)),
        children: sessions
            .map(
              (session) => ListTile(
                dense: true,
                title: Text(
                  l10n.editGoalSessionLine(
                    dateFormat.format(session.date),
                    _sessionLabel(session.type, l10n),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FullPlanExpansion extends StatelessWidget {
  const _FullPlanExpansion({required this.weeks, required this.dateFormat});
  final Iterable<PlanWeek> weeks;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: ExpansionTile(
        key: const Key('editGoalFullPlanExpansion'),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
        ),
        title: Text(l10n.editGoalFullProposedPlan),
        children: weeks
            .map(
              (week) => _WeekExpansion(
                weekNumber: week.weekNumber,
                sessions: week.sessions,
                dateFormat: dateFormat,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _EditGoalSuccessScreen extends StatelessWidget {
  const _EditGoalSuccessScreen({
    required this.acceptance,
    required this.proposal,
  });

  final GoalEditAcceptance acceptance;
  final GoalEditProposal proposal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final next =
        acceptance.plan.sessions
            .where(
              (session) =>
                  session.status == SessionStatus.today ||
                  session.status == SessionStatus.upcoming,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final nextSession = next.isEmpty ? null : next.first;
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
                l10n.editGoalSuccessTitle,
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.editGoalSuccessSubtitle,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RaceEstimateCard(estimate: proposal.raceEstimate),
              const SizedBox(height: AppSpacing.lg),
              _SuccessNote(
                text: l10n.editGoalProgressPreserved(
                  proposal.summary.preservedCount,
                ),
              ),
              if (nextSession != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SuccessNote(
                  text: l10n.editGoalNextWorkout(
                    dateFormat.format(nextSession.date),
                    _sessionLabel(nextSession.type, l10n),
                  ),
                ),
              ],
              const Spacer(),
              AppButton(
                label: l10n.editGoalViewPlan,
                onPressed: () => context.go(RouteNames.plan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessNote extends StatelessWidget {
  const _SuccessNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.base),
    decoration: BoxDecoration(
      color: AppColors.backgroundCard,
      borderRadius: AppRadius.borderLg,
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: Text(text, style: AppTypography.bodyLarge),
  );
}

GoalEditProposal? _proposal(EditGoalState state) => switch (state) {
  EditGoalPreviewReady(:final proposal) ||
  EditGoalApplying(:final proposal) => proposal,
  EditGoalFailure(:final proposal) => proposal,
  _ => null,
};

String _stateError(EditGoalState state, AppLocalizations l10n) {
  if (state case EditGoalFailure(:final reason)) {
    return switch (reason) {
      EditGoalFailureReason.auth => l10n.editGoalErrorAuth,
      EditGoalFailureReason.invalidInput => l10n.editGoalErrorInvalid,
      EditGoalFailureReason.timeout => l10n.editGoalErrorTimeout,
      EditGoalFailureReason.stale => l10n.editGoalErrorStale,
      EditGoalFailureReason.expired => l10n.editGoalErrorExpired,
      EditGoalFailureReason.conflict => l10n.editGoalErrorConflict,
      EditGoalFailureReason.parse => l10n.editGoalErrorParse,
      EditGoalFailureReason.generic => l10n.editGoalErrorGeneric,
    };
  }
  return l10n.editGoalErrorParse;
}

String _raceLabel(RunnerGoalRace race, AppLocalizations l10n) => switch (race) {
  RunnerGoalRace.fiveK => l10n.race5K,
  RunnerGoalRace.tenK => l10n.race10K,
  RunnerGoalRace.halfMarathon => l10n.raceHalfMarathon,
  RunnerGoalRace.marathon => l10n.raceMarathon,
  RunnerGoalRace.other => l10n.raceOther,
};

String _sessionLabel(SessionType type, AppLocalizations l10n) => switch (type) {
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
  SessionType.restDay => l10n.sessionTypeRestDay,
  SessionType.raceDay => l10n.raceDayInfoTitle,
};

bool _hasChangeDetails(GoalEditChangeSummary summary) =>
    summary.addedUpcomingSessions.isNotEmpty ||
    summary.removedUpcomingSessions.isNotEmpty ||
    summary.materiallyChangedUpcomingSessions.isNotEmpty;

List<PlanWeek> _upcomingWeeks(GoalEditProposal proposal) {
  final currentWeek = proposal.candidatePlan.currentWeekNumber;
  return proposal.candidatePlan.allWeeks
      .where((week) => week.weekNumber >= currentWeek)
      .toList(growable: false);
}

String _changeMetrics({
  required int? durationMinutes,
  required double? distanceKm,
  required String locale,
  required UnitSystem unitSystem,
  required AppLocalizations l10n,
}) {
  final values = <String>[];
  if (distanceKm != null) {
    final formatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 1;
    values.add(
      '${formatter.format(UnitFormatter.distanceValue(distanceKm, unitSystem))} '
      '${UnitFormatter.unitLabel(unitSystem, l10n)}',
    );
  }
  if (durationMinutes != null) {
    values.add(UnitFormatter.formatDuration(durationMinutes, l10n));
  }
  return values.join(' · ');
}

String _formatTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
