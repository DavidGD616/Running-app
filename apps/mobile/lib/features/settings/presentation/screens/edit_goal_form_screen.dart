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

class EditGoalFormScreen extends ConsumerStatefulWidget {
  const EditGoalFormScreen({super.key});

  @override
  ConsumerState<EditGoalFormScreen> createState() => _EditGoalFormScreenState();
}

class _EditGoalFormScreenState extends ConsumerState<EditGoalFormScreen> {
  final _timeController = TextEditingController();
  bool _didPrefill = false;
  String? _localValidationKey;

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(editGoalProvider);
    final draft = _draft(state);
    if (draft != null && !_didPrefill) {
      _didPrefill = true;
      _timeController.text = _formatTime(draft.targetTime);
    }
    final isPreviewing = state is EditGoalPreviewing;
    final failure = state is EditGoalFailure ? state : null;
    final evidenceSuggestion = ref.watch(editGoalEvidenceSuggestionProvider);
    final selectedRaceSuggestion = evidenceSuggestion?.projectTo(
      draft?.race ?? RunnerGoalRace.other,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.editGoalFormTitle),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: state is EditGoalLoading
              ? const Center(child: CircularProgressIndicator())
              : draft == null
              ? _InitialLoadFailure(
                  message: failure == null
                      ? l10n.editGoalErrorParse
                      : _failureText(failure.reason, l10n),
                  retryLabel: l10n.editGoalRetry,
                  onRetry: () =>
                      ref.read(editGoalProvider.notifier).retryInitialization(),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.editGoalFormSubtitle,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
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
                                      onTap: () =>
                                          _update(draft.copyWith(race: race)),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            SectionLabel(label: l10n.editGoalFixedDateSection),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: _ToggleCard(
                                    label: l10n.yes,
                                    selected: draft.hasRaceDate,
                                    onTap: () => _update(
                                      draft.copyWith(hasRaceDate: true),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _ToggleCard(
                                    label: l10n.no,
                                    selected: !draft.hasRaceDate,
                                    onTap: () => _update(
                                      draft.copyWith(
                                        hasRaceDate: false,
                                        clearRaceDate: true,
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
                                    : DateFormat.yMMMd(
                                        Localizations.localeOf(
                                          context,
                                        ).toLanguageTag(),
                                      ).format(draft.raceDate!),
                                onTap: () => _pickDate(draft),
                              ),
                              if (_localValidationKey == 'date') ...[
                                const SizedBox(height: AppSpacing.xs),
                                _ErrorText(l10n.editGoalDateMinimumError),
                              ],
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            SectionLabel(label: l10n.editGoalTargetTimeSection),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              key: const Key('editGoalTargetTimeField'),
                              controller: _timeController,
                              keyboardType: TextInputType.datetime,
                              style: AppTypography.bodyLarge,
                              decoration: InputDecoration(
                                hintText: l10n.editGoalTargetTimeHint,
                                filled: true,
                                fillColor: AppColors.backgroundCard,
                                border: const OutlineInputBorder(
                                  borderRadius: AppRadius.borderLg,
                                  borderSide: BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                                enabledBorder: const OutlineInputBorder(
                                  borderRadius: AppRadius.borderLg,
                                  borderSide: BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: AppRadius.borderLg,
                                  borderSide: BorderSide(
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setState(() {
                                _localValidationKey = null;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.editGoalCurrentTarget(
                                _formatTime(draft.targetTime),
                              ),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (selectedRaceSuggestion != null)
                              Text(
                                l10n.editGoalSuggestedTarget(
                                  _formatTime(
                                    selectedRaceSuggestion.targetTime,
                                  ),
                                ),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.accentLight,
                                ),
                              ),
                            if (_localValidationKey == 'time') ...[
                              const SizedBox(height: AppSpacing.xs),
                              _ErrorText(l10n.editGoalTimeError),
                            ],
                            if (failure != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _ErrorText(_failureText(failure.reason, l10n)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: isPreviewing
                          ? l10n.editGoalPreviewLoading
                          : failure == null
                          ? l10n.editGoalPreviewChanges
                          : l10n.editGoalRetry,
                      isLoading: isPreviewing,
                      onPressed: isPreviewing ? null : () => _preview(draft),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _update(EditGoalDraft draft) {
    setState(() => _localValidationKey = null);
    ref.read(editGoalProvider.notifier).updateDraft(draft);
  }

  Future<void> _pickDate(EditGoalDraft draft) async {
    final now = ref.read(editGoalClockProvider)();
    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
    final initial =
        draft.raceDate != null && !draft.raceDate!.isBefore(firstDate)
        ? draft.raceDate!
        : firstDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365 * 5)),
    );
    if (selected != null) _update(draft.copyWith(raceDate: selected));
  }

  Future<void> _preview(EditGoalDraft draft) async {
    final parsed = _parseTime(_timeController.text);
    if (parsed == null) {
      setState(() => _localValidationKey = 'time');
      return;
    }
    final now = ref.read(editGoalClockProvider)();
    if (draft.hasRaceDate &&
        (draft.raceDate == null ||
            draft.raceDate!.isBefore(
              DateTime(
                now.year,
                now.month,
                now.day,
              ).add(const Duration(days: 7)),
            ))) {
      setState(() => _localValidationKey = 'date');
      return;
    }
    final updated = draft.copyWith(targetTime: parsed);
    ref.read(editGoalProvider.notifier).updateDraft(updated);
    final ready = await ref.read(editGoalProvider.notifier).preview();
    if (ready && mounted) {
      context.push(RouteNames.settingsUpdatePlanEditGoalPreview);
    }
  }
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
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
  EditGoalPreviewing(:final draft) ||
  EditGoalPreviewReady(:final draft) ||
  EditGoalApplying(:final draft) => draft,
  EditGoalFailure(:final draft) => draft,
  _ => null,
};

String _raceLabel(RunnerGoalRace race, AppLocalizations l10n) => switch (race) {
  RunnerGoalRace.fiveK => l10n.race5K,
  RunnerGoalRace.tenK => l10n.race10K,
  RunnerGoalRace.halfMarathon => l10n.raceHalfMarathon,
  RunnerGoalRace.marathon => l10n.raceMarathon,
  RunnerGoalRace.other => l10n.raceOther,
};

String _formatTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

Duration? _parseTime(String value) {
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
