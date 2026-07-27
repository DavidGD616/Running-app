import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/settings/domain/change_schedule_models.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/runner_profile_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 13, 9, 0);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('infers a valid legacy draft from profile + active plan', () {
    final profile = buildRunnerProfile();
    final activePlan = TrainingPlan.fromJson(
      _planJson(
        id: 'plan-legacy',
        sessions: [
          _sessionJson(
            id: 'run-1',
            date: DateTime(2026, 7, 14),
            type: 'easyRun',
          ),
          _sessionJson(
            id: 'run-2',
            date: DateTime(2026, 7, 16),
            type: 'tempoRun',
          ),
          _sessionJson(
            id: 'run-3',
            date: DateTime(2026, 7, 13),
            type: 'easyRun',
          ),
        ],
      ),
    )!;

    final draft = ChangeScheduleDraft.inferFromLegacyProfileAndActivePlan(
      profile: profile,
      activePlan: activePlan,
      clock: now,
    );

    expect(draft.isValid, isTrue);
    expect(draft.availability.primaryLongRunWeekday, 7);
    expect(draft.availability.targetRunningDays, 4);
    expect(draft.availability.availableDays, containsAll([1, 2, 4, 7]));
    expect(draft.availability.availableDays.length, 4);
    final firstDay = draft.availability.days.firstWhere((day) => day.day == 1);
    final sunday = draft.availability.days.firstWhere((day) => day.day == 7);
    expect(firstDay.maxDurationMinutes, 45);
    expect(sunday.maxDurationMinutes, 90);
  });

  test('derives a canonical Monday-to-Sunday comparison for both plans', () {
    final sourcePlan = TrainingPlan.fromJson(
      _planJson(
        id: 'source-plan',
        sessions: [
          _sessionJson(
            id: 'source-easy',
            date: DateTime(2026, 7, 13, 8),
            type: 'easyRun',
            description: 'canonical source summary',
            durationMinutes: 35,
            distanceKm: 5.5,
          ),
          _sessionJson(
            id: 'source-rest',
            date: DateTime(2026, 7, 15),
            type: 'restDay',
          ),
          _sessionJson(
            id: 'source-long',
            date: DateTime(2026, 7, 19),
            type: 'longRun',
            durationMinutes: 105,
            distanceKm: 16,
          ),
        ],
      ),
    )!;
    final candidatePlan = TrainingPlan.fromJson(
      _planJson(
        id: 'candidate-plan',
        sessions: [
          _sessionJson(
            id: 'candidate-intervals',
            date: DateTime(2026, 7, 14),
            type: 'intervals',
            durationMinutes: 45,
          ),
          _sessionJson(
            id: 'candidate-long',
            date: DateTime(2026, 7, 18),
            type: 'longRun',
            distanceKm: 18,
          ),
        ],
      ),
    )!;

    final comparison = ChangeScheduleWeekComparison.fromPlans(
      sourcePlan: sourcePlan,
      candidatePlan: candidatePlan,
      weekStart: DateTime(2026, 7, 13, 23, 45),
    );

    expect(comparison.weekStart, DateTime(2026, 7, 13));
    expect(comparison.currentWeek, hasLength(7));
    expect(comparison.updatedWeek, hasLength(7));
    expect(comparison.currentWeek.map((day) => day.weekday), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(comparison.currentWeek.first.date, DateTime(2026, 7, 13));
    expect(comparison.currentWeek.last.date, DateTime(2026, 7, 19));

    final currentMonday = comparison.currentWeek[0].primarySession!;
    expect(currentMonday.id, 'source-easy');
    expect(currentMonday.type.name, 'easyRun');
    expect(currentMonday.summary, 'canonical source summary');
    expect(currentMonday.durationMinutes, 35);
    expect(currentMonday.distanceKm, 5.5);
    expect(comparison.currentWeek[2].isExplicitRestDay, isTrue);
    expect(comparison.currentWeek[3].hasNoSession, isTrue);
    expect(comparison.currentWeek[6].hasLongRun, isTrue);
    expect(comparison.currentWeek[6].primarySession?.isLongRun, isTrue);

    expect(comparison.updatedWeek[1].primarySession?.id, 'candidate-intervals');
    expect(comparison.updatedWeek[5].hasLongRun, isTrue);
    expect(comparison.updatedWeek[0].hasNoSession, isTrue);
  });

  test('rejects a comparison that is not anchored to a Monday', () {
    final plan = TrainingPlan.fromJson(_planJson(id: 'plan'))!;

    expect(
      () => ChangeScheduleWeekComparison.fromPlans(
        sourcePlan: plan,
        candidatePlan: plan,
        weekStart: DateTime(2026, 7, 14),
      ),
      throwsFormatException,
    );
  });

  test('preserves every session scheduled on the same comparison day', () {
    final sourcePlan = TrainingPlan.fromJson(
      _planJson(
        id: 'source-plan',
        sessions: [
          _sessionJson(
            id: 'easy-session',
            date: DateTime(2026, 7, 14, 7),
            type: 'easyRun',
            durationMinutes: 35,
            distanceKm: 5,
          ),
          _sessionJson(
            id: 'long-session',
            date: DateTime(2026, 7, 14, 18),
            type: 'longRun',
            durationMinutes: 60,
            distanceKm: 16,
          ),
        ],
      ),
    )!;
    final candidatePlan = TrainingPlan.fromJson(
      _planJson(id: 'candidate-plan'),
    )!;

    final comparison = ChangeScheduleWeekComparison.fromPlans(
      sourcePlan: sourcePlan,
      candidatePlan: candidatePlan,
      weekStart: DateTime(2026, 7, 13),
    );

    final tuesdaySessions = comparison.currentWeek[1].sessions;
    expect(tuesdaySessions, hasLength(2));
    expect(tuesdaySessions.map((session) => session.id), [
      'easy-session',
      'long-session',
    ]);
    expect(tuesdaySessions[0].durationMinutes, 35);
    expect(tuesdaySessions[0].distanceKm, 5);
    expect(tuesdaySessions[1].isLongRun, isTrue);
    expect(tuesdaySessions[1].durationMinutes, 60);
    expect(tuesdaySessions[1].distanceKm, 16);
  });

  test(
    'proposal payload uses effective week and stable serialized structure',
    () {
      final availability = _availability();
      final draft = ChangeScheduleDraft(
        availability: availability,
        effectiveWeek: ChangeScheduleEffectiveWeek.current,
      );
      final nextDraft = draft.copyWith(
        effectiveWeek: ChangeScheduleEffectiveWeek.next,
      );

      expect(
        draft.previewPayload(
          DateTime(2026, 7, 13, 12),
          DateTime(2026, 7, 13, 12),
        ),
        {
          'action': 'preview',
          'availability': availability.toJson(),
          'effectiveFrom': '2026-07-13',
          'localDate': '2026-07-13',
        },
      );
      expect(
        nextDraft.previewPayload(
          DateTime(2026, 7, 13, 12),
          DateTime(2026, 7, 13, 12),
        )['effectiveFrom'],
        '2026-07-20',
      );
    },
  );

  test('draft JSON is symmetric and stores the effective week safely', () {
    final draft = ChangeScheduleDraft(
      availability: _availability(),
      effectiveWeek: ChangeScheduleEffectiveWeek.next,
    );

    final raw = draft.toJson();
    final restored = ChangeScheduleDraft.fromJson(raw);

    expect(restored.effectiveWeek, ChangeScheduleEffectiveWeek.next);
    expect(restored.availability.primaryLongRunWeekday, 7);
    expect(restored.availability.targetRunningDays, 4);
    expect(restored.availability.days.length, 7);
  });

  test('stored draft parsing enforces canonical fields', () {
    final storedRaw = {
      'data': {
        'availability': _availability().toJson(),
        'effectiveWeek': 'current',
      },
      'sourcePlanVersionId': 'plan-legacy',
      'status': 'editing',
      'revision': 4,
      'updatedAt': '2026-07-13T09:00:00.000Z',
    };

    final parsed = StoredChangeScheduleDraft.fromJson(storedRaw);
    expect(parsed.sourcePlanId, 'plan-legacy');
    expect(parsed.status, ChangeScheduleDraftStatus.editing);
    expect(parsed.revision, 4);
    expect(parsed.draft.availability.primaryLongRunWeekday, 7);
    expect(parsed.toJson()['status'], ChangeScheduleDraftStatus.editing.key);

    final malformed = {
      'availability': _availability().toJson(),
      'effectiveWeek': 'current',
    };
    expect(
      () => StoredChangeScheduleDraft.fromJson(malformed),
      throwsFormatException,
    );

    expect(
      () => StoredChangeScheduleDraft.fromJson({
        ...storedRaw,
        'status': 'unknown_status',
      }),
      throwsFormatException,
    );
  });

  test(
    'change schedule remote drafts persist and reload canonical draft payload',
    () async {
      final remoteUpdatedAt = now.add(const Duration(minutes: 5)).toUtc();
      final remote = _InMemoryChangeScheduleDraftRemoteStore(
        userId: 'user-2',
        serverUpdatedAt: remoteUpdatedAt,
      );
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: 'user-2',
        remoteStore: remote,
      );
      final draft = ChangeScheduleDraft(
        availability: _availability(),
        effectiveWeek: ChangeScheduleEffectiveWeek.next,
      );
      final sourcePlanId = 'active-plan';
      final updatedAt = now.toUtc();

      await store.save(
        draft: draft,
        sourcePlanId: sourcePlanId,
        status: ChangeScheduleDraftStatus.assessmentPending,
        revision: 9,
        updatedAt: updatedAt,
      );

      final row = remote.rowFor();
      expect(row, isNotNull);
      expect(
        row!['proposed_availability'],
        equals(draft.availability.toJson()),
      );
      expect(row['effective_week'], equals(draft.effectiveWeek.key));
      expect(row['updated_at'], equals(remoteUpdatedAt.toIso8601String()));
      expect(row['source_plan_version_id'], sourcePlanId);
      expect(row['status'], ChangeScheduleDraftStatus.assessmentPending.key);

      await preferences.remove(
        ChangeScheduleDraftStore.storageKeyForUser('user-2'),
      );
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.draft.availability.primaryLongRunWeekday, 7);
      expect(loaded.draft.effectiveWeek, ChangeScheduleEffectiveWeek.next);
      expect(loaded.updatedAt, equals(remoteUpdatedAt));
      expect(loaded.revision, 9);
      expect(loaded.status, ChangeScheduleDraftStatus.assessmentPending);
    },
  );

  test('remote draft always wins over newer local draft cache', () async {
    final remote = _InMemoryChangeScheduleDraftRemoteStore(userId: 'user-3');
    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-3',
      remoteStore: remote,
    );
    final localDraft = ChangeScheduleDraft(
      availability: _availability(),
      effectiveWeek: ChangeScheduleEffectiveWeek.next,
    );
    final remoteDraft = ChangeScheduleDraft(
      availability: _availability().copyWith(primaryLongRunWeekday: 1),
      effectiveWeek: ChangeScheduleEffectiveWeek.current,
    );
    final localSourcePlanId = 'local-plan';
    final remoteSourcePlanId = 'remote-plan';

    await preferences.setString(
      ChangeScheduleDraftStore.storageKeyForUser('user-3'),
      jsonEncode(
        StoredChangeScheduleDraft(
          draft: localDraft,
          sourcePlanId: localSourcePlanId,
          status: ChangeScheduleDraftStatus.editing,
          revision: 3,
          updatedAt: DateTime(2026, 7, 13, 10).toUtc(),
        ).toJson(),
      ),
    );

    await remote.save(
      sourcePlanId: remoteSourcePlanId,
      proposedAvailability: remoteDraft.availability.toJson(),
      effectiveWeek: remoteDraft.effectiveWeek.key,
      status: ChangeScheduleDraftStatus.assessmentPending,
      revision: 2,
      updatedAt: DateTime(2026, 7, 13, 9).toUtc(),
    );

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.sourcePlanId, remoteSourcePlanId);
    expect(loaded.draft.effectiveWeek, remoteDraft.effectiveWeek);
    expect(loaded.draft.availability.primaryLongRunWeekday, 1);
    expect(loaded.revision, 2);
    expect(loaded.status, ChangeScheduleDraftStatus.assessmentPending);
    expect(loaded.updatedAt, equals(DateTime(2026, 7, 13, 9).toUtc()));
  });

  test(
    'remote draft absence is authoritative and clears local cache',
    () async {
      final localDraft = StoredChangeScheduleDraft(
        draft: ChangeScheduleDraft(
          availability: _availability(),
          effectiveWeek: ChangeScheduleEffectiveWeek.next,
        ),
        sourcePlanId: 'local-plan',
        status: ChangeScheduleDraftStatus.assessmentPending,
        revision: 1,
        updatedAt: DateTime(2026, 7, 13, 9).toUtc(),
      );
      final storageKey = ChangeScheduleDraftStore.storageKeyForUser('user-5');
      await preferences.setString(storageKey, jsonEncode(localDraft.toJson()));

      final remote = _InMemoryChangeScheduleDraftRemoteStore(userId: 'user-5');
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: 'user-5',
        remoteStore: remote,
      );

      final loaded = await store.load();

      expect(loaded, isNull);
      expect(preferences.getString(storageKey), isNull);
    },
  );

  test('local legacy draft may omit effective week', () async {
    const userId = 'local-legacy-user';
    final storageKey = ChangeScheduleDraftStore.storageKeyForUser(userId);
    await preferences.setString(
      storageKey,
      jsonEncode({
        'data': {'availability': _availability().toJson()},
        'sourcePlanVersionId': 'legacy-plan',
        'status': ChangeScheduleDraftStatus.editing.key,
        'revision': 1,
        'updatedAt': now.toUtc().toIso8601String(),
      }),
    );

    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: userId,
    );

    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.draft.effectiveWeek, ChangeScheduleEffectiveWeek.current);
  });

  test(
    'remote drafts reject missing and invalid effective week values',
    () async {
      for (final effectiveWeek in <Object?>[null, 'tomorrow']) {
        final row = <String, dynamic>{
          'source_plan_version_id': 'remote-plan',
          'proposed_availability': _availability().toJson(),
          'status': ChangeScheduleDraftStatus.editing.key,
          'revision': 1,
          'updated_at': now.toUtc().toIso8601String(),
        };
        if (effectiveWeek != null) {
          row['effective_week'] = effectiveWeek;
        }
        final store = ChangeScheduleDraftStore(
          preferences: preferences,
          client: null,
          userId: 'remote-effective-week-$effectiveWeek',
          remoteStore: _InMemoryChangeScheduleDraftRemoteStore(
            userId: 'remote-effective-week-$effectiveWeek',
            seedRow: row,
          ),
        );

        await expectLater(store.load(), throwsFormatException);
      }
    },
  );

  test('remote drafts reject noncanonical statuses', () async {
    const userId = 'remote-invalid-status';
    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: userId,
      remoteStore: _InMemoryChangeScheduleDraftRemoteStore(
        userId: userId,
        seedRow: {
          'source_plan_version_id': 'remote-plan',
          'proposed_availability': _availability().toJson(),
          'effective_week': ChangeScheduleEffectiveWeek.current.key,
          'status': 'unknown_status',
          'revision': 1,
          'updated_at': now.toUtc().toIso8601String(),
        },
      ),
    );

    await expectLater(store.load(), throwsFormatException);
  });

  test('discard fails when local deletion is blocked', () async {
    final draft = ChangeScheduleDraft(
      availability: _availability(),
      effectiveWeek: ChangeScheduleEffectiveWeek.current,
    );
    final sourcePlanId = 'active-plan';
    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: null,
      removeLocal: (_) async => false,
    );

    await store.save(
      draft: draft,
      sourcePlanId: sourcePlanId,
      status: ChangeScheduleDraftStatus.assessmentPending,
      revision: 1,
      updatedAt: now,
    );

    expect(await store.discard(), isFalse);
    expect(
      preferences.getString(ChangeScheduleDraftStore.storageKeyForUser(null)),
      isNotNull,
    );
  });

  test('discard fails when remote cleanup fails', () async {
    final remote = _InMemoryChangeScheduleDraftRemoteStore(
      userId: 'user-6',
      discardShouldFail: true,
    );
    final store = ChangeScheduleDraftStore(
      preferences: preferences,
      client: null,
      userId: 'user-6',
      remoteStore: remote,
    );

    await store.save(
      draft: ChangeScheduleDraft(
        availability: _availability(),
        effectiveWeek: ChangeScheduleEffectiveWeek.current,
      ),
      sourcePlanId: 'active-plan',
      status: ChangeScheduleDraftStatus.assessmentPending,
      revision: 1,
      updatedAt: now,
    );

    expect(await store.discard(), isFalse);
    expect(remote.rowFor(), isNotNull);
    expect(
      preferences.getString(
        ChangeScheduleDraftStore.storageKeyForUser('user-6'),
      ),
      isNotNull,
    );
  });

  test(
    'malformed remote draft payload fails fast instead of falling back to local',
    () async {
      final localDraft = StoredChangeScheduleDraft(
        draft: ChangeScheduleDraft(
          availability: _availability().copyWith(primaryLongRunWeekday: 1),
          effectiveWeek: ChangeScheduleEffectiveWeek.current,
        ),
        sourcePlanId: 'local-plan',
        status: ChangeScheduleDraftStatus.editing,
        revision: 1,
        updatedAt: DateTime(2026, 7, 12, 10).toUtc(),
      );
      final storageKey = ChangeScheduleDraftStore.storageKeyForUser('user-4');
      await preferences.setString(storageKey, jsonEncode(localDraft.toJson()));

      final malformedRemote = _InMemoryChangeScheduleDraftRemoteStore(
        userId: 'user-4',
        seedRow: {
          'source_plan_version_id': 'remote-plan',
          'status': ChangeScheduleDraftStatus.assessmentPending.key,
          'revision': 2,
          'updated_at': DateTime(2026, 7, 12, 11).toUtc().toIso8601String(),
          'data': {'availability': _availability().toJson()},
        },
      );
      final store = ChangeScheduleDraftStore(
        preferences: preferences,
        client: null,
        userId: 'user-4',
        remoteStore: malformedRemote,
      );

      expect(() => store.load(), throwsFormatException);
      expect(
        preferences.getString(storageKey),
        equals(jsonEncode(localDraft.toJson())),
      );
    },
  );

  test('parses all response models from server-shaped payloads', () {
    final preview = ChangeSchedulePreviewResponse.fromJson(
      _previewResponseJson(),
    );
    final accepted = ChangeScheduleAcceptedResponse.fromJson(
      _acceptedResponseJson(),
    );
    final scheduled = ChangeScheduleScheduledResponse.fromJson(
      _scheduledResponseJson(),
    );
    final cancelled = ChangeScheduleCancelledResponse.fromJson(
      _cancelledResponseJson(),
    );
    final activated = ChangeScheduleActivatedResponse.fromJson(
      _activatedResponseJson(),
    );
    final undone = ChangeScheduleUndoneResponse.fromJson(_undoneResponseJson());

    expect(preview.proposalId, 'proposal-preview-1');
    expect(accepted.versionId, 'plan-accepted-1');
    expect(accepted.plan.id, 'plan-accepted-1');
    expect(accepted.plan.sessions, isEmpty);
    expect(scheduled.activationStatus, 'scheduled');
    expect(cancelled.proposalStatus, 'cancelled');
    expect(activated.activationStatus, 'active');
    expect(undone.priorPlanVersionId, 'plan-legacy');
  });

  test('rejected accepted response plan payload throws parse failure', () {
    expect(
      () => ChangeScheduleAcceptedResponse.fromJson(
        _malformedAcceptedResponseJson(),
      ),
      throwsFormatException,
    );
  });

  test(
    'lifecycle rows use canonical lineage and support exact legacy matches',
    () {
      final proposal = ChangeScheduleLifecycleProposal.fromDatabaseRow({
        'id': 'proposal-scheduled-1',
        'source_plan_version_id': 'active-plan',
        'status': 'scheduled',
        'proposed_availability': _availability().toJson(),
        'candidate_plan': _planJson(id: 'plan-scheduled-1'),
        'impact': {
          'impact': <dynamic>[],
          'warnings': <dynamic>[],
          'goalImpact': <String, dynamic>{},
        },
        'effective_from': '2026-07-20',
        'expires_at': '2026-07-13T10:00:00.000Z',
        'accepted_plan_version_id': null,
        'scheduled_plan_version_id': 'plan-scheduled-1',
        'prior_active_plan_version_id': null,
        'prior_active_availability_version_id': null,
        'accepted_availability_version_id': null,
      });
      final legacyActivation =
          ChangeScheduleLifecycleActivation.fromDatabaseRow({
            'id': 'activation-1',
            'source_plan_version_id': 'active-plan',
            'queued_candidate_plan_version_id': 'plan-scheduled-1',
            'availability_version_id': 'availability-scheduled-1',
            'effective_from': '2026-07-20',
            'status': 'scheduled',
            'proposal_id': null,
          });

      expect(legacyActivation.matchesScheduledProposal(proposal), isTrue);
      expect(
        legacyActivation.toScheduledResponse(proposal).proposalId,
        'proposal-scheduled-1',
      );

      final mismatchedActivation =
          ChangeScheduleLifecycleActivation.fromDatabaseRow({
            'id': 'activation-2',
            'source_plan_version_id': 'active-plan',
            'queued_candidate_plan_version_id': 'different-candidate',
            'availability_version_id': 'availability-scheduled-1',
            'effective_from': '2026-07-20',
            'status': 'scheduled',
            'proposal_id': null,
          });
      expect(mismatchedActivation.matchesScheduledProposal(proposal), isFalse);
      expect(
        () => mismatchedActivation.toScheduledResponse(proposal),
        throwsFormatException,
      );

      expect(
        () => ChangeScheduleLifecycleProposal.fromDatabaseRow({
          'id': 'proposal-malformed',
          'source_plan_version_id': 'active-plan',
          'status': 'pending',
          'proposed_availability': _availability().toJson(),
          'candidate_plan': const <String, dynamic>{},
          'impact': {
            'impact': <dynamic>[],
            'warnings': <dynamic>[],
            'goalImpact': <String, dynamic>{},
          },
          'effective_from': '2026-07-13',
          'expires_at': '2026-07-13T10:00:00.000Z',
          'accepted_plan_version_id': null,
          'scheduled_plan_version_id': null,
        }),
        throwsFormatException,
      );
    },
  );
}

ChangeScheduleAvailability _availability() => ChangeScheduleAvailability(
  days: [
    for (final day in [1, 2, 3, 4, 5, 6, 7])
      ChangeScheduleAvailabilityDay(
        day: day,
        available: day == 1 || day == 2 || day == 4 || day == 7,
        maxDurationMinutes: day == 1 || day == 2 || day == 4
            ? 45
            : day == 7
            ? 90
            : null,
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

Map<String, dynamic> _sessionJson({
  required String id,
  required DateTime date,
  required String type,
  String? description,
  int? durationMinutes,
  double? distanceKm,
}) => {
  'schemaVersion': 1,
  'id': id,
  'date': date.toIso8601String(),
  'type': type,
  'status': 'upcoming',
  'weekNumber': 1,
  'description': ?description,
  'durationMinutes': ?durationMinutes,
  'distanceKm': ?distanceKm,
};

Map<String, dynamic> _previewResponseJson() => {
  'proposalId': 'proposal-preview-1',
  'sourcePlanVersionId': 'plan-legacy',
  'effectiveFrom': '2026-07-13',
  'asOfDate': '2026-07-13',
  'expiresAt': '2099-12-31T23:59:59.000Z',
  'candidatePlan': _planJson(id: 'candidate-plan'),
  'impacts': <dynamic>[],
  'warnings': <dynamic>[],
  'goalImpact': {},
  'proposedAvailability': _availability().toJson(),
};

Map<String, dynamic> _acceptedResponseJson() => {
  'versionId': 'plan-accepted-1',
  'plan': _planJson(id: 'plan-accepted-1'),
  'priorActivePlanVersionId': 'plan-legacy',
  'priorActiveAvailabilityVersionId': 'availability-old',
  'acceptedAvailabilityVersionId': 'availability-new',
};

Map<String, dynamic> _malformedAcceptedResponseJson() => {
  'versionId': 'plan-accepted-1',
  'plan': {'id': 'plan-accepted-1'},
  'priorActivePlanVersionId': 'plan-legacy',
  'priorActiveAvailabilityVersionId': 'availability-old',
  'acceptedAvailabilityVersionId': 'availability-new',
};

class _InMemoryChangeScheduleDraftRemoteStore
    implements ChangeScheduleDraftRemoteStore {
  _InMemoryChangeScheduleDraftRemoteStore({
    required String userId,
    DateTime? serverUpdatedAt,
    Map<String, dynamic>? seedRow,
    bool discardShouldFail = false,
  }) : _userId = userId,
       _serverUpdatedAt = serverUpdatedAt,
       _seedRow = seedRow,
       _discardShouldFail = discardShouldFail;

  final String _userId;
  final DateTime? _serverUpdatedAt;
  final Map<String, Map<String, dynamic>> _rows = {};
  final Map<String, dynamic>? _seedRow;
  final bool _discardShouldFail;

  Map<String, dynamic>? rowFor() => _rows[_userId];

  @override
  Future<Map<String, dynamic>?> load() async => _rows[_userId] ?? _seedRow;

  @override
  Future<DateTime?> save({
    required String sourcePlanId,
    required Map<String, dynamic> proposedAvailability,
    required String effectiveWeek,
    required ChangeScheduleDraftStatus status,
    required int revision,
    DateTime? updatedAt,
  }) async {
    final serverUpdatedAt =
        _serverUpdatedAt ?? updatedAt ?? DateTime.now().toUtc();
    _rows[_userId] = {
      'source_plan_version_id': sourcePlanId,
      'proposed_availability': proposedAvailability,
      'effective_week': effectiveWeek,
      'status': status.key,
      'revision': revision,
      'updated_at': serverUpdatedAt.toUtc().toIso8601String(),
    };
    return serverUpdatedAt;
  }

  @override
  Future<void> discard() async {
    if (_discardShouldFail) {
      throw const FormatException('Cannot discard remote draft.');
    }
    _rows.remove(_userId);
  }
}

Map<String, dynamic> _scheduledResponseJson() => {
  'proposalId': 'proposal-preview-1',
  'activationId': 'activation-1',
  'scheduledPlanVersionId': 'plan-scheduled-1',
  'scheduledAvailabilityVersionId': 'availability-scheduled-1',
  'activationStatus': 'scheduled',
};

Map<String, dynamic> _cancelledResponseJson() => {
  'proposalId': 'proposal-preview-1',
  'proposalStatus': 'cancelled',
  'activationId': 'activation-1',
  'scheduledPlanVersionId': 'plan-scheduled-1',
};

Map<String, dynamic> _activatedResponseJson() => {
  'proposalId': 'proposal-preview-1',
  'activationId': 'activation-1',
  'proposalStatus': 'active',
  'acceptedPlanVersionId': 'plan-accepted-2',
  'priorActivePlanVersionId': 'plan-legacy',
  'priorActiveAvailabilityVersionId': 'availability-old',
  'acceptedAvailabilityVersionId': 'availability-new',
  'activationStatus': 'active',
  'plan': _planJson(id: 'plan-accepted-2'),
};

Map<String, dynamic> _undoneResponseJson() => {
  'proposalId': 'proposal-preview-1',
  'priorPlanVersionId': 'plan-legacy',
  'priorAvailabilityVersionId': 'availability-old',
  'restoredPlanVersionId': 'plan-undo',
  'restoredAvailabilityVersionId': 'availability-undo',
};
