import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../full_plan/presentation/screens/full_plan_screen.dart';
import '../new_goal_provider.dart';

_candidatePlanFromState(NewGoalState state) {
  return switch (state) {
    NewGoalProposalReady(:final proposal) => proposal.candidatePlan,
    NewGoalApplying(:final proposal) => proposal.candidatePlan,
    _ => null,
  };
}

class NewGoalFullPlanScreen extends ConsumerWidget {
  const NewGoalFullPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newGoalProvider);
    final l10n = AppLocalizations.of(context)!;
    final plan = _candidatePlanFromState(state);

    if (plan == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppDetailHeaderBar(title: l10n.newGoalFullPlanTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.newGoalFullPlanUnavailable,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final totalWeeks =
        _candidatePlanFromState(state)?.totalWeeks ?? plan.totalWeeks;

    return FullPlanScreen(
      trainingPlan: plan,
      title: l10n.newGoalFullPlanTitle,
      note: l10n.newGoalFullPlanNote(totalWeeks),
    );
  }
}
