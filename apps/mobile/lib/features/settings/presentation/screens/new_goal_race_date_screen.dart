import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class NewGoalRaceDateScreen extends ConsumerStatefulWidget {
  const NewGoalRaceDateScreen({super.key});

  @override
  ConsumerState<NewGoalRaceDateScreen> createState() =>
      _NewGoalRaceDateScreenState();
}

class _NewGoalRaceDateScreenState extends ConsumerState<NewGoalRaceDateScreen> {
  RunnerGoalRace? _selectedRace;
  bool? _hasRaceDate;
  DateTime? _raceDate;
  bool _initialized = false;
  bool _isSubmitting = false;

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
    _selectedRace = draft.race;
    _hasRaceDate = draft.hasRaceDate;
    _raceDate = draft.raceDate;
  }

  Future<void> _pickRaceDate() async {
    final bounds = buildRaceDatePickerBounds(
      clock: ref.read(newGoalClockProvider)(),
    );
    final initialDate = pickInitialDate(
      selectedDate: _raceDate,
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
      _raceDate = picked;
    });
  }

  Future<void> _advance() async {
    if (!_canContinue || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(newGoalProvider.notifier).setRace(
            race: _selectedRace!,
            hasRaceDate: _hasRaceDate!,
            raceDate: _raceDate,
          );
      if (!mounted) return;
      context.push(RouteNames.settingsUpdatePlanNewGoalSchedule);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _canContinue =>
      _selectedRace != null &&
      _hasRaceDate != null &&
      (_hasRaceDate == false || _raceDate != null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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

    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final races = [
      OnboardingValues.race5k,
      OnboardingValues.race10k,
      OnboardingValues.raceHalfMarathon,
      OnboardingValues.raceMarathon,
    ].map((raceKey) {
      final label = OnboardingValues.localizeRace(raceKey, l10n);
      return (key: raceKey, label: label);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsNewGoal),
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
                      Text(l10n.goalRaceLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      ...races.map(
                        (race) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: _RaceCard(
                            label: race.label,
                            selected:
                                _selectedRace?.key == race.key,
                            onTap: () {
                              setState(() {
                                _selectedRace = switch (race.key) {
                                  OnboardingValues.race5k =>
                                    RunnerGoalRace.fiveK,
                                  OnboardingValues.race10k =>
                                    RunnerGoalRace.tenK,
                                  OnboardingValues.raceHalfMarathon =>
                                    RunnerGoalRace.halfMarathon,
                                  OnboardingValues.raceMarathon =>
                                    RunnerGoalRace.marathon,
                                  _ => _selectedRace,
                                };
                              });
                            },
                          ),
                        ),
                      ),
                      if (_selectedRace != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          l10n.raceHasDateLabel,
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _ToggleButton(
                                label: l10n.yes,
                                isSelected: _hasRaceDate == true,
                                onTap: () {
                                  setState(() {
                                    _hasRaceDate = true;
                                    _raceDate = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _ToggleButton(
                                label: l10n.no,
                                isSelected: _hasRaceDate == false,
                                onTap: () {
                                  setState(() {
                                    _hasRaceDate = false;
                                    _raceDate = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_hasRaceDate == true) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppPickerField(
                          label: l10n.raceDateLabel,
                          hint: l10n.tapToSetDate,
                          value: _raceDate != null
                              ? dateFormat.format(_raceDate!)
                              : null,
                          onTap: _pickRaceDate,
                        ),
                      ],
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

class _RaceCard extends StatelessWidget {
  const _RaceCard({
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/flame.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
