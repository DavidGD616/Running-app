import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../features/onboarding/presentation/onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';
import '../new_goal_provider.dart';
import '../../domain/new_goal_models.dart';

class NewGoalIntroScreen extends ConsumerStatefulWidget {
  const NewGoalIntroScreen({super.key});

  @override
  ConsumerState<NewGoalIntroScreen> createState() => _NewGoalIntroScreenState();
}

class _NewGoalIntroScreenState extends ConsumerState<NewGoalIntroScreen> {
  bool _isStartingOver = false;

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

  bool _hasRestoredDraft(NewGoalState state) => switch (state) {
        NewGoalEditing(:final hasRestoredDraft) => hasRestoredDraft,
        _ => false,
      };

  Future<void> _continue() async {
    context.push(RouteNames.settingsUpdatePlanNewGoalForm);
  }

  Future<void> _startOver() async {
    setState(() {
      _isStartingOver = true;
    });

    try {
      await ref.read(newGoalProvider.notifier).startOver();
      if (!mounted) return;
      context.push(RouteNames.settingsUpdatePlanNewGoalForm);
    } finally {
      if (mounted) {
        setState(() {
          _isStartingOver = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(newGoalProvider);
    final draft = _draftFromState(state);
    final hasRestoredDraft = _hasRestoredDraft(state);

    if (state is NewGoalLoading && draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (draft == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppDetailHeaderBar(title: l10n.settingsNewGoal),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.lg,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  state is NewGoalFailure
                      ? _failureText(state.reason, l10n)
                      : l10n.errorGeneric,
                  style: AppTypography.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.editGoalKeepCurrent,
                  onPressed: () =>
                      ref.read(newGoalProvider.notifier).retryInitialization(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final raceLabel = OnboardingValues.localizeRace(draft.race.key, l10n);
    final dateLabel = draft.effectiveGoal.hasRaceDate && draft.raceDate != null
        ? DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(
              draft.raceDate!,
            )
        : l10n.editGoalNoDate;

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
                      Text(
                        l10n.settingsNewGoalIntroTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.settingsNewGoalIntroSubtitle,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.settingsSummaryGoalSection,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoCard(
                        title: l10n.goalRaceLabel,
                        race: raceLabel,
                        dateLabel: dateLabel,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _GoalPoint(text: l10n.settingsNewGoalIntroPointRace),
                      const SizedBox(height: AppSpacing.md),
                      _GoalPoint(text: l10n.settingsNewGoalIntroPointDate),
                      const SizedBox(height: AppSpacing.md),
                      _GoalPoint(text: l10n.settingsNewGoalIntroPointPlan),
                      const SizedBox(height: AppSpacing.md),
                      _GoalPoint(text: l10n.settingsNewGoalIntroPointTraining),
                    ],
                  ),
                ),
              ),
              if (hasRestoredDraft) ...[
                AppButton(
                  label: l10n.continueButton,
                  onPressed: _continue,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.editGoalDiscard,
                  variant: AppButtonVariant.secondary,
                  onPressed: _isStartingOver ? null : _startOver,
                  isLoading: _isStartingOver,
                ),
              ] else
                AppButton(
                  label: l10n.setGoalButton,
                  onPressed: _continue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.race,
    required this.dateLabel,
  });

  final String title;
  final String race;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Text(race, style: AppTypography.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(dateLabel, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _GoalPoint extends StatelessWidget {
  const _GoalPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(text, style: AppTypography.bodyMedium),
    );
  }
}

String _failureText(NewGoalFailureReason reason, AppLocalizations l10n) =>
    l10n.errorGeneric;
