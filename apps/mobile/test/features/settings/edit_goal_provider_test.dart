import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/domain/edit_goal_models.dart';
import 'package:running_app/features/settings/presentation/edit_goal_provider.dart';
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

  test('draft serializes only canonical choices and fitness evidence', () {
    final draft = EditGoalDraft(
      originalGoal: GoalEditGoal(
        race: RunnerGoalRace.tenK,
        hasRaceDate: false,
        raceDate: null,
      ),
      race: RunnerGoalRace.tenK,
      hasRaceDate: false,
      raceDate: null,
      changes: const {EditGoalChange.distance, EditGoalChange.raceDate},
      fitnessResult: EditGoalFitnessResult(
        source: EditGoalFitnessSource.manual,
        distanceKm: 5,
        elapsed: const Duration(minutes: 24, seconds: 30),
        recordedOn: DateTime(2026, 7, 10),
        hardEffort: true,
      ),
    );

    expect(EditGoalDraft.fromJson(draft.toJson()).race, RunnerGoalRace.tenK);
    expect(
      draft.previewPayload(
        sourcePlanVersionId: 'plan-1',
        localDate: now,
        locale: 'es',
      ),
      {
        'action': 'preview',
        'sourcePlanVersionId': 'plan-1',
        'race': 'race_10k',
        'hasRaceDate': false,
        'raceDate': null,
        'fitnessResult': {
          'source': 'manual',
          'distanceKm': 5,
          'elapsedSeconds': 1470,
          'recordedOn': '2026-07-10',
          'hardEffort': true,
        },
        'localDate': '2026-07-13',
        'locale': 'es',
      },
    );
    expect(draft.toJson().containsKey('targetTime'), isFalse);
  });

  test('local drafts are isolated by authenticated account', () async {
    final draft = EditGoalDraft(
      originalGoal: GoalEditGoal(
        race: RunnerGoalRace.tenK,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
      ),
      race: RunnerGoalRace.tenK,
      hasRaceDate: true,
      raceDate: DateTime(2026, 10, 18),
      changes: const {EditGoalChange.distance},
    );
    final userAStore = EditGoalDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-a',
    );
    final userBStore = EditGoalDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-b',
    );

    await userAStore.save(
      draft: draft,
      sourcePlanId: 'user-a-plan',
      status: 'editing',
      revision: 1,
      updatedAt: now,
    );

    expect(await userBStore.load(), isNull);
    expect((await userAStore.load())?.draft.race, RunnerGoalRace.tenK);
  });

  test(
    'initializes an unselected edit draft without an editable target time',
    () async {
      final container = _container(now: now, preferences: preferences);
      addTearDown(container.dispose);

      final editing = await _editingState(container);

      expect(editing.draft.race, RunnerGoalRace.halfMarathon);
      expect(editing.draft.changes, isEmpty);
      expect(editing.sourcePlanId, 'active-plan');
    },
  );

  test('persists draft choices locally for offline resume', () async {
    final container = _container(now: now, preferences: preferences);
    addTearDown(container.dispose);
    final editing = await _editingState(container);

    container
        .read(editGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(
            race: RunnerGoalRace.tenK,
            changes: const {EditGoalChange.distance},
          ),
        );

    final storageKey = EditGoalDraftStore.storageKeyForUser(null);
    await _waitFor(() => preferences.getString(storageKey) != null);
    final stored =
        jsonDecode(preferences.getString(storageKey)!) as Map<String, dynamic>;
    final data = stored['data'] as Map<String, dynamic>;
    expect(data['race'], 'race_10k');
    expect(data['changes'], ['distance']);
  });

  test(
    'preview sends no target time and parses a server-derived range',
    () async {
      Object? capturedBody;
      final container = _container(
        now: now,
        preferences: preferences,
        locale: 'es',
        client: (_, {body}) async {
          capturedBody = body;
          return FunctionResponse(data: _proposalJson(), status: 200);
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);
      container
          .read(editGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(changes: const {EditGoalChange.raceDate}),
          );

      expect(await container.read(editGoalProvider.notifier).preview(), isTrue);
      expect(capturedBody, {
        'action': 'preview',
        'sourcePlanVersionId': 'active-plan',
        'race': 'race_half_marathon',
        'hasRaceDate': true,
        'raceDate': '2026-10-18',
        'localDate': '2026-07-13',
        'locale': 'es',
      });
      final ready = container.read(editGoalProvider) as EditGoalPreviewReady;
      expect(
        ready.proposal.raceEstimate.centerTime,
        const Duration(hours: 1, minutes: 55),
      );
      expect(ready.proposal.raceEstimate.confidence, 'high');
    },
  );

  test('requires a fitness check instead of inventing an estimate', () async {
    final container = _container(
      now: now,
      preferences: preferences,
      client: (_, {body}) async =>
          FunctionResponse(data: _fitnessCheckResponse(), status: 200),
    );
    addTearDown(container.dispose);
    final editing = await _editingState(container);
    container
        .read(editGoalProvider.notifier)
        .updateDraft(
          editing.draft.copyWith(
            changes: const {EditGoalChange.distance},
            race: RunnerGoalRace.tenK,
          ),
        );

    expect(await container.read(editGoalProvider.notifier).preview(), isFalse);
    final check =
        container.read(editGoalProvider) as EditGoalFitnessCheckRequired;
    expect(check.fitnessCheck.benchmarkKind, 'five_k_run');
    expect(check.fitnessCheck.safeDates, [DateTime(2026, 7, 16)]);
  });

  test(
    'scheduling an assessment leaves the plan unchanged until a result',
    () async {
      final container = _container(now: now, preferences: preferences);
      addTearDown(container.dispose);
      final editing = await _editingState(container);
      final check = GoalEditFitnessCheck.fromJson(
        _fitnessCheckResponse()['fitnessCheck'],
      );
      container
          .read(editGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(changes: const {EditGoalChange.distance}),
          );

      await container
          .read(editGoalProvider.notifier)
          .scheduleAssessment(check, DateTime(2026, 7, 16));
      final pending =
          container.read(editGoalProvider) as EditGoalAssessmentPending;
      expect(pending.draft.assessment?.kind, 'five_k_run');
      expect(pending.draft.fitnessResult, isNull);

      container
          .read(editGoalProvider.notifier)
          .useFitnessResult(
            EditGoalFitnessResult(
              source: EditGoalFitnessSource.assessment,
              distanceKm: 5,
              elapsed: const Duration(minutes: 25),
              recordedOn: DateTime(2026, 7, 16),
              hardEffort: true,
            ),
          );
      final updated = container.read(editGoalProvider) as EditGoalEditing;
      expect(
        updated.draft.fitnessResult?.source,
        EditGoalFitnessSource.assessment,
      );
    },
  );

  test(
    'stale preview rebuilds with the latest plan and retains selections',
    () async {
      var loads = 0;
      final bodies = <Map<String, dynamic>>[];
      final container = _container(
        now: now,
        preferences: preferences,
        loader: () async => _initialData(
          activePlanId: ++loads == 1 ? 'active-plan' : 'fresh-plan',
        ),
        client: (_, {body}) async {
          bodies.add(body! as Map<String, dynamic>);
          if (bodies.length == 1) {
            return FunctionResponse(
              data: const {'error': 'source_plan_stale'},
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
      container
          .read(editGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(
              race: RunnerGoalRace.tenK,
              changes: const {EditGoalChange.distance},
            ),
          );

      expect(
        await container.read(editGoalProvider.notifier).preview(),
        isFalse,
      );
      expect(
        await container.read(editGoalProvider.notifier).refreshAndPreview(),
        isTrue,
      );
      final ready = container.read(editGoalProvider) as EditGoalPreviewReady;
      expect(ready.sourcePlanId, 'fresh-plan');
      expect(ready.draft.race, RunnerGoalRace.tenK);
      expect(ready.draft.changes, const {EditGoalChange.distance});
      expect(bodies.last['sourcePlanVersionId'], 'fresh-plan');
    },
  );

  test(
    'apply uses only the proposal id, clears the draft, and exposes recap data',
    () async {
      final calls = <Object?>[];
      final container = _container(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          calls.add(body);
          return FunctionResponse(
            data: (body! as Map<String, dynamic>)['action'] == 'accept'
                ? _acceptanceJson()
                : _proposalJson(),
            status: 200,
          );
        },
      );
      addTearDown(container.dispose);
      final editing = await _editingState(container);
      container
          .read(editGoalProvider.notifier)
          .updateDraft(
            editing.draft.copyWith(changes: const {EditGoalChange.raceDate}),
          );
      await container.read(editGoalProvider.notifier).preview();

      expect(await container.read(editGoalProvider.notifier).apply(), isTrue);
      expect(calls.last, {'action': 'accept', 'proposalId': 'proposal-1'});
      final success = container.read(editGoalProvider) as EditGoalSuccess;
      expect(success.proposal.summary.preservedCount, 4);
      expect(
        preferences.getString(EditGoalDraftStore.storageKeyForUser(null)),
        isNull,
      );
    },
  );
}

ProviderContainer _container({
  required DateTime now,
  required SharedPreferences preferences,
  String locale = 'en',
  EditGoalFunctionClient? client,
  EditGoalInitialDataLoader? loader,
}) {
  final container = ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      editGoalClockProvider.overrideWithValue(() => now),
      editGoalLocaleCodeProvider.overrideWithValue(locale),
      editGoalInitialDataLoaderProvider.overrideWithValue(
        loader ?? () async => _initialData(),
      ),
      editGoalFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async =>
                FunctionResponse(data: _proposalJson(), status: 200),
      ),
      editGoalCacheReconcilerProvider.overrideWithValue((_) async {}),
    ],
  );
  container.listen(editGoalProvider, (_, _) {}, fireImmediately: true);
  return container;
}

Future<EditGoalEditing> _editingState(ProviderContainer container) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final state = container.read(editGoalProvider);
    if (state is EditGoalEditing) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Edit Goal did not initialize.');
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Expected asynchronous work to finish.');
}

EditGoalInitialData _initialData({String activePlanId = 'active-plan'}) =>
    EditGoalInitialData(
      profile: buildRunnerProfile(),
      activePlanId: activePlanId,
    );

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

Map<String, dynamic> _proposalJson({String sourcePlanId = 'active-plan'}) => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': sourcePlanId,
  'expiresAt': '2026-07-13T17:15:00.000Z',
  'currentGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'proposedGoal': {
    'race': 'race_half_marathon',
    'hasRaceDate': true,
    'raceDate': '2026-10-18',
  },
  'raceEstimate': {
    'centerTimeSeconds': 6900,
    'fasterTimeSeconds': 6720,
    'slowerTimeSeconds': 7080,
    'confidence': 'high',
    'evidence': [
      {
        'source': 'manual',
        'recordedOn': '2026-07-10',
        'description': 'Recent hard running result',
      },
    ],
  },
  'candidatePlan': _planJson('candidate-plan'),
  'summary': {
    'preservedCount': 4,
    'addedUpcomingCount': 0,
    'removedUpcomingCount': 0,
    'materiallyChangedUpcomingCount': 0,
    'totalWeeks': 12,
    'endDate': '2026-10-18',
  },
  'warnings': ['short_notice'],
};

Map<String, dynamic> _acceptanceJson() {
  final profile = buildRunnerProfile().toJson();
  profile['acceptedRaceTarget'] = const AcceptedRaceTarget(
    distanceKm: 21.097,
    primaryTime: Duration(hours: 1, minutes: 55),
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
