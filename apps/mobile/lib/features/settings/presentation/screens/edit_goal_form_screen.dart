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
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../domain/edit_goal_models.dart';
import '../edit_goal_provider.dart';

enum _EditGoalStep {
  changes,
  details,
  fitness,
  manualResult,
  scheduleAssessment,
}

class EditGoalFormScreen extends ConsumerStatefulWidget {
  const EditGoalFormScreen({super.key});

  @override
  ConsumerState<EditGoalFormScreen> createState() => _EditGoalFormScreenState();
}

class _EditGoalFormScreenState extends ConsumerState<EditGoalFormScreen> {
  _EditGoalStep _step = _EditGoalStep.changes;
  final _distanceController = TextEditingController();
  final _timeController = TextEditingController();
  DateTime? _resultDate;
  DateTime? _assessmentDate;
  bool? _hardEffort;
  String? _validation;

  @override
  void dispose() {
    _distanceController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(editGoalProvider);
    final draft = _draft(state);
    final screen = switch (state) {
      EditGoalLoading() => const Center(child: CircularProgressIndicator()),
      EditGoalFailure(:final draft) when draft == null => _InitialLoadFailure(
        message: _failureText(state.reason, l10n),
        retryLabel: l10n.editGoalRetry,
        onRetry: () =>
            ref.read(editGoalProvider.notifier).retryInitialization(),
      ),
      EditGoalFitnessCheckRequired(:final fitnessCheck, :final draft) =>
        _buildFitnessCheck(context, l10n, draft, fitnessCheck),
      EditGoalAssessmentPending(:final draft) => _buildAssessmentPending(
        context,
        l10n,
        draft,
      ),
      _ when draft != null => _buildEditing(context, l10n, draft, state),
      _ => _InitialLoadFailure(
        message: l10n.editGoalErrorParse,
        retryLabel: l10n.editGoalRetry,
        onRetry: () =>
            ref.read(editGoalProvider.notifier).retryInitialization(),
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.editGoalFormTitle,
        onBack: () {
          if (_step != _EditGoalStep.changes) {
            setState(() {
              _step = _EditGoalStep.changes;
              _validation = null;
            });
          } else {
            context.pop();
          }
        },
      ),
      body: SafeArea(top: false, child: screen),
    );
  }

  Widget _buildEditing(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
    EditGoalState state,
  ) {
    return switch (_step) {
      _EditGoalStep.changes => _buildChanges(context, l10n, draft),
      _EditGoalStep.details => _buildDetails(context, l10n, draft, state),
      _EditGoalStep.manualResult => _buildManualResult(
        context,
        l10n,
        draft,
        source: EditGoalFitnessSource.manual,
      ),
      _EditGoalStep.scheduleAssessment => const SizedBox.shrink(),
      _EditGoalStep.fitness => const SizedBox.shrink(),
    };
  }

  Widget _buildChanges(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
  ) {
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editGoalCurrentGoalLabel, style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _CurrentGoalCard(draft: draft),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.editGoalWhatChangedTitle,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalWhatChangedSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SelectCard(
            key: const Key('editGoalDistanceChange'),
            label: l10n.editGoalChangeDistanceTitle,
            subtitle: l10n.editGoalChangeDistanceSubtitle,
            selected: draft.changes.contains(EditGoalChange.distance),
            onTap: () => _toggleChange(draft, EditGoalChange.distance),
          ),
          const SizedBox(height: AppSpacing.md),
          _SelectCard(
            key: const Key('editGoalDateChange'),
            label: l10n.editGoalChangeDateTitle,
            subtitle: l10n.editGoalChangeDateSubtitle,
            selected: draft.changes.contains(EditGoalChange.raceDate),
            onTap: () => _toggleChange(draft, EditGoalChange.raceDate),
          ),
          const Spacer(),
          AppButton(
            key: const Key('editGoalChangesContinue'),
            label: l10n.continueButton,
            onPressed: !draft.isChangeSelected
                ? null
                : () => setState(() => _step = _EditGoalStep.details),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.editGoalDiscard,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await ref.read(editGoalProvider.notifier).discard();
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
    EditGoalState state,
  ) {
    final isPreviewing = state is EditGoalPreviewing;
    final failure = state is EditGoalFailure ? state : null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editGoalDetailsTitle, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalDetailsSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (draft.changes.contains(EditGoalChange.distance)) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(label: l10n.editGoalDistanceSection),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: RunnerGoalRace.values
                  .where((race) => race != RunnerGoalRace.other)
                  .map(
                    (race) => _ChoiceChip(
                      label: _raceLabel(race, l10n),
                      selected: draft.race == race,
                      onTap: () => _update(
                        draft.copyWith(
                          race: race,
                          clearFitnessResult: true,
                          clearAssessment: true,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (draft.changes.contains(EditGoalChange.raceDate)) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(label: l10n.editGoalFixedDateSection),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _ToggleCard(
                    label: l10n.editGoalHasDate,
                    selected: draft.hasRaceDate,
                    onTap: () => _update(
                      draft.copyWith(
                        hasRaceDate: true,
                        clearFitnessResult: true,
                        clearAssessment: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ToggleCard(
                    label: l10n.editGoalNoDate,
                    selected: !draft.hasRaceDate,
                    onTap: () => _update(
                      draft.copyWith(
                        hasRaceDate: false,
                        clearRaceDate: true,
                        clearFitnessResult: true,
                        clearAssessment: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (draft.hasRaceDate) ...[
              const SizedBox(height: AppSpacing.md),
              _DateField(
                label: draft.raceDate == null
                    ? l10n.tapToSetDate
                    : DateFormat.yMMMd(locale).format(draft.raceDate!),
                onTap: () => _pickRaceDate(draft),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              _InformationNote(text: l10n.editGoalNoDateNote),
            ],
          ],
          if (state is EditGoalEditing && state.wasRebased) ...[
            const SizedBox(height: AppSpacing.lg),
            _InformationNote(text: l10n.editGoalUpdatedSincePreview),
          ],
          if (_validation != null || failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorText(
              _validation == 'date'
                  ? l10n.editGoalDatePastError
                  : failure == null
                  ? l10n.editGoalErrorInvalid
                  : _failureText(failure.reason, l10n),
            ),
          ],
          const Spacer(),
          AppButton(
            key: const Key('editGoalReviewChanges'),
            label: isPreviewing
                ? l10n.editGoalPreviewLoading
                : l10n.editGoalPreviewChanges,
            isLoading: isPreviewing,
            onPressed: isPreviewing ? null : () => _review(draft),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessCheck(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
    GoalEditFitnessCheck check,
  ) {
    if (_step == _EditGoalStep.manualResult) {
      return _buildManualResult(
        context,
        l10n,
        draft,
        source: EditGoalFitnessSource.manual,
      );
    }
    if (_step == _EditGoalStep.scheduleAssessment) {
      return _buildScheduleAssessment(context, l10n, draft, check);
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editGoalFitnessCheckTitle,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalFitnessCheckSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (check.suggestedActivities.isNotEmpty) ...[
            SectionLabel(label: l10n.editGoalRecommendedResult),
            const SizedBox(height: AppSpacing.md),
            ...check.suggestedActivities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SuggestedActivityCard(
                  activity: activity,
                  dateFormat: DateFormat.yMMMd(locale),
                  onUse: () => _prefillSuggestedActivity(activity),
                ),
              ),
            ),
          ],
          SectionLabel(label: l10n.editGoalOtherOptions),
          const SizedBox(height: AppSpacing.md),
          _SelectCard(
            label: l10n.editGoalEnterResult,
            subtitle: l10n.editGoalEnterResultSubtitle,
            selected: false,
            onTap: () => setState(() {
              _hardEffort = null;
              _validation = null;
              _step = _EditGoalStep.manualResult;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          _SelectCard(
            label: l10n.editGoalScheduleBenchmark,
            subtitle: l10n.editGoalScheduleBenchmarkSubtitle,
            selected: false,
            onTap: () =>
                setState(() => _step = _EditGoalStep.scheduleAssessment),
          ),
          const Spacer(),
          AppButton(
            label: l10n.editGoalKeepCurrent,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              ref.read(editGoalProvider.notifier).cancelPreview();
              setState(() => _step = _EditGoalStep.details);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManualResult(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft, {
    required EditGoalFitnessSource source,
  }) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editGoalEnterResult, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalManualResultSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _InputLabel(label: l10n.editGoalResultDistance),
          const SizedBox(height: AppSpacing.sm),
          _TextInput(
            key: const Key('editGoalResultDistance'),
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hint: l10n.editGoalResultDistanceHint,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InputLabel(label: l10n.editGoalResultTime),
          const SizedBox(height: AppSpacing.sm),
          _TextInput(
            key: const Key('editGoalResultTime'),
            controller: _timeController,
            keyboardType: TextInputType.datetime,
            hint: l10n.editGoalResultTimeHint,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InputLabel(label: l10n.editGoalResultDate),
          const SizedBox(height: AppSpacing.sm),
          _DateField(
            label: _resultDate == null
                ? l10n.tapToSetDate
                : DateFormat.yMMMd(locale).format(_resultDate!),
            onTap: _pickResultDate,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InputLabel(label: l10n.editGoalHardEffortQuestion),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ToggleCard(
                  label: l10n.yes,
                  selected: _hardEffort == true,
                  onTap: () => setState(() => _hardEffort = true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ToggleCard(
                  label: l10n.no,
                  selected: _hardEffort == false,
                  onTap: () => setState(() => _hardEffort = false),
                ),
              ),
            ],
          ),
          if (_validation != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorText(l10n.editGoalResultValidation),
          ],
          const Spacer(),
          AppButton(
            label: l10n.editGoalUseResult,
            onPressed: () => _useManualResult(draft, source),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleAssessment(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
    GoalEditFitnessCheck check,
  ) {
    final safeDates = check.safeDates;
    _assessmentDate ??= safeDates.isEmpty ? null : safeDates.first;
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editGoalBenchmarkTitle,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            check.benchmarkKind == 'five_k_run'
                ? l10n.editGoalBenchmarkFiveKExplanation
                : l10n.editGoalBenchmarkOneKExplanation,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(label: l10n.editGoalSafeDatesLabel),
          const SizedBox(height: AppSpacing.md),
          if (safeDates.isEmpty)
            _InformationNote(text: l10n.editGoalNoSafeDates)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: safeDates
                  .map(
                    (date) => _ChoiceChip(
                      label: DateFormat.MMMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(date),
                      selected: _assessmentDate == date,
                      onTap: () => setState(() => _assessmentDate = date),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: AppSpacing.lg),
          _InformationNote(text: l10n.editGoalBenchmarkPlanNote),
          const Spacer(),
          AppButton(
            label: l10n.editGoalScheduleAssessmentButton,
            onPressed: _assessmentDate == null
                ? null
                : () => ref
                      .read(editGoalProvider.notifier)
                      .scheduleAssessment(check, _assessmentDate!),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentPending(
    BuildContext context,
    AppLocalizations l10n,
    EditGoalDraft draft,
  ) {
    if (_step == _EditGoalStep.manualResult) {
      return _buildManualResult(
        context,
        l10n,
        draft,
        source: EditGoalFitnessSource.assessment,
      );
    }
    final assessment = draft.assessment!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _PageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editGoalInProgressTitle,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalInProgressSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _AssessmentCard(
            assessment: assessment,
            dateFormat: DateFormat.yMMMd(locale),
          ),
          const Spacer(),
          AppButton(
            label: l10n.editGoalEnterAssessmentResult,
            onPressed: () => setState(() {
              _hardEffort = null;
              _validation = null;
              _step = _EditGoalStep.manualResult;
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.editGoalUseAnotherResult,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              ref.read(editGoalProvider.notifier).cancelAssessment();
              setState(() {
                _hardEffort = null;
                _validation = null;
                _step = _EditGoalStep.manualResult;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.editGoalDiscard,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await ref.read(editGoalProvider.notifier).discard();
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
    );
  }

  void _toggleChange(EditGoalDraft draft, EditGoalChange change) {
    _update(draft.toggleChange(change));
  }

  void _update(EditGoalDraft draft) {
    setState(() => _validation = null);
    ref.read(editGoalProvider.notifier).updateDraft(draft);
  }

  Future<void> _pickRaceDate(EditGoalDraft draft) async {
    final now = ref.read(editGoalClockProvider)();
    final firstDate = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate:
          draft.raceDate != null && !draft.raceDate!.isBefore(firstDate)
          ? draft.raceDate!
          : firstDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365 * 5)),
    );
    if (selected != null) _update(draft.copyWith(raceDate: selected));
  }

  Future<void> _pickResultDate() async {
    final now = ref.read(editGoalClockProvider)();
    final selected = await showDatePicker(
      context: context,
      initialDate: _resultDate ?? now,
      firstDate: now.subtract(const Duration(days: 84)),
      lastDate: now,
    );
    if (selected != null) setState(() => _resultDate = selected);
  }

  Future<void> _review(EditGoalDraft draft) async {
    final now = ref.read(editGoalClockProvider)();
    if (draft.hasRaceDate &&
        (draft.raceDate == null ||
            draft.raceDate!.isBefore(DateTime(now.year, now.month, now.day)))) {
      setState(() => _validation = 'date');
      return;
    }
    final ready = await ref.read(editGoalProvider.notifier).preview();
    if (ready && mounted) {
      context.push(RouteNames.settingsUpdatePlanEditGoalPreview);
    }
  }

  void _useManualResult(EditGoalDraft draft, EditGoalFitnessSource source) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final distance = NumberFormat.decimalPattern(
      locale,
    ).tryParse(_distanceController.text.trim())?.toDouble();
    final elapsed = _parseDuration(_timeController.text);
    final date = _resultDate;
    if (distance == null ||
        distance <= 0 ||
        elapsed == null ||
        date == null ||
        _hardEffort != true) {
      setState(() => _validation = 'result');
      return;
    }
    final result = EditGoalFitnessResult(
      source: source,
      distanceKm: distance,
      elapsed: elapsed,
      recordedOn: date,
      hardEffort: true,
    );
    ref.read(editGoalProvider.notifier).useFitnessResult(result);
    final updated = _draft(ref.read(editGoalProvider));
    if (updated != null) _review(updated);
  }

  void _prefillSuggestedActivity(GoalEditSuggestedActivity activity) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() {
      _distanceController.text = NumberFormat(
        '0.##',
        locale,
      ).format(activity.distanceKm);
      _timeController.text = _formatDuration(activity.elapsed);
      _resultDate = activity.recordedOn;
      _hardEffort = null;
      _validation = null;
      _step = _EditGoalStep.manualResult;
    });
  }
}

class _PageLayout extends StatelessWidget {
  const _PageLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.lg,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _CurrentGoalCard extends StatelessWidget {
  const _CurrentGoalCard({required this.draft});
  final EditGoalDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goal = draft.originalGoal;
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
          Text(_raceLabel(goal.race, l10n), style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            goal.raceDate == null
                ? l10n.editGoalNoFixedDate
                : DateFormat.yMMMd(locale).format(goal.raceDate!),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
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
          color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.borderFull,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentPrimary : AppColors.backgroundCard,
        borderRadius: AppRadius.borderFull,
        border: Border.all(
          color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: selected
              ? AppColors.backgroundPrimary
              : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.borderLg,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: selected ? AppColors.accentMuted : AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: Center(child: Text(label, style: AppTypography.titleMedium)),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('editGoalDateField'),
    onTap: onTap,
    borderRadius: AppRadius.borderLg,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(label, style: AppTypography.bodyLarge),
    ),
  );
}

class _SuggestedActivityCard extends StatelessWidget {
  const _SuggestedActivityCard({
    required this.activity,
    required this.dateFormat,
    required this.onUse,
  });
  final GoalEditSuggestedActivity activity;
  final DateFormat dateFormat;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
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
          Text(
            l10n.editGoalSuggestedActivity(
              dateFormat.format(activity.recordedOn),
              NumberFormat('0.0', locale).format(activity.distanceKm),
              _formatDuration(activity.elapsed),
            ),
            style: AppTypography.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: l10n.editGoalUseThisActivity, onPressed: onUse),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, required this.dateFormat});
  final EditGoalAssessment assessment;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFiveK = assessment.kind == 'five_k_run';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.accentPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFiveK ? l10n.editGoalBenchmarkFiveK : l10n.editGoalBenchmarkOneK,
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateFormat.format(assessment.scheduledFor),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.editGoalAssessmentScheduled,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.accentLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.controller,
    required this.keyboardType,
    required this.hint,
  });
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    key: key,
    controller: controller,
    keyboardType: keyboardType,
    style: AppTypography.bodyLarge,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.backgroundCard,
      border: const OutlineInputBorder(
        borderRadius: AppRadius.borderLg,
        borderSide: BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.borderLg,
        borderSide: BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.borderLg,
        borderSide: BorderSide(color: AppColors.accentPrimary),
      ),
    ),
  );
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTypography.labelLarge);
}

class _InformationNote extends StatelessWidget {
  const _InformationNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.base),
    decoration: BoxDecoration(
      color: AppColors.accentMuted,
      borderRadius: AppRadius.borderLg,
    ),
    child: Text(
      text,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.caption.copyWith(color: AppColors.error));
}

class _InitialLoadFailure extends StatelessWidget {
  const _InitialLoadFailure({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ErrorText(message),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('editGoalInitializationRetry'),
          label: retryLabel,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

EditGoalDraft? _draft(EditGoalState state) => switch (state) {
  EditGoalEditing(:final draft) ||
  EditGoalFitnessCheckRequired(:final draft) ||
  EditGoalAssessmentPending(:final draft) ||
  EditGoalPreviewing(:final draft) ||
  EditGoalPreviewReady(:final draft) ||
  EditGoalApplying(:final draft) => draft,
  EditGoalFailure(:final draft) => draft,
  EditGoalLoading() || EditGoalSuccess() => null,
};

String _raceLabel(RunnerGoalRace race, AppLocalizations l10n) => switch (race) {
  RunnerGoalRace.fiveK => l10n.race5K,
  RunnerGoalRace.tenK => l10n.race10K,
  RunnerGoalRace.halfMarathon => l10n.raceHalfMarathon,
  RunnerGoalRace.marathon => l10n.raceMarathon,
  RunnerGoalRace.other => l10n.raceOther,
};

Duration? _parseDuration(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 3) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = int.tryParse(parts[2]);
  if (hours == null ||
      minutes == null ||
      seconds == null ||
      hours < 0 ||
      minutes < 0 ||
      minutes > 59 ||
      seconds < 0 ||
      seconds > 59) {
    return null;
  }
  final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
  return duration > Duration.zero ? duration : null;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _failureText(EditGoalFailureReason reason, AppLocalizations l10n) =>
    switch (reason) {
      EditGoalFailureReason.auth => l10n.editGoalErrorAuth,
      EditGoalFailureReason.invalidInput => l10n.editGoalErrorInvalid,
      EditGoalFailureReason.timeout => l10n.editGoalErrorTimeout,
      EditGoalFailureReason.stale => l10n.editGoalErrorStale,
      EditGoalFailureReason.expired => l10n.editGoalErrorExpired,
      EditGoalFailureReason.conflict => l10n.editGoalErrorConflict,
      EditGoalFailureReason.parse => l10n.editGoalErrorParse,
      EditGoalFailureReason.generic => l10n.editGoalErrorGeneric,
    };
