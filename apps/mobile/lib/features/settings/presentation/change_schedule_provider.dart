import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../../training_plan/data/plan_version_repository.dart';
import '../../training_plan/data/supabase_plan_version_repository.dart';
import '../../training_plan/domain/models/plan_version.dart';
import '../../training_plan/domain/models/training_plan.dart';
import '../../training_plan/presentation/training_plan_provider.dart';
import '../domain/change_schedule_models.dart';

typedef ChangeScheduleFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});
typedef ChangeScheduleInitialDataLoader =
    Future<ChangeScheduleInitialData> Function();
typedef ChangeScheduleCacheReconciler =
    Future<void> Function(ChangeScheduleAcceptedResponse acceptance);

class ChangeScheduleInitialData {
  const ChangeScheduleInitialData({
    required this.profile,
    required this.activePlan,
  });

  final RunnerProfile profile;
  final TrainingPlan activePlan;
}

enum ChangeScheduleFailureReason {
  auth('change_schedule_auth'),
  invalidInput('change_schedule_invalid_input'),
  timeout('change_schedule_timeout'),
  stale('change_schedule_stale'),
  expired('change_schedule_expired'),
  conflict('change_schedule_conflict'),
  parse('change_schedule_parse'),
  generic('change_schedule_error');

  const ChangeScheduleFailureReason(this.key);
  final String key;
}

enum ChangeScheduleAction {
  accept('accept_now'),
  schedule('schedule'),
  cancel('cancel_scheduled'),
  activate('activate_due'),
  undo('undo');

  const ChangeScheduleAction(this.key);
  final String key;
}

sealed class ChangeScheduleState {
  const ChangeScheduleState();
}

class ChangeScheduleLoading extends ChangeScheduleState {
  const ChangeScheduleLoading();
}

class ChangeScheduleEditing extends ChangeScheduleState {
  const ChangeScheduleEditing({
    required this.draft,
    required this.sourcePlanId,
    this.wasRebased = false,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final bool wasRebased;
}

class ChangeSchedulePreviewing extends ChangeScheduleState {
  const ChangeSchedulePreviewing({
    required this.draft,
    required this.sourcePlanId,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
}

class ChangeSchedulePreviewReady extends ChangeScheduleState {
  const ChangeSchedulePreviewReady({
    required this.draft,
    required this.sourcePlanId,
    required this.preview,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeSchedulePreviewResponse preview;
}

class ChangeScheduleApplying extends ChangeScheduleState {
  const ChangeScheduleApplying({
    required this.draft,
    required this.sourcePlanId,
    required this.action,
    this.preview,
    this.scheduled,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleAction action;
  final ChangeSchedulePreviewResponse? preview;
  final ChangeScheduleScheduledResponse? scheduled;
}

class ChangeScheduleScheduled extends ChangeScheduleState {
  const ChangeScheduleScheduled({
    required this.draft,
    required this.sourcePlanId,
    required this.scheduled,
    required this.preview,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleScheduledResponse scheduled;
  final ChangeSchedulePreviewResponse preview;
}

class ChangeScheduleCancelled extends ChangeScheduleState {
  const ChangeScheduleCancelled({
    required this.draft,
    required this.sourcePlanId,
    required this.cancelled,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleCancelledResponse cancelled;
}

class ChangeScheduleActivated extends ChangeScheduleState {
  const ChangeScheduleActivated({
    required this.draft,
    required this.sourcePlanId,
    required this.activated,
    this.preview,
    this.scheduled,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleActivatedResponse activated;
  final ChangeSchedulePreviewResponse? preview;
  final ChangeScheduleScheduledResponse? scheduled;
}

class ChangeScheduleUndone extends ChangeScheduleState {
  const ChangeScheduleUndone({
    required this.draft,
    required this.sourcePlanId,
    required this.undone,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleUndoneResponse undone;
}

class ChangeScheduleSuccess extends ChangeScheduleState {
  const ChangeScheduleSuccess({
    required this.draft,
    required this.sourcePlanId,
    required this.acceptance,
    required this.preview,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleAcceptedResponse acceptance;
  final ChangeSchedulePreviewResponse preview;
}

class ChangeScheduleFailure extends ChangeScheduleState {
  const ChangeScheduleFailure({
    required this.draft,
    required this.sourcePlanId,
    required this.reason,
    this.preview,
    this.action,
  });

  final ChangeScheduleDraft? draft;
  final String? sourcePlanId;
  final ChangeScheduleFailureReason reason;
  final ChangeSchedulePreviewResponse? preview;
  final ChangeScheduleAction? action;
}

final changeScheduleFunctionClientProvider =
    Provider<ChangeScheduleFunctionClient>((ref) {
      final client = ref.read(supabaseClientProvider);
      return (name, {body}) => client.functions.invoke(name, body: body);
    });

final changeScheduleClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final changeScheduleDraftStoreProvider = Provider<ChangeScheduleDraftStore>((
  ref,
) {
  final userId = ref.watch(currentUserProvider)?.id;
  return ChangeScheduleDraftStore(
    preferences: ref.watch(sharedPreferencesProvider),
    client: SupabaseConfig.isConfigured
        ? ref.watch(supabaseClientProvider)
        : null,
    userId: userId,
  );
});

final changeScheduleInitialDataLoaderProvider =
    Provider<ChangeScheduleInitialDataLoader>((ref) {
      return () async {
        final profile = await ref
            .read(runnerProfileRepositoryProvider)
            .loadProfileAsync();
        final activePlan = await ref
            .read(planVersionRepositoryProvider)
            .loadActivePlanAsync();
        if (profile == null || activePlan == null) {
          throw const FormatException(
            'Missing persisted change schedule source data.',
          );
        }

        return ChangeScheduleInitialData(
          profile: profile,
          activePlan: activePlan,
        );
      };
    });

final changeScheduleCacheReconcilerProvider =
    Provider<ChangeScheduleCacheReconciler>((ref) {
      return (acceptance) async {
        Object? failure;
        final planRepository = ref.read(
          sharedPreferencesPlanVersionRepositoryProvider,
        );
        final generatedAt = ref.read(changeScheduleClockProvider)();

        try {
          await planRepository.saveActivePlan(
            PlanVersion(
              id: acceptance.versionId,
              generatedAt: generatedAt,
              requestedBy: 'change_schedule',
              isActive: true,
              plan: acceptance.plan,
            ),
          );
        } catch (error) {
          failure = error;
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

        if (failure != null) {
          throw failure;
        }
      };
    });

class ChangeScheduleNotifier extends Notifier<ChangeScheduleState> {
  int _revision = 1;
  Future<void> _persistenceTail = Future<void>.value();

  @override
  ChangeScheduleState build() {
    Future.microtask(initialize);
    return const ChangeScheduleLoading();
  }

  Future<void> initialize() async {
    if (!ref.mounted) return;
    state = const ChangeScheduleLoading();
    try {
      final initial = await ref.read(changeScheduleInitialDataLoaderProvider)();
      final stored = await ref.read(changeScheduleDraftStoreProvider).load();
      final now = ref.read(changeScheduleClockProvider)();
      final activePlan = initial.activePlan;
      final sourcePlanId = activePlan.id;
      final baseline = ChangeScheduleDraft.inferFromLegacyProfileAndActivePlan(
        profile: initial.profile,
        activePlan: activePlan,
        clock: now,
      );
      final hasCurrentSourceDraft =
          stored != null && stored.sourcePlanId == sourcePlanId;
      final draft = hasCurrentSourceDraft ? stored.draft : baseline;
      _revision = stored?.revision ?? 1;
      final wasRebased = stored != null && !hasCurrentSourceDraft;
      state = ChangeScheduleEditing(
        draft: draft,
        sourcePlanId: sourcePlanId,
        wasRebased: wasRebased,
      );
    } catch (_) {
      if (ref.mounted) {
        state = const ChangeScheduleFailure(
          draft: null,
          sourcePlanId: null,
          reason: ChangeScheduleFailureReason.parse,
        );
      }
    }
  }

  Future<void> retryInitialization() => initialize();

  void updateDraft(ChangeScheduleDraft draft) {
    final sourcePlanId = _sourcePlanId(state);
    if (sourcePlanId == null) return;

    final wasRebased = switch (state) {
      ChangeScheduleEditing(:final wasRebased) => wasRebased,
      _ => false,
    };
    state = ChangeScheduleEditing(
      draft: draft,
      sourcePlanId: sourcePlanId,
      wasRebased: wasRebased,
    );
    unawaited(
      _persist(
        draft,
        sourcePlanId,
        status: ChangeScheduleDraftStatus.editing,
      ),
    );
  }

  void setAvailability(ChangeScheduleAvailability availability) {
    final draft = _draft(state);
    if (draft == null) return;
    updateDraft(draft.copyWith(availability: availability));
  }

  void setEffectiveWeek(ChangeScheduleEffectiveWeek effectiveWeek) {
    final draft = _draft(state);
    if (draft == null) return;
    updateDraft(draft.copyWith(effectiveWeek: effectiveWeek));
  }

  Future<void> discard() async {
    await _drainPersistence();
    await ref.read(changeScheduleDraftStoreProvider).discard();
    await initialize();
  }

  Future<bool> preview() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    if (draft == null || sourcePlanId == null) return false;

    if (!_validDraft(draft)) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.invalidInput,
      );
      return false;
    }

    state = ChangeSchedulePreviewing(draft: draft, sourcePlanId: sourcePlanId);
    await _persist(
      draft,
      sourcePlanId,
      status: ChangeScheduleDraftStatus.editing,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: draft.previewPayload(
              ref.read(changeScheduleClockProvider)(),
              ref.read(changeScheduleClockProvider)(),
            ),
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          preview: null,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final preview = ChangeSchedulePreviewResponse.fromJson(data);
      if (preview.sourcePlanVersionId != sourcePlanId) {
        _setFailure(
          draft,
          sourcePlanId,
          ChangeScheduleFailureReason.parse,
          preview: null,
        );
        return false;
      }

      await _persist(
        draft,
        sourcePlanId,
        status: ChangeScheduleDraftStatus.proposalReady,
      );
      state = ChangeSchedulePreviewReady(
        draft: draft,
        sourcePlanId: sourcePlanId,
        preview: preview,
      );
      return true;
    } on TimeoutException {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.timeout);
    } on FunctionException catch (error) {
      _setFailure(draft, sourcePlanId, _mapFunctionException(error));
    } on FormatException {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
    } catch (_) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.generic);
    }

    return false;
  }

  Future<bool> acceptNow() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final preview = _preview(state);
    if (draft == null || sourcePlanId == null || preview == null) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
      return false;
    }

    state = ChangeScheduleApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      action: ChangeScheduleAction.accept,
      preview: preview,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: {'action': 'accept_now', 'proposalId': preview.proposalId},
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          preview: preview,
          action: ChangeScheduleAction.accept,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final acceptance = ChangeScheduleAcceptedResponse.fromJson(data);
      await _cacheAccepted(acceptance);
      final discarded = await ref
          .read(changeScheduleDraftStoreProvider)
          .discard();
      if (!discarded) {
        _setFailure(
          draft,
          sourcePlanId,
          ChangeScheduleFailureReason.generic,
          preview: preview,
          action: ChangeScheduleAction.accept,
        );
        return false;
      }

      if (!ref.mounted) return false;
      state = ChangeScheduleSuccess(
        draft: draft,
        sourcePlanId: sourcePlanId,
        acceptance: acceptance,
        preview: preview,
      );
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.timeout,
        preview: preview,
        action: ChangeScheduleAction.accept,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        preview: preview,
        action: ChangeScheduleAction.accept,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.parse,
        preview: preview,
        action: ChangeScheduleAction.accept,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.generic,
        preview: preview,
        action: ChangeScheduleAction.accept,
      );
    }

    return false;
  }

  Future<bool> schedule() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final preview = _preview(state);
    if (draft == null || sourcePlanId == null || preview == null) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
      return false;
    }

    state = ChangeScheduleApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      action: ChangeScheduleAction.schedule,
      preview: preview,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: {'action': 'schedule', 'proposalId': preview.proposalId},
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          preview: preview,
          action: ChangeScheduleAction.schedule,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final scheduled = ChangeScheduleScheduledResponse.fromJson(data);
      state = ChangeScheduleScheduled(
        draft: draft,
        sourcePlanId: sourcePlanId,
        scheduled: scheduled,
        preview: preview,
      );
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.timeout,
        preview: preview,
        action: ChangeScheduleAction.schedule,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        preview: preview,
        action: ChangeScheduleAction.schedule,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.parse,
        preview: preview,
        action: ChangeScheduleAction.schedule,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.generic,
        preview: preview,
        action: ChangeScheduleAction.schedule,
      );
    }

    return false;
  }

  Future<bool> cancelScheduled() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final scheduled = _scheduled(state);
    final proposalId = scheduled?.proposalId;
    if (draft == null || sourcePlanId == null || proposalId == null) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
      return false;
    }

    state = ChangeScheduleApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      action: ChangeScheduleAction.cancel,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: {'action': 'cancel_scheduled', 'proposalId': proposalId},
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          action: ChangeScheduleAction.cancel,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final cancelled = ChangeScheduleCancelledResponse.fromJson(data);
      state = ChangeScheduleCancelled(
        draft: draft,
        sourcePlanId: sourcePlanId,
        cancelled: cancelled,
      );
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.timeout,
        action: ChangeScheduleAction.cancel,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        action: ChangeScheduleAction.cancel,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.parse,
        action: ChangeScheduleAction.cancel,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.generic,
        action: ChangeScheduleAction.cancel,
      );
    }

    return false;
  }

  Future<bool> activateDue() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final scheduled = _scheduled(state);
    final activationId = scheduled?.activationId;
    if (draft == null || sourcePlanId == null || activationId == null) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
      return false;
    }

    state = ChangeScheduleApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      action: ChangeScheduleAction.activate,
      scheduled: scheduled,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: {'action': 'activate_due', 'activationId': activationId},
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          action: ChangeScheduleAction.activate,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final activated = ChangeScheduleActivatedResponse.fromJson(data);

      if (activated.plan != null) {
        final plan = _planFromMap(activated.plan!);
        await _savePlanVersion(
          planId: activated.acceptedPlanVersionId ?? '',
          plan: plan,
        );
      }

      ref.invalidate(runnerProfileProvider);
      ref.invalidate(trainingPlanProvider);
      try {
        await ref.read(runnerProfileProvider.future);
      } catch (_) {}
      try {
        await ref.read(trainingPlanProvider.future);
      } catch (_) {}

      state = ChangeScheduleActivated(
        draft: draft,
        sourcePlanId: sourcePlanId,
        activated: activated,
        scheduled: scheduled,
        preview: _preview(state),
      );
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.timeout,
        action: ChangeScheduleAction.activate,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        action: ChangeScheduleAction.activate,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.parse,
        action: ChangeScheduleAction.activate,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.generic,
        action: ChangeScheduleAction.activate,
      );
    }

    return false;
  }

  Future<bool> undo() async {
    final draft = _draft(state);
    final sourcePlanId = _sourcePlanId(state);
    final proposalId = _proposalId(state);
    if (draft == null || sourcePlanId == null || proposalId == null) {
      _setFailure(draft, sourcePlanId, ChangeScheduleFailureReason.parse);
      return false;
    }

    state = ChangeScheduleApplying(
      draft: draft,
      sourcePlanId: sourcePlanId,
      action: ChangeScheduleAction.undo,
    );

    try {
      final response = await ref
          .read(changeScheduleFunctionClientProvider)(
            'change-schedule',
            body: {'action': 'undo', 'proposalId': proposalId},
          )
          .timeout(const Duration(seconds: 130));

      if (!_successful(response)) {
        _setFailure(
          draft,
          sourcePlanId,
          _mapResponseFailure(response),
          action: ChangeScheduleAction.undo,
        );
        return false;
      }

      final data = _mapFromDynamic(response.data);
      final undone = ChangeScheduleUndoneResponse.fromJson(data);
      state = ChangeScheduleUndone(
        draft: draft,
        sourcePlanId: sourcePlanId,
        undone: undone,
      );
      return true;
    } on TimeoutException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.timeout,
        action: ChangeScheduleAction.undo,
      );
    } on FunctionException catch (error) {
      _setFailure(
        draft,
        sourcePlanId,
        _mapFunctionException(error),
        action: ChangeScheduleAction.undo,
      );
    } on FormatException {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.parse,
        action: ChangeScheduleAction.undo,
      );
    } catch (_) {
      _setFailure(
        draft,
        sourcePlanId,
        ChangeScheduleFailureReason.generic,
        action: ChangeScheduleAction.undo,
      );
    }

    return false;
  }

  Future<void> _cacheAccepted(ChangeScheduleAcceptedResponse acceptance) async {
    await ref.read(changeScheduleCacheReconcilerProvider)(acceptance);
  }

  Future<void> _savePlanVersion({
    required String planId,
    required TrainingPlan plan,
  }) async {
    if (planId.isEmpty) {
      return;
    }
    final repository = ref.read(sharedPreferencesPlanVersionRepositoryProvider);
    await repository.saveActivePlan(
      PlanVersion(
        id: planId,
        generatedAt: ref.read(changeScheduleClockProvider)(),
        requestedBy: 'change_schedule',
        isActive: true,
        plan: plan,
      ),
    );
  }

  Future<void> _persist(
    ChangeScheduleDraft draft,
    String sourcePlanId, {
    required ChangeScheduleDraftStatus status,
  }) {
    final revision = ++_revision;
    final updatedAt = ref.read(changeScheduleClockProvider)();
    final store = ref.read(changeScheduleDraftStoreProvider);
    final previous = _persistenceTail;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // Failed local writes are best-effort.
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
      // Discard can still continue even after failed local writes.
    }
  }

  void _setFailure(
    ChangeScheduleDraft? draft,
    String? sourcePlanId,
    ChangeScheduleFailureReason reason, {
    ChangeSchedulePreviewResponse? preview,
    ChangeScheduleAction? action,
  }) {
    if (!ref.mounted) return;
    state = ChangeScheduleFailure(
      draft: draft,
      sourcePlanId: sourcePlanId,
      reason: reason,
      preview: preview,
      action: action,
    );
  }
}

final changeScheduleProvider =
    NotifierProvider.autoDispose<ChangeScheduleNotifier, ChangeScheduleState>(
      ChangeScheduleNotifier.new,
    );

ChangeScheduleDraft? _draft(ChangeScheduleState state) => switch (state) {
  ChangeScheduleLoading() => null,
  ChangeScheduleEditing(:final draft) => draft,
  ChangeSchedulePreviewing(:final draft) => draft,
  ChangeSchedulePreviewReady(:final draft) => draft,
  ChangeScheduleApplying(:final draft) => draft,
  ChangeScheduleScheduled(:final draft) => draft,
  ChangeScheduleCancelled(:final draft) => draft,
  ChangeScheduleActivated(:final draft) => draft,
  ChangeScheduleUndone(:final draft) => draft,
  ChangeScheduleSuccess(:final draft) => draft,
  ChangeScheduleFailure(:final draft) => draft,
};

String? _sourcePlanId(ChangeScheduleState state) => switch (state) {
  ChangeScheduleLoading() => null,
  ChangeScheduleEditing(:final sourcePlanId) => sourcePlanId,
  ChangeSchedulePreviewing(:final sourcePlanId) => sourcePlanId,
  ChangeSchedulePreviewReady(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleApplying(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleScheduled(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleCancelled(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleActivated(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleUndone(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleSuccess(:final sourcePlanId) => sourcePlanId,
  ChangeScheduleFailure(:final sourcePlanId) => sourcePlanId,
};

ChangeSchedulePreviewResponse? _preview(ChangeScheduleState state) =>
    switch (state) {
      ChangeSchedulePreviewReady(:final preview) => preview,
      ChangeScheduleApplying(:final preview) => preview,
      ChangeScheduleScheduled(:final preview) => preview,
      ChangeScheduleActivated(:final preview) => preview,
      ChangeScheduleFailure(:final preview) => preview,
      _ => null,
    };

ChangeScheduleScheduledResponse? _scheduled(ChangeScheduleState state) =>
    switch (state) {
      ChangeScheduleScheduled(:final scheduled) => scheduled,
      ChangeScheduleApplying(:final scheduled) => scheduled,
      _ => null,
    };

String? _proposalId(ChangeScheduleState state) => switch (state) {
  ChangeSchedulePreviewReady(:final preview) => preview.proposalId,
  ChangeScheduleScheduled(:final preview) => preview.proposalId,
  ChangeScheduleActivated(:final scheduled) => scheduled?.proposalId,
  ChangeScheduleFailure(:final preview) => preview?.proposalId,
  ChangeScheduleApplying(:final preview) => preview?.proposalId,
  _ => null,
};

bool _successful(FunctionResponse response) =>
    response.status >= 200 && response.status < 300;

ChangeScheduleFailureReason _mapResponseFailure(FunctionResponse response) {
  final error = _mapFromDynamic(response.data)['error'];

  if (response.status == 401 ||
      response.status == 403 ||
      error == 'unauthorized' ||
      error == 'missing_authorization' ||
      error == 'user_missing') {
    return ChangeScheduleFailureReason.auth;
  }

  if (response.status == 400 || error == 'invalid_request') {
    return ChangeScheduleFailureReason.invalidInput;
  }

  if (error == 'proposal_expired') {
    return ChangeScheduleFailureReason.expired;
  }

  if (error == 'proposal_not_found' ||
      error == 'proposal_not_current_week' ||
      error == 'proposal_not_pending' ||
      error == 'proposal_not_accepted' ||
      error == 'proposal_not_scheduled' ||
      error == 'source_plan_stale' ||
      error == 'source_profile_stale' ||
      error == 'proposal_plan_version_conflict' ||
      error == 'activation_not_due' ||
      error == 'activation_not_available' ||
      error == 'undo_not_available' ||
      error == 'undo_plan_not_active') {
    return ChangeScheduleFailureReason.conflict;
  }

  if (error == 'plan_id_missing' ||
      error == 'availability_id_missing' ||
      error == 'proposal_plan_id_missing' ||
      error == 'proposal_availability_id_missing' ||
      error == 'activation_timestamp_missing' ||
      error == 'proposal_inconsistent' ||
      error == 'proposal_cancelled_timestamp_missing') {
    return ChangeScheduleFailureReason.parse;
  }

  if (response.status == 404 ||
      error == 'activation_not_found' ||
      error == 'activation_proposal_not_found' ||
      error == 'proposal_profile_not_found') {
    return ChangeScheduleFailureReason.stale;
  }

  if (response.status == 408 || response.status == 504 || error == 'timeout') {
    return ChangeScheduleFailureReason.timeout;
  }

  if (response.status == 409) {
    return ChangeScheduleFailureReason.conflict;
  }

  return ChangeScheduleFailureReason.generic;
}

ChangeScheduleFailureReason _mapFunctionException(FunctionException error) {
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

TrainingPlan _planFromMap(Map<String, dynamic> map) =>
    TrainingPlan.fromJson(map) ??
    (throw const FormatException('Invalid plan data.'));

bool _validDraft(ChangeScheduleDraft draft) => draft.isValid;
