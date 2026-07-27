import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/change_schedule_models.dart';
import '../change_schedule_provider.dart';

/// A focused, in-app flow for changing availability without re-entering
/// onboarding. The provider owns the draft and request lifecycle; this screen
/// owns only the temporary setup step and the last in-session review details.
class ChangeScheduleFlowScreen extends ConsumerStatefulWidget {
  const ChangeScheduleFlowScreen({super.key});

  @override
  ConsumerState<ChangeScheduleFlowScreen> createState() =>
      _ChangeScheduleFlowScreenState();
}

class _ChangeScheduleFlowScreenState
    extends ConsumerState<ChangeScheduleFlowScreen> {
  static const _totalSteps = 3;
  static const _capOptions = <int?>[null, 30, 45, 60, 90];

  int _step = 1;
  ChangeSchedulePreviewResponse? _lastPreview;
  ChangeScheduleScheduledResponse? _lastScheduled;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeScheduleProvider);
    _rememberLifecycleDetails(state);

    final isApplying = state is ChangeScheduleApplying;
    final isOutcome = _isOutcome(state);
    return PopScope(
      canPop: !isApplying && (_step == 1 || isOutcome),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || isApplying) return;
        _handleBack(state);
      },
      child: _buildState(context, state),
    );
  }

  Widget _buildState(BuildContext context, ChangeScheduleState state) {
    if (state is ChangeScheduleLoading) {
      return _statusScaffold(
        context,
        title: AppLocalizations.of(context)!.changeScheduleLoading,
        subtitle: AppLocalizations.of(context)!.changeScheduleLoadingSubtitle,
        isLoading: true,
        onBack: () => _handleBack(state),
      );
    }

    if (state is ChangeScheduleFailure) {
      return _failureScaffold(context, state);
    }

    if (state is ChangeScheduleApplying) {
      return _statusScaffold(
        context,
        title: _applyingLabel(AppLocalizations.of(context)!, state.action),
        subtitle: AppLocalizations.of(context)!.changeScheduleApplying,
        isLoading: true,
        onBack: () => _handleBack(state),
      );
    }

    if (state is ChangeScheduleSuccess) {
      return _acceptedScaffold(context, state);
    }

    if (state is ChangeScheduleScheduled) {
      return _scheduledScaffold(context, state);
    }

    if (state is ChangeScheduleCancelled) {
      final preview = _lastPreview;
      final scheduled = _lastScheduled;
      return _outcomeScaffold(
        context,
        title: AppLocalizations.of(context)!.changeScheduleCancelledTitle,
        subtitle: AppLocalizations.of(context)!.changeScheduleCancelledSubtitle,
        detail: preview != null && scheduled != null
            ? AppLocalizations.of(context)!.changeSchedulePreviouslyScheduledFor(
                _formatDate(context, preview.effectiveFrom),
              )
            : null,
        onBack: () => _handleBack(state),
      );
    }

    if (state is ChangeScheduleActivated) {
      final preview = _lastPreview;
      return _outcomeScaffold(
        context,
        title: AppLocalizations.of(context)!.changeScheduleActivatedTitle,
        subtitle: AppLocalizations.of(context)!.changeScheduleActivatedSubtitle,
        detail: preview == null
            ? null
            : AppLocalizations.of(context)!.changeScheduleEffectiveDate(
                _formatDate(context, preview.effectiveFrom),
              ),
        onBack: () => _handleBack(state),
      );
    }

    if (state is ChangeScheduleUndone) {
      return _outcomeScaffold(
        context,
        title: AppLocalizations.of(context)!.changeScheduleUndoneTitle,
        subtitle: AppLocalizations.of(context)!.changeScheduleUndoneSubtitle,
        onBack: () => _handleBack(state),
      );
    }

    if (state is ChangeSchedulePreviewReady) {
      return _previewScaffold(context, state);
    }

    final draft = _draftFor(state);
    if (draft == null) {
      return _statusScaffold(
        context,
        title: AppLocalizations.of(context)!.changeScheduleFailureTitle,
        subtitle: AppLocalizations.of(context)!.changeScheduleErrorGeneric,
        isLoading: false,
        onBack: () => _handleBack(state),
      );
    }
    return _flowScaffold(context, state, draft);
  }

  Widget _flowScaffold(
    BuildContext context,
    ChangeScheduleState state,
    ChangeScheduleDraft draft,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isPreviewing = state is ChangeSchedulePreviewing;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.changeScheduleTitle,
        onBack: () => _handleBack(state),
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
                      Text(
                        l10n.changeScheduleStepProgress(_step, _totalSteps),
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_step == 1) _availabilityStep(context, draft),
                      if (_step == 2) _longRunStep(context, draft),
                      if (_step == 3) _reviewStep(context, draft),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_step == _totalSteps)
                AppButton(
                  key: const Key('changeSchedulePreview'),
                  label: l10n.changeSchedulePreview,
                  isLoading: isPreviewing,
                  onPressed: isPreviewing
                      ? null
                      : () => ref.read(changeScheduleProvider.notifier).preview(),
                )
              else
                AppButton(
                  key: const Key('changeScheduleStepContinue'),
                  label: l10n.changeScheduleStepContinue,
                  onPressed: draft.isValid ? _advance : null,
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('changeScheduleStepBack'),
                label: l10n.changeScheduleStepBack,
                variant: AppButtonVariant.secondary,
                onPressed: isPreviewing ? null : () => _handleBack(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availabilityStep(BuildContext context, ChangeScheduleDraft draft) {
    final l10n = AppLocalizations.of(context)!;
    final availability = draft.availability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: l10n.changeScheduleAvailabilityTitle,
          subtitle: l10n.changeScheduleAvailabilitySubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.changeScheduleAvailableDays, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.changeScheduleRunningDays(availability.availableDays.length),
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        ...availability.days.map((day) {
          final dayLabel = _weekdayLabel(day.day, l10n);
          final availabilityLabel = day.available
              ? l10n.changeScheduleAvailable
              : l10n.changeScheduleUnavailable;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DayAvailabilityCard(
              dayLabel: dayLabel,
              availabilityLabel: availabilityLabel,
              daySemantics: l10n.changeScheduleDayToggleSemantics(
                dayLabel,
                availabilityLabel,
              ),
              isAvailable: day.available,
              onToggle: () => _toggleDay(draft, day.day),
              capLabel: l10n.changeScheduleDurationCap,
              capOptions: _capOptions,
              selectedCap: day.maxDurationMinutes,
              capLabelFor: (cap) => _capLabel(cap, l10n),
              capSemanticsFor: (cap) => l10n.changeScheduleCapChoiceSemantics(
                dayLabel,
                _capLabel(cap, l10n),
              ),
              capKeyFor: (cap) =>
                  Key('changeScheduleCap${day.day}${cap ?? 'None'}'),
              onSelectCap: (cap) => _setDayCap(draft, day.day, cap),
              toggleKey: Key('changeScheduleDay${day.day}'),
            ),
          );
        }),
      ],
    );
  }

  Widget _longRunStep(BuildContext context, ChangeScheduleDraft draft) {
    final l10n = AppLocalizations.of(context)!;
    final availability = draft.availability;
    final availableDays = availability.availableDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: l10n.changeScheduleLongRunTitle,
          subtitle: l10n.changeScheduleLongRunSubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.changeSchedulePrimaryLongRun, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final day in availableDays)
              _ChoiceChip(
                label: _weekdayLabel(day, l10n),
                semanticsLabel: l10n.changeScheduleOptionSemantics(
                  _weekdayLabel(day, l10n),
                  day == availability.primaryLongRunWeekday
                      ? l10n.changeScheduleSelected
                      : l10n.changeScheduleNotSelected,
                ),
                selected: day == availability.primaryLongRunWeekday,
                onTap: () => _setPrimaryLongRunDay(draft, day),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.changeScheduleBackupLongRun, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _ChoiceChip(
              label: l10n.changeScheduleNoBackup,
              semanticsLabel: l10n.changeScheduleOptionSemantics(
                l10n.changeScheduleNoBackup,
                availability.backupLongRunWeekday == null
                    ? l10n.changeScheduleSelected
                    : l10n.changeScheduleNotSelected,
              ),
              selected: availability.backupLongRunWeekday == null,
              onTap: () => _setBackupLongRunDay(draft, null),
            ),
            for (final day in availableDays)
              if (day != availability.primaryLongRunWeekday)
                _ChoiceChip(
                  label: _weekdayLabel(day, l10n),
                  semanticsLabel: l10n.changeScheduleOptionSemantics(
                    _weekdayLabel(day, l10n),
                    day == availability.backupLongRunWeekday
                        ? l10n.changeScheduleSelected
                        : l10n.changeScheduleNotSelected,
                  ),
                  selected: day == availability.backupLongRunWeekday,
                  onTap: () => _setBackupLongRunDay(draft, day),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.changeScheduleSameDayTitle, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.md),
        _SelectionTile(
          label: l10n.changeScheduleSameDaySeparate,
          subtitle: l10n.changeScheduleSameDaySeparateSubtitle,
          semanticsLabel: l10n.changeScheduleOptionSemantics(
            l10n.changeScheduleSameDaySeparate,
            availability.sameDayRunStrengthPreference ==
                    ChangeScheduleSameDayPreference.separateSessions
                ? l10n.changeScheduleSelected
                : l10n.changeScheduleNotSelected,
          ),
          selected: availability.sameDayRunStrengthPreference ==
              ChangeScheduleSameDayPreference.separateSessions,
          onTap: () => _setSameDayPreference(
            draft,
            ChangeScheduleSameDayPreference.separateSessions,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SelectionTile(
          label: l10n.changeScheduleSameDayAvoid,
          subtitle: l10n.changeScheduleSameDayAvoidSubtitle,
          semanticsLabel: l10n.changeScheduleOptionSemantics(
            l10n.changeScheduleSameDayAvoid,
            availability.sameDayRunStrengthPreference ==
                    ChangeScheduleSameDayPreference.avoidSameDay
                ? l10n.changeScheduleSelected
                : l10n.changeScheduleNotSelected,
          ),
          selected: availability.sameDayRunStrengthPreference ==
              ChangeScheduleSameDayPreference.avoidSameDay,
          onTap: () => _setSameDayPreference(
            draft,
            ChangeScheduleSameDayPreference.avoidSameDay,
          ),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context, ChangeScheduleDraft draft) {
    final l10n = AppLocalizations.of(context)!;
    final availability = draft.availability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: l10n.changeScheduleReviewTitle,
          subtitle: l10n.changeScheduleReviewSubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.changeScheduleEffectiveWeek, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.md),
        _SelectionTile(
          label: l10n.changeScheduleEffectiveCurrent,
          subtitle: l10n.changeScheduleEffectiveCurrentSubtitle,
          semanticsLabel: l10n.changeScheduleOptionSemantics(
            l10n.changeScheduleEffectiveCurrent,
            draft.effectiveWeek == ChangeScheduleEffectiveWeek.current
                ? l10n.changeScheduleSelected
                : l10n.changeScheduleNotSelected,
          ),
          selected: draft.effectiveWeek == ChangeScheduleEffectiveWeek.current,
          onTap: () => _setEffectiveWeek(ChangeScheduleEffectiveWeek.current),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SelectionTile(
          label: l10n.changeScheduleEffectiveNext,
          subtitle: l10n.changeScheduleEffectiveNextSubtitle,
          semanticsLabel: l10n.changeScheduleOptionSemantics(
            l10n.changeScheduleEffectiveNext,
            draft.effectiveWeek == ChangeScheduleEffectiveWeek.next
                ? l10n.changeScheduleSelected
                : l10n.changeScheduleNotSelected,
          ),
          selected: draft.effectiveWeek == ChangeScheduleEffectiveWeek.next,
          onTap: () => _setEffectiveWeek(ChangeScheduleEffectiveWeek.next),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ReviewCard(
          lines: [
            l10n.changeScheduleReviewAvailability(
              availability.availableDays
                  .map((day) => _weekdayLabel(day, l10n))
                  .join(', '),
            ),
            l10n.changeScheduleReviewLongRun(
              _weekdayLabel(availability.primaryLongRunWeekday, l10n),
            ),
            l10n.changeScheduleReviewBackup(
              availability.backupLongRunWeekday == null
                  ? l10n.changeScheduleNoBackup
                  : _weekdayLabel(availability.backupLongRunWeekday!, l10n),
            ),
            l10n.changeScheduleReviewSameDay(
              _sameDayPreferenceLabel(
                availability.sameDayRunStrengthPreference,
                l10n,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewScaffold(
    BuildContext context,
    ChangeSchedulePreviewReady state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final preview = state.preview;
    final dateFormat = DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final effectiveDate = dateFormat.format(preview.effectiveFrom);
    final proposedSessions = preview.candidatePlan['sessions'];
    final proposedSessionCount = proposedSessions is List
        ? proposedSessions.length
        : 0;
    final shouldApplyNow =
        state.draft.effectiveWeek == ChangeScheduleEffectiveWeek.current;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.changeScheduleTitle,
        onBack: () => _handleBack(state),
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
                      Text(
                        l10n.changeSchedulePreviewTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.changeScheduleEffectiveDate(effectiveDate),
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _PreviewSummaryCard(
                        summaryLabel: l10n.changeSchedulePreviewGoalImpact(
                          _intFrom(preview.goalImpact['movedSessions']),
                          _intFrom(preview.goalImpact['shortenedSessions']),
                          _intFrom(preview.goalImpact['removedSessions']),
                          _intFrom(preview.goalImpact['splitSessions']),
                        ),
                        sessionLabel: l10n.changeSchedulePreviewCandidateSessions(
                          proposedSessionCount,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.changeSchedulePreviewWarnings,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (preview.warnings.isEmpty)
                        _InformationCard(
                          label: l10n.changeSchedulePreviewNoWarnings,
                          color: AppColors.info,
                        )
                      else
                        ...preview.warnings.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _InformationCard(
                              label: _warningLabel(warning, l10n),
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.changeSchedulePreviewImpacts,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (preview.impacts.isEmpty)
                        _InformationCard(
                          label: l10n.changeSchedulePreviewNoImpacts,
                          color: AppColors.info,
                        )
                      else
                        ...preview.impacts.map(
                          (impact) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _InformationCard(
                              label: _impactLabel(impact, l10n),
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: Key(
                  shouldApplyNow
                      ? 'changeScheduleApply'
                      : 'changeScheduleSchedule',
                ),
                label: shouldApplyNow
                    ? l10n.changeScheduleApplyNow
                    : l10n.changeScheduleSchedule,
                onPressed: () {
                  final notifier = ref.read(changeScheduleProvider.notifier);
                  if (shouldApplyNow) {
                    notifier.acceptNow();
                  } else {
                    notifier.schedule();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('changeScheduleStepBack'),
                label: l10n.changeScheduleStepBack,
                variant: AppButtonVariant.secondary,
                onPressed: () => _handleBack(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _acceptedScaffold(
    BuildContext context,
    ChangeScheduleSuccess state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final preview = _lastPreview ?? state.preview;
    return _outcomeScaffold(
      context,
      title: l10n.changeScheduleAcceptedTitle,
      subtitle: l10n.changeScheduleAcceptedSubtitle,
      detail: l10n.changeScheduleEffectiveDate(
        _formatDate(context, preview.effectiveFrom),
      ),
      onBack: () => _handleBack(state),
      primary: AppButton(
        key: const Key('changeScheduleUndo'),
        label: l10n.changeScheduleUndo,
        variant: AppButtonVariant.secondary,
        onPressed: () => ref.read(changeScheduleProvider.notifier).undo(),
      ),
    );
  }

  Widget _scheduledScaffold(
    BuildContext context,
    ChangeScheduleScheduled state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final preview = _lastPreview ?? state.preview;
    final scheduled = _lastScheduled ?? state.scheduled;
    final date = _formatDate(context, preview.effectiveFrom);
    return _outcomeScaffold(
      context,
      title: l10n.changeScheduleScheduledTitle,
      subtitle: l10n.changeScheduleScheduledSubtitle,
      detail: scheduled.activationStatus.isEmpty
          ? null
          : l10n.changeScheduleScheduledFor(date),
      onBack: () => _handleBack(state),
      primary: AppButton(
        key: const Key('changeScheduleCancel'),
        label: l10n.changeScheduleCancel,
        variant: AppButtonVariant.secondary,
        onPressed: () =>
            ref.read(changeScheduleProvider.notifier).cancelScheduled(),
      ),
    );
  }

  Widget _outcomeScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onBack,
    String? detail,
    Widget? primary,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.changeScheduleTitle, onBack: onBack),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium,
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          detail,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (primary != null) ...[
                primary,
                const SizedBox(height: AppSpacing.sm),
              ],
              AppButton(
                key: const Key('changeScheduleDone'),
                label: l10n.changeScheduleDone,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onBack,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.changeScheduleTitle, onBack: onBack),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    height: AppSpacing.xl,
                    width: AppSpacing.xl,
                    child: CircularProgressIndicator(
                      color: AppColors.accentPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _failureScaffold(
    BuildContext context,
    ChangeScheduleFailure state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final requiresAuthoritativeReload =
        state.reason.requiresAuthoritativeReload;
    final canRecover = state.draft != null && !requiresAuthoritativeReload;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.changeScheduleTitle,
        onBack: () => _handleBack(state),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.changeScheduleFailureTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _failureLabel(state.reason, l10n),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                key: const Key('changeScheduleReloadOrReturn'),
                label: _failureRecoveryLabel(state, l10n),
                onPressed: canRecover
                    ? () => _recoverFailure(state)
                    : () => ref
                          .read(changeScheduleProvider.notifier)
                          .retryInitialization(),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('changeScheduleDone'),
                label: l10n.changeScheduleDone,
                variant: AppButtonVariant.secondary,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _advance() {
    if (_step >= _totalSteps) return;
    setState(() => _step += 1);
  }

  void _handleBack(ChangeScheduleState state) {
    if (state is ChangeScheduleApplying) return;
    if (_isOutcome(state)) {
      _finish();
      return;
    }
    if (state is ChangeScheduleFailure) {
      if (state.reason.requiresAuthoritativeReload) {
        ref.read(changeScheduleProvider.notifier).retryInitialization();
      } else if (state.draft != null) {
        _recoverFailure(state);
      } else {
        _finish();
      }
      return;
    }
    if (_step > 1) {
      final draft = _draftFor(state);
      if (draft != null && state is! ChangeScheduleEditing) {
        ref.read(changeScheduleProvider.notifier).updateDraft(draft);
      }
      setState(() => _step -= 1);
      return;
    }
    _finish();
  }

  void _recoverFailure(ChangeScheduleFailure state) {
    final notifier = ref.read(changeScheduleProvider.notifier);
    if (state.reason.requiresAuthoritativeReload) {
      notifier.retryInitialization();
      return;
    }
    if (notifier.recoverFromFailure()) {
      if (state.action != ChangeScheduleAction.cancel &&
          state.action != ChangeScheduleAction.activate &&
          state.action != ChangeScheduleAction.undo) {
        setState(() => _step = _totalSteps);
      }
      return;
    }

    final draft = state.draft;
    if (draft == null) {
      notifier.retryInitialization();
      return;
    }
    notifier.updateDraft(draft);
    setState(() => _step = _totalSteps);
  }

  void _finish() => Navigator.of(context).maybePop();

  void _toggleDay(ChangeScheduleDraft draft, int targetDay) {
    final availability = draft.availability;
    final selectedDay = availability.days.firstWhere(
      (day) => day.day == targetDay,
    );
    if (selectedDay.available && availability.availableDays.length == 1) {
      return;
    }

    final nextDays = [
      for (final day in availability.days)
        ChangeScheduleAvailabilityDay(
          day: day.day,
          available: day.day == targetDay ? !day.available : day.available,
          maxDurationMinutes: day.day == targetDay && day.available
              ? null
              : day.maxDurationMinutes,
        ),
    ];
    final availableDays = [
      for (final day in nextDays)
        if (day.available) day.day,
    ];
    var primary = availability.primaryLongRunWeekday;
    if (!availableDays.contains(primary)) primary = availableDays.first;
    final backup = availability.backupLongRunWeekday;
    final clearBackup = backup != null &&
        (!availableDays.contains(backup) || backup == primary);
    final nextAvailability = availability.copyWith(
      days: nextDays,
      targetRunningDays: availableDays.length,
      primaryLongRunWeekday: primary,
      clearBackupLongRunWeekday: clearBackup,
    );
    ref.read(changeScheduleProvider.notifier).setAvailability(nextAvailability);
  }

  void _setDayCap(ChangeScheduleDraft draft, int targetDay, int? cap) {
    final availability = draft.availability;
    final nextDays = [
      for (final day in availability.days)
        ChangeScheduleAvailabilityDay(
          day: day.day,
          available: day.available,
          maxDurationMinutes: day.day == targetDay ? cap : day.maxDurationMinutes,
        ),
    ];
    ref
        .read(changeScheduleProvider.notifier)
        .setAvailability(availability.copyWith(days: nextDays));
  }

  void _setPrimaryLongRunDay(ChangeScheduleDraft draft, int day) {
    final availability = draft.availability;
    var nextAvailability = availability.withPrimaryLongRunDay(day);
    if (nextAvailability.backupLongRunWeekday == day) {
      nextAvailability = nextAvailability.copyWith(clearBackupLongRunWeekday: true);
    }
    ref.read(changeScheduleProvider.notifier).setAvailability(nextAvailability);
  }

  void _setBackupLongRunDay(ChangeScheduleDraft draft, int? day) {
    final availability = draft.availability;
    ref.read(changeScheduleProvider.notifier).setAvailability(
          day == null
              ? availability.copyWith(clearBackupLongRunWeekday: true)
              : availability.copyWith(backupLongRunWeekday: day),
        );
  }

  void _setSameDayPreference(
    ChangeScheduleDraft draft,
    ChangeScheduleSameDayPreference preference,
  ) {
    ref.read(changeScheduleProvider.notifier).setAvailability(
          draft.availability.copyWith(
            sameDayRunStrengthPreference: preference,
          ),
        );
  }

  void _setEffectiveWeek(ChangeScheduleEffectiveWeek effectiveWeek) {
    ref.read(changeScheduleProvider.notifier).setEffectiveWeek(effectiveWeek);
  }

  void _rememberLifecycleDetails(ChangeScheduleState state) {
    if (state is ChangeSchedulePreviewReady) {
      _lastPreview = state.preview;
    } else if (state is ChangeScheduleApplying) {
      _lastPreview = state.preview ?? _lastPreview;
      _lastScheduled = state.scheduled ?? _lastScheduled;
    } else if (state is ChangeScheduleScheduled) {
      _lastPreview = state.preview;
      _lastScheduled = state.scheduled;
    } else if (state is ChangeScheduleActivated) {
      _lastPreview = state.preview ?? _lastPreview;
      _lastScheduled = state.scheduled ?? _lastScheduled;
    } else if (state is ChangeScheduleSuccess) {
      _lastPreview = state.preview;
    } else if (state is ChangeScheduleFailure) {
      _lastPreview = state.preview ?? _lastPreview;
    }
  }

  bool _isOutcome(ChangeScheduleState state) =>
      state is ChangeScheduleSuccess ||
      state is ChangeScheduleScheduled ||
      state is ChangeScheduleCancelled ||
      state is ChangeScheduleActivated ||
      state is ChangeScheduleUndone;
}

ChangeScheduleDraft? _draftFor(ChangeScheduleState state) => switch (state) {
  ChangeScheduleLoading() => null,
  ChangeScheduleEditing(:final draft) => draft,
  ChangeSchedulePreviewing(:final draft) => draft,
  ChangeSchedulePreviewReady(:final draft) => draft,
  ChangeScheduleApplying(:final draft) => draft,
  ChangeScheduleScheduled(:final draft) => draft,
  ChangeScheduleCancelled(:final draft) => draft,
  ChangeScheduleActivated(:final draft) => draft,
  ChangeScheduleUndone(:final draft) => draft,
  ChangeScheduleSuccess(:final draft) => draft,
  ChangeScheduleFailure(:final draft) => draft,
};

String _weekdayLabel(int day, AppLocalizations l10n) => switch (day) {
  1 => l10n.weekdayMonday,
  2 => l10n.weekdayTuesday,
  3 => l10n.weekdayWednesday,
  4 => l10n.weekdayThursday,
  5 => l10n.weekdayFriday,
  6 => l10n.weekdaySaturday,
  7 => l10n.weekdaySunday,
  _ => l10n.changeScheduleUnavailable,
};

String _capLabel(int? cap, AppLocalizations l10n) =>
    cap == null ? l10n.changeScheduleNoCap : l10n.changeScheduleCapMinutes(cap);

String _sameDayPreferenceLabel(
  ChangeScheduleSameDayPreference preference,
  AppLocalizations l10n,
) => switch (preference) {
  ChangeScheduleSameDayPreference.separateSessions =>
    l10n.changeScheduleSameDaySeparate,
  ChangeScheduleSameDayPreference.avoidSameDay => l10n.changeScheduleSameDayAvoid,
};

String _warningLabel(String warning, AppLocalizations l10n) => switch (warning) {
  'long_run_backup' => l10n.changeScheduleWarningLongRunBackup,
  'shortened_for_time_cap' => l10n.changeScheduleWarningShortenedForTimeCap,
  'removed_for_constraints' => l10n.changeScheduleWarningRemovedForConstraints,
  'immutable_preserved' => l10n.changeScheduleWarningImmutablePreserved,
  'one_run_warning' => l10n.changeScheduleWarningOneRun,
  'constraints_not_fully_supported' =>
    l10n.changeScheduleWarningConstraintsNotFullySupported,
  _ => l10n.changeScheduleWarningFallback,
};

String _impactLabel(Object? impact, AppLocalizations l10n) {
  final key = impact is Map ? impact['key'] : null;
  return switch (key) {
    'move' => l10n.changeScheduleImpactMove,
    'long_run_backup' => l10n.changeScheduleImpactLongRunBackup,
    'shortened_for_time_cap' => l10n.changeScheduleImpactShortenedForTimeCap,
    'removed_for_constraints' => l10n.changeScheduleImpactRemovedForConstraints,
    'split_for_frequency' => l10n.changeScheduleImpactSplitForFrequency,
    _ => l10n.changeScheduleImpactFallback,
  };
}

String _failureLabel(
  ChangeScheduleFailureReason reason,
  AppLocalizations l10n,
) => switch (reason) {
  ChangeScheduleFailureReason.auth => l10n.changeScheduleErrorAuth,
  ChangeScheduleFailureReason.invalidInput => l10n.changeScheduleErrorInvalidInput,
  ChangeScheduleFailureReason.timeout => l10n.changeScheduleErrorTimeout,
  ChangeScheduleFailureReason.stale => l10n.changeScheduleErrorStale,
  ChangeScheduleFailureReason.expired => l10n.changeScheduleErrorExpired,
  ChangeScheduleFailureReason.conflict => l10n.changeScheduleErrorConflict,
  ChangeScheduleFailureReason.parse => l10n.changeScheduleErrorParse,
  ChangeScheduleFailureReason.generic => l10n.changeScheduleErrorGeneric,
};

String _failureRecoveryLabel(
  ChangeScheduleFailure state,
  AppLocalizations l10n,
) {
  if (state.reason.requiresAuthoritativeReload) {
    return l10n.changeScheduleReload;
  }

  return switch (state.action) {
    ChangeScheduleAction.cancel || ChangeScheduleAction.activate =>
      l10n.changeScheduleReturnToScheduled,
    ChangeScheduleAction.undo => l10n.changeScheduleReturnToUpdated,
    _ => l10n.changeScheduleReturnToReview,
  };
}

String _applyingLabel(
  AppLocalizations l10n,
  ChangeScheduleAction action,
) => switch (action) {
  ChangeScheduleAction.accept => l10n.changeScheduleApplyingAccept,
  ChangeScheduleAction.schedule => l10n.changeScheduleApplyingSchedule,
  ChangeScheduleAction.cancel => l10n.changeScheduleApplyingCancel,
  ChangeScheduleAction.activate => l10n.changeScheduleApplyingActivate,
  ChangeScheduleAction.undo => l10n.changeScheduleApplyingUndo,
};

int _intFrom(Object? value) => value is int ? value : 0;

String _formatDate(BuildContext context, DateTime date) => DateFormat.yMMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date);

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTypography.bodyMedium),
      ],
    );
  }
}

class _DayAvailabilityCard extends StatelessWidget {
  const _DayAvailabilityCard({
    required this.dayLabel,
    required this.availabilityLabel,
    required this.daySemantics,
    required this.isAvailable,
    required this.onToggle,
    required this.capLabel,
    required this.capOptions,
    required this.selectedCap,
    required this.capLabelFor,
    required this.capSemanticsFor,
    required this.capKeyFor,
    required this.onSelectCap,
    required this.toggleKey,
  });

  final String dayLabel;
  final String availabilityLabel;
  final String daySemantics;
  final bool isAvailable;
  final VoidCallback onToggle;
  final String capLabel;
  final List<int?> capOptions;
  final int? selectedCap;
  final String Function(int? cap) capLabelFor;
  final String Function(int? cap) capSemanticsFor;
  final Key Function(int? cap) capKeyFor;
  final ValueChanged<int?> onSelectCap;
  final Key toggleKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: isAvailable ? AppColors.borderFocused : AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: daySemantics,
            button: true,
            selected: isAvailable,
            child: InkWell(
              key: toggleKey,
              onTap: onToggle,
              borderRadius: AppRadius.borderLg,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayLabel, style: AppTypography.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(availabilityLabel, style: AppTypography.bodyMedium),
                        ],
                      ),
                    ),
                    _SelectionIndicator(selected: isAvailable),
                  ],
                ),
              ),
            ),
          ),
          if (isAvailable) ...[
            const Divider(height: 1, color: AppColors.borderDefault),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(capLabel, style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final cap in capOptions)
                        _ChoiceChip(
                          key: capKeyFor(cap),
                          label: capLabelFor(cap),
                          semanticsLabel: capSemanticsFor(cap),
                          selected: cap == selectedCap,
                          onTap: () => onSelectCap(cap),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    required this.subtitle,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderLg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentMuted : AppColors.backgroundCard,
              borderRadius: AppRadius.borderLg,
              border: Border.all(
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.borderDefault,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
                _SelectionIndicator(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentPrimary : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.borderDefault,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: selected
                    ? AppColors.backgroundPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: AppSpacing.lg,
      width: AppSpacing.lg,
      decoration: BoxDecoration(
        color: selected ? AppColors.accentPrimary : AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                height: AppSpacing.sm,
                width: AppSpacing.sm,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.lines});

  final List<String> lines;

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
          for (var index = 0; index < lines.length; index++) ...[
            Text(lines[index], style: AppTypography.bodyMedium),
            if (index < lines.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PreviewSummaryCard extends StatelessWidget {
  const _PreviewSummaryCard({
    required this.summaryLabel,
    required this.sessionLabel,
  });

  final String summaryLabel;
  final String sessionLabel;

  @override
  Widget build(BuildContext context) {
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
          Text(summaryLabel, style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(sessionLabel, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: color),
      ),
      child: Text(label, style: AppTypography.bodyMedium),
    );
  }
}
