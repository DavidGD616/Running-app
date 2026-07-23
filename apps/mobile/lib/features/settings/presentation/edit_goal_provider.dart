import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/config/supabase_config.dart';
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
import '../domain/edit_goal_models.dart';

typedef EditGoalFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});
typedef EditGoalInitialDataLoader = Future<EditGoalInitialData> Function();
typedef EditGoalCacheReconciler =
    Future<void> Function(GoalEditAcceptance acceptance);

class EditGoalInitialData {
  const EditGoalInitialData({
    required this.profile,
    required this.activePlanId,
  });

  final RunnerProfile profile;
  final String activePlanId;
}

class StoredEditGoalDraft {
  const StoredEditGoalDraft({
    required this.draft,
    required this.sourcePlanId,
    required this.status,
    required this.revision,
    required this.updatedAt,
  });

  final EditGoalDraft draft;
  final String sourcePlanId;
  final String status;
  final int revision;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'sourcePlanVersionId': sourcePlanId,
    'data': draft.toJson(),
    'status': status,
    'revision': revision,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoredEditGoalDraft.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final revision = json['revision'];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (data is! Map ||
        revision is! int ||
        revision <= 0 ||
        updatedAt == null) {
      throw const FormatException('Invalid stored Edit Goal draft.');
    }
    return StoredEditGoalDraft(
      draft: EditGoalDraft.fromJson(
        data.map((key, value) => MapEntry('$key', value)),
      ),
      sourcePlanId: _requiredNonEmptyString(json['sourcePlanVersionId']),
      status: _requiredNonEmptyString(json['status']),
      revision: revision,
      updatedAt: updatedAt,
    );
  }
}

class EditGoalDraftStore {
  EditGoalDraftStore({
    required SharedPreferences preferences,
    required SupabaseClient? client,
    required String? userId,
  }) : _preferences = preferences,
       _client = client,
       _userId = userId;

  static const _storageKeyPrefix = 'edit_goal_draft_v2';

  static String storageKeyForUser(String? userId) {
    final normalizedUserId = userId?.trim();
    return normalizedUserId == null || normalizedUserId.isEmpty
        ? '${_storageKeyPrefix}_guest'
        : '${_storageKeyPrefix}_$normalizedUserId';
  }

  final SharedPreferences _preferences;
  final SupabaseClient? _client;
  final String? _userId;

  String get _storageKey => storageKeyForUser(_userId);

  Future<StoredEditGoalDraft?> load() async {
    final local = _loadLocal();
    final userId = _userId;
    if (userId == null || _client == null) return local;
    try {
      final row = await _client
          .from('goal_edit_drafts')
          .select('source_plan_version_id,data,status,revision,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return local;
      final remote = StoredEditGoalDraft.fromJson({
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
      // Local persistence keeps the edit resumable while a device is offline
      // or a migration has not reached the current backend yet.
    }
    return local;
  }

  Future<void> save({
    required EditGoalDraft draft,
    required String sourcePlanId,
    required String status,
    required int revision,
    required DateTime updatedAt,
  }) async {
    final stored = StoredEditGoalDraft(
      draft: draft,
      sourcePlanId: sourcePlanId,
      status: status,
      revision: revision,
      updatedAt: updatedAt,
    );
    await _saveLocal(stored);
    final userId = _userId;
    if (userId == null || _client == null) return;
    try {
      await _client.from('goal_edit_drafts').upsert({
        'user_id': userId,
        'source_plan_version_id': sourcePlanId,
        'data': draft.toJson(),
        'status': status,
        'revision': revision,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      final assessment = draft.assessment;
      if (assessment != null) {
        await _client.from('goal_edit_assessments').upsert({
          'id': assessment.id,
          'user_id': userId,
          'draft_user_id': userId,
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
      // A later save retries the remote copy. The local record is already the
      // source of truth for this device and must not be discarded.
    }
  }

  Future<void> discard() async {
    await _preferences.remove(_storageKey);
    final userId = _userId;
    if (userId == null || _client == null) return;
    try {
      await _client.from('goal_edit_drafts').delete().eq('user_id', userId);
    } catch (_) {
      // Deliberately best-effort: the user should still be able to leave the
      // flow offline, and the next authenticated session retries cleanup.
    }
  }

  StoredEditGoalDraft? _loadLocal() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return StoredEditGoalDraft.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
      }
    } catch (_) {
      // A corrupt local cache should not block opening the flow.
    }
    return null;
  }

  Future<void> _saveLocal(StoredEditGoalDraft draft) async {
    await _preferences.setString(_storageKey, jsonEncode(draft.toJson()));
  }
}

final editGoalFunctionClientProvider = Provider<EditGoalFunctionClient>((ref) {
  final client = ref.read(supabaseClientProvider);
  return (name, {body}) => client.functions.invoke(name, body: body);
});

final editGoalClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final editGoalLocaleCodeProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).value?.languageCode == 'es' ? 'es' : 'en';
});

final editGoalDraftStoreProvider = Provider<EditGoalDraftStore>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return EditGoalDraftStore(
    preferences: ref.watch(sharedPreferencesProvider),
    client: SupabaseConfig.isConfigured
        ? ref.watch(supabaseClientProvider)
        : null,
    userId: userId,
  );
});

final editGoalInitialDataLoaderProvider = Provider<EditGoalInitialDataLoader>((
  ref,
) {
  return () async {
    final profile = await ref
        .read(runnerProfileRepositoryProvider)
        .loadProfileAsync();
    final plan = await ref
        .read(planVersionRepositoryProvider)
        .loadActivePlanAsync();
    if (profile == null || plan == null) {
      throw const FormatException('Missing persisted Edit Goal data.');
    }
    return EditGoalInitialData(profile: profile, activePlanId: plan.id);
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
  const EditGoalEditing({
    required this.draft,
    required this.sourcePlanId,
    this.wasRebased = false,
  });

  final EditGoalDraft draft;
  final String sourcePlanId;
  final bool wasRebased;
}

class EditGoalFitnessCheckRequired extends EditGoalState {
  const EditGoalFitnessCheckRequired({
    required this.draft,
    required this.sourcePlanId,
    required this.fitnessCheck,
  });

  final EditGoalDraft draft;
  final String sourcePlanId;
  final GoalEditFitnessCheck fitnessCheck;
}

class EditGoalAssessmentPending extends EditGoalState {
  const EditGoalAssessmentPending({
    required this.draft,
    required this.sourcePlanId,
  });

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
  const EditGoalSuccess({required this.acceptance, required this.proposal});
  final GoalEditAcceptance acceptance;
  final GoalEditProposal proposal;
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
  int _revision = 1;

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
      final stored = await ref.read(editGoalDraftStoreProvider).load();
      if (!ref.mounted) return;
      final draft =
          stored?.draft ?? EditGoalDraft.fromProfile(profile: initial.profile);
      _revision = stored?.revision ?? 1;
      final wasRebased =
          stored != null && stored.sourcePlanId != initial.activePlanId;
      if (draft.assessment != null && draft.fitnessResult == null) {
        state = EditGoalAssessmentPending(
          draft: draft,
          sourcePlanId: initial.activePlanId,
        );
      } else {
        state = EditGoalEditing(
          draft: draft,
          sourcePlanId: initial.activePlanId,
          wasRebased: wasRebased,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = const EditGoalFailure(
          draft: null,
          sourcePlanId: null,
          reason: EditGoalFailureReason.parse,
        );
      }
    }
  }

  Future<void> retryInitialization() => initialize();

  void updateDraft(EditGoalDraft draft) {
    final sourcePlanId = _sourcePlanId(state);
    if (sourcePlanId == null) return;
    state = EditGoalEditing(draft: draft, sourcePlanId: sourcePlanId);
    unawaited(_persist(draft, sourcePlanId, status: 'editing'));
  }

  Future<void> scheduleAssessment(
    GoalEditFitnessCheck check,
    DateTime date,
  ) async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null ||
        sourcePlanId == null ||
        !check.safeDates.contains(date)) {
      return;
    }
    final assessment = EditGoalAssessment(
      id: 'goal-edit-${ref.read(editGoalClockProvider)().microsecondsSinceEpoch}',
      kind: check.benchmarkKind,
      scheduledFor: date,
      safeDates: check.safeDates,
    );
    final updated = draft.copyWith(assessment: assessment);
    await _persist(updated, sourcePlanId, status: 'assessment_pending');
    if (ref.mounted) {
      state = EditGoalAssessmentPending(
        draft: updated,
        sourcePlanId: sourcePlanId,
      );
    }
  }

  void cancelAssessment() {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;
    final updated = draft.copyWith(clearAssessment: true);
    updateDraft(updated);
  }

  void useFitnessResult(EditGoalFitnessResult result) {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return;
    final updated = draft.copyWith(fitnessResult: result);
    state = EditGoalEditing(draft: updated, sourcePlanId: sourcePlanId);
    unawaited(_persist(updated, sourcePlanId, status: 'editing'));
  }

  Future<void> discard() async {
    await ref.read(editGoalDraftStoreProvider).discard();
    await initialize();
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
      final initial = await ref.read(editGoalInitialDataLoaderProvider)();
      if (!ref.mounted) return false;
      state = EditGoalEditing(
        draft: draft,
        sourcePlanId: initial.activePlanId,
        wasRebased: previousSourcePlanId != initial.activePlanId,
      );
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
    await _persist(draft, sourcePlanId, status: 'editing');
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
      final data = _mapFromDynamic(response.data);
      if (data['state'] == 'fitness_check_required') {
        final fitnessCheck = GoalEditFitnessCheck.fromJson(
          data['fitnessCheck'],
        );
        if (ref.mounted) {
          state = EditGoalFitnessCheckRequired(
            draft: draft,
            sourcePlanId: sourcePlanId,
            fitnessCheck: fitnessCheck,
          );
        }
        return false;
      }
      final proposal = GoalEditProposal.fromJson(data);
      if (proposal.sourcePlanVersionId != sourcePlanId) {
        throw const FormatException('Mismatched proposal source plan.');
      }
      await _persist(draft, sourcePlanId, status: 'proposal_ready');
      if (ref.mounted) {
        state = EditGoalPreviewReady(
          draft: draft,
          sourcePlanId: sourcePlanId,
          proposal: proposal,
        );
      }
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
        // The committed response remains authoritative even if a local cache
        // reload fails. No compensating remote write is attempted.
      }
      await ref.read(editGoalDraftStoreProvider).discard();
      if (ref.mounted) {
        state = EditGoalSuccess(acceptance: acceptance, proposal: proposal);
      }
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

  Future<void> _persist(
    EditGoalDraft draft,
    String sourcePlanId, {
    required String status,
  }) async {
    _revision++;
    await ref
        .read(editGoalDraftStoreProvider)
        .save(
          draft: draft,
          sourcePlanId: sourcePlanId,
          status: status,
          revision: _revision,
          updatedAt: ref.read(editGoalClockProvider)(),
        );
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
  EditGoalFitnessCheckRequired(:final draft) ||
  EditGoalAssessmentPending(:final draft) ||
  EditGoalPreviewing(:final draft) ||
  EditGoalPreviewReady(:final draft) ||
  EditGoalApplying(:final draft) => draft,
  EditGoalFailure(:final draft) => draft,
  EditGoalSuccess() || EditGoalLoading() => null,
};

String? _sourcePlanId(EditGoalState state) => switch (state) {
  EditGoalEditing(:final sourcePlanId) ||
  EditGoalFitnessCheckRequired(:final sourcePlanId) ||
  EditGoalAssessmentPending(:final sourcePlanId) ||
  EditGoalPreviewing(:final sourcePlanId) ||
  EditGoalPreviewReady(:final sourcePlanId) ||
  EditGoalApplying(:final sourcePlanId) => sourcePlanId,
  EditGoalFailure(:final sourcePlanId) => sourcePlanId,
  EditGoalSuccess() || EditGoalLoading() => null,
};

GoalEditProposal? _proposal(EditGoalState state) => switch (state) {
  EditGoalPreviewReady(:final proposal) ||
  EditGoalApplying(:final proposal) => proposal,
  EditGoalFailure(:final proposal) => proposal,
  _ => null,
};

bool _validDraft(EditGoalDraft draft, DateTime now) {
  if (!draft.isChangeSelected || draft.race == RunnerGoalRace.other) {
    return false;
  }
  if (!draft.hasRaceDate) return draft.raceDate == null;
  final raceDate = draft.raceDate;
  if (raceDate == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  final raceDay = DateTime(raceDate.year, raceDate.month, raceDate.day);
  return !raceDay.isBefore(today);
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
  return _mapResponseFailure(
    FunctionResponse(
      data: _mapFromDynamic(error.details),
      status: error.status,
    ),
  );
}

Map<String, dynamic> _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

String _requiredNonEmptyString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Missing persisted Edit Goal value.');
  }
  return value;
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
