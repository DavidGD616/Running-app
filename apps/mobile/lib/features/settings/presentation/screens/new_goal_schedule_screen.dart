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
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../domain/new_goal_models.dart';
import '../new_goal_provider.dart';
import '../new_goal_date_picker_utils.dart';

class NewGoalScheduleScreen extends ConsumerStatefulWidget {
  const NewGoalScheduleScreen({super.key});

  @override
  ConsumerState<NewGoalScheduleScreen> createState() =>
      _NewGoalScheduleScreenState();
}

class _NewGoalScheduleScreenState
    extends ConsumerState<NewGoalScheduleScreen> {
  bool _initialized = false;
  bool _isSubmitting = false;
  String? _trainingDays;
  String? _longRunDay;
  String? _weekdayTime;
  String? _weekendTime;
  DateTime? _planStartDate;
  final Set<String> _hardDays = {};
  String? _preferredTimeOfDay;

  NewGoalDraft? _draftFromState(NewGoalState state) => switch (state) {
    NewGoalEditing(:final draft) => draft,
    NewGoalRecommendationLoading(:final draft) => draft,
    NewGoalProposalLoading(:final draft) => draft,
    NewGoalProposalReady(:final draft) => draft,
    NewGoalFitnessCheckRequired(:final draft) => draft,
    NewGoalAssessmentPending(:final draft) => draft,
    NewGoalRecommendationReady(:final draft) => draft,
    NewGoalApplying(:final draft) => draft,
    NewGoalFailure(:final draft) => draft,
    NewGoalLoading() => null,
    NewGoalSuccess() => null,
  };

  void _applyFromDraft(NewGoalDraft draft) {
    _trainingDays = draft.schedule.trainingDays.toString();
    _longRunDay = draft.schedule.longRunDay.key;
    _weekdayTime = draft.schedule.weekdayTime.key;
    _weekendTime = draft.schedule.weekendTime.key;
    _planStartDate = draft.planStartDate;
    _preferredTimeOfDay = draft.schedule.preferredTimeOfDay?.key;
    _hardDays
      ..clear()
      ..addAll(draft.schedule.hardDays.map((day) => day.key));
  }

  bool get _canContinue {
    return _trainingDays != null &&
        _longRunDay != null &&
        _weekdayTime != null &&
        _weekendTime != null &&
        _planStartDate != null;
  }

  Future<void> _pickPlanStartDate() async {
    final bounds = buildPlanStartDatePickerBounds(
      clock: ref.read(newGoalClockProvider)(),
    );
    final initialDate = pickInitialDate(
      selectedDate: _planStartDate,
      minDate: bounds.firstDate,
      maxDate: bounds.lastDate,
      fallbackDate: bounds.fallbackDate,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: bounds.firstDate,
      lastDate: bounds.lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            onPrimary: AppColors.backgroundPrimary,
            surface: AppColors.backgroundSecondary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _planStartDate = picked;
    });
  }

  Future<void> _advance() async {
    if (!_canContinue || _isSubmitting) return;
    final trainingDays = int.tryParse(_trainingDays ?? '');
    if (trainingDays == null) return;
    if (_longRunDay == null ||
        _weekdayTime == null ||
        _weekendTime == null ||
        _planStartDate == null) {
      return;
    }

    final notifier = ref.read(newGoalProvider.notifier);
    final schedule = NewGoalSchedule(
      trainingDays: trainingDays,
      longRunDay: WeekdayChoice.fromKey(_longRunDay!)!,
      weekdayTime: TimeSlot.fromKey(_weekdayTime!)!,
      weekendTime: TimeSlot.fromKey(_weekendTime!)!,
      hardDays: _hardDays
          .map((day) => WeekdayChoice.fromKey(day))
          .whereType<WeekdayChoice>()
          .toSet(),
      preferredTimeOfDay: _preferredTimeOfDay == null
          ? null
          : PreferredTimeOfDay.fromKey(_preferredTimeOfDay!),
    );

    setState(() => _isSubmitting = true);
    try {
      await notifier.setSchedule(schedule);
      await notifier.setPlanStartDate(_planStartDate!);
      if (!mounted) return;
      context.push(RouteNames.settingsUpdatePlanNewGoalTraining);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(localeTag);
    final state = ref.watch(newGoalProvider);
    final draft = _draftFromState(state);

    if (!_initialized && draft != null) {
      _applyFromDraft(draft);
      _initialized = true;
    }
    if (!_initialized && draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (draft == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: Text(l10n.errorGeneric)),
      );
    }

    final dayOptions = [
      OnboardingValues.dayMon,
      OnboardingValues.dayTue,
      OnboardingValues.dayWed,
      OnboardingValues.dayThu,
      OnboardingValues.dayFri,
      OnboardingValues.daySat,
      OnboardingValues.daySun,
    ];
    final trainingDayOptions = ['2', '3', '4', '5', '6', '7'];
    final weekdayTimeOptions = [
      OnboardingValues.time20min,
      OnboardingValues.time30min,
      OnboardingValues.time45min,
      OnboardingValues.time60min,
      OnboardingValues.time75plusMin,
      OnboardingValues.time90min,
      OnboardingValues.time2plusHours,
    ];
    final weekendTimeOptions = [
      OnboardingValues.time30min,
      OnboardingValues.time45min,
      OnboardingValues.time60min,
      OnboardingValues.time90min,
      OnboardingValues.time2plusHours,
    ];
    final timeOfDayOptions = [
      PreferredTimeOfDay.earlyMorning.key,
      PreferredTimeOfDay.morning.key,
      PreferredTimeOfDay.afternoon.key,
      PreferredTimeOfDay.evening.key,
      PreferredTimeOfDay.noPreference.key,
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.scheduleTitle),
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
                        l10n.trainingDaysLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: trainingDayOptions
                            .map(
                              (days) => _SelectChip(
                                label: days,
                                selected: _trainingDays == days,
                                onTap: () => setState(() => _trainingDays = days),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.longRunDayLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: dayOptions
                            .map(
                              (day) => _SelectChip(
                                label: OnboardingValues.localizeDay(day, l10n),
                                selected: _longRunDay == day,
                                onTap: () => setState(() => _longRunDay = day),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.weekdayTimeLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: weekdayTimeOptions
                            .map(
                              (time) => _SelectChip(
                                label: OnboardingValues.localizeTimeSlot(
                                  time,
                                  l10n,
                                ),
                                selected: _weekdayTime == time,
                                onTap: () => setState(
                                  () => _weekdayTime = time,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.weekendTimeLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: weekendTimeOptions
                            .map(
                              (time) => _SelectChip(
                                label: OnboardingValues.localizeTimeSlot(
                                  time,
                                  l10n,
                                ),
                                selected: _weekendTime == time,
                                onTap: () => setState(
                                  () => _weekendTime = time,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.hardDaysLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: dayOptions
                            .map(
                              (day) => _SelectChip(
                                label: OnboardingValues.localizeDay(day, l10n),
                                selected: _hardDays.contains(day),
                                onTap: () {
                                  setState(() {
                                    if (_hardDays.contains(day)) {
                                      _hardDays.remove(day);
                                    } else {
                                      _hardDays.add(day);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.preferredTimeOfDayLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: timeOfDayOptions
                            .map(
                              (option) => _SelectChip(
                                label: OnboardingValues.localizeTimeOfDay(
                                  option,
                                  l10n,
                                ),
                                selected: _preferredTimeOfDay == option,
                                onTap: () => setState(
                                  () => _preferredTimeOfDay = option,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.settingsNewGoalScheduleSection,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPickerField(
                        label: l10n.scheduleStartDateLabel,
                        hint: l10n.scheduleStartDate,
                        value: _planStartDate != null
                            ? dateFormat.format(_planStartDate!)
                            : null,
                        onTap: _pickPlanStartDate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.continueButton,
                isLoading: _isSubmitting,
                onPressed: _canContinue && !_isSubmitting ? _advance : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
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
          vertical: AppSpacing.md / 2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: selected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
