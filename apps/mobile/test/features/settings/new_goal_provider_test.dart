import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/domain/new_goal_models.dart';
import 'package:running_app/features/settings/presentation/new_goal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/runner_profile_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 13, 16, 45);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('draft initializes from profile without editable target time', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final editing = await _editingState(container);

    expect(editing.draft.race, RunnerGoalRace.halfMarathon);
    expect(editing.draft.hasRaceDate, isTrue);
    expect(editing.draft.fitnessResult, isNull);
    expect(editing.sourcePlanId, 'active-plan');
  });

  test('fresh draft clears a profile plan start before today', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      loader: () async => NewGoalInitialData(
        profile: _profileWithPlanStart(DateTime(2026, 7, 12)),
        activePlanId: 'active-plan',
      ),
    );
    addTearDown(container.dispose);

    final editing = await _editingState(container);

    expect(editing.draft.planStartDate, isNull);
  });

  test('restored draft clears a plan start after its race date', () async {
    final store = NewGoalDraftStore(
      preferences: preferences,
      client: null,
      userId: null,
    );
    final invalidDraft = NewGoalDraft(
      race: RunnerGoalRace.tenK,
      hasRaceDate: true,
      raceDate: DateTime(2026, 8, 1),
      planStartDate: DateTime(2026, 8, 2),
      schedule: const NewGoalSchedule(
        trainingDays: 4,
        longRunDay: WeekdayChoice.sunday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      ),
      planPreference: PlanPreferenceChoice.balanced,
      healthChanged: false,
    );
    await store.save(
      draft: invalidDraft,
      sourcePlanId: 'active-plan',
      status: NewGoalDraftStatus.editing.key,
      revision: 3,
      updatedAt: now,
    );
    final container = _container(
      now: now,
      preferences: preferences,
      store: store,
    );
    addTearDown(container.dispose);

    final editing = await _editingState(container);

    expect(editing.draft.planStartDate, isNull);
  });

  test('local drafts are isolated by authenticated account', () async {
    final draft = NewGoalDraft(
      race: RunnerGoalRace.tenK,
      hasRaceDate: true,
      raceDate: DateTime(2026, 10, 18),
      planStartDate: DateTime(2026, 7, 13),
      schedule: const NewGoalSchedule(
        trainingDays: 4,
        longRunDay: WeekdayChoice.sunday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
      ),
      planPreference: PlanPreferenceChoice.performance,
      healthChanged: false,
    );
    final userA = NewGoalDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-a',
    );
    final userB = NewGoalDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-b',
    );

    await userA.save(
      draft: draft,
      sourcePlanId: 'plan-a',
      status: NewGoalDraftStatus.editing.key,
      revision: 1,
      updatedAt: now,
    );

    expect(await userB.load(), isNull);
    expect((await userA.load())?.draft.race, RunnerGoalRace.tenK);
  });

  test('persists draft changes locally for offline resume', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final editing = await _editingState(container);

    container
        .read(newGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(planStartDate: DateTime(2026, 7, 15)),
        );

    final storageKey = NewGoalDraftStore.storageKeyForUser(null);
    await _waitFor(() => preferences.getString(storageKey) != null);
    final stored =
        jsonDecode(preferences.getString(storageKey)!) as Map<String, dynamic>;
    final data = stored['data'] as Map<String, dynamic>;
    expect(data['planStartDate'], '2026-07-15');
  });

  test('serializes rapid local saves in revision order', () async {
    final controlled = _ControlledDraftStore(preferences);
    addTearDown(controlled.releaseAll);
    final container = _container(
      now: now,
      preferences: preferences,
      store: controlled,
    );
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    final notifier = container.read(newGoalProvider.notifier);

    notifier.updateDraft(
      editing.draft.copyWith(planStartDate: DateTime(2026, 7, 14)),
    );
    notifier.updateDraft(
      editing.draft.copyWith(planStartDate: DateTime(2026, 7, 20)),
    );

    await _waitFor(() => controlled.savedDrafts.length == 1);
    expect(controlled.savedDrafts.single.planStartDate, DateTime(2026, 7, 14));
    controlled.releaseNext();
    await _waitFor(() => controlled.savedDrafts.length == 2);
    expect(controlled.savedDrafts.last.planStartDate, DateTime(2026, 7, 20));
    expect(controlled.revisions, [2, 3]);
  });

  test(
    'recommend and preview send locale payload and return proposal',
    () async {
      final calls = <Object?>[];
      final container = _container(
        now: now,
        preferences: preferences,
        locale: 'es',
        client: (_, {body}) async {
          calls.add(body);
          final action = (body! as Map<String, dynamic>)['action'];
          if (action == 'recommend') {
            return FunctionResponse(data: _recommendationJson(), status: 200);
          }
          if (action == 'preview') {
            return FunctionResponse(data: _proposalJson(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);

      container
          .read(newGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(
              planStartDate: DateTime(2026, 7, 20),
              clearHealth: true,
            ),
          );

      expect(
        await container.read(newGoalProvider.notifier).recommend(),
        isTrue,
      );
      expect(calls, hasLength(1));
      expect(calls.single, {
        'action': 'recommend',
        'sourcePlanVersionId': 'active-plan',
        'race': 'race_half_marathon',
        'hasRaceDate': true,
        'raceDate': '2026-10-18',
        'planStartDate': '2026-07-20',
        'schedule': {
          'trainingDays': 4,
          'longRunDay': 'day_sun',
          'weekdayTime': 'time_45_min',
          'weekendTime': 'time_90_min',
          'hardDays': ['day_thu', 'day_tue'],
          'preferredTimeOfDay': 'time_of_day_morning',
          'planStartDate': '2026-07-20',
        },
        'trainingPreferences': {'planPreference': 'plan_balanced'},
        'healthChanged': false,
        'locale': 'es',
        'localDate': '2026-07-13',
      });
      expect(
        container.read(newGoalProvider),
        isA<NewGoalRecommendationReady>(),
      );

      expect(await container.read(newGoalProvider.notifier).preview(), isTrue);
      expect(calls, hasLength(2));
      expect(calls[1], {
        'action': 'preview',
        'sourcePlanVersionId': 'active-plan',
        'race': 'race_half_marathon',
        'hasRaceDate': true,
        'raceDate': '2026-10-18',
        'planStartDate': '2026-07-20',
        'schedule': {
          'trainingDays': 4,
          'longRunDay': 'day_sun',
          'weekdayTime': 'time_45_min',
          'weekendTime': 'time_90_min',
          'hardDays': ['day_thu', 'day_tue'],
          'preferredTimeOfDay': 'time_of_day_morning',
          'planStartDate': '2026-07-20',
        },
        'trainingPreferences': {'planPreference': 'plan_balanced'},
        'healthChanged': false,
        'locale': 'es',
        'localDate': '2026-07-13',
      });
      final ready = container.read(newGoalProvider) as NewGoalProposalReady;
      expect(ready.proposal.id, 'proposal-1');
    },
  );

  test('preview requires recommendation before it runs', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        return FunctionResponse(data: _recommendationJson(), status: 200);
      },
    );
    addTearDown(container.dispose);
    await _editingState(container);

    expect(await container.read(newGoalProvider.notifier).preview(), isFalse);
    final state = container.read(newGoalProvider);
    expect(state, isA<NewGoalFailure>());
    expect((state as NewGoalFailure).reason, NewGoalFailureReason.invalidInput);
  });

  test('health changed flag enforces health payload requirements', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    container
        .read(newGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(
            clearHealth: true,
            healthChanged: true,
            clearFitnessResult: true,
          ),
        );

    expect(await container.read(newGoalProvider.notifier).recommend(), isFalse);
    final failure = container.read(newGoalProvider);
    expect(failure, isA<NewGoalFailure>());
    expect(
      (failure as NewGoalFailure).reason,
      NewGoalFailureReason.invalidInput,
    );
  });

  test('refreshAndPreview keeps draft state while regenerating', () async {
    final calls = <Object?>[];
    final container = _container(
      now: now,
      preferences: preferences,
      locale: 'en',
      client: (_, {body}) async {
        calls.add(body);
        if (body is Map<String, dynamic> && body['action'] == 'recommend') {
          return FunctionResponse(data: _recommendationJson(), status: 200);
        }
        if (body is Map<String, dynamic> && body['action'] == 'preview') {
          return FunctionResponse(data: _proposalJson(), status: 200);
        }
        return FunctionResponse(data: {'error': 'invalid'}, status: 400);
      },
    );
    addTearDown(container.dispose);

    final editing = await _editingState(container);
    container
        .read(newGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(planStartDate: DateTime(2026, 7, 20)),
        );
    expect(
      await container.read(newGoalProvider.notifier).refreshAndPreview(),
      isTrue,
    );
    expect(container.read(newGoalProvider), isA<NewGoalProposalReady>());
    expect(calls, hasLength(2));
    final state = container.read(newGoalProvider) as NewGoalProposalReady;
    expect(state.draft.race, editing.draft.race);
  });

  test(
    'assessment result retains assessment identity for completion persistence',
    () async {
      final container = _container(now: now, preferences: preferences);
      addTearDown(container.dispose);
      await _editingState(container);
      final check = NewGoalFitnessCheck.fromJson(
        _fitnessCheckResponse()['fitnessCheck'],
      );
      await container
          .read(newGoalProvider.notifier)
          .scheduleAssessment(check, DateTime(2026, 7, 16));

      final pending =
          container.read(newGoalProvider) as NewGoalAssessmentPending;
      expect(pending.draft.assessment?.kind, 'five_k_run');
      expect(pending.draft.fitnessResult, isNull);

      container
          .read(newGoalProvider.notifier)
          .useFitnessResult(
            NewGoalFitnessResult(
              source: NewGoalFitnessSource.assessment,
              distanceKm: 5,
              elapsed: const Duration(minutes: 25),
              recordedOn: DateTime(2026, 7, 16),
              hardEffort: true,
            ),
          );

      final editingState = container.read(newGoalProvider) as NewGoalEditing;
      expect(
        editingState.draft.fitnessResult?.source,
        NewGoalFitnessSource.assessment,
      );
      expect(editingState.draft.assessment?.kind, 'five_k_run');

      await _waitFor(
        () =>
            preferences.getString(NewGoalDraftStore.storageKeyForUser(null)) !=
            null,
      );
      final stored = await NewGoalDraftStore(
        preferences: preferences,
        client: null,
        userId: null,
      ).load();
      expect(stored?.draft.assessment?.kind, 'five_k_run');
      expect(
        stored?.draft.fitnessResult?.source,
        NewGoalFitnessSource.assessment,
      );
    },
  );

  test(
    'preview expiration uses injected clock, while apply still uses injected clock too',
    () async {
      final calls = <Object?>[];
      final hostNow = DateTime.now();
      final injectedNow = hostNow.subtract(const Duration(days: 30));
      final proposalExpiresAt = hostNow.subtract(const Duration(days: 1));

      final container = _container(
        now: injectedNow,
        preferences: preferences,
        client: (_, {body}) async {
          calls.add(body);
          final action = (body! as Map<String, dynamic>)['action'];
          if (action == 'recommend') {
            return FunctionResponse(data: _recommendationJson(), status: 200);
          }
          if (action == 'preview') {
            return FunctionResponse(
              data: _proposalJson(
                expiresAt: proposalExpiresAt.toIso8601String(),
              ),
              status: 200,
            );
          }
          if (action == 'accept') {
            return FunctionResponse(data: _acceptanceJson(), status: 200);
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);
      container
          .read(newGoalProvider.notifier)
          .updateDraft(editing.draft.copyWith(planStartDate: injectedNow));

      expect(
        await container.read(newGoalProvider.notifier).recommend(),
        isTrue,
      );
      expect(await container.read(newGoalProvider.notifier).preview(), isTrue);
      expect(container.read(newGoalProvider), isA<NewGoalProposalReady>());
      expect(calls, hasLength(2));
      expect(await container.read(newGoalProvider.notifier).apply(), isTrue);
      expect(container.read(newGoalProvider), isA<NewGoalSuccess>());
    },
  );

  test('apply sends accept action and clears draft storage', () async {
    final calls = <Object?>[];
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        calls.add(body);
        final action = (body! as Map<String, dynamic>)['action'];
        if (action == 'recommend') {
          return FunctionResponse(data: _recommendationJson(), status: 200);
        }
        if (action == 'preview') {
          return FunctionResponse(data: _proposalJson(), status: 200);
        }
        if (action == 'accept') {
          return FunctionResponse(data: _acceptanceJson(), status: 200);
        }
        return FunctionResponse(data: {'error': 'invalid'}, status: 200);
      },
    );
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    container
        .read(newGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(planStartDate: DateTime(2026, 7, 20)),
        );
    await container.read(newGoalProvider.notifier).recommend();
    await container.read(newGoalProvider.notifier).preview();
    await _waitFor(
      () =>
          preferences.getString(NewGoalDraftStore.storageKeyForUser(null)) !=
          null,
    );
    final storedAfterPreview =
        jsonDecode(
              preferences.getString(NewGoalDraftStore.storageKeyForUser(null))!,
            )
            as Map<String, dynamic>;
    expect(storedAfterPreview['status'], 'proposal_ready');

    expect(await container.read(newGoalProvider.notifier).apply(), isTrue);
    expect(calls.last, {'action': 'accept', 'proposalId': 'proposal-1'});
    expect(container.read(newGoalProvider), isA<NewGoalSuccess>());
    expect(
      preferences.getString(NewGoalDraftStore.storageKeyForUser(null)),
      isNull,
    );
  });

  test('apply retries the same proposal after a timeout', () async {
    final acceptedProposalIds = <String>[];
    var acceptAttempts = 0;
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async {
        final payload = body! as Map<String, dynamic>;
        switch (payload['action']) {
          case 'recommend':
            return FunctionResponse(data: _recommendationJson(), status: 200);
          case 'preview':
            return FunctionResponse(data: _proposalJson(), status: 200);
          case 'accept':
            acceptedProposalIds.add(payload['proposalId']! as String);
            acceptAttempts += 1;
            if (acceptAttempts == 1) {
              throw TimeoutException('accept response was lost');
            }
            return FunctionResponse(data: _acceptanceJson(), status: 200);
        }
        return FunctionResponse(data: {'error': 'invalid'}, status: 400);
      },
    );
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    container
        .read(newGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(planStartDate: DateTime(2026, 7, 20)),
        );
    final notifier = container.read(newGoalProvider.notifier);
    expect(await notifier.recommend(), isTrue);
    expect(await notifier.preview(), isTrue);

    expect(await notifier.apply(), isFalse);
    final failure = container.read(newGoalProvider) as NewGoalFailure;
    expect(failure.reason, NewGoalFailureReason.timeout);
    expect(failure.proposal?.id, 'proposal-1');

    expect(await notifier.apply(), isTrue);
    expect(container.read(newGoalProvider), isA<NewGoalSuccess>());
    expect(acceptedProposalIds, ['proposal-1', 'proposal-1']);
  });

  test('recommend rejects plan starts outside the valid goal window', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    final notifier = container.read(newGoalProvider.notifier);

    notifier.updateDraft(
      editing.draft.copyWith(planStartDate: DateTime(2026, 7, 12)),
    );
    expect(await notifier.recommend(), isFalse);
    expect(
      (container.read(newGoalProvider) as NewGoalFailure).reason,
      NewGoalFailureReason.invalidInput,
    );

    notifier.updateDraft(
      editing.draft.copyWith(planStartDate: DateTime(2026, 10, 19)),
    );
    expect(await notifier.recommend(), isFalse);
    expect(
      (container.read(newGoalProvider) as NewGoalFailure).reason,
      NewGoalFailureReason.invalidInput,
    );
  });

  test(
    'apply returns stale state when source profile has become stale',
    () async {
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final action = (body! as Map<String, dynamic>)['action'];
          if (action == 'recommend') {
            return FunctionResponse(data: _recommendationJson(), status: 200);
          }
          if (action == 'preview') {
            return FunctionResponse(data: _proposalJson(), status: 200);
          }
          if (action == 'accept') {
            return FunctionResponse(
              data: {'error': 'source_profile_stale'},
              status: 409,
            );
          }
          return FunctionResponse(data: {'error': 'invalid'}, status: 400);
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);

      container
          .read(newGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(planStartDate: DateTime(2026, 7, 20)),
          );

      expect(
        await container.read(newGoalProvider.notifier).recommend(),
        isTrue,
      );
      expect(await container.read(newGoalProvider.notifier).preview(), isTrue);
      expect(container.read(newGoalProvider), isA<NewGoalProposalReady>());

      expect(await container.read(newGoalProvider.notifier).apply(), isFalse);
      final state = container.read(newGoalProvider);
      expect(state, isA<NewGoalFailure>());
      expect((state as NewGoalFailure).reason, NewGoalFailureReason.stale);
      expect((state).draft, isNotNull);
      expect((state).proposal, isNotNull);
    },
  );
}

ProviderContainer _container({
  required DateTime now,
  required SharedPreferences preferences,
  String locale = 'en',
  NewGoalFunctionClient? client,
  NewGoalInitialDataLoader? loader,
  NewGoalDraftStore? store,
  NewGoalCacheReconciler? cacheReconciler,
}) {
  final container = ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      newGoalClockProvider.overrideWithValue(() => now),
      newGoalLocaleCodeProvider.overrideWithValue(locale),
      newGoalInitialDataLoaderProvider.overrideWithValue(
        loader ?? () async => _initialData(),
      ),
      newGoalFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async =>
                FunctionResponse(data: _proposalJson(), status: 200),
      ),
      newGoalCacheReconcilerProvider.overrideWithValue(
        cacheReconciler ?? ((_) async {}),
      ),
      if (store != null) newGoalDraftStoreProvider.overrideWithValue(store),
    ],
  );
  container.listen(newGoalProvider, (_, _) {}, fireImmediately: true);
  return container;
}

class _ControlledDraftStore extends NewGoalDraftStore {
  _ControlledDraftStore(SharedPreferences preferences)
    : super(preferences: preferences, client: null, userId: null);

  final savedDrafts = <NewGoalDraft>[];
  final revisions = <int>[];
  final _releases = <Completer<void>>[];

  @override
  Future<StoredNewGoalDraft?> load() async => null;

  @override
  Future<void> save({
    required NewGoalDraft draft,
    required String sourcePlanId,
    required String status,
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

Future<NewGoalEditing> _editingState(ProviderContainer container) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final state = container.read(newGoalProvider);
    if (state is NewGoalEditing) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('New Goal did not initialize.');
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Expected asynchronous work to finish.');
}

NewGoalInitialData _initialData({String activePlanId = 'active-plan'}) =>
    NewGoalInitialData(
      profile: buildRunnerProfile(),
      activePlanId: activePlanId,
    );

RunnerProfile _profileWithPlanStart(DateTime planStartDate) {
  final profile = buildRunnerProfile();
  return profile.copyWith(
    schedule: ScheduleProfile(
      trainingDays: profile.schedule.trainingDays,
      longRunDay: profile.schedule.longRunDay,
      weekdayTime: profile.schedule.weekdayTime,
      weekendTime: profile.schedule.weekendTime,
      hardDays: profile.schedule.hardDays,
      preferredTimeOfDay: profile.schedule.preferredTimeOfDay,
      planStartDate: planStartDate,
    ),
  );
}

Map<String, dynamic> _fitnessCheckResponse() => {
  'state': 'fitness_check_required',
  'sourcePlanVersionId': 'active-plan',
  'fitnessCheck': {
    'suggestedActivities': <dynamic>[],
    'benchmark': {
      'kind': 'five_k_run',
      'safeDates': ['2026-07-16'],
    },
  },
};

Map<String, dynamic> _proposalJson({
  String sourcePlanId = 'active-plan',
  String? expiresAt,
}) => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': sourcePlanId,
  'expiresAt': expiresAt ?? '2099-12-31T23:59:59.000Z',
  'sourceGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'proposedGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'candidatePlan': _planJson('candidate-plan'),
  'warnings': ['short_notice'],
  'recommendation': {
    'mode': 'long_term',
    'startDate': '2026-07-23',
    'endDate': '2026-10-15',
    'weeks': 12,
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
    'daysToRace': 87,
  },
  'raceEstimate': {
    'centerTimeSeconds': 3600,
    'fasterTimeSeconds': 3500,
    'slowerTimeSeconds': 3900,
    'confidence': 'high',
    'evidence': [
      {
        'source': 'race_estimator',
        'recordedOn': '2026-07-20',
        'reason': 'model_derived',
      },
    ],
  },
};

Map<String, dynamic> _recommendationJson() => {
  'sourceGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'proposedGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'recommendation': {
    'mode': 'long_term',
    'startDate': '2026-07-23',
    'endDate': '2026-10-15',
    'weeks': 12,
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
    'daysToRace': 87,
  },
  'raceEstimate': {
    'centerTimeSeconds': 3600,
    'fasterTimeSeconds': 3500,
    'slowerTimeSeconds': 3900,
    'confidence': 'high',
    'evidence': [
      {
        'source': 'race_estimator',
        'recordedOn': '2026-07-20',
        'reason': 'model_derived',
      },
    ],
  },
};

Map<String, dynamic> _acceptanceJson() => {
  'versionId': 'accepted-plan',
  'plan': _planJson('accepted-plan'),
  'profile': buildRunnerProfile().toJson(),
};

Map<String, dynamic> _planJson(String id) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': 12,
  'currentWeekNumber': 3,
  'sessions': <Map<String, dynamic>>[],
};
