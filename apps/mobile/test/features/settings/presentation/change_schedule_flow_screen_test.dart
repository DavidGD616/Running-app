import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/core/theme/app_theme.dart';
import 'package:running_app/features/onboarding/presentation/screens/schedule_screen.dart';
import 'package:running_app/features/settings/domain/change_schedule_models.dart';
import 'package:running_app/features/settings/presentation/change_schedule_provider.dart';
import 'package:running_app/features/settings/presentation/screens/change_schedule_flow_screen.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 7, 13, 12);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('uses the dedicated change schedule route instead of onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(_app(now: now, preferences: preferences));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeScheduleFlowScreen), findsOneWidget);
    expect(find.byType(ScheduleScreen), findsNothing);
    expect(find.text('Change schedule'), findsOneWidget);
  });

  testWidgets('progresses through a valid draft, previews, and applies it', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          calls.add(payload);
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(data: _acceptedResponse(), status: 200),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('changeScheduleDay1')));
    await tester.pumpAndSettle();
    expect(find.text('3 running days each week'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeScheduleStepContinue')));
    await tester.pumpAndSettle();
    expect(find.text('Long run preferences'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeScheduleStepContinue')));
    await tester.pumpAndSettle();
    expect(find.text('Review your schedule'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeSchedulePreview')));
    await tester.pumpAndSettle();
    expect(calls.single['action'], 'preview');
    expect(find.text('Schedule preview'), findsOneWidget);
    expect(find.text('A workout moves to another available day.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeScheduleApply')));
    await tester.pumpAndSettle();
    expect(calls.last['action'], 'accept_now');
    expect(find.text('Your schedule has been updated'), findsOneWidget);
    expect(find.byKey(const Key('changeScheduleUndo')), findsOneWidget);
    expect(find.byKey(const Key('changeScheduleDone')), findsOneWidget);
  });

  testWidgets('pre-due scheduled change has Cancel but no activation CTA', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        lifecycleLoader: lifecycle,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changeScheduleCancel')), findsOneWidget);
    expect(find.byKey(const Key('changeScheduleActivateDue')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        lifecycleLoader: lifecycle,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changeScheduleCancel')), findsOneWidget);
    expect(find.byKey(const Key('changeScheduleActivateDue')), findsNothing);
  });

  testWidgets(
    'due scheduled change exposes an accessible activation CTA and keeps Cancel',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      Future<ChangeScheduleLifecycleLoadResult> lifecycle(String _) =>
          Future.value(ChangeScheduleLifecycleAvailable(
            ChangeScheduleLifecycleData(
              scheduledProposal: _lifecycleProposal(
                status: ChangeScheduleLifecycleProposalStatus.scheduled,
                id: 'proposal-scheduled-1',
                sourcePlanId: 'active-plan',
                effectiveFrom: '2026-07-13',
                scheduledPlanVersionId: 'plan-scheduled-1',
              ),
              scheduledActivation: _lifecycleActivation(
                proposalId: 'proposal-scheduled-1',
                sourcePlanId: 'active-plan',
                effectiveFrom: '2026-07-13',
                queuedPlanVersionId: 'plan-scheduled-1',
              ),
            ),
          ));

      await tester.pumpWidget(
        _app(
          now: now,
          preferences: preferences,
          lifecycleLoader: lifecycle,
          client: (_, {body}) async {
            final payload = body! as Map<String, dynamic>;
            calls.add(payload);
            return switch (payload['action']) {
              'activate_due' => FunctionResponse(
                data: _activatedResponse(),
                status: 200,
              ),
              _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
            };
          },
          activationCacheReconciler: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('changeScheduleActivateDue')), findsOneWidget);
      expect(find.text('Activate schedule now'), findsOneWidget);
      expect(find.byKey(const Key('changeScheduleCancel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('changeScheduleActivateDue')));
      await tester.pumpAndSettle();

      expect(calls.single, {
        'action': 'activate_due',
        'activationId': 'activation-1',
      });
      expect(find.text('Scheduled change activated'), findsOneWidget);
    },
  );

  testWidgets('re-entering accepted state exposes a functional Undo', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    final reconciliation = Completer<void>();
    ChangeScheduleUndoneResponse? reconciled;
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

    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        initialData: () async => _initialData(activePlanId: 'plan-accepted-1'),
        lifecycleLoader: lifecycle,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          calls.add(payload);
          return FunctionResponse(
            data: _undoneResponse(id: 'proposal-accepted-1'),
            status: 200,
          );
        },
        undoCacheReconciler: (undone) async {
          reconciled = undone;
          await reconciliation.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changeScheduleUndo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeScheduleUndo')));
    await tester.pump();
    expect(calls.single, {'action': 'undo', 'proposalId': 'proposal-accepted-1'});
    expect(reconciled?.proposalId, 'proposal-accepted-1');
    expect(reconciled?.priorPlanVersionId, 'plan-previous');
    expect(reconciled?.priorAvailabilityVersionId, 'availability-previous');
    expect(reconciled?.restoredPlanVersionId, 'plan-accepted-1');
    expect(reconciled?.restoredAvailabilityVersionId, 'availability-accepted');
    expect(find.text('Undoing your schedule change…'), findsOneWidget);
    expect(find.text('Schedule change undone'), findsNothing);

    reconciliation.complete();
    await tester.pumpAndSettle();
    expect(find.text('Schedule change undone'), findsOneWidget);
  });

  testWidgets('failed cancel returns to the scheduled recovery state', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        lifecycleLoader: lifecycle,
        client: (_, {body}) async => FunctionResponse(
          data: {'error': 'timeout'},
          status: 504,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeScheduleCancel')));
    await tester.pumpAndSettle();
    expect(find.text('Return to scheduled change'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changeScheduleReloadOrReturn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changeScheduleCancel')), findsOneWidget);
  });

  testWidgets('terminal failure reloads the authoritative schedule', (
    tester,
  ) async {
    var lifecycleLoads = 0;
    Future<ChangeScheduleLifecycleLoadResult> lifecycle(String _) async {
      lifecycleLoads += 1;
      if (lifecycleLoads == 1) {
        return const ChangeScheduleLifecycleUnavailable();
      }

      return ChangeScheduleLifecycleAvailable(
        ChangeScheduleLifecycleData(
          scheduledProposal: _lifecycleProposal(
            status: ChangeScheduleLifecycleProposalStatus.scheduled,
            id: 'proposal-reloaded-1',
            sourcePlanId: 'active-plan',
            effectiveFrom: '2026-07-20',
            scheduledPlanVersionId: 'plan-reloaded-1',
          ),
          scheduledActivation: _lifecycleActivation(
            proposalId: 'proposal-reloaded-1',
            sourcePlanId: 'active-plan',
            effectiveFrom: '2026-07-20',
            queuedPlanVersionId: 'plan-reloaded-1',
          ),
        ),
      );
    }

    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        lifecycleLoader: lifecycle,
        client: (_, {body}) async {
          final payload = body! as Map<String, dynamic>;
          return switch (payload['action']) {
            'preview' => FunctionResponse(data: _previewResponse(), status: 200),
            'accept_now' => FunctionResponse(
              data: {'error': 'proposal_expired'},
              status: 409,
            ),
            _ => FunctionResponse(data: {'error': 'invalid'}, status: 400),
          };
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('changeScheduleStepContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeScheduleStepContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeSchedulePreview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeScheduleApply')));
    await tester.pumpAndSettle();

    expect(find.text('Reload schedule'), findsOneWidget);
    expect(find.text('Return to review'), findsNothing);
    expect(lifecycleLoads, 1);

    await tester.tap(find.byKey(const Key('changeScheduleReloadOrReturn')));
    await tester.pumpAndSettle();

    expect(lifecycleLoads, 2);
    expect(find.byKey(const Key('changeScheduleCancel')), findsOneWidget);
  });
}

Widget _app({
  required DateTime now,
  required SharedPreferences preferences,
  ChangeScheduleFunctionClient? client,
  ChangeScheduleInitialDataLoader? initialData,
  ChangeScheduleLifecycleLoader? lifecycleLoader,
  ChangeScheduleActivationCacheReconciler? activationCacheReconciler,
  ChangeScheduleUndoCacheReconciler? undoCacheReconciler,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.settingsUpdatePlanSchedule,
    routes: [
      GoRoute(
        path: RouteNames.settingsUpdatePlanSchedule,
        builder: (context, state) => const ChangeScheduleFlowScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      changeScheduleClockProvider.overrideWithValue(() => now),
      changeScheduleInitialDataLoaderProvider.overrideWithValue(
        initialData ?? () async => _initialData(),
      ),
      changeScheduleLifecycleLoaderProvider.overrideWithValue(
        lifecycleLoader ?? (_) async => const ChangeScheduleLifecycleUnavailable(),
      ),
      changeScheduleFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async =>
                FunctionResponse(data: _previewResponse(), status: 200),
      ),
      changeScheduleCacheReconcilerProvider.overrideWithValue((_) async {}),
      changeScheduleActivationCacheReconcilerProvider.overrideWithValue(
        activationCacheReconciler ?? ((_) async {}),
      ),
      changeScheduleUndoCacheReconcilerProvider.overrideWithValue(
        undoCacheReconciler ?? ((_) async {}),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

ChangeScheduleInitialData _initialData({String activePlanId = 'active-plan'}) =>
    ChangeScheduleInitialData(
      profile: buildRunnerProfile(),
      activePlan: TrainingPlan.fromJson(_planJson(id: activePlanId))!,
    );

ChangeScheduleAvailability _availability() => ChangeScheduleAvailability(
  days: const [
    ChangeScheduleAvailabilityDay(
      day: 1,
      available: true,
      maxDurationMinutes: 45,
    ),
    ChangeScheduleAvailabilityDay(
      day: 2,
      available: true,
      maxDurationMinutes: 45,
    ),
    ChangeScheduleAvailabilityDay(day: 3, available: false),
    ChangeScheduleAvailabilityDay(
      day: 4,
      available: true,
      maxDurationMinutes: 45,
    ),
    ChangeScheduleAvailabilityDay(day: 5, available: false),
    ChangeScheduleAvailabilityDay(day: 6, available: false),
    ChangeScheduleAvailabilityDay(
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

Map<String, dynamic> _planJson({required String id}) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': 12,
  'currentWeekNumber': 1,
  'sessions': <Map<String, dynamic>>[],
};

ChangeScheduleLifecycleProposal _lifecycleProposal({
  required ChangeScheduleLifecycleProposalStatus status,
  required String id,
  required String sourcePlanId,
  String effectiveFrom = '2026-07-13',
  String? acceptedPlanVersionId,
  String? scheduledPlanVersionId,
}) => ChangeScheduleLifecycleProposal.fromDatabaseRow({
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
  'expires_at': '2099-12-31T23:59:59.000Z',
  'accepted_plan_version_id': acceptedPlanVersionId,
  'scheduled_plan_version_id': scheduledPlanVersionId,
  'prior_active_plan_version_id': 'plan-previous',
  'prior_active_availability_version_id': 'availability-previous',
  'accepted_availability_version_id': 'availability-accepted',
});

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
  'impacts': [
    {'key': 'move', 'sessionId': 'session-1'},
  ],
  'warnings': ['immutable_preserved'],
  'goalImpact': {
    'movedSessions': 1,
    'shortenedSessions': 0,
    'removedSessions': 0,
    'splitSessions': 0,
  },
  'proposedAvailability': _availability().toJson(),
};

Map<String, dynamic> _acceptedResponse() => {
  'versionId': 'plan-accepted-1',
  'plan': _planJson(id: 'plan-accepted-1'),
  'priorActivePlanVersionId': 'plan-previous',
  'priorActiveAvailabilityVersionId': 'availability-previous',
  'acceptedAvailabilityVersionId': 'availability-accepted',
};

Map<String, dynamic> _activatedResponse() => {
  'proposalId': 'proposal-scheduled-1',
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
  'restoredPlanVersionId': 'plan-accepted-1',
  'restoredAvailabilityVersionId': 'availability-accepted',
};
