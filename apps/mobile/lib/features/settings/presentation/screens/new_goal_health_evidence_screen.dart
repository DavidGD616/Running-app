import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/new_goal_models.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../new_goal_provider.dart';

class NewGoalHealthEvidenceScreen extends ConsumerStatefulWidget {
  const NewGoalHealthEvidenceScreen({super.key});

  @override
  ConsumerState<NewGoalHealthEvidenceScreen> createState() =>
      _NewGoalHealthEvidenceScreenState();
}

class _NewGoalHealthEvidenceScreenState
    extends ConsumerState<NewGoalHealthEvidenceScreen> {
  String? _painLevel;
  String? _injuryHistory;
  String? _healthConditions;
  bool _isDirty = false;
  bool _initialized = false;
  bool _isSubmitting = false;

  void _applyFromDraft(NewGoalDraft draft) {
    final health = draft.health;
    _painLevel = health?.painLevel.key;
    _injuryHistory = health?.injuryHistory.key;
    _healthConditions = health?.hasHealthConditions.key;
    _isDirty = false;
  }

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

  bool get _isComplete =>
      _painLevel != null && _injuryHistory != null && _healthConditions != null;

  Future<void> _advance() async {
    if (!_isComplete || _isSubmitting) return;
    final provider = ref.read(newGoalProvider.notifier);
    setState(() => _isSubmitting = true);
    try {
      if (_isDirty &&
          _painLevel != null &&
          _injuryHistory != null &&
          _healthConditions != null) {
        await provider.setHealthSnapshot(
          NewGoalHealthSnapshot(
            painLevel: _painLevelChoice,
            injuryHistory: _injuryChoice,
            hasHealthConditions: _healthConditionChoice,
          ),
        );
      }

      if (_isDirty) {
        await provider.setHealthChanged(true);
      }
      if (!mounted) return;
      context.push(RouteNames.settingsUpdatePlanNewGoalRecommendation);
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

    if (!_initialized && draft != null) {
      _applyFromDraft(draft);
      _initialized = true;
    }

    if (draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final painOptions = {
      'pain_no': l10n.painNo,
      'pain_mild': l10n.painMild,
      'pain_moderate': l10n.painModerate,
      'pain_severe': l10n.painSevere,
    };
    final injuryOptions = {
      'injury_no': l10n.injuryNo,
      'injury_once': l10n.injuryOnce,
      'injury_multiple': l10n.injuryMultiple,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.healthTitle),
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
                        l10n.currentPainLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...painOptions.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _SelectCard(
                            label: entry.value,
                            isSelected: _painLevel == entry.key,
                            onTap: () {
                              setState(() {
                                _painLevel = entry.key;
                                _isDirty = true;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.recentInjuryLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: injuryOptions,
                        selected: _injuryHistory,
                        onSelect: (value) {
                          setState(() {
                            _injuryHistory = value;
                            _isDirty = true;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.healthConditionsLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.no,
                              isSelected: _healthConditions == 'no',
                              onTap: () {
                                setState(() {
                                  _healthConditions = 'no';
                                  _isDirty = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.yes,
                              isSelected: _healthConditions == 'yes',
                              onTap: () {
                                setState(() {
                                  _healthConditions = 'yes';
                                  _isDirty = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.continueButton,
                isLoading: _isSubmitting,
                onPressed: _isComplete && !_isSubmitting ? _advance : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _HealthEnums on _NewGoalHealthEvidenceScreenState {
  PainLevelChoice get _painLevelChoice {
    return switch (_painLevel) {
      'pain_no' => PainLevelChoice.none,
      'pain_mild' => PainLevelChoice.mild,
      'pain_moderate' => PainLevelChoice.moderate,
      _ => PainLevelChoice.severe,
    };
  }

  InjuryHistoryChoice get _injuryChoice {
    return switch (_injuryHistory) {
      'injury_once' => InjuryHistoryChoice.once,
      'injury_multiple' => InjuryHistoryChoice.multiple,
      _ => InjuryHistoryChoice.none,
    };
  }

  BinaryChoice get _healthConditionChoice {
    return _healthConditions == 'yes' ? BinaryChoice.yes : BinaryChoice.no;
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.entries
          .map((entry) {
            final isSelected = selected == entry.key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _ToggleButton(
                  label: entry.value,
                  isSelected: isSelected,
                  onTap: () => onSelect(entry.key),
                ),
              ),
            );
          })
          .toList(growable: false),
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
