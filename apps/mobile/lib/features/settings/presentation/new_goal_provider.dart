import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../../localization/presentation/locale_provider.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../../training_plan/data/plan_version_repository.dart';
import '../../training_plan/data/supabase_plan_version_repository.dart';
import '../../training_plan/domain/models/plan_version.dart';
import '../../training_plan/presentation/training_plan_provider.dart';
import '../domain/new_goal_models.dart';

typedef NewGoalFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});
typedef NewGoalInitialDataLoader = Future<NewGoalInitialData> Function();
typedef NewGoalCacheReconciler =
    Future<void> Function(NewGoalAcceptance acceptance);

class NewGoalInitialData {
  const NewGoalInitialData({required this.profile, required this.activePlanId});

  final RunnerProfile profile;
  final String activePlanId;
}

class NewGoalDraftStore {
  NewGoalDraftStore({
    required SharedPreferences preferences,
    required SupabaseClient? client,
    required String? userId,
  }) : _preferences = preferences,
       _client = client,
       _userId = userId,
       _storageKey = storageKeyForUser(userId);

  static const _storageKeyPrefix = 'new_goal_draft_v1';

  final SharedPreferences _preferences;
  final SupabaseClient? _client;
  final String? _userId;
  final String _storageKey;

  static String storageKeyForUser(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '${_storageKeyPrefix}_guest';
    }
    return '${_storageKeyPrefix}_$normalized';
  }

  String get storageKey => _storageKey;

  Future<StoredNewGoalDraft?> load() async {
    final local = _loadLocal();
    if (_client == null || _userId == null) return local;

    try {
      final row = await _client
          .from('new_goal_drafts')
          .select('source_plan_version_id,data,status,revision,updated_at')
          .eq('user_id', _userId)
          .maybeSingle();

      if (row == null) return local;

      final remote = StoredNewGoalDraft.fromJson({
        'sourcePlanVersionId': row['source_plan_version_id'],
        'data': row['data'],
        'status': row['status'],
        'revision': row['revision'],
        'updatedAt': row['updated_at'],
      });

      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _saveLocal(remote);
        return remote;
      }
    } catch (_) {
      // Local cache stays source of truth when remote is offline/unavailable.
    }

    return local;
  }

  Future<void> save({
    required NewGoalDraft draft,
    required String sourcePlanId,
    required String status,
    required int revision,
    required DateTime updatedAt,
  }) async {
    final stored = StoredNewGoalDraft(
      draft: draft,
      sourcePlanId: sourcePlanId,
      status: status,
      revision: revision,
      updatedAt: updatedAt,
    );

    await _saveLocal(stored);
    if (_client == null || _userId == null) return;

    try {
      await _client.from('new_goal_drafts').upsert({
        'user_id': _userId,
        'source_plan_version_id': sourcePlanId,
        'data': draft.toJson(),
        'status': status,
        'revision': revision,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      final assessment = draft.assessment;
      if (assessment != null) {
        await _client.from('new_goal_assessments').upsert({
          'id': assessment.id,
          'user_id': _userId,
          'draft_user_id': _userId,
          'kind': assessment.kind,
          'scheduled_for': _dateOnly(assessment.scheduledFor),
          'safe_dates': assessment.safeDates
              .map(_dateOnly)
              .toList(growable: false),
          'status': draft.fitnessResult == null ? 'scheduled' : 'completed',
          if (draft.fitnessResult != null) ...{
            'result': draft.fitnessResult!.toJson(),
            'completed_at': updatedAt.toUtc().toIso8601String(),
          },
          'updated_at': updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
      }
    } catch (_) {
      // Local persistence remains available offline.
    }
  }

  Future<void> discard() async {
    await _preferences.remove(_storageKey);
    if (_client == null || _userId == null) return;

    try {
      await _client.from('new_goal_drafts').delete().eq('user_id', _userId);
      await _client
          .from('new_goal_assessments')
          .delete()
          .eq('draft_user_id', _userId);
    } catch (_) {
      // Cleanup best-effort.
    }
  }

  StoredNewGoalDraft? _loadLocal() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return StoredNewGoalDraft.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
      }
    } catch (_) {
      // Keep reading resilient to corrupted local cache.
    }

    return null;
  }

  Future<void> _saveLocal(StoredNewGoalDraft stored) async {
    await _preferences.setString(_storageKey, jsonEncode(stored.toJson()));
  }
}

final newGoalFunctionClientProvider = Provider<NewGoalFunctionClient>((ref) {
  final client = ref.read(supabaseClientProvider);
  return (name, {body}) => client.functions.invoke(name, body: body);
});

final newGoalClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final newGoalLocaleCodeProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).value?.languageCode == 'es' ? 'es' : 'en';
});

final newGoalDraftStoreProvider = Provider<NewGoalDraftStore>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return NewGoalDraftStore(
    preferences: ref.watch(sharedPreferencesProvider),
    client: SupabaseConfig.isConfigured
        ? ref.watch(supabaseClientProvider)
        : null,
    userId: userId,
  );
});

final newGoalInitialDataLoaderProvider = Provider<NewGoalInitialDataLoader>((
  ref,
) {
  return () async {
    final profile = await ref
        .read(runnerProfileRepositoryProvider)
        .loadProfileAsync();
    final activePlan = await ref
        .read(planVersionRepositoryProvider)
        .loadActivePlanAsync();
    if (profile == null || activePlan == null) {
      throw const FormatException('Missing persisted new goal source data.');
    }

    return NewGoalInitialData(profile: profile, activePlanId: activePlan.id);
  };
});

final newGoalCacheReconcilerProvider = Provider<NewGoalCacheReconciler>((ref) {
  return (acceptance) async {
    Object? failure;
    final profileCache = SharedPreferencesRunnerProfileRepository(
      ref.read(sharedPreferencesProvider),
    );
    final planCache = ref.read(sharedPreferencesPlanVersionRepositoryProvider);

    try {
      await profileCache.cacheProfile(acceptance.profile);
    } catch (error) {
      failure = error;
    }

    try {
      await planCache.saveActivePlan(
        PlanVersion(
          id: acceptance.versionId,
          generatedAt: ref.read(newGoalClockProvider)(),
          requestedBy: 'new_goal',
          isActive: true,
          plan: acceptance.plan,
        ),
      );
    } catch (error) {
      failure ??= error;
    }

    ref.invalidate(runnerProfileProvider);
    ref.invalidate(trainingPlanProvider);
    try {
      await ref.read(runnerProfileProvider.future);
    } catch (error) {
      failure ??= error;
    }
    try {
      await ref.read(trainingPlanProvider.future);
    } catch (error) {
      failure ??= error;
    }

    if (failure != null) throw failure;
  };
});

enum NewGoalFailureReason {
  auth('new_goal_auth'),
  invalidInput('new_goal_invalid_input'),
  timeout('new_goal_timeout'),
  stale('new_goal_stale'),
  expired('new_goal_expired'),
  conflict('new_goal_conflict'),
  parse('new_goal_parse'),
  generic('new_goal_error');

  const NewGoalFailureReason(this.key);
  final String key;
}

enum NewGoalDraftStatus {
  editing('editing'),
  assessmentPending('assessment_pending'),
  proposalReady('proposal_ready');

  const NewGoalDraftStatus(this.key);
  final String key;

  static NewGoalDraftStatus parse(Object? value) {
    for (final status in values) {
      if (status.key == value) return status;
    }
    return NewGoalDraftStatus.editing;
  }
}

sealed class NewGoalState {
  const NewGoalState();
}

class NewGoalLoading extends NewGoalState {
  const NewGoalLoading();
}

class NewGoalEditing extends NewGoalState {
  const NewGoalEditing({
    required this.draft,
    required this.sourcePlanId,
    this.wasRebased = false,
    this.hasRestoredDraft = false,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final bool wasRebased;
  final bool hasRestoredDraft;
}

class NewGoalRecommendationLoading extends NewGoalState {
  const NewGoalRecommendationLoading({
    required this.draft,
    required this.sourcePlanId,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
}

class NewGoalRecommendationReady extends NewGoalState {
  const NewGoalRecommendationReady({
    required this.draft,
    required this.sourcePlanId,
    required this.recommendation,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final NewGoalRecommendation recommendation;
}

class NewGoalFitnessCheckRequired extends NewGoalState {
  const NewGoalFitnessCheckRequired({
    required this.draft,
    required this.sourcePlanId,
    required this.fitnessCheck,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final NewGoalFitnessCheck fitnessCheck;
}

class NewGoalAssessmentPending extends NewGoalState {
  const NewGoalAssessmentPending({
    required this.draft,
    required this.sourcePlanId,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
}

class NewGoalProposalLoading extends NewGoalState {
  const NewGoalProposalLoading({
    required this.draft,
    required this.sourcePlanId,
    required this.recommendation,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final NewGoalRecommendation recommendation;
}

class NewGoalProposalReady extends NewGoalState {
  const NewGoalProposalReady({
    required this.draft,
    required this.sourcePlanId,
    required this.recommendation,
    required this.proposal,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final NewGoalRecommendation recommendation;
  final NewGoalProposal proposal;
}

class NewGoalApplying extends NewGoalState {
  const NewGoalApplying({
    required this.draft,
    required this.sourcePlanId,
    required this.recommendation,
    required this.proposal,
  });

  final NewGoalDraft draft;
  final String sourcePlanId;
  final NewGoalRecommendation recommendation;
  final NewGoalProposal proposal;
}

class NewGoalSuccess extends NewGoalState {
  const NewGoalSuccess({required this.acceptance, required this.proposal});

  final NewGoalAcceptance acceptance;
  final NewGoalProposal proposal;
}

class NewGoalFailure extends NewGoalState {
  const NewGoalFailure({
    required this.draft,
    required this.sourcePlanId,
    required this.reason,
    this.proposal,
  });

  final NewGoalDraft? draft;
  final String? sourcePlanId;
  final NewGoalFailureReason reason;
  final NewGoalProposal? proposal;
}

class NewGoalNotifier extends Notifier<NewGoalState> {
  int _revision = 1;
  Future<void> _persistenceTail = Future<void>.value();

  @override
  NewGoalState build() {
    Future.microtask(initialize);
    return const NewGoalLoading();
  }

  Future<void> initialize() async {
    if (!ref.mounted) return;
    state = const NewGoalLoading();

    try {
      final initial = await ref.read(newGoalInitialDataLoaderProvider)();
      final stored = await ref.read(newGoalDraftStoreProvider).load();
      final baseDraft = NewGoalDraft.fromProfile(profile: initial.profile);

      final mergedDraft = stored == null
          ? baseDraft
          : _coalesceDraft(stored.draft, baseDraft);
      final sourcePlanId = initial.activePlanId;
      _revision = stored?.revision ?? 1;
      final wasRebased = stored != null && stored.sourcePlanId != sourcePlanId;

      if (mergedDraft.assessment != null && mergedDraft.fitnessResult == null) {
        state = NewGoalAssessmentPending(
          draft: mergedDraft,
          sourcePlanId: sourcePlanId,
        );
      } else {
        state = NewGoalEditing(
          draft: mergedDraft,
          sourcePlanId: sourcePlanId,
          wasRebased: wasRebased,
          hasRestoredDraft: stored != null,
        );
      }

      if (state is NewGoalAssessmentPending && stored == null) {
        await discard();
      }
    } catch (_) {
      if (ref.mounted) {
        state = const NewGoalFailure(
          draft: null,
          sourcePlanId: null,
          reason: NewGoalFailureReason.parse,
        );
      }
    }
  }

  Future<void> retryInitialization() => initialize();

  Future<void> startOver() async {
    await _drainPersistence();
    await ref.read(newGoalDraftStoreProvider).discard();
    if (!ref.mounted) return;

    final sourcePlanId = await _latestSourcePlanId();
    final draft = await _freshDraft();
    state = NewGoalEditing(
      draft: draft,
      sourcePlanId: sourcePlanId,
      hasRestoredDraft: false,
    );
    await _persist(draft, sourcePlanId, status: NewGoalDraftStatus.editing.key);
  }

  void updateDraft(NewGoalDraft draft) {
    final sourcePlanId = _sourcePlanId(state);
    if (sourcePlanId == null) return;

    state = NewGoalEditing(
      draft: draft,
      sourcePlanId: sourcePlanId,
      hasRestoredDraft: _hasRestoredDraft(state),
    );
    unawaited(
      _persist(draft, sourcePlanId, status: NewGoalDraftStatus.editing.key),
    );
  }

  Future<void> setRace({
    required RunnerGoalRace race,
    required bool hasRaceDate,
    DateTime? raceDate,
  }) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(
      draft.copyWith(
        race: race,
        hasRaceDate: hasRaceDate,
        raceDate: raceDate,
        clearRaceDate: !hasRaceDate,
      ),
      sourcePlanId,
    );
  }

  Future<void> setPlanStartDate(DateTime? planStartDate) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(
      draft.copyWith(
        planStartDate: planStartDate,
        clearPlanStartDate: planStartDate == null,
      ),
      sourcePlanId,
    );
  }

  Future<void> setSchedule(NewGoalSchedule schedule) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(draft.copyWith(schedule: schedule), sourcePlanId);
  }

  Future<void> setPlanPreference(PlanPreferenceChoice planPreference) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(
      draft.copyWith(planPreference: planPreference),
      sourcePlanId,
    );
  }

  Future<void> setHealthChanged(bool changed) async {
    await setHealthChangedWithSnapshot(changed);
  }

  Future<void> setHealthChangedWithSnapshot(
    bool changed, {
    NewGoalHealthSnapshot? snapshot,
  }) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(
      draft.withHealthChanged(changed, snapshot: snapshot),
      sourcePlanId,
    );
  }

  Future<void> setHealthSnapshot(NewGoalHealthSnapshot snapshot) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    await _applyDraft(
      draft.copyWith(health: snapshot, healthChanged: true),
      sourcePlanId,
    );
  }

  void useFitnessResult(NewGoalFitnessResult result) {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    final updated = draft.copyWith(
      fitnessResult: result,
      clearFitnessResult: false,
      assessment: null,
      clearAssessment: true,
    );

    state = NewGoalEditing(
      draft: updated,
      sourcePlanId: sourcePlanId,
      hasRestoredDraft: _hasRestoredDraft(state),
    );
    unawaited(
      _persist(updated, sourcePlanId, status: _statusForDraft(updated, state)),
    );
  }

  Future<void> scheduleAssessment(
    NewGoalFitnessCheck check,
    DateTime date,
  ) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    final normalized = _dateOnly(date);
    final safe = check.safeDates.any(
      (candidate) => _dateOnly(candidate) == normalized,
    );
    if (!safe) return;

    final assessment = NewGoalAssessment(
      id: 'new-goal-${ref.read(newGoalClockProvider)().microsecondsSinceEpoch}',
      kind: check.benchmarkKind,
      scheduledFor: date,
      safeDates: check.safeDates,
    );

    final nextDraft = draft.copyWith(
      assessment: assessment,
      clearAssessment: false,
      clearFitnessResult: false,
    );

    await _persist(
      nextDraft,
      sourcePlanId,
      status: NewGoalDraftStatus.assessmentPending.key,
    );
    state = NewGoalAssessmentPending(
      draft: nextDraft,
      sourcePlanId: sourcePlanId,
    );
  }

  void cancelAssessment() {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    final updated = draft.copyWith(
      clearAssessment: true,
      clearFitnessResult: true,
    );
    updateDraft(updated);
  }

  void clearFitnessResult() {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;

    final updated = draft.copyWith(clearFitnessResult: true);
    state = NewGoalEditing(
      draft: updated,
      sourcePlanId: sourcePlanId,
      hasRestoredDraft: _hasRestoredDraft(state),
    );
    unawaited(
      _persist(updated, sourcePlanId, status: NewGoalDraftStatus.editing.key),
    );
  }

  Future<bool> preview() async {
    if (state case NewGoalRecommendationReady(
      :final draft,
      :final sourcePlanId,
      :final recommendation,
    )) {
      return _previewDraft(
        draft: draft,
        sourcePlanId: sourcePlanId,
        recommendation: recommendation,
      );
    }

    _setFailure(
      _draft(state),
      _sourcePlanId(state),
      NewGoalFailureReason.invalidInput,
    );
    return false;
  }

  Future<bool> refreshAndPreview() async {
    final draft = _draft(state);
    final previousSourcePlanId = _sourcePlanId(state);
    final previousProposal = _proposal(state);
    if (draft == null) return false;

    try {
      final initial = await ref.read(newGoalInitialDataLoaderProvider)();
      if (!ref.mounted) return false;
      final sourcePlanId = initial.activePlanId;

      if (sourcePlanId != previousSourcePlanId) {
        state = NewGoalEditing(
          draft: draft,
          sourcePlanId: sourcePlanId,
          wasRebased: true,
          hasRestoredDraft: _hasRestoredDraft(state),
        );
      }

      if (!await _recommendDraft(draft: draft, sourcePlanId: sourcePlanId)) {
        return false;
      }

      final recommendation = _recommendation(state);
      if (recommendation == null) return false;

      return _previewDraft(
        draft: draft,
        sourcePlanId: sourcePlanId,
        recommendation: recommendation,
      );
    } catch (_) {
      if (ref.mounted) {
        state = NewGoalFailure(
          draft: draft,
          sourcePlanId: previousSourcePlanId,
          reason: NewGoalFailureReason.parse,
          proposal: previousProposal,
        );
      }
      return false;
    }
  }

  Future<bool> recommend() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return false;
    return _recommendDraft(draft: draft, sourcePlanId: sourcePlanId);
  }

  Future<bool> _recommendDraft({
    required NewGoalDraft draft,
    required String sourcePlanId,
  }) async {
    if (!_validDraft(draft, ref.read(newGoalClockProvider)())) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.invalidInput);
      return false;
    }
    if (draft.healthChanged && draft.health == null) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.invalidInput);
      return false;
    }

    state = NewGoalRecommendationLoading(
      draft: draft,
      sourcePlanId: sourcePlanId,
    );
    await _persist(draft, sourcePlanId, status: NewGoalDraftStatus.editing.key);

    try {
      final response = await ref
          .read(newGoalFunctionClientProvider)(
            'new-goal',
            body: draft.recommendationPayload(
              sourcePlanVersionId: sourcePlanId,
              action: 'recommend',
              locale: ref.read(newGoalLocaleCodeProvider),
              localDate: ref.read(newGoalClockProvider)(),
            ),
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(draft, sourcePlanId, _mapResponseFailure(response));
        return false;
      }

      final data = _mapFromDynamic(response.data);
      if (data['state'] == 'fitness_check_required') {
        state = NewGoalFitnessCheckRequired(
          draft: draft,
          sourcePlanId: sourcePlanId,
          fitnessCheck: NewGoalFitnessCheck.fromJson(data['fitnessCheck']),
        );
        return false;
      }

      final recommendation = NewGoalRecommendation.fromJson(data);
      if (recommendation.sourceGoal.race == RunnerGoalRace.other) {
        _setFailure(draft, sourcePlanId, NewGoalFailureReason.parse);
        return false;
      }

      await _persist(
        draft,
        sourcePlanId,
        status: NewGoalDraftStatus.editing.key,
      );
      state = NewGoalRecommendationReady(
        draft: draft,
        sourcePlanId: sourcePlanId,
        recommendation: recommendation,
      );
      return true;
    } on TimeoutException {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.timeout);
    } on FunctionException catch (error) {
      _setFailure(draft, sourcePlanId, _mapFunctionException(error));
    } catch (_) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.parse);
    }
    return false;
  }

  Future<bool> _previewDraft({
    required NewGoalDraft draft,
    required String sourcePlanId,
    required NewGoalRecommendation recommendation,
  }) async {
    if (!_validDraft(draft, ref.read(newGoalClockProvider)())) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.invalidInput);
      return false;
    }
    if (draft.healthChanged && draft.health == null) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.invalidInput);
      return false;
    }

    state = NewGoalProposalLoading(
      draft: draft,
      sourcePlanId: sourcePlanId,
      recommendation: recommendation,
    );
    await _persist(draft, sourcePlanId, status: NewGoalDraftStatus.editing.key);

    try {
      final response = await ref
          .read(newGoalFunctionClientProvider)(
            'new-goal',
            body: draft.recommendationPayload(
              sourcePlanVersionId: sourcePlanId,
              action: 'preview',
              locale: ref.read(newGoalLocaleCodeProvider),
              localDate: ref.read(newGoalClockProvider)(),
            ),
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(draft, sourcePlanId, _mapResponseFailure(response));
        return false;
      }

      final data = _mapFromDynamic(response.data);
      if (data['state'] == 'fitness_check_required') {
        state = NewGoalFitnessCheckRequired(
          draft: draft,
          sourcePlanId: sourcePlanId,
          fitnessCheck: NewGoalFitnessCheck.fromJson(data['fitnessCheck']),
        );
        return false;
      }

      final proposal = NewGoalProposal.fromJson(data);
      if (proposal.sourcePlanVersionId != sourcePlanId) {
        _setFailure(draft, sourcePlanId, NewGoalFailureReason.parse);
        return false;
      }
      if (_isExpired(proposal.expiresAt)) {
        _setFailure(draft, sourcePlanId, NewGoalFailureReason.expired);
        return false;
      }

      await _persist(
        draft,
        sourcePlanId,
        status: NewGoalDraftStatus.proposalReady.key,
      );
      state = NewGoalProposalReady(
        draft: draft,
        sourcePlanId: sourcePlanId,
        recommendation: recommendation,
        proposal: proposal,
      );
      return true;
    } on TimeoutException {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.timeout);
    } on FunctionException catch (error) {
      _setFailure(draft, sourcePlanId, _mapFunctionException(error));
    } catch (_) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.parse);
    }
    return false;
  }

  Future<bool> apply() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final proposal = _proposal(state);
    final recommendation = _recommendation(state);
    final now = ref.read(newGoalClockProvider)();

    if (draft == null ||
        sourcePlanId == null ||
        proposal == null ||
        recommendation == null) {
      _setFailure(draft, sourcePlanId, NewGoalFailureReason.invalidInput);
      return false;
    }

    if (_isExpired(proposal.expiresAt, now)) {
      _setFailure(
        draft,
        sourcePlanId,
        NewGoalFailureReason.expired,
        proposal: proposal,
      );
      return false;
    }

    state = NewGoalApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      recommendation: recommendation,
      proposal: proposal,
    );

    try {
      final response = await ref
          .read(newGoalFunctionClientProvider)(
            'new-goal',
            body: proposalActionPayload(proposal.id),
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

      final acceptance = NewGoalAcceptance.fromJson(response.data);
      try {
        await ref.read(newGoalCacheReconcilerProvider)(acceptance);
      } catch (_) {
        // Apply response is authoritative, local cache reconciliation is best-effort.
      }

      await ref.read(newGoalDraftStoreProvider).discard();
      if (!ref.mounted) return false;
      state = NewGoalSuccess(acceptance: acceptance, proposal: proposal);
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        NewGoalFailureReason.timeout,
        proposal: proposal,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        proposal: proposal,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        NewGoalFailureReason.parse,
        proposal: proposal,
      );
    }

    return false;
  }

  Future<void> discard() async {
    await _drainPersistence();
    await ref.read(newGoalDraftStoreProvider).discard();
    await initialize();
  }

  Future<void> _applyDraft(NewGoalDraft draft, String sourcePlanId) async {
    state = NewGoalEditing(
      draft: draft,
      sourcePlanId: sourcePlanId,
      hasRestoredDraft: _hasRestoredDraft(state),
    );

    await _persist(draft, sourcePlanId, status: _statusForDraft(draft, state));
  }

  Future<void> _persist(
    NewGoalDraft draft,
    String sourcePlanId, {
    required String status,
  }) {
    final revision = ++_revision;
    final updatedAt = ref.read(newGoalClockProvider)();
    final store = ref.read(newGoalDraftStoreProvider);

    final previous = _persistenceTail;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // Failed writes shouldn't block the next one.
      }
      await store.save(
        draft: draft,
        sourcePlanId: sourcePlanId,
        status: status,
        revision: revision,
        updatedAt: updatedAt,
      );
    }();

    _persistenceTail = next;
    return next;
  }

  Future<void> _drainPersistence() async {
    try {
      await _persistenceTail;
    } catch (_) {
      // best effort
    }
  }

  NewGoalDraft _coalesceDraft(
    NewGoalDraft storedDraft,
    NewGoalDraft defaultDraft,
  ) {
    return storedDraft.copyWith(
      planStartDate: storedDraft.planStartDate ?? defaultDraft.planStartDate,
    );
  }

  Future<NewGoalDraft> _freshDraft() async {
    final initial = await ref.read(newGoalInitialDataLoaderProvider)();
    return NewGoalDraft.fromProfile(profile: initial.profile);
  }

  Future<String> _latestSourcePlanId() async {
    final initial = await ref.read(newGoalInitialDataLoaderProvider)();
    return initial.activePlanId;
  }

  void _setFailure(
    NewGoalDraft? draft,
    String? sourcePlanId,
    NewGoalFailureReason reason, {
    NewGoalProposal? proposal,
  }) {
    if (!ref.mounted) return;
    state = NewGoalFailure(
      draft: draft,
      sourcePlanId: sourcePlanId,
      reason: reason,
      proposal: proposal,
    );
  }

  String _statusForDraft(NewGoalDraft draft, NewGoalState state) {
    if (draft.assessment != null && draft.fitnessResult == null) {
      return NewGoalDraftStatus.assessmentPending.key;
    }
    if (state is NewGoalProposalReady || state is NewGoalApplying) {
      return NewGoalDraftStatus.proposalReady.key;
    }
    return NewGoalDraftStatus.editing.key;
  }
}

final newGoalProvider =
    NotifierProvider.autoDispose<NewGoalNotifier, NewGoalState>(
      NewGoalNotifier.new,
    );

NewGoalDraft? _draft(NewGoalState state) => switch (state) {
  NewGoalLoading() => null,
  NewGoalEditing(:final draft) => draft,
  NewGoalRecommendationLoading(:final draft) => draft,
  NewGoalRecommendationReady(:final draft) => draft,
  NewGoalProposalLoading(:final draft) => draft,
  NewGoalProposalReady(:final draft) => draft,
  NewGoalFitnessCheckRequired(:final draft) => draft,
  NewGoalAssessmentPending(:final draft) => draft,
  NewGoalApplying(:final draft) => draft,
  NewGoalSuccess() => null,
  NewGoalFailure(:final draft) => draft,
};

String? _sourcePlanId(NewGoalState state) => switch (state) {
  NewGoalLoading() => null,
  NewGoalEditing(:final sourcePlanId) => sourcePlanId,
  NewGoalRecommendationLoading(:final sourcePlanId) => sourcePlanId,
  NewGoalRecommendationReady(:final sourcePlanId) => sourcePlanId,
  NewGoalProposalLoading(:final sourcePlanId) => sourcePlanId,
  NewGoalProposalReady(:final sourcePlanId) => sourcePlanId,
  NewGoalFitnessCheckRequired(:final sourcePlanId) => sourcePlanId,
  NewGoalAssessmentPending(:final sourcePlanId) => sourcePlanId,
  NewGoalApplying(:final sourcePlanId) => sourcePlanId,
  NewGoalFailure(:final sourcePlanId) => sourcePlanId,
  NewGoalSuccess() => null,
};

NewGoalProposal? _proposal(NewGoalState state) => switch (state) {
  NewGoalProposalReady(:final proposal) => proposal,
  NewGoalApplying(:final proposal) => proposal,
  NewGoalFailure(:final proposal) => proposal,
  NewGoalLoading() ||
  NewGoalEditing() ||
  NewGoalRecommendationLoading() ||
  NewGoalProposalLoading() ||
  NewGoalFitnessCheckRequired() ||
  NewGoalAssessmentPending() ||
  NewGoalRecommendationReady() ||
  NewGoalSuccess() => null,
};

NewGoalRecommendation? _recommendation(NewGoalState state) => switch (state) {
  NewGoalRecommendationReady(:final recommendation) => recommendation,
  NewGoalProposalLoading(:final recommendation) => recommendation,
  NewGoalProposalReady(:final recommendation) => recommendation,
  NewGoalApplying(:final recommendation) => recommendation,
  NewGoalRecommendationLoading() => null,
  NewGoalLoading() ||
  NewGoalEditing() ||
  NewGoalFitnessCheckRequired() ||
  NewGoalAssessmentPending() ||
  NewGoalSuccess() ||
  NewGoalFailure() => null,
};

bool _hasRestoredDraft(NewGoalState state) => switch (state) {
  NewGoalEditing(:final hasRestoredDraft) => hasRestoredDraft,
  _ => false,
};

bool _validDraft(NewGoalDraft draft, DateTime now) {
  final goal = draft.effectiveGoal;
  if (goal.race == RunnerGoalRace.other) return false;
  if (!goal.hasRaceDate && goal.raceDate != null) return false;
  if (goal.hasRaceDate && goal.raceDate == null) return false;
  if (draft.planStartDate == null) return false;

  final today = DateTime(now.year, now.month, now.day);
  if (goal.hasRaceDate &&
      goal.raceDate != null &&
      !goal.raceDate!.isAtSameMomentAs(today) &&
      goal.raceDate!.isBefore(today)) {
    return false;
  }

  if (draft.schedule.trainingDays <= 0) return false;
  return true;
}

bool _successful(FunctionResponse response) =>
    response.status >= 200 && response.status < 300;

NewGoalFailureReason _mapResponseFailure(FunctionResponse response) {
  final error = _mapFromDynamic(response.data)['error'];
  if (response.status == 401 ||
      response.status == 403 ||
      error == 'unauthorized' ||
      error == 'missing_authorization') {
    return NewGoalFailureReason.auth;
  }
  if (response.status == 400 || error == 'invalid_request') {
    return NewGoalFailureReason.invalidInput;
  }
  if (response.status == 408 || response.status == 504 || error == 'timeout') {
    return NewGoalFailureReason.timeout;
  }
  if (error == 'proposal_expired' || error == 'recommendation_expired') {
    return NewGoalFailureReason.expired;
  }
  if (error == 'source_plan_stale' || error == 'proposal_not_found') {
    return NewGoalFailureReason.stale;
  }
  if (response.status == 409 || error == 'proposal_not_pending') {
    return NewGoalFailureReason.conflict;
  }
  return NewGoalFailureReason.generic;
}

NewGoalFailureReason _mapFunctionException(FunctionException error) {
  return _mapResponseFailure(
    FunctionResponse(
      data: _mapFromDynamic(error.details),
      status: error.status,
    ),
  );
}

Map<String, dynamic> _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return const {};
}

Map<String, dynamic> proposalActionPayload(String proposalId) => {
  'action': 'accept',
  'proposalId': proposalId,
};

bool _isExpired(DateTime expiresAt, [DateTime? now]) =>
    expiresAt.isBefore(now ?? DateTime.now());

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
