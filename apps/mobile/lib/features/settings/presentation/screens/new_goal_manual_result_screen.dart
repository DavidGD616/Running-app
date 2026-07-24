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
import '../../../../l10n/app_localizations.dart';
import '../../domain/new_goal_models.dart';
import '../new_goal_provider.dart';

class NewGoalManualResultScreen extends ConsumerStatefulWidget {
  const NewGoalManualResultScreen({super.key});

  @override
  ConsumerState<NewGoalManualResultScreen> createState() =>
      _NewGoalManualResultScreenState();
}

class _NewGoalManualResultScreenState
    extends ConsumerState<NewGoalManualResultScreen> {
  final _distanceController = TextEditingController();
  final _timeController = TextEditingController();
  DateTime? _resultDate;
  bool? _hardEffort;
  String? _validation;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _distanceController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickResultDate() async {
    final now = _normalizeDate(ref.read(newGoalClockProvider)());
    final firstDate = now.subtract(const Duration(days: 84));
    final initialDate = _clampDateForPicker(
      requested: _resultDate ?? now,
      minDate: firstDate,
      maxDate: now,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _resultDate = _normalizeDate(selected));
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) return;

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
      setState(() => _validation = l10n.newGoalManualResultValidation);
      return;
    }

    final notifier = ref.read(newGoalProvider.notifier);
    final now = _normalizeDate(ref.read(newGoalClockProvider)());
    final normalizedDate = _normalizeDate(date);
    if (normalizedDate.isAfter(now)) {
      setState(() => _validation = l10n.newGoalManualResultValidation);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      notifier.useFitnessResult(
        NewGoalFitnessResult(
          source: NewGoalFitnessSource.manual,
          distanceKm: distance,
          elapsed: elapsed,
          recordedOn: normalizedDate,
          hardEffort: true,
        ),
      );
      if (!mounted) return;
      final success = await notifier.recommend();
      if (!mounted) return;
      if (success) {
        context.push(RouteNames.settingsUpdatePlanNewGoalRecommendation);
      } else {
        final failureState = ref.read(newGoalProvider);
        if (failureState is NewGoalFailure &&
            failureState.reason == NewGoalFailureReason.invalidInput) {
          setState(() => _validation = l10n.newGoalManualResultValidation);
        } else {
          setState(() => _validation = l10n.newGoalManualResultSubmissionError);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(newGoalProvider);
    final draft = _draftFromState(state);

    if (draft == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: const SafeArea(
          top: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.newGoalManualResultTitle),
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.newGoalManualResultTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.newGoalManualResultSubtitle,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _InputLabel(label: l10n.newGoalResultDistance),
                      const SizedBox(height: AppSpacing.sm),
                      _TextInput(
                        key: const Key('newGoalManualResultDistanceField'),
                        controller: _distanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        hint: l10n.newGoalResultDistanceHint,
                        onChanged: (_) {
                          if (_validation != null) {
                            setState(() => _validation = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InputLabel(label: l10n.newGoalResultTime),
                      const SizedBox(height: AppSpacing.sm),
                      _TextInput(
                        key: const Key('newGoalManualResultTimeField'),
                        controller: _timeController,
                        keyboardType: TextInputType.datetime,
                        hint: l10n.newGoalResultTimeHint,
                        onChanged: (_) {
                          if (_validation != null) {
                            setState(() => _validation = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InputLabel(label: l10n.newGoalResultDate),
                      const SizedBox(height: AppSpacing.sm),
                      _DateField(
                        key: const Key('newGoalManualResultDateField'),
                        label: _resultDate == null
                            ? l10n.tapToSetDate
                            : DateFormat.yMMMd(locale).format(_resultDate!),
                        onTap: _pickResultDate,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InputLabel(label: l10n.newGoalHardEffortQuestion),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleCard(
                              tapKey: const Key(
                                'newGoalManualResultHardEffortYes',
                              ),
                              label: l10n.yes,
                              selected: _hardEffort == true,
                              onTap: () {
                                setState(() {
                                  _hardEffort = true;
                                  _validation = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleCard(
                              tapKey: const Key(
                                'newGoalManualResultHardEffortNo',
                              ),
                              label: l10n.no,
                              selected: _hardEffort == false,
                              onTap: () {
                                setState(() {
                                  _hardEffort = false;
                                  _validation = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_validation != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ErrorText(_validation!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.newGoalManualResultUseButton,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

NewGoalDraft? _draftFromState(NewGoalState state) => switch (state) {
  NewGoalEditing(:final draft) => draft,
  NewGoalRecommendationLoading(:final draft) => draft,
  NewGoalRecommendationReady(:final draft) => draft,
  NewGoalFitnessCheckRequired(:final draft) => draft,
  NewGoalAssessmentPending(:final draft) => draft,
  NewGoalProposalLoading(:final draft) => draft,
  NewGoalProposalReady(:final draft) => draft,
  NewGoalApplying(:final draft) => draft,
  NewGoalFailure(:final draft) => draft,
  _ => null,
};

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tapKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) => InkWell(
    key: tapKey,
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
  const _DateField({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
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

class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.controller,
    required this.keyboardType,
    required this.hint,
    this.onChanged,
  });
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: key,
    controller: controller,
    keyboardType: keyboardType,
    style: AppTypography.bodyLarge,
    onChanged: onChanged,
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.caption.copyWith(color: AppColors.error));
}

DateTime _normalizeDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _clampDateForPicker({
  required DateTime requested,
  required DateTime minDate,
  required DateTime maxDate,
}) {
  final normalized = _normalizeDate(requested);
  if (normalized.isBefore(minDate)) return minDate;
  if (normalized.isAfter(maxDate)) return maxDate;
  return normalized;
}

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
