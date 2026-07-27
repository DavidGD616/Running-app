import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/settings/domain/change_schedule_models.dart';
import 'package:running_app/features/settings/presentation/change_schedule_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 13, 16, 45);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('initializes an inferred draft with active plan id', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final state = await _editingState(container);

    expect(state.sourcePlanId, 'active-plan');
    expect(state.draft.availability.targetRunningDays, 4);
    expect(state.draft.isValid, isTrue);
  });

  test('initialization preserves a draft for the current active plan', () async {
    final storedDraft = ChangeScheduleDraft(
      availability: _availability().copyWith(primaryLongRunWeekday: 1),
      effectiveWeek: ChangeScheduleEffectiveWeek.next,
    );
    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: null,
    );
    await store.save(
      draft: storedDraft,
      sourcePlanId: 'active-plan',
      status: ChangeScheduleDraftStatus.editing,
      revision: 4,
      updatedAt: now,
    );
    final container = _container(
      now: now,
      preferences: preferences,
      store: store,
    );
    addTearDown(container.dispose);

    final state = await _editingState(container);

    expect(state.draft.availability.primaryLongRunWeekday, 1);
    expect(state.draft.effectiveWeek, ChangeScheduleEffectiveWeek.next);
    expect(state.wasRebased, isFalse);
  });

  test(
    'initialization rebases an uncleared accepted draft after offline restart',
    () async {
      const userId = 'accepted-draft-user';
      final remote = _InMemoryChangeScheduleDraftRemoteStore(
        userId: userId,
        loadShouldFail: true,
      );
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: userId,
        remoteStore: remote,
        removeLocal: (_) async => false,
      );
      final staleDraft = ChangeScheduleDraft(
        availability: _availability().copyWith(primaryLongRunWeekday: 1),
        effectiveWeek: ChangeScheduleEffectiveWeek.next,
      );
      await store.save(
        draft: staleDraft,
        sourcePlanId: 'plan-before-accept',
        status: ChangeScheduleDraftStatus.proposalReady,
        revision: 4,
        updatedAt: now,
      );
      expect(await store.discard(), isFalse);
      expect(remote.rowFor(), isNull);

      final container = _container(
        now: now,
        preferences: preferences,
        store: store,
        loader: () async => _initialData(activePlanId: 'plan-accepted-1'),
      );
      addTearDown(container.dispose);

      final editing = await _editingState(container);

      expect(editing.sourcePlanId, 'plan-accepted-1');
      expect(editing.draft.availability.primaryLongRunWeekday, 7);
      expect(editing.draft.effectiveWeek, ChangeScheduleEffectiveWeek.current);
      expect(editing.wasRebased, isTrue);

      container
          .read(changeScheduleProvider.notifier)
          .setEffectiveWeek(ChangeScheduleEffectiveWeek.next);
      final updated = container.read(changeScheduleProvider);
      expect(updated, isA<ChangeScheduleEditing>());
      expect((updated as ChangeScheduleEditing).wasRebased, isTrue);
    },
  );

  test('local drafts are isolated by authenticated account', () async {
    final baselineDraft = ChangeScheduleDraft(
      availability: _availability(),
      effectiveWeek: ChangeScheduleEffectiveWeek.current,
    );
    final guestStore = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: null,
    );
    final userAStore = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-a',
    );

    await guestStore.save(
      draft: baselineDraft,
      sourcePlanId: 'active-plan',
      status: ChangeScheduleDraftStatus.editing,
      revision: 1,
      updatedAt: now,
    );

    expect(await userAStore.load(), isNull);

    await guestStore.save(
      draft: baselineDraft,
      sourcePlanId: 'active-plan',
      status: ChangeScheduleDraftStatus.editing,
      revision: 2,
      updatedAt: now,
    );

    expect(
      (await guestStore.load())?.draft.availability.primaryLongRunWeekday,
      baselineDraft.availability.primaryLongRunWeekday,
    );
  });

  test('persists rapid draft saves in revision order', () async {
    final controlled = _ControlledDraftStore(preferences);
    addTearDown(controlled.releaseAll);

    final container = _container(
      now: now,
      preferences: preferences,
      store: controlled,
    );
    addTearDown(container.dispose);

    final editing = await _editingState(container);
    final notifier = container.read(changeScheduleProvider.notifier);

    notifier.setEffectiveWeek(ChangeScheduleEffectiveWeek.next);
    notifier.setEffectiveWeek(ChangeScheduleEffectiveWeek.current);

    await _waitFor(() => controlled.savedDrafts.length == 1);
    expect(controlled.savedDrafts.first.availability.primaryLongRunWeekday, 7);
    controlled.releaseNext();
    await _waitFor(() => controlled.savedDrafts.length == 2);
    expect(controlled.savedDrafts.last.availability.primaryLongRunWeekday, 7);
    expect(controlled.revisions, [2, 3]);
    controlled.releaseNext();
    expect(editing.draft.availability.targetRunningDays, 4);
  });

  test(
    'preview sends a strict payload and stores proposal-ready status',
    () async {
      final calls = <Object?>[];
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          calls.add(body);
          return FunctionResponse(data: _previewResponse(), status: 200);
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);

      final previewResult = await container
          .read(changeScheduleProvider.notifier)
          .preview();
      if (!previewResult) {
        final currentState = container.read(changeScheduleProvider);
        if (currentState is ChangeScheduleFailure) {
          fail(
            'preview failed with sourcePlanId=${currentState.sourcePlanId} '
            'reason=${currentState.reason}',
          );
        }
        fail('preview failed with state=$currentState');
      }
      expect(previewResult, isTrue);

      final expected = editing.draft.previewPayload(now, now);
      expect(calls, hasLength(1));
      expect(calls.single, expected);

      final state = container.read(changeScheduleProvider);
      expect(state, isA<ChangeSchedulePreviewReady>());
      expect(
        (state as ChangeSchedulePreviewReady).preview.proposalId,
        'proposal-preview-1',
      );
      expect(
        preferences.getString(ChangeScheduleDraftStore.storageKeyForUser(null)),
        isNotNull,
      );
      final stored =
          jsonDecode(
                preferences.getString(
                  ChangeScheduleDraftStore.storageKeyForUser(null),
                )!,
              )
              as Map<String, dynamic>;
      expect(stored['status'], ChangeScheduleDraftStatus.proposalReady.key);
    },
  );

  test('preview carries a source-vs-candidate effective-week comparison', () async {
    final activePlan = _trainingPlan(
      'active-plan',
      sessions: [
        _sessionJson(
          id: 'current-easy',
          date: DateTime(2026, 7, 13),
          type: 'easyRun',
          durationMinutes: 35,
        ),
        _sessionJson(
          id: 'current-long',
          date: DateTime(2026, 7, 19),
          type: 'longRun',
          distanceKm: 16,
        ),
      ],
    );
    final candidatePlan = _planJson(
      id: 'candidate-plan',
      sessions: [
        _sessionJson(
          id: 'updated-intervals',
          date: DateTime(2026, 7, 14),
          type: 'intervals',
          durationMinutes: 45,
        ),
        _sessionJson(
          id: 'updated-long',
          date: DateTime(2026, 7, 18),
          type: 'longRun',
          distanceKm: 18,
        ),
      ],
    );
    final container = _container(
      now: now,
      preferences: preferences,
      loader: () async => ChangeScheduleInitialData(
        profile: buildRunnerProfile(),
        activePlan: activePlan,
      ),
      client: (_, {body}) async => FunctionResponse(
        data: {..._previewResponse(), 'candidatePlan': candidatePlan},
        status: 200,
      ),
    );
    addTearDown(container.dispose);

    await _editingState(container);
    expect(await container.read(changeScheduleProvider.notifier).preview(), isTrue);

    final state = container.read(changeScheduleProvider)
        as ChangeSchedulePreviewReady;
    expect(state.sourcePlan.id, 'active-plan');
    expect(state.comparison.weekStart, DateTime(2026, 7, 13));
    expect(state.comparison.currentWeek[0].primarySession?.id, 'current-easy');
    expect(state.comparison.currentWeek[6].hasLongRun, isTrue);
    expect(
      state.comparison.updatedWeek[1].primarySession?.id,
      'updated-intervals',
    );
    expect(state.comparison.updatedWeek[5].hasLongRun, isTrue);
  });

  test('preview rejects a response for a different source plan', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async => FunctionResponse(
        data: {
          ..._previewResponse(),
          'sourcePlanVersionId': 'different-active-plan',
        },
        status: 200,
      ),
    );
    addTearDown(container.dispose);

    await _editingState(container);
    expect(await container.read(changeScheduleProvider.notifier).preview(), isFalse);

    final failure = container.read(changeScheduleProvider) as ChangeScheduleFailure;
    expect(failure.reason, ChangeScheduleFailureReason.parse);
    expect(failure.comparison, isNull);
  });

  test('pending lifecycle hydration rebuilds the comparison after restart', () async {
    final activePlan = _trainingPlan(
      'active-plan',
      sessions: [
        _sessionJson(
          id: 'current-rest',
          date: DateTime(2026, 7, 13),
          type: 'restDay',
        ),
        _sessionJson(
          id: 'current-long',
          date: DateTime(2026, 7, 19),
          type: 'longRun',
        ),
      ],
    );
    final pending = ChangeScheduleLifecycleProposal.fromDatabaseRow({
      ..._lifecycleProposalRow(
        status: ChangeScheduleLifecycleProposalStatus.pending,
        id: 'proposal-pending-comparison',
        sourcePlanId: 'active-plan',
      ),
      'candidate_plan': _planJson(
        id: 'candidate-pending',
        sessions: [
          _sessionJson(
            id: 'updated-tempo',
            date: DateTime(2026, 7, 16),
            type: 'tempoRun',
            durationMinutes: 50,
          ),
        ],
      ),
    });
    Future<ChangeScheduleLifecycleLoadResult> lifecycle(String _) async =>
        ChangeScheduleLifecycleAvailable(
          ChangeScheduleLifecycleData(pendingProposal: pending),
        );
    ChangeScheduleInitialData loader() => ChangeScheduleInitialData(
      profile: buildRunnerProfile(),
      activePlan: activePlan,
    );

    final first = _container(
      now: now,
      preferences: preferences,
      loader: () async => loader(),
      lifecycleLoader: lifecycle,
    );
    await _waitFor(
      () => first.read(changeScheduleProvider) is ChangeSchedulePreviewReady,
    );
    first.dispose();

    final restarted = _container(
      now: now,
      preferences: preferences,
      loader: () async => loader(),
      lifecycleLoader: lifecycle,
    );
    addTearDown(restarted.dispose);
    await _waitFor(
      () =>
          restarted.read(changeScheduleProvider) is ChangeSchedulePreviewReady,
    );

    final state = restarted.read(changeScheduleProvider)
        as ChangeSchedulePreviewReady;
    expect(state.sourcePlan.id, 'active-plan');
    expect(state.comparison.currentWeek[0].isExplicitRestDay, isTrue);
    expect(state.comparison.currentWeek[6].hasLongRun, isTrue);
    expect(state.comparison.updatedWeek[3].primarySession?.id, 'updated-tempo');
    expect(state.comparison.updatedWeek[0].hasNoSession, isTrue);
  });

  test('accept_now applies the proposal and clears draft storage', () async {
    final calls = <Object?>[];
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        calls.add(body);
        final payload = body! as Map<String, dynamic>;
        if (payload['action'] == 'preview') {
          return FunctionResponse(data: _previewResponse(), status: 200);
        }
        if (payload['action'] == 'accept_now') {
          return FunctionResponse(data: _acceptedResponse(), status: 200);
        }
        return FunctionResponse(data: {'error': 'invalid'}, status: 400);
      },
    );
    addTearDown(container.dispose);

    await _editingState(container);
    expect(
      await container.read(changeScheduleProvider.notifier).preview(),
      isTrue,
    );
    final acceptNowResult = await container
        .read(changeScheduleProvider.notifier)
        .acceptNow();
    expect(acceptNowResult, isTrue);

    expect(calls.length, 2);
    expect(calls.last, {
      'action': 'accept_now',
      'proposalId': 'proposal-preview-1',
      'localDate': '2026-07-13',
    });
    final success =
        container.read(changeScheduleProvider) as ChangeScheduleSuccess;
    expect(success.acceptance.versionId, 'plan-accepted-1');
    expect(
      preferences.getString(ChangeScheduleDraftStore.storageKeyForUser(null)),
      isNull,
    );
  });

  test(
    'accept_now fails when local cleanup is blocked so no success state is emitted',
    () async {
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: null,
        removeLocal: (_) async => false,
      );
      final container = _container(
        now: now,
        preferences: preferences,
        store: store,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'accept_now') {
            return FunctionResponse(data: _acceptedResponse(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect(
        (failure as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.generic,
      );
      expect(failure.action, ChangeScheduleAction.accept);
      expect(failure.preview, isA<ChangeSchedulePreviewResponse>());
      expect(failure.draft?.isValid, isTrue);
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleSuccess>()),
      );
      expect(
        jsonDecode(
          preferences.getString(ChangeScheduleDraftStore.storageKeyForUser(null))!,
        )['status'],
        ChangeScheduleDraftStatus.proposalReady.key,
      );
    },
  );

  test(
    'accept_now fails when remote cleanup fails and keeps the draft for recovery',
    () async {
      final remote = _InMemoryChangeScheduleDraftRemoteStore(
        userId: 'user-remote-fail',
        discardShouldFail: true,
      );
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: 'user-remote-fail',
        remoteStore: remote,
      );
      final container = _container(
        now: now,
        preferences: preferences,
        store: store,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'accept_now') {
            return FunctionResponse(data: _acceptedResponse(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect(
        (failure as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.generic,
      );
      expect(failure.action, ChangeScheduleAction.accept);
      expect(failure.preview, isA<ChangeSchedulePreviewResponse>());
      expect(failure.draft?.isValid, isTrue);
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleSuccess>()),
      );
      expect(
        jsonDecode(
          preferences.getString(
            ChangeScheduleDraftStore.storageKeyForUser('user-remote-fail'),
          )!,
        )['status'],
        ChangeScheduleDraftStatus.proposalReady.key,
      );
      expect(remote.rowFor(), isNotNull);
    },
  );

  test(
    'accept_now rejects malformed accepted plans and keeps draft resumable',
    () async {
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'accept_now') {
            return FunctionResponse(
              data: _malformedAcceptedResponse(),
              status: 200,
            );
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);

      expect(await notifier.acceptNow(), isFalse);
      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect(
        (failure as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.parse,
      );
      expect(failure.action, ChangeScheduleAction.accept);
      expect(failure.preview, isA<ChangeSchedulePreviewResponse>());
      expect(failure.draft?.isValid, isTrue);
      expect(
        jsonDecode(
          preferences.getString(
            ChangeScheduleDraftStore.storageKeyForUser(null),
          )!,
        )['status'],
        ChangeScheduleDraftStatus.proposalReady.key,
      );
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleSuccess>()),
      );
    },
  );

  test(
    'accept_now treats cache reconciliation parse failures as parse failure',
    () async {
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'accept_now') {
            return FunctionResponse(data: _acceptedResponse(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
        cacheReconciler: (_) async {
          throw const FormatException('reconciliation failed');
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);

      expect(await notifier.acceptNow(), isFalse);
      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect(
        (failure as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.parse,
      );
      expect(
        jsonDecode(
          preferences.getString(
            ChangeScheduleDraftStore.storageKeyForUser(null),
          )!,
        )['status'],
        ChangeScheduleDraftStatus.proposalReady.key,
      );
    },
  );

  test(
    'accept_now treats non-parse cache reconciliation failures as generic',
    () async {
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'accept_now') {
            return FunctionResponse(data: _acceptedResponse(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
        cacheReconciler: (_) async {
          throw StateError('reconciliation failed');
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);

      expect(await notifier.acceptNow(), isFalse);
      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect(
        (failure as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.generic,
      );
      expect(failure.action, ChangeScheduleAction.accept);
      expect(failure.preview, isA<ChangeSchedulePreviewResponse>());
      expect(failure.draft?.isValid, isTrue);
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleSuccess>()),
      );
      expect(
        jsonDecode(
          preferences.getString(
            ChangeScheduleDraftStore.storageKeyForUser(null),
          )!,
        )['status'],
        ChangeScheduleDraftStatus.proposalReady.key,
      );
    },
  );

  test('schedule then cancel updates scheduled and cancelled states', () async {
    final calls = <Object?>[];
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        calls.add(body);
        final payload = body! as Map<String, dynamic>;
        if (payload['action'] == 'preview') {
          return FunctionResponse(data: _previewResponse(), status: 200);
        }
        if (payload['action'] == 'schedule') {
          return FunctionResponse(data: _scheduledResponse(), status: 200);
        }
        if (payload['action'] == 'cancel_scheduled') {
          return FunctionResponse(data: _cancelledResponse(), status: 200);
        }
        return FunctionResponse(data: {'error': 'invalid'}, status: 400);
      },
    );
    addTearDown(container.dispose);

    await _editingState(container);
    expect(
      await container.read(changeScheduleProvider.notifier).preview(),
      isTrue,
    );
    final scheduleResult = await container
        .read(changeScheduleProvider.notifier)
        .schedule();
    expect(scheduleResult, isTrue);

    final scheduled = container.read(changeScheduleProvider);
    expect(scheduled, isA<ChangeScheduleScheduled>());
    expect(
      (scheduled as ChangeScheduleScheduled).scheduled.activationId,
      'activation-1',
    );

    expect(
      await container.read(changeScheduleProvider.notifier).cancelScheduled(),
      isTrue,
    );
    expect(
      container.read(changeScheduleProvider),
      isA<ChangeScheduleCancelled>(),
    );
    expect(
      calls.map((call) => (call as Map)['action']),
      containsAll(['preview', 'schedule', 'cancel_scheduled']),
    );
    expect(calls.firstWhere((call) => (call as Map)['action'] == 'schedule'), {
      'action': 'schedule',
      'proposalId': 'proposal-preview-1',
      'localDate': '2026-07-13',
    });
    expect(
      calls.firstWhere((call) => (call as Map)['action'] == 'cancel_scheduled'),
      {'action': 'cancel_scheduled', 'proposalId': 'proposal-preview-1'},
    );
  });

  test(
    'activate due accepts the production response without plan only after reconciliation',
    () async {
      final calls = <Object?>[];
      final reconciliation = Completer<void>();
      String? reconciledPlanVersionId;
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          calls.add(body);
          final payload = body! as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _previewResponse(), status: 200);
          }
          if (payload['action'] == 'schedule') {
            return FunctionResponse(data: _scheduledResponse(), status: 200);
          }
          if (payload['action'] == 'activate_due') {
            return FunctionResponse(data: _activatedResponse(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
        activationCacheReconciler: (activated) async {
          reconciledPlanVersionId = activated.acceptedPlanVersionId;
          expect(activated.plan, isNull);
          await reconciliation.future;
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(changeScheduleProvider.notifier);
      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.schedule(), isTrue);

      final activation = notifier.activateDue();
      await _waitFor(
        () => calls.any(
          (call) => call is Map && call['action'] == 'activate_due',
        ),
      );
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleApplying>());
      expect(reconciledPlanVersionId, 'plan-scheduled-1');
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleActivated>()),
      );

      reconciliation.complete();
      expect(await activation, isTrue);

      final state = container.read(changeScheduleProvider);
      expect(state, isA<ChangeScheduleActivated>());
      expect(
        (state as ChangeScheduleActivated).activated.acceptedPlanVersionId,
        'plan-scheduled-1',
      );
      expect(
        calls.firstWhere((call) => (call as Map)['action'] == 'activate_due'),
        {
          'action': 'activate_due',
          'activationId': 'activation-1',
          'localDate': '2026-07-13',
        },
      );
    },
  );

  test('activate due rejects a mismatched authoritative plan refresh', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        return switch (payload['action']) {
          'preview' => FunctionResponse(data: _previewResponse(), status: 200),
          'schedule' => FunctionResponse(data: _scheduledResponse(), status: 200),
          'activate_due' => FunctionResponse(
            data: _activatedResponse(),
            status: 200,
          ),
          _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
        };
      },
      activationCacheReconciler: (_) async {
        throw const ChangeScheduleActivationReconciliationException(
          ChangeScheduleFailureReason.stale,
        );
      },
    );
    addTearDown(container.dispose);

    final notifier = container.read(changeScheduleProvider.notifier);
    await _editingState(container);
    expect(await notifier.preview(), isTrue);
    expect(await notifier.schedule(), isTrue);
    expect(await notifier.activateDue(), isFalse);

    final failure = container.read(changeScheduleProvider);
    expect(failure, isA<ChangeScheduleFailure>());
    expect(
      (failure as ChangeScheduleFailure).reason,
      ChangeScheduleFailureReason.stale,
    );
    expect(failure.action, ChangeScheduleAction.activate);
    expect(notifier.recoverFromFailure(), isTrue);
    await _editingState(container);
  });

  test('activate due fails when authoritative reconciliation refresh fails', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        return switch (payload['action']) {
          'preview' => FunctionResponse(data: _previewResponse(), status: 200),
          'schedule' => FunctionResponse(data: _scheduledResponse(), status: 200),
          'activate_due' => FunctionResponse(
            data: _activatedResponse(),
            status: 200,
          ),
          _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
        };
      },
      activationCacheReconciler: (_) async {
        throw StateError('authoritative refresh failed');
      },
    );
    addTearDown(container.dispose);

    final notifier = container.read(changeScheduleProvider.notifier);
    await _editingState(container);
    expect(await notifier.preview(), isTrue);
    expect(await notifier.schedule(), isTrue);
    expect(await notifier.activateDue(), isFalse);

    final failure = container.read(changeScheduleProvider);
    expect(failure, isA<ChangeScheduleFailure>());
    expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.generic);
    expect(failure.action, ChangeScheduleAction.activate);
    expect(notifier.recoverFromFailure(), isTrue);
    expect(container.read(changeScheduleProvider), isA<ChangeScheduleScheduled>());
  });

  test(
    'undo accepts the production response ids only after cache reconciliation',
    () async {
      final calls = <Map<String, dynamic>>[];
      final reconciliation = Completer<void>();
      ChangeScheduleUndoneResponse? reconciled;
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          calls.add(payload);
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: _acceptedResponse(),
              status: 200,
            ),
            'undo' => FunctionResponse(data: _undoneResponse(), status: 200),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (undone) async {
          reconciled = undone;
          await reconciliation.future;
        },
      );
      addTearDown(container.dispose);

      await _editingState(container);
      expect(
        await container.read(changeScheduleProvider.notifier).preview(),
        isTrue,
      );
      expect(
        await container.read(changeScheduleProvider.notifier).acceptNow(),
        isTrue,
      );
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleSuccess>());

      final undo = container.read(changeScheduleProvider.notifier).undo();
      await _waitFor(() => calls.any((call) => call['action'] == 'undo'));
      expect(calls.last, {'action': 'undo', 'proposalId': 'proposal-preview-1'});
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleApplying>());
      expect(reconciled?.proposalId, 'proposal-preview-1');
      expect(reconciled?.priorPlanVersionId, 'plan-previous');
      expect(reconciled?.priorAvailabilityVersionId, 'availability-previous');
      expect(reconciled?.restoredPlanVersionId, 'plan-accepted-1');
      expect(
        reconciled?.restoredAvailabilityVersionId,
        'availability-accepted',
      );
      expect(
        container.read(changeScheduleProvider),
        isNot(isA<ChangeScheduleUndone>()),
      );

      reconciliation.complete();
      expect(await undo, isTrue);
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleUndone>());
    },
  );

  test(
    'undo rejects ids inconsistent with the accepted lifecycle and reloads',
    () async {
      var lifecycleLoads = 0;
      var cacheReconciled = false;
      final container = _container(
        now: now,
        preferences: preferences,
        lifecycleLoader: (_) async {
          lifecycleLoads += 1;
          return const ChangeScheduleLifecycleUnavailable();
        },
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: _acceptedResponse(),
              status: 200,
            ),
            'undo' => FunctionResponse(
              data: {
                ..._undoneResponse(),
                'restoredPlanVersionId': 'different-accepted-plan',
              },
              status: 200,
            ),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (_) async {
          cacheReconciled = true;
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(changeScheduleProvider.notifier);

      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isTrue);
      expect(await notifier.undo(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.stale);
      expect(failure.action, ChangeScheduleAction.undo);
      expect(cacheReconciled, isFalse);

      expect(notifier.recoverFromFailure(), isTrue);
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleLoading>());
      await _editingState(container);
      expect(lifecycleLoads, 2);
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleSuccess>()));
    },
  );

  test(
    'undo rejects a legacy response with omitted lifecycle proof and reloads authoritatively',
    () async {
      var authoritativeLoads = 0;
      var cacheReconciled = false;
      final container = _container(
        now: now,
        preferences: preferences,
        authoritativeLoader: () async {
          authoritativeLoads += 1;
          return _initialData(activePlanId: 'plan-previous');
        },
        lifecycleLoader: (_) async => const ChangeScheduleLifecycleUnavailable(),
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: {
                ..._acceptedResponse(),
                'priorActivePlanVersionId': null,
                'priorActiveAvailabilityVersionId': null,
                'acceptedAvailabilityVersionId': null,
              },
              status: 200,
            ),
            'undo' => FunctionResponse(
              data: {
                'proposalId': 'proposal-preview-1',
                'priorPlanVersionId': 'plan-accepted-1',
                'priorAvailabilityVersionId': 'availability-accepted',
              },
              status: 200,
            ),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (_) async {
          cacheReconciled = true;
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(changeScheduleProvider.notifier);

      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isTrue);
      final accepted =
          container.read(changeScheduleProvider) as ChangeScheduleSuccess;
      expect(accepted.acceptance.versionId, 'plan-accepted-1');
      expect(
        accepted.acceptance.priorActivePlanVersionId,
        isNull,
      );

      expect(await notifier.undo(), isFalse);
      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.stale);
      expect(failure.action, ChangeScheduleAction.undo);
      expect(cacheReconciled, isFalse);
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleUndone>()));

      expect(notifier.recoverFromFailure(), isTrue);
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleLoading>());
      final recovered = await _editingState(container);
      expect(authoritativeLoads, 1);
      expect(recovered.sourcePlanId, 'plan-previous');
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleSuccess>()));
    },
  );

  test(
    'undo rejects an omitted deactivation proof and reloads authoritatively',
    () async {
      var authoritativeLoads = 0;
      var cacheReconciled = false;
      final container = _container(
        now: now,
        preferences: preferences,
        authoritativeLoader: () async {
          authoritativeLoads += 1;
          return _initialData(activePlanId: 'plan-previous');
        },
        lifecycleLoader: (_) async => const ChangeScheduleLifecycleUnavailable(),
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: _acceptedResponse(),
              status: 200,
            ),
            'undo' => FunctionResponse(
              data: {
                'proposalId': 'proposal-preview-1',
                'priorPlanVersionId': 'plan-previous',
                'priorAvailabilityVersionId': 'availability-previous',
              },
              status: 200,
            ),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (_) async {
          cacheReconciled = true;
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(changeScheduleProvider.notifier);

      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isTrue);
      expect(await notifier.undo(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.stale);
      expect(failure.action, ChangeScheduleAction.undo);
      expect(cacheReconciled, isFalse);
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleUndone>()));

      expect(notifier.recoverFromFailure(), isTrue);
      final recovered = await _editingState(container);
      expect(authoritativeLoads, 1);
      expect(recovered.sourcePlanId, 'plan-previous');
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleSuccess>()));
    },
  );

  test(
    'undo reloads instead of retrying after authoritative active ids mismatch',
    () async {
      var lifecycleLoads = 0;
      var authoritativeLoads = 0;
      final container = _container(
        now: now,
        preferences: preferences,
        authoritativeLoader: () async {
          authoritativeLoads += 1;
          return _initialData(activePlanId: 'plan-previous');
        },
        lifecycleLoader: (_) async {
          lifecycleLoads += 1;
          return const ChangeScheduleLifecycleUnavailable();
        },
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: _acceptedResponse(),
              status: 200,
            ),
            'undo' => FunctionResponse(data: _undoneResponse(), status: 200),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (_) async {
          throw const ChangeScheduleUndoReconciliationException(
            ChangeScheduleFailureReason.stale,
          );
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(changeScheduleProvider.notifier);

      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isTrue);
      expect(await notifier.undo(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.stale);
      expect(failure.action, ChangeScheduleAction.undo);

      expect(notifier.recoverFromFailure(), isTrue);
      await _editingState(container);
      expect(authoritativeLoads, 1);
      expect(lifecycleLoads, 2);
      final recovered =
          container.read(changeScheduleProvider) as ChangeScheduleEditing;
      expect(recovered.sourcePlanId, 'plan-previous');
    },
  );

  test(
    'undo reloads authoritatively when post-mutation reconciliation fails',
    () async {
      var lifecycleLoads = 0;
      final container = _container(
        now: now,
        preferences: preferences,
        lifecycleLoader: (_) async {
          lifecycleLoads += 1;
          return const ChangeScheduleLifecycleUnavailable();
        },
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: _acceptedResponse(),
              status: 200,
            ),
            'undo' => FunctionResponse(data: _undoneResponse(), status: 200),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
        undoCacheReconciler: (_) async {
          throw StateError('authoritative refresh failed');
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(changeScheduleProvider.notifier);

      await _editingState(container);
      expect(await notifier.preview(), isTrue);
      expect(await notifier.acceptNow(), isTrue);
      expect(await notifier.undo(), isFalse);

      final failure = container.read(changeScheduleProvider);
      expect(failure, isA<ChangeScheduleFailure>());
      expect((failure as ChangeScheduleFailure).reason, ChangeScheduleFailureReason.stale);
      expect(failure.action, ChangeScheduleAction.undo);

      expect(notifier.recoverFromFailure(), isTrue);
      expect(container.read(changeScheduleProvider), isA<ChangeScheduleLoading>());
      await _editingState(container);
      expect(lifecycleLoads, 2);
      expect(container.read(changeScheduleProvider), isNot(isA<ChangeScheduleSuccess>()));
    },
  );

  test('initialization restores scheduled state after provider disposal', () async {
    Future<ChangeScheduleLifecycleLoadResult> lifecycle(String _) =>
        Future.value(ChangeScheduleLifecycleAvailable(
      ChangeScheduleLifecycleData(
        scheduledProposal: _lifecycleProposal(
          status: ChangeScheduleLifecycleProposalStatus.scheduled,
          id: 'proposal-scheduled-1',
          sourcePlanId: 'active-plan',
          effectiveFrom: '2026-07-20',
          scheduledPlanVersionId: 'plan-scheduled-1',
        ),
        scheduledActivation: _lifecycleActivation(
          proposalId: 'proposal-scheduled-1',
          sourcePlanId: 'active-plan',
          effectiveFrom: '2026-07-20',
          queuedPlanVersionId: 'plan-scheduled-1',
        ),
      ),
        ));

    final first = _container(
      now: now,
      preferences: preferences,
      lifecycleLoader: lifecycle,
    );
    await _waitFor(
      () => first.read(changeScheduleProvider) is ChangeScheduleScheduled,
    );
    first.dispose();

    final restarted = _container(
      now: now,
      preferences: preferences,
      lifecycleLoader: lifecycle,
    );
    addTearDown(restarted.dispose);
    await _waitFor(
      () => restarted.read(changeScheduleProvider) is ChangeScheduleScheduled,
    );

    final state =
        restarted.read(changeScheduleProvider) as ChangeScheduleScheduled;
    expect(state.scheduled.proposalId, 'proposal-scheduled-1');
    expect(state.scheduled.activationId, 'activation-1');
  });

  test('initialization restores an accepted undoable state after restart', () async {
    final calls = <Map<String, dynamic>>[];
    Future<ChangeScheduleLifecycleLoadResult> lifecycle(String _) =>
        Future.value(ChangeScheduleLifecycleAvailable(
      ChangeScheduleLifecycleData(
        acceptedProposal: _lifecycleProposal(
          status: ChangeScheduleLifecycleProposalStatus.accepted,
          id: 'proposal-accepted-1',
          sourcePlanId: 'plan-before-accept',
          acceptedPlanVersionId: 'plan-accepted-1',
        ),
      ),
        ));

    final first = _container(
      now: now,
      preferences: preferences,
      loader: () async => _initialData(activePlanId: 'plan-accepted-1'),
      lifecycleLoader: lifecycle,
    );
    await _waitFor(
      () => first.read(changeScheduleProvider) is ChangeScheduleSuccess,
    );
    first.dispose();

    final restarted = _container(
      now: now,
      preferences: preferences,
      loader: () async => _initialData(activePlanId: 'plan-accepted-1'),
      lifecycleLoader: lifecycle,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        calls.add(payload);
        return FunctionResponse(
          data: _undoneResponse(id: 'proposal-accepted-1'),
          status: 200,
        );
      },
    );
    addTearDown(restarted.dispose);
    await _waitFor(
      () => restarted.read(changeScheduleProvider) is ChangeScheduleSuccess,
    );

    expect(await restarted.read(changeScheduleProvider.notifier).undo(), isTrue);
    expect(calls.single, {'action': 'undo', 'proposalId': 'proposal-accepted-1'});
    expect(restarted.read(changeScheduleProvider), isA<ChangeScheduleUndone>());
  });

  test('cancel and undo failures restore their truthful lifecycle states', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        return switch (payload['action']) {
          'preview' => FunctionResponse(data: _previewResponse(), status: 200),
          'schedule' => FunctionResponse(data: _scheduledResponse(), status: 200),
          'cancel_scheduled' => FunctionResponse(
            data: {'error': 'timeout'},
            status: 504,
          ),
          _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
        };
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(changeScheduleProvider.notifier);

    await _editingState(container);
    expect(await notifier.preview(), isTrue);
    expect(await notifier.schedule(), isTrue);
    expect(await notifier.cancelScheduled(), isFalse);
    final cancelledFailure =
        container.read(changeScheduleProvider) as ChangeScheduleFailure;
    expect(cancelledFailure.scheduled, isNotNull);
    expect(cancelledFailure.preview, isNotNull);
    expect(notifier.recoverFromFailure(), isTrue);
    expect(container.read(changeScheduleProvider), isA<ChangeScheduleScheduled>());

    final acceptedContainer = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        return switch (payload['action']) {
          'preview' => FunctionResponse(data: _previewResponse(), status: 200),
          'accept_now' => FunctionResponse(
            data: _acceptedResponse(),
            status: 200,
          ),
          'undo' => FunctionResponse(data: {'error': 'timeout'}, status: 504),
          _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
        };
      },
    );
    addTearDown(acceptedContainer.dispose);
    final acceptedNotifier = acceptedContainer.read(
      changeScheduleProvider.notifier,
    );
    await _editingState(acceptedContainer);
    expect(await acceptedNotifier.preview(), isTrue);
    expect(await acceptedNotifier.acceptNow(), isTrue);
    expect(await acceptedNotifier.undo(), isFalse);
    final undoFailure =
        acceptedContainer.read(changeScheduleProvider) as ChangeScheduleFailure;
    expect(undoFailure.acceptance, isNotNull);
    expect(undoFailure.preview, isNotNull);
    expect(acceptedNotifier.recoverFromFailure(), isTrue);
    expect(acceptedContainer.read(changeScheduleProvider), isA<ChangeScheduleSuccess>());
  });

  test(
    'terminal lifecycle failures reload authoritatively instead of restoring cached state',
    () async {
      final terminalFailures = <({ChangeScheduleFailureReason reason, Object error, int status})>[
        (
          reason: ChangeScheduleFailureReason.expired,
          error: 'proposal_expired',
          status: 409,
        ),
        (
          reason: ChangeScheduleFailureReason.stale,
          error: 'activation_not_found',
          status: 404,
        ),
        (
          reason: ChangeScheduleFailureReason.conflict,
          error: 'proposal_plan_version_conflict',
          status: 409,
        ),
      ];

      for (final terminal in terminalFailures) {
        var lifecycleLoads = 0;
        final container = _container(
          now: now,
          preferences: preferences,
          lifecycleLoader: (_) async {
            lifecycleLoads += 1;
            return const ChangeScheduleLifecycleUnavailable();
          },
          client: (_, {body}) async {
            final payload = body! as Map<String, dynamic>;
            return switch (payload['action']) {
              'preview' => FunctionResponse(
                data: _previewResponse(),
                status: 200,
              ),
              'accept_now' => FunctionResponse(
                data: {'error': terminal.error},
                status: terminal.status,
              ),
              _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
            };
          },
        );
        addTearDown(container.dispose);
        final notifier = container.read(changeScheduleProvider.notifier);

        await _editingState(container);
        expect(await notifier.preview(), isTrue);
        expect(await notifier.acceptNow(), isFalse);
        final failure = container.read(changeScheduleProvider);
        expect(failure, isA<ChangeScheduleFailure>());
        expect(
          (failure as ChangeScheduleFailure).reason,
          terminal.reason,
        );
        expect(failure.preview, isNotNull);

        expect(notifier.recoverFromFailure(), isTrue);
        expect(container.read(changeScheduleProvider), isA<ChangeScheduleLoading>());
        await _waitFor(
          () => container.read(changeScheduleProvider) is ChangeScheduleEditing,
        );
        expect(lifecycleLoads, 2);
        expect(container.read(changeScheduleProvider), isNot(isA<ChangeSchedulePreviewReady>()));
      }
    },
  );

  test('timeout lifecycle failures still recover the cached scheduled state', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        return switch (payload['action']) {
          'preview' => FunctionResponse(data: _previewResponse(), status: 200),
          'schedule' => FunctionResponse(data: _scheduledResponse(), status: 200),
          'cancel_scheduled' => FunctionResponse(
            data: {'error': 'timeout'},
            status: 504,
          ),
          _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
        };
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(changeScheduleProvider.notifier);

    await _editingState(container);
    expect(await notifier.preview(), isTrue);
    expect(await notifier.schedule(), isTrue);
    expect(await notifier.cancelScheduled(), isFalse);
    expect(
      (container.read(changeScheduleProvider) as ChangeScheduleFailure).reason,
      ChangeScheduleFailureReason.timeout,
    );

    expect(notifier.recoverFromFailure(), isTrue);
    expect(container.read(changeScheduleProvider), isA<ChangeScheduleScheduled>());
  });

  test('initialization rejects scheduled lifecycle rows from another active plan', () async {
    final scheduled = _lifecycleProposal(
      status: ChangeScheduleLifecycleProposalStatus.scheduled,
      id: 'proposal-scheduled-1',
      sourcePlanId: 'active-plan',
      effectiveFrom: '2026-07-20',
      scheduledPlanVersionId: 'plan-scheduled-1',
    );

    final staleLifecycles = <ChangeScheduleLifecycleData>[
      ChangeScheduleLifecycleData(
        scheduledProposal: _lifecycleProposal(
          status: ChangeScheduleLifecycleProposalStatus.scheduled,
          id: 'proposal-stale-source',
          sourcePlanId: 'previous-plan',
          effectiveFrom: '2026-07-20',
          scheduledPlanVersionId: 'plan-scheduled-1',
        ),
        scheduledActivation: _lifecycleActivation(
          proposalId: 'proposal-stale-source',
          sourcePlanId: 'active-plan',
          effectiveFrom: '2026-07-20',
          queuedPlanVersionId: 'plan-scheduled-1',
        ),
      ),
      ChangeScheduleLifecycleData(
        scheduledProposal: scheduled,
        scheduledActivation: _lifecycleActivation(
          proposalId: 'proposal-scheduled-1',
          sourcePlanId: 'previous-plan',
          effectiveFrom: '2026-07-20',
          queuedPlanVersionId: 'plan-scheduled-1',
        ),
      ),
    ];

    for (final lifecycle in staleLifecycles) {
      final container = _container(
        now: now,
        preferences: preferences,
        lifecycleLoader: (_) async => ChangeScheduleLifecycleAvailable(lifecycle),
      );
      addTearDown(container.dispose);
      await _waitFor(
        () => container.read(changeScheduleProvider) is ChangeScheduleFailure,
      );
      expect(
        (container.read(changeScheduleProvider) as ChangeScheduleFailure).reason,
        ChangeScheduleFailureReason.parse,
      );
    }
  });

  test('expired or malformed lifecycle previews are not restored as valid', () async {
    final expired = _container(
      now: now,
      preferences: preferences,
      lifecycleLoader: (_) async => ChangeScheduleLifecycleAvailable(
        ChangeScheduleLifecycleData(
          pendingProposal: _lifecycleProposal(
            status: ChangeScheduleLifecycleProposalStatus.pending,
            id: 'proposal-expired',
            sourcePlanId: 'active-plan',
            expiresAt: '2026-07-13T16:44:59.000Z',
          ),
        ),
      ),
    );
    addTearDown(expired.dispose);
    expect(await _editingState(expired), isA<ChangeScheduleEditing>());

    final malformed = _container(
      now: now,
      preferences: preferences,
      lifecycleLoader: (_) async {
        ChangeScheduleLifecycleProposal.fromDatabaseRow({
          ..._lifecycleProposalRow(
            status: ChangeScheduleLifecycleProposalStatus.pending,
            id: 'proposal-malformed',
            sourcePlanId: 'active-plan',
          ),
          'candidate_plan': const <String, dynamic>{},
        });
        throw StateError('Malformed lifecycle row unexpectedly parsed.');
      },
    );
    addTearDown(malformed.dispose);
    await _waitFor(
      () => malformed.read(changeScheduleProvider) is ChangeScheduleFailure,
    );
    expect(
      (malformed.read(changeScheduleProvider) as ChangeScheduleFailure).reason,
      ChangeScheduleFailureReason.parse,
    );
  });
}

ProviderContainer _container({
  required DateTime now,
  required SharedPreferences preferences,
  ChangeScheduleFunctionClient? client,
  ChangeScheduleInitialDataLoader? loader,
  ChangeScheduleInitialDataLoader? authoritativeLoader,
  ChangeScheduleLifecycleLoader? lifecycleLoader,
  ChangeScheduleDraftStore? store,
  ChangeScheduleCacheReconciler? cacheReconciler,
  ChangeScheduleActivationCacheReconciler? activationCacheReconciler,
  ChangeScheduleUndoCacheReconciler? undoCacheReconciler,
}) {
  final container = ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      changeScheduleClockProvider.overrideWithValue(() => now),
      changeScheduleInitialDataLoaderProvider.overrideWithValue(
        loader ?? () async => _initialData(),
      ),
      if (authoritativeLoader != null)
        changeScheduleAuthoritativeInitialDataLoaderProvider.overrideWithValue(
          authoritativeLoader,
        ),
      changeScheduleLifecycleLoaderProvider.overrideWithValue(
        lifecycleLoader ?? (_) async => const ChangeScheduleLifecycleUnavailable(),
      ),
      changeScheduleFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async =>
                FunctionResponse(data: _previewResponse(), status: 200),
      ),
      changeScheduleCacheReconcilerProvider.overrideWithValue(
        cacheReconciler ?? ((_) async {}),
      ),
      changeScheduleActivationCacheReconcilerProvider.overrideWithValue(
        activationCacheReconciler ?? ((_) async {}),
      ),
      changeScheduleUndoCacheReconcilerProvider.overrideWithValue(
        undoCacheReconciler ?? ((_) async {}),
      ),
      if (store != null)
        changeScheduleDraftStoreProvider.overrideWithValue(store),
    ],
  );
  container.listen(changeScheduleProvider, (_, _) {}, fireImmediately: true);
  return container;
}

class _InMemoryChangeScheduleDraftRemoteStore
    implements ChangeScheduleDraftRemoteStore {
  _InMemoryChangeScheduleDraftRemoteStore({
    required String userId,
    bool discardShouldFail = false,
    bool loadShouldFail = false,
  }) : _userId = userId,
       _discardShouldFail = discardShouldFail,
       _loadShouldFail = loadShouldFail;

  final String _userId;
  final bool _discardShouldFail;
  final bool _loadShouldFail;
  final Map<String, Map<String, dynamic>> _rows = {};

  Map<String, dynamic>? rowFor() => _rows[_userId];

  @override
  Future<Map<String, dynamic>?> load() async {
    if (_loadShouldFail) {
      throw StateError('Remote draft store is unavailable.');
    }
    return _rows[_userId];
  }

  @override
  Future<DateTime?> save({
    required String sourcePlanId,
    required Map<String, dynamic> proposedAvailability,
    required String effectiveWeek,
    required ChangeScheduleDraftStatus status,
    required int revision,
  }) async {
    _rows[_userId] = {
      'source_plan_version_id': sourcePlanId,
      'proposed_availability': proposedAvailability,
      'effective_week': effectiveWeek,
      'status': status.key,
      'revision': revision,
    };
    return DateTime(2026, 7, 13, 17).toUtc();
  }

  @override
  Future<void> discard() async {
    if (_discardShouldFail) {
      throw const FormatException('remote discard failed');
    }
    _rows.remove(_userId);
  }
}

class _ControlledDraftStore extends ChangeScheduleDraftStore {
  _ControlledDraftStore(SharedPreferences preferences)
    : super(preferences: preferences, client: null, userId: null);

  final savedDrafts = <ChangeScheduleDraft>[];
  final revisions = <int>[];
  final _releases = <Completer<void>>[];

  @override
  Future<StoredChangeScheduleDraft?> load() async => null;

  @override
  Future<void> save({
    required ChangeScheduleDraft draft,
    required String sourcePlanId,
    required ChangeScheduleDraftStatus status,
    required int revision,
    required DateTime updatedAt,
  }) {
    savedDrafts.add(draft);
    revisions.add(revision);
    final release = Completer<void>();
    _releases.add(release);
    return release.future;
  }

  void releaseNext() {
    _releases.firstWhere((release) => !release.isCompleted).complete();
  }

  void releaseAll() {
    for (final release in _releases) {
      if (!release.isCompleted) release.complete();
    }
  }
}

Future<ChangeScheduleEditing> _editingState(ProviderContainer container) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    final state = container.read(changeScheduleProvider);
    if (state is ChangeScheduleEditing) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Change Schedule did not initialize.');
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Expected asynchronous work to finish.');
}

ChangeScheduleInitialData _initialData({String activePlanId = 'active-plan'}) =>
    ChangeScheduleInitialData(
      profile: buildRunnerProfile(),
      activePlan: _trainingPlan(activePlanId),
    );

ChangeScheduleAvailability _availability() => ChangeScheduleAvailability(
  days: [
    const ChangeScheduleAvailabilityDay(
      day: 1,
      available: true,
      maxDurationMinutes: 45,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 2,
      available: true,
      maxDurationMinutes: 45,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 3,
      available: false,
      maxDurationMinutes: null,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 4,
      available: true,
      maxDurationMinutes: 45,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 5,
      available: false,
      maxDurationMinutes: null,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 6,
      available: false,
      maxDurationMinutes: null,
    ),
    const ChangeScheduleAvailabilityDay(
      day: 7,
      available: true,
      maxDurationMinutes: 90,
    ),
  ],
  targetRunningDays: 4,
  primaryLongRunWeekday: 7,
  backupLongRunWeekday: 2,
  sameDayRunStrengthPreference:
      ChangeScheduleSameDayPreference.separateSessions,
);

Map<String, dynamic> _planJson({
  required String id,
  List<Map<String, dynamic>> sessions = const [],
}) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': 12,
  'currentWeekNumber': 1,
  'sessions': sessions,
};

TrainingPlan _trainingPlan(
  String id, {
  List<Map<String, dynamic>> sessions = const [],
}) =>
    TrainingPlan.fromJson(_planJson(id: id, sessions: sessions))!;

Map<String, dynamic> _sessionJson({
  required String id,
  required DateTime date,
  required String type,
  int? durationMinutes,
  double? distanceKm,
}) => {
  'schemaVersion': 1,
  'id': id,
  'date': date.toIso8601String(),
  'type': type,
  'status': 'upcoming',
  'weekNumber': 1,
  'durationMinutes': ?durationMinutes,
  'distanceKm': ?distanceKm,
};

ChangeScheduleLifecycleProposal _lifecycleProposal({
  required ChangeScheduleLifecycleProposalStatus status,
  required String id,
  required String sourcePlanId,
  String effectiveFrom = '2026-07-13',
  String expiresAt = '2099-12-31T23:59:59.000Z',
  String? acceptedPlanVersionId,
  String? scheduledPlanVersionId,
}) => ChangeScheduleLifecycleProposal.fromDatabaseRow(
  _lifecycleProposalRow(
    status: status,
    id: id,
    sourcePlanId: sourcePlanId,
    effectiveFrom: effectiveFrom,
    expiresAt: expiresAt,
    acceptedPlanVersionId: acceptedPlanVersionId,
    scheduledPlanVersionId: scheduledPlanVersionId,
  ),
);

Map<String, dynamic> _lifecycleProposalRow({
  required ChangeScheduleLifecycleProposalStatus status,
  required String id,
  required String sourcePlanId,
  String effectiveFrom = '2026-07-13',
  String expiresAt = '2099-12-31T23:59:59.000Z',
  String? acceptedPlanVersionId,
  String? scheduledPlanVersionId,
}) => {
  'id': id,
  'source_plan_version_id': sourcePlanId,
  'status': status.key,
  'proposed_availability': _availability().toJson(),
  'candidate_plan': _planJson(
    id: acceptedPlanVersionId ?? scheduledPlanVersionId ?? sourcePlanId,
  ),
  'impact': {
    'impact': <dynamic>[],
    'warnings': <dynamic>[],
    'goalImpact': <String, dynamic>{},
  },
  'effective_from': effectiveFrom,
  'expires_at': expiresAt,
  'accepted_plan_version_id': acceptedPlanVersionId,
  'scheduled_plan_version_id': scheduledPlanVersionId,
  'prior_active_plan_version_id': 'plan-previous',
  'prior_active_availability_version_id': 'availability-previous',
  'accepted_availability_version_id': 'availability-accepted',
};

ChangeScheduleLifecycleActivation _lifecycleActivation({
  required String proposalId,
  required String sourcePlanId,
  required String effectiveFrom,
  required String queuedPlanVersionId,
}) => ChangeScheduleLifecycleActivation.fromDatabaseRow({
  'id': 'activation-1',
  'source_plan_version_id': sourcePlanId,
  'queued_candidate_plan_version_id': queuedPlanVersionId,
  'availability_version_id': 'availability-scheduled-1',
  'effective_from': effectiveFrom,
  'status': 'scheduled',
  'proposal_id': proposalId,
});

Map<String, dynamic> _previewResponse() => {
  'proposalId': 'proposal-preview-1',
  'sourcePlanVersionId': 'active-plan',
  'effectiveFrom': '2026-07-13',
  'asOfDate': '2026-07-13',
  'expiresAt': '2099-12-31T23:59:59.000Z',
  'candidatePlan': _planJson(id: 'candidate-plan'),
  'impacts': <dynamic>[],
  'warnings': <dynamic>[],
  'goalImpact': {},
  'proposedAvailability': _availability().toJson(),
};

Map<String, dynamic> _acceptedResponse() => {
  'versionId': 'plan-accepted-1',
  'plan': _planJson(id: 'plan-accepted-1'),
  'priorActivePlanVersionId': 'plan-previous',
  'priorActiveAvailabilityVersionId': 'availability-previous',
  'acceptedAvailabilityVersionId': 'availability-accepted',
};

Map<String, dynamic> _malformedAcceptedResponse() => {
  'versionId': 'plan-accepted-1',
  'plan': {'id': 'plan-accepted-1'},
  'priorActivePlanVersionId': 'plan-previous',
  'priorActiveAvailabilityVersionId': 'availability-previous',
  'acceptedAvailabilityVersionId': 'availability-accepted',
};

Map<String, dynamic> _scheduledResponse() => {
  'proposalId': 'proposal-preview-1',
  'activationId': 'activation-1',
  'scheduledPlanVersionId': 'plan-scheduled-1',
  'scheduledAvailabilityVersionId': 'availability-scheduled-1',
  'activationStatus': 'scheduled',
};

Map<String, dynamic> _cancelledResponse() => {
  'proposalId': 'proposal-preview-1',
  'proposalStatus': 'cancelled',
  'activationId': 'activation-1',
  'scheduledPlanVersionId': 'plan-scheduled-1',
};

Map<String, dynamic> _activatedResponse() => {
  'proposalId': 'proposal-preview-1',
  'activationId': 'activation-1',
  'proposalStatus': 'accepted',
  'acceptedPlanVersionId': 'plan-scheduled-1',
  'priorActivePlanVersionId': 'plan-previous',
  'priorActiveAvailabilityVersionId': 'availability-previous',
  'acceptedAvailabilityVersionId': 'availability-accepted',
  'activationStatus': 'activated',
};

Map<String, dynamic> _undoneResponse({String id = 'proposal-preview-1'}) => {
  'proposalId': id,
  'priorPlanVersionId': 'plan-previous',
  'priorAvailabilityVersionId': 'availability-previous',
  // Despite the historical wire names, these identify the accepted artifacts
  // that undo just deactivated/cancelled.
  'restoredPlanVersionId': 'plan-accepted-1',
  'restoredAvailabilityVersionId': 'availability-accepted',
};
