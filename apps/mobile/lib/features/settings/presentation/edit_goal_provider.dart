import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../../localization/presentation/locale_provider.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../../training_plan/data/supabase_plan_version_repository.dart';
import '../../training_plan/data/plan_version_repository.dart';
import '../../training_plan/domain/models/plan_version.dart';
import '../../training_plan/domain/models/training_plan.dart';
import '../../training_plan/presentation/training_plan_provider.dart';
import '../domain/edit_goal_models.dart';

typedef EditGoalFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});
typedef EditGoalInitialDataLoader = Future<EditGoalInitialData> Function();
typedef EditGoalCacheReconciler =
    Future<void> Function(GoalEditAcceptance acceptance);

class EditGoalInitialData {
  const EditGoalInitialData({
    required this.profile,
    required this.acceptedRaceTarget,
    required this.activePlanId,
  });

  final RunnerProfile profile;
  final AcceptedRaceTarget acceptedRaceTarget;
  final String activePlanId;
}

final editGoalFunctionClientProvider = Provider<EditGoalFunctionClient>((ref) {
  final client = ref.read(supabaseClientProvider);
  return (name, {body}) => client.functions.invoke(name, body: body);
});

final editGoalClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final editGoalLocaleCodeProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).value?.languageCode == 'es' ? 'es' : 'en';
});

class EditGoalEvidenceSuggestion {
  const EditGoalEvidenceSuggestion({
    required this.race,
    required this.targetTime,
  });

  final RunnerGoalRace race;
  final Duration targetTime;
}

final editGoalEvidenceSuggestionProvider =
    Provider<EditGoalEvidenceSuggestion?>((ref) {
      final plan = ref.watch(trainingPlanProvider).value;
      final targetTime = plan?.evidenceTarget?.time;
      if (plan == null || targetTime == null) return null;
      final race = switch (plan.raceType) {
        TrainingPlanRaceType.fiveK => RunnerGoalRace.fiveK,
        TrainingPlanRaceType.tenK => RunnerGoalRace.tenK,
        TrainingPlanRaceType.halfMarathon => RunnerGoalRace.halfMarathon,
        TrainingPlanRaceType.marathon => RunnerGoalRace.marathon,
        TrainingPlanRaceType.other => RunnerGoalRace.other,
      };
      return EditGoalEvidenceSuggestion(race: race, targetTime: targetTime);
    });

final editGoalInitialDataLoaderProvider = Provider<EditGoalInitialDataLoader>((
  ref,
) {
  return () async {
    final profileRepository = ref.read(runnerProfileRepositoryProvider);
    final planRepository = ref.read(planVersionRepositoryProvider);
    final profile = await profileRepository.loadProfileAsync();
    final plan = await planRepository.loadActivePlanAsync();
    if (profile == null || plan == null) {
      throw const FormatException('Missing persisted Edit Goal data.');
    }

    AcceptedRaceTarget? acceptedRaceTarget;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      try {
        final row = await ref
            .read(supabaseClientProvider)
            .from('runner_profiles')
            .select('data')
            .eq('user_id', user.id)
            .maybeSingle();
        final data = _mapFromDynamic(row?['data']);
        final rawTarget = data['acceptedRaceTarget'];
        if (rawTarget is Map) {
          acceptedRaceTarget = AcceptedRaceTarget.fromJson(
            rawTarget.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // Fall through to the persisted draft cache when remote profile data
        // is temporarily unavailable.
      }
    }
    acceptedRaceTarget ??= (await profileRepository.loadDraftAsync(
      refresh: false,
    ))?.acceptedRaceTarget;
    if (acceptedRaceTarget == null) {
      throw const FormatException('Missing accepted race target.');
    }
    return EditGoalInitialData(
      profile: profile,
      acceptedRaceTarget: acceptedRaceTarget,
      activePlanId: plan.id,
    );
  };
});

final editGoalCacheReconcilerProvider = Provider<EditGoalCacheReconciler>((
  ref,
) {
  return (acceptance) async {
    Object? firstError;
    final profileCache = SharedPreferencesRunnerProfileRepository(
      ref.read(sharedPreferencesProvider),
    );
    final planCache = ref.read(sharedPreferencesPlanVersionRepositoryProvider);

    try {
      await profileCache.cacheProfile(acceptance.profile);
      await profileCache.saveDraft(
        RunnerProfileDraft.fromRunnerProfile(
          acceptance.profile,
        ).copyWith(acceptedRaceTarget: acceptance.acceptedRaceTarget),
      );
    } catch (error) {
      firstError = error;
    }

    try {
      await planCache.saveActivePlan(
        PlanVersion(
          id: acceptance.versionId,
          generatedAt: ref.read(editGoalClockProvider)(),
          requestedBy: 'edit_goal',
          isActive: true,
          plan: acceptance.plan,
        ),
      );
    } catch (error) {
      firstError ??= error;
    }

    // Both accepted response caches are attempted before consumers reload.
    // Reload errors do not erase the accepted fallback written above.
    ref.invalidate(runnerProfileProvider);
    ref.invalidate(trainingPlanProvider);
    try {
      await ref.read(runnerProfileProvider.future);
    } catch (error) {
      firstError ??= error;
    }
    try {
      await ref.read(trainingPlanProvider.future);
    } catch (error) {
      firstError ??= error;
    }
    if (firstError != null) throw firstError;
  };
});

enum EditGoalFailureReason {
  auth('edit_goal_auth'),
  invalidInput('edit_goal_invalid_input'),
  timeout('edit_goal_timeout'),
  stale('edit_goal_stale'),
  expired('edit_goal_expired'),
  conflict('edit_goal_conflict'),
  parse('edit_goal_parse'),
  generic('edit_goal_error');

  const EditGoalFailureReason(this.key);
  final String key;
}

sealed class EditGoalState {
  const EditGoalState();
}

class EditGoalLoading extends EditGoalState {
  const EditGoalLoading();
}

class EditGoalEditing extends EditGoalState {
  const EditGoalEditing({required this.draft, required this.sourcePlanId});
  final EditGoalDraft draft;
  final String sourcePlanId;
}

class EditGoalPreviewing extends EditGoalState {
  const EditGoalPreviewing({required this.draft, required this.sourcePlanId});
  final EditGoalDraft draft;
  final String sourcePlanId;
}

class EditGoalPreviewReady extends EditGoalState {
  const EditGoalPreviewReady({
    required this.draft,
    required this.sourcePlanId,
    required this.proposal,
  });
  final EditGoalDraft draft;
  final String sourcePlanId;
  final GoalEditProposal proposal;
}

class EditGoalApplying extends EditGoalState {
  const EditGoalApplying({
    required this.draft,
    required this.sourcePlanId,
    required this.proposal,
  });
  final EditGoalDraft draft;
  final String sourcePlanId;
  final GoalEditProposal proposal;
}

class EditGoalSuccess extends EditGoalState {
  const EditGoalSuccess({required this.acceptance});
  final GoalEditAcceptance acceptance;
}

class EditGoalFailure extends EditGoalState {
  const EditGoalFailure({
    required this.draft,
    required this.sourcePlanId,
    required this.reason,
    this.proposal,
  });
  final EditGoalDraft? draft;
  final String? sourcePlanId;
  final EditGoalFailureReason reason;
  final GoalEditProposal? proposal;
}

class EditGoalNotifier extends Notifier<EditGoalState> {
  @override
  EditGoalState build() {
    Future.microtask(initialize);
    return const EditGoalLoading();
  }

  Future<void> initialize() async {
    if (!ref.mounted) return;
    state = const EditGoalLoading();
    try {
      final initial = await ref.read(editGoalInitialDataLoaderProvider)();
      if (!ref.mounted) return;
      state = EditGoalEditing(
        draft: EditGoalDraft.fromProfile(
          profile: initial.profile,
          acceptedRaceTarget: initial.acceptedRaceTarget,
        ),
        sourcePlanId: initial.activePlanId,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = const EditGoalFailure(
        draft: null,
        sourcePlanId: null,
        reason: EditGoalFailureReason.parse,
      );
    }
  }

  Future<void> retryInitialization() => initialize();

  void updateDraft(EditGoalDraft draft) {
    final sourcePlanId = _sourcePlanId(state);
    if (sourcePlanId == null) return;
    state = EditGoalEditing(draft: draft, sourcePlanId: sourcePlanId);
  }

  Future<bool> preview() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return false;
    return _previewDraft(draft, sourcePlanId);
  }

  Future<bool> refreshAndPreview() async {
    final draft = _draft(state);
    if (draft == null) return false;
    final previousSourcePlanId = _sourcePlanId(state);
    final previousProposal = _proposal(state);
    try {
      // Reload every persisted input so recovery observes the latest active
      // plan. The returned profile/target validate persistence but must not
      // replace the user's in-progress draft.
      final initial = await ref.read(editGoalInitialDataLoaderProvider)();
      if (!ref.mounted) return false;
      state = EditGoalEditing(draft: draft, sourcePlanId: initial.activePlanId);
      return _previewDraft(draft, initial.activePlanId);
    } catch (_) {
      if (ref.mounted) {
        state = EditGoalFailure(
          draft: draft,
          sourcePlanId: previousSourcePlanId,
          reason: EditGoalFailureReason.parse,
          proposal: previousProposal,
        );
      }
      return false;
    }
  }

  Future<bool> _previewDraft(EditGoalDraft draft, String sourcePlanId) async {
    if (!_validDraft(draft, ref.read(editGoalClockProvider)())) {
      state = EditGoalFailure(
        draft: draft,
        sourcePlanId: sourcePlanId,
        reason: EditGoalFailureReason.invalidInput,
      );
      return false;
    }
    state = EditGoalPreviewing(draft: draft, sourcePlanId: sourcePlanId);
    try {
      final response = await ref
          .read(editGoalFunctionClientProvider)(
            'edit-goal',
            body: draft.previewPayload(
              sourcePlanVersionId: sourcePlanId,
              localDate: ref.read(editGoalClockProvider)(),
              locale: ref.read(editGoalLocaleCodeProvider),
            ),
          )
          .timeout(const Duration(seconds: 130));
      if (!_successful(response)) {
        _setFailure(draft, sourcePlanId, _mapResponseFailure(response));
        return false;
      }
      final proposal = GoalEditProposal.fromJson(response.data);
      if (proposal.sourcePlanVersionId != sourcePlanId) {
        throw const FormatException('Mismatched proposal source plan.');
      }
      if (!ref.mounted) return true;
      state = EditGoalPreviewReady(
        draft: draft,
        sourcePlanId: sourcePlanId,
        proposal: proposal,
      );
      return true;
    } on TimeoutException {
      _setFailure(draft, sourcePlanId, EditGoalFailureReason.timeout);
    } on FunctionException catch (error) {
      _setFailure(draft, sourcePlanId, _mapFunctionException(error));
    } on FormatException {
      _setFailure(draft, sourcePlanId, EditGoalFailureReason.parse);
    } catch (_) {
      _setFailure(draft, sourcePlanId, EditGoalFailureReason.generic);
    }
    return false;
  }

  void cancelPreview() {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;
    state = EditGoalEditing(draft: draft, sourcePlanId: sourcePlanId);
  }

  Future<bool> apply() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final proposal = _proposal(state);
    if (draft == null || sourcePlanId == null || proposal == null) return false;
    state = EditGoalApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      proposal: proposal,
    );
    try {
      final response = await ref
          .read(editGoalFunctionClientProvider)(
            'edit-goal',
            body: {'action': 'accept', 'proposalId': proposal.id},
          )
          .timeout(const Duration(seconds: 130));
      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          proposal: proposal,
        );
        return false;
      }
      final acceptance = GoalEditAcceptance.fromJson(response.data);
      try {
        await ref.read(editGoalCacheReconcilerProvider)(acceptance);
      } catch (_) {
        // The server commit is authoritative. Provider invalidation/reload is
        // retained and no compensating local or remote write is attempted.
      }
      if (ref.mounted) state = EditGoalSuccess(acceptance: acceptance);
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        EditGoalFailureReason.timeout,
        proposal: proposal,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        proposal: proposal,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        EditGoalFailureReason.parse,
        proposal: proposal,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        EditGoalFailureReason.generic,
        proposal: proposal,
      );
    }
    return false;
  }

  void _setFailure(
    EditGoalDraft draft,
    String sourcePlanId,
    EditGoalFailureReason reason, {
    GoalEditProposal? proposal,
  }) {
    if (!ref.mounted) return;
    state = EditGoalFailure(
      draft: draft,
      sourcePlanId: sourcePlanId,
      reason: reason,
      proposal: proposal,
    );
  }
}

final editGoalProvider =
    NotifierProvider.autoDispose<EditGoalNotifier, EditGoalState>(
      EditGoalNotifier.new,
    );

EditGoalDraft? _draft(EditGoalState state) => switch (state) {
  EditGoalEditing(:final draft) ||
  EditGoalPreviewing(:final draft) ||
  EditGoalPreviewReady(:final draft) ||
  EditGoalApplying(:final draft) => draft,
  EditGoalFailure(:final draft) => draft,
  _ => null,
};

String? _sourcePlanId(EditGoalState state) => switch (state) {
  EditGoalEditing(:final sourcePlanId) ||
  EditGoalPreviewing(:final sourcePlanId) ||
  EditGoalPreviewReady(:final sourcePlanId) ||
  EditGoalApplying(:final sourcePlanId) => sourcePlanId,
  EditGoalFailure(:final sourcePlanId) => sourcePlanId,
  _ => null,
};

GoalEditProposal? _proposal(EditGoalState state) => switch (state) {
  EditGoalPreviewReady(:final proposal) ||
  EditGoalApplying(:final proposal) => proposal,
  EditGoalFailure(:final proposal) => proposal,
  _ => null,
};

bool _validDraft(EditGoalDraft draft, DateTime now) {
  if (draft.race == RunnerGoalRace.other || draft.targetTime <= Duration.zero) {
    return false;
  }
  if (!draft.hasRaceDate) return draft.raceDate == null;
  final raceDate = draft.raceDate;
  if (raceDate == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  final raceDay = DateTime(raceDate.year, raceDate.month, raceDate.day);
  return !raceDay.isBefore(today.add(const Duration(days: 7)));
}

bool _successful(FunctionResponse response) =>
    response.status >= 200 && response.status < 300;

EditGoalFailureReason _mapResponseFailure(FunctionResponse response) {
  final error = _mapFromDynamic(response.data)['error'];
  if (response.status == 401 ||
      error == 'unauthorized' ||
      error == 'missing_authorization') {
    return EditGoalFailureReason.auth;
  }
  if (response.status == 400 || error == 'invalid_request') {
    return EditGoalFailureReason.invalidInput;
  }
  if (error == 'proposal_expired') return EditGoalFailureReason.expired;
  if (error == 'source_plan_stale' || error == 'proposal_not_found') {
    return EditGoalFailureReason.stale;
  }
  if (response.status == 408 || response.status == 504) {
    return EditGoalFailureReason.timeout;
  }
  if (response.status == 409 || error == 'proposal_not_pending') {
    return EditGoalFailureReason.conflict;
  }
  return EditGoalFailureReason.generic;
}

EditGoalFailureReason _mapFunctionException(FunctionException error) {
  final details = _mapFromDynamic(error.details);
  return _mapResponseFailure(
    FunctionResponse(data: details, status: error.status),
  );
}

Map<String, dynamic> _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}
