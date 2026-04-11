import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../training_plan/data/supabase_plan_version_repository.dart';
import '../../training_plan/domain/models/plan_version.dart';
import '../../training_plan/domain/models/training_plan.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class PlanGenerationState {
  const PlanGenerationState();
}

class PlanGenerationIdle extends PlanGenerationState {
  const PlanGenerationIdle();
}

class PlanGenerationLoading extends PlanGenerationState {
  const PlanGenerationLoading();
}

class PlanGenerationSuccess extends PlanGenerationState {
  const PlanGenerationSuccess(this.versionId);
  final String versionId;
}

class PlanGenerationFailure extends PlanGenerationState {
  const PlanGenerationFailure(this.reason);

  /// Canonical failure key — localized at the UI layer.
  ///
  /// Possible values: 'generation_no_data', 'generation_parse_error',
  /// 'generation_timeout', 'generation_error'
  final String reason;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PlanGenerationNotifier extends Notifier<PlanGenerationState> {
  @override
  PlanGenerationState build() => const PlanGenerationIdle();

  /// Calls the `generate-plan` Edge Function, parses the returned plan,
  /// saves it to the repository, and transitions state accordingly.
  ///
  /// [requestedBy] is a canonical source key:
  ///   'onboarding' | 'settings_update' | 'retry'
  Future<void> generate({required String requestedBy}) async {
    state = const PlanGenerationLoading();
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions
          .invoke(
            'generate-plan',
            body: {'requestedBy': requestedBy},
          )
          .timeout(const Duration(seconds: 60));

      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['versionId'] == null) {
        state = const PlanGenerationFailure('generation_no_data');
        return;
      }

      final rawPlan = data['plan'];
      if (rawPlan is! Map<String, dynamic>) {
        state = const PlanGenerationFailure('generation_parse_error');
        return;
      }

      final plan = TrainingPlan.fromJson(rawPlan);
      if (plan == null) {
        state = const PlanGenerationFailure('generation_parse_error');
        return;
      }

      final version = PlanVersion(
        id: data['versionId'] as String,
        generatedAt: DateTime.now(),
        requestedBy: requestedBy,
        isActive: true,
        plan: plan,
      );
      await ref.read(planVersionRepositoryProvider).saveActivePlan(version);

      state = PlanGenerationSuccess(data['versionId'] as String);
    } on TimeoutException {
      state = const PlanGenerationFailure('generation_timeout');
    } catch (_) {
      state = const PlanGenerationFailure('generation_error');
    }
  }

  /// Resets back to idle (used when the user dismisses the error state
  /// without retrying, or before a retry attempt).
  void reset() => state = const PlanGenerationIdle();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final planGenerationProvider =
    NotifierProvider<PlanGenerationNotifier, PlanGenerationState>(
  PlanGenerationNotifier.new,
);
