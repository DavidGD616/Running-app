import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../localization/presentation/locale_provider.dart';
import '../../training_plan/data/supabase_plan_version_repository.dart';
import '../../training_plan/domain/models/plan_version.dart';
import '../../training_plan/domain/models/training_plan.dart';
import '../domain/models/professional_plan_input.dart';

typedef PlanGenerationFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});

final planGenerationFunctionClientProvider =
    Provider<PlanGenerationFunctionClient>((ref) {
      final client = ref.read(supabaseClientProvider);
      return (name, {body}) => client.functions.invoke(name, body: body);
    });

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
  /// 'generation_timeout', 'generation_error', 'generation_input_missing'
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
  Future<void> generate({
    required String requestedBy,
    ProfessionalPlanInput? professionalPlanInput,
  }) async {
    if (requestedBy == _onboardingRequestedBy &&
        professionalPlanInput == null) {
      state = const PlanGenerationFailure('generation_input_missing');
      return;
    }

    state = const PlanGenerationLoading();
    try {
      final functionClient = ref.read(planGenerationFunctionClientProvider);
      final locale = ref.read(localeProvider).value;
      final localeCode = locale?.languageCode ?? 'en';

      final requestBody = <String, dynamic>{
        'requestedBy': requestedBy,
        'locale': localeCode,
      };
      if (professionalPlanInput != null) {
        requestBody['professionalPlanInput'] = professionalPlanInput.toJson();
      }

      final res = await functionClient(
        'generate-plan',
        body: requestBody,
      ).timeout(const Duration(seconds: 130));

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

  void emitInputMissingFailure() =>
      state = const PlanGenerationFailure('generation_input_missing');
}

const String _onboardingRequestedBy = 'onboarding';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final planGenerationProvider =
    NotifierProvider<PlanGenerationNotifier, PlanGenerationState>(
      PlanGenerationNotifier.new,
    );
