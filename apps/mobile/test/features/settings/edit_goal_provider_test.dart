import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/domain/edit_goal_models.dart';
import 'package:running_app/features/settings/presentation/edit_goal_provider.dart';
import 'package:running_app/features/training_plan/data/plan_version_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/runner_profile_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 13, 16, 45);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test(
    'initializes draft from persisted profile and accepted target',
    () async {
      final container = _container(now: now);
      addTearDown(container.dispose);
      final editing = await _editingState(container);

      expect(editing.draft.race, RunnerGoalRace.halfMarathon);
      expect(editing.draft.hasRaceDate, isTrue);
      expect(editing.draft.raceDate, DateTime(2026, 10, 18));
      expect(editing.draft.targetTime, const Duration(hours: 1, minutes: 55));
      expect(editing.sourcePlanId, 'active-plan');
    },
  );

  test(
    'preview sends exact canonical payload and does not reconcile caches',
    () async {
      final invocations = <_Invocation>[];
      var reconcileCount = 0;
      final container = _container(
        now: now,
        locale: 'es',
        client: (name, {body}) async {
          invocations.add(_Invocation(name, body));
          return FunctionResponse(data: _proposalJson(), status: 200);
        },
        reconciler: (_) async => reconcileCount++,
      );
      addTearDown(container.dispose);
      await _editingState(container);

      expect(await container.read(editGoalProvider.notifier).preview(), isTrue);
      expect(invocations.single.name, 'edit-goal');
      expect(invocations.single.body, {
        'action': 'preview',
        'sourcePlanVersionId': 'active-plan',
        'race': 'race_half_marathon',
        'hasRaceDate': true,
        'raceDate': '2026-10-18',
        'targetTimeSeconds': 6900,
        'localDate': '2026-07-13',
        'locale': 'es',
      });
      expect(reconcileCount, 0);
      expect(container.read(editGoalProvider), isA<EditGoalPreviewReady>());
    },
  );

  test(
    'cancel returns to editing without invoking cache reconciliation',
    () async {
      var reconcileCount = 0;
      final container = _container(
        now: now,
        client: (_, {body}) async =>
            FunctionResponse(data: _proposalJson(), status: 200),
        reconciler: (_) async => reconcileCount++,
      );
      addTearDown(container.dispose);
      await _editingState(container);
      await container.read(editGoalProvider.notifier).preview();

      container.read(editGoalProvider.notifier).cancelPreview();

      final editing = container.read(editGoalProvider) as EditGoalEditing;
      expect(editing.draft.targetTime, const Duration(hours: 1, minutes: 55));
      expect(reconcileCount, 0);
    },
  );

  test('proposal parsing is strict and parses warnings and suggestion', () {
    final proposal = GoalEditProposal.fromJson(_proposalJson());
    expect(proposal.warnings, [
      GoalEditWarning.shortNotice,
      GoalEditWarning.aggressiveTarget,
    ]);
    expect(proposal.suggestedTargetTime, const Duration(seconds: 7100));
    expect(proposal.summary.materiallyChangedUpcomingCount, 2);

    expect(
      () => GoalEditProposal.fromJson({
        ..._proposalJson(),
        'warnings': ['unknown_warning'],
      }),
      throwsFormatException,
    );
    expect(
      () => GoalEditProposal.fromJson({
        ..._proposalJson(),
        'summary': {
          ...(_proposalJson()['summary'] as Map<String, dynamic>),
          'preservedCount': -1,
        },
      }),
      throwsFormatException,
    );
  });

  test(
    'timeout preserves draft and maps to canonical timeout failure',
    () async {
      final container = _container(
        now: now,
        client: (_, {body}) async => throw TimeoutException('network timeout'),
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);

      expect(
        await container.read(editGoalProvider.notifier).preview(),
        isFalse,
      );
      final failure = container.read(editGoalProvider) as EditGoalFailure;
      expect(failure.reason, EditGoalFailureReason.timeout);
      expect(identical(failure.draft, editing.draft), isTrue);
    },
  );

  test('stale and expired backend errors map distinctly', () async {
    final responses = <FunctionResponse>[
      FunctionResponse(data: {'error': 'source_plan_stale'}, status: 409),
      FunctionResponse(data: {'error': 'proposal_expired'}, status: 409),
    ];
    final container = _container(
      now: now,
      client: (_, {body}) async => responses.removeAt(0),
    );
    addTearDown(container.dispose);
    await _editingState(container);

    await container.read(editGoalProvider.notifier).preview();
    expect(
      (container.read(editGoalProvider) as EditGoalFailure).reason,
      EditGoalFailureReason.stale,
    );
    await container.read(editGoalProvider.notifier).preview();
    expect(
      (container.read(editGoalProvider) as EditGoalFailure).reason,
      EditGoalFailureReason.expired,
    );
  });

  test(
    'accept sends proposal id only and reconciles authoritative caches',
    () async {
      final invocations = <_Invocation>[];
      final container = _container(
        now: now,
        preferences: preferences,
        client: (name, {body}) async {
          invocations.add(_Invocation(name, body));
          final action = (body as Map<String, dynamic>)['action'];
          return action == 'preview'
              ? FunctionResponse(data: _proposalJson(), status: 200)
              : FunctionResponse(data: _acceptanceJson(), status: 200);
        },
      );
      addTearDown(container.dispose);
      await _editingState(container);
      await container.read(editGoalProvider.notifier).preview();

      expect(await container.read(editGoalProvider.notifier).apply(), isTrue);
      expect(invocations.last.body, {
        'action': 'accept',
        'proposalId': 'proposal-1',
      });
      final success = container.read(editGoalProvider) as EditGoalSuccess;
      expect(success.acceptance.versionId, 'accepted-plan');
      expect(success.acceptance.plan.id, 'accepted-plan');

      final profileCache = SharedPreferencesRunnerProfileRepository(
        preferences,
      );
      final cachedProfile = profileCache.loadProfile();
      final cachedDraft = profileCache.loadDraft();
      expect(cachedProfile?.goal.race, RunnerGoalRace.tenK);
      expect(cachedProfile?.goal.hasRaceDate, isFalse);
      expect(cachedProfile?.goal.raceDate, isNull);
      expect(cachedDraft?.goal.race, RunnerGoalRace.tenK);
      expect(cachedDraft?.acceptedRaceTarget?.distanceKm, 10.0);
      expect(
        cachedDraft?.acceptedRaceTarget?.primaryTime,
        const Duration(minutes: 46, seconds: 30),
      );

      final cachedPlan = SharedPreferencesPlanVersionRepository(
        preferences,
      ).loadActivePlanSync();
      expect(cachedPlan?.id, 'accepted-plan');
      final rawVersion =
          jsonDecode(preferences.getString('active_plan_version_v1')!)
              as Map<String, dynamic>;
      expect(rawVersion['id'], 'accepted-plan');
      expect(rawVersion['requestedBy'], 'edit_goal');
      expect(rawVersion['isActive'], isTrue);
    },
  );

  test(
    'cache reconciliation failure does not roll back server success',
    () async {
      var acceptCalls = 0;
      final container = _container(
        now: now,
        client: (_, {body}) async {
          final action = (body as Map<String, dynamic>)['action'];
          if (action == 'preview') {
            return FunctionResponse(data: _proposalJson(), status: 200);
          }
          acceptCalls++;
          return FunctionResponse(data: _acceptanceJson(), status: 200);
        },
        reconciler: (_) async => throw StateError('cache unavailable'),
      );
      addTearDown(container.dispose);
      await _editingState(container);
      await container.read(editGoalProvider.notifier).preview();

      expect(await container.read(editGoalProvider.notifier).apply(), isTrue);
      expect(container.read(editGoalProvider), isA<EditGoalSuccess>());
      expect(acceptCalls, 1);
    },
  );

  test('initial load failure can retry into editing state', () async {
    var loadCount = 0;
    final container = _container(
      now: now,
      loader: () async {
        loadCount++;
        if (loadCount == 1) throw StateError('storage unavailable');
        return _initialData();
      },
    );
    addTearDown(container.dispose);

    final failure = await _failureState(container);
    expect(failure.draft, isNull);
    expect(failure.reason, EditGoalFailureReason.parse);

    await container.read(editGoalProvider.notifier).retryInitialization();
    final editing = await _editingState(container);
    expect(editing.sourcePlanId, 'active-plan');
    expect(loadCount, 2);
  });

  test('stale recovery reloads source id and preserves user draft', () async {
    var loadCount = 0;
    final invocations = <Map<String, dynamic>>[];
    final container = _container(
      now: now,
      loader: () async {
        loadCount++;
        return _initialData(
          activePlanId: loadCount == 1 ? 'active-plan' : 'fresh-plan',
        );
      },
      client: (_, {body}) async {
        final payload = body as Map<String, dynamic>;
        invocations.add(payload);
        if (invocations.length == 1) {
          return FunctionResponse(
            data: {'error': 'source_plan_stale'},
            status: 409,
          );
        }
        return FunctionResponse(
          data: _proposalJson(sourcePlanId: 'fresh-plan'),
          status: 200,
        );
      },
    );
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    const target = Duration(minutes: 47, seconds: 30);
    final userDraft = editing.draft.copyWith(
      race: RunnerGoalRace.tenK,
      hasRaceDate: false,
      clearRaceDate: true,
      targetTime: target,
    );
    container.read(editGoalProvider.notifier).updateDraft(userDraft);

    expect(await container.read(editGoalProvider.notifier).preview(), isFalse);
    expect(
      (container.read(editGoalProvider) as EditGoalFailure).reason,
      EditGoalFailureReason.stale,
    );
    expect(
      await container.read(editGoalProvider.notifier).refreshAndPreview(),
      isTrue,
    );

    expect(loadCount, 2);
    expect(invocations.last, {
      'action': 'preview',
      'sourcePlanVersionId': 'fresh-plan',
      'race': 'race_10k',
      'hasRaceDate': false,
      'raceDate': null,
      'targetTimeSeconds': target.inSeconds,
      'localDate': '2026-07-13',
      'locale': 'en',
    });
    final ready = container.read(editGoalProvider) as EditGoalPreviewReady;
    expect(ready.sourcePlanId, 'fresh-plan');
    expect(ready.draft.race, RunnerGoalRace.tenK);
    expect(ready.draft.hasRaceDate, isFalse);
    expect(ready.draft.targetTime, target);
  });

  test('auto-dispose recreates fresh persisted state after success', () async {
    var loadCount = 0;
    final freshProfile = buildRunnerProfile().copyWith(
      goal: const GoalProfile(
        race: RunnerGoalRace.marathon,
        hasRaceDate: false,
      ),
    );
    final container = _container(
      now: now,
      keepProviderAlive: false,
      loader: () async {
        loadCount++;
        return loadCount == 1
            ? _initialData()
            : EditGoalInitialData(
                profile: freshProfile,
                acceptedRaceTarget: const AcceptedRaceTarget(
                  distanceKm: 42.195,
                  primaryTime: Duration(hours: 3, minutes: 30),
                ),
                activePlanId: 'fresh-active-plan',
              );
      },
      client: (_, {body}) async {
        final action = (body as Map<String, dynamic>)['action'];
        return FunctionResponse(
          data: action == 'preview' ? _proposalJson() : _acceptanceJson(),
          status: 200,
        );
      },
      reconciler: (_) async {},
    );
    addTearDown(container.dispose);
    final firstSubscription = container.listen(
      editGoalProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await _editingState(container);
    await container.read(editGoalProvider.notifier).preview();
    await container.read(editGoalProvider.notifier).apply();
    expect(container.read(editGoalProvider), isA<EditGoalSuccess>());

    firstSubscription.close();
    await container.pump();
    expect(container.exists(editGoalProvider), isFalse);

    final reopenedSubscription = container.listen(
      editGoalProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(reopenedSubscription.close);
    final reopened = await _editingState(container);
    expect(reopened.sourcePlanId, 'fresh-active-plan');
    expect(reopened.draft.race, RunnerGoalRace.marathon);
    expect(reopened.draft.targetTime, const Duration(hours: 3, minutes: 30));
    expect(loadCount, 2);
  });

  test(
    'ambiguous accept timeout retries same proposal and reconciles once',
    () async {
      final acceptPayloads = <Object?>[];
      var acceptCount = 0;
      var successCount = 0;
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final action = (body as Map<String, dynamic>)['action'];
          if (action == 'preview') {
            return FunctionResponse(data: _proposalJson(), status: 200);
          }
          acceptCount++;
          acceptPayloads.add(body);
          if (acceptCount == 1) {
            throw TimeoutException('response lost after commit');
          }
          return FunctionResponse(data: _acceptanceJson(), status: 200);
        },
      );
      addTearDown(container.dispose);
      final successSubscription = container.listen(editGoalProvider, (_, next) {
        if (next is EditGoalSuccess) successCount++;
      });
      addTearDown(successSubscription.close);
      await _editingState(container);
      await container.read(editGoalProvider.notifier).preview();

      expect(await container.read(editGoalProvider.notifier).apply(), isFalse);
      final timeout = container.read(editGoalProvider) as EditGoalFailure;
      expect(timeout.reason, EditGoalFailureReason.timeout);
      expect(timeout.proposal?.id, 'proposal-1');
      expect(timeout.draft?.targetTime, const Duration(hours: 1, minutes: 55));

      expect(await container.read(editGoalProvider.notifier).apply(), isTrue);
      expect(acceptPayloads, [
        {'action': 'accept', 'proposalId': 'proposal-1'},
        {'action': 'accept', 'proposalId': 'proposal-1'},
      ]);
      expect(successCount, 1);
      final success = container.read(editGoalProvider) as EditGoalSuccess;
      expect(success.acceptance.versionId, 'accepted-plan');
      final profileCache = SharedPreferencesRunnerProfileRepository(
        preferences,
      );
      expect(profileCache.loadProfile()?.goal.race, RunnerGoalRace.tenK);
      expect(
        profileCache.loadDraft()?.acceptedRaceTarget?.primaryTime,
        const Duration(minutes: 46, seconds: 30),
      );
      expect(
        SharedPreferencesPlanVersionRepository(
          preferences,
        ).loadActivePlanSync()?.id,
        'accepted-plan',
      );
    },
  );
}

ProviderContainer _container({
  required DateTime now,
  String locale = 'en',
  SharedPreferences? preferences,
  EditGoalFunctionClient? client,
  EditGoalCacheReconciler? reconciler,
  EditGoalInitialDataLoader? loader,
  bool keepProviderAlive = true,
}) {
  final profile = buildRunnerProfile();
  final container = ProviderContainer.test(
    overrides: [
      editGoalClockProvider.overrideWithValue(() => now),
      editGoalLocaleCodeProvider.overrideWithValue(locale),
      if (preferences != null)
        sharedPreferencesProvider.overrideWithValue(preferences),
      editGoalInitialDataLoaderProvider.overrideWithValue(
        loader ?? () async => _initialData(profile: profile),
      ),
      editGoalFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async =>
                FunctionResponse(data: _proposalJson(), status: 200),
      ),
      if (reconciler != null)
        editGoalCacheReconcilerProvider.overrideWithValue(reconciler)
      else if (preferences == null)
        editGoalCacheReconcilerProvider.overrideWithValue((_) async {}),
    ],
  );
  if (keepProviderAlive) {
    container.listen(editGoalProvider, (_, _) {}, fireImmediately: true);
  }
  return container;
}

Future<EditGoalEditing> _editingState(ProviderContainer container) async {
  container.read(editGoalProvider);
  for (var attempt = 0; attempt < 20; attempt++) {
    final state = container.read(editGoalProvider);
    if (state is EditGoalEditing) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Edit Goal did not initialize.');
}

Future<EditGoalFailure> _failureState(ProviderContainer container) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final state = container.read(editGoalProvider);
    if (state is EditGoalFailure) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Edit Goal did not fail initialization.');
}

EditGoalInitialData _initialData({
  RunnerProfile? profile,
  String activePlanId = 'active-plan',
}) => EditGoalInitialData(
  profile: profile ?? buildRunnerProfile(),
  acceptedRaceTarget: const AcceptedRaceTarget(
    distanceKm: 21.097,
    primaryTime: Duration(hours: 1, minutes: 55),
  ),
  activePlanId: activePlanId,
);

Map<String, dynamic> _proposalJson({String sourcePlanId = 'active-plan'}) => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': sourcePlanId,
  'expiresAt': '2026-07-13T17:15:00.000Z',
  'currentGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
    'targetTimeSeconds': 6900,
  },
  'proposedGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
    'targetTimeSeconds': 6900,
  },
  'candidatePlan': _planJson('candidate-plan'),
  'summary': {
    'preservedCount': 4,
    'addedUpcomingCount': 3,
    'removedUpcomingCount': 1,
    'materiallyChangedUpcomingCount': 2,
    'totalWeeks': 12,
    'endDate': '2026-10-18',
  },
  'warnings': ['short_notice', 'aggressive_target'],
  'suggestedTargetTimeSeconds': 7100,
};

Map<String, dynamic> _acceptanceJson() {
  final profile = buildRunnerProfile().toJson();
  profile['goal'] = {
    'race': 'race_10k',
    'hasRaceDate': false,
    'raceDate': null,
  };
  profile['acceptedRaceTarget'] = const AcceptedRaceTarget(
    distanceKm: 10,
    primaryTime: Duration(minutes: 46, seconds: 30),
  ).toJson();
  return {
    'versionId': 'accepted-plan',
    'plan': _planJson('accepted-plan'),
    'profile': profile,
  };
}

Map<String, dynamic> _planJson(String id) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': 12,
  'currentWeekNumber': 3,
  'sessions': <Map<String, dynamic>>[],
};

class _Invocation {
  const _Invocation(this.name, this.body);
  final String name;
  final Object? body;
}
