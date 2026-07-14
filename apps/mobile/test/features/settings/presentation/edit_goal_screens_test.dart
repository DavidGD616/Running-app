import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/presentation/edit_goal_provider.dart';
import 'package:running_app/features/settings/presentation/screens/edit_goal_form_screen.dart';
import 'package:running_app/features/settings/presentation/screens/edit_goal_preview_screen.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 7, 13, 12);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(393, 852);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('form prefills canonical goal and renders Spanish copy', (
    tester,
  ) async {
    await tester.pumpWidget(_app(now: now, locale: const Locale('es')));
    await tester.pumpAndSettle();

    expect(find.text('Editar objetivo'), findsOneWidget);
    expect(find.text('Media Maratón'), findsOneWidget);
    expect(find.text('1:55:00'), findsOneWidget);
    expect(find.textContaining('Objetivo respaldado'), findsOneWidget);
  });

  testWidgets('initial load failure shows retry and recovers to form', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        loader: () async {
          loadCount++;
          if (loadCount == 1) throw StateError('storage unavailable');
          return _initialData();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('We could not read the updated plan.'), findsOneWidget);
    expect(
      find.byKey(const Key('editGoalInitializationRetry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('editGoalInitializationRetry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editGoalTargetTimeField')), findsOneWidget);
    expect(find.text('Half Marathon'), findsOneWidget);
    expect(loadCount, 2);
  });

  testWidgets('form validates positive target and fixed-date toggle', (
    tester,
  ) async {
    await tester.pumpWidget(_app(now: now));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('editGoalTargetTimeField')),
      '0:00:00',
    );
    await tester.tap(find.text('Preview changes'));
    await tester.pump();
    expect(
      find.text('Enter a positive target time as HH:MM:SS.'),
      findsOneWidget,
    );

    await tester.tap(find.text('No'));
    await tester.pump();
    expect(find.byKey(const Key('editGoalDateField')), findsNothing);
  });

  testWidgets(
    'switching race hides stale evidence suggestion and preserves target input',
    (tester) async {
      await tester.pumpWidget(_app(now: now));
      await tester.pumpAndSettle();

      expect(find.text('Evidence-supported target: 1:58:00'), findsOneWidget);
      final targetField = find.byKey(const Key('editGoalTargetTimeField'));
      await tester.enterText(targetField, '0:47:30');
      await tester.tap(find.text('10K'));
      await tester.pump();

      expect(find.text('Evidence-supported target: 1:58:00'), findsNothing);
      expect(tester.widget<TextField>(targetField).controller?.text, '0:47:30');
    },
  );

  testWidgets(
    'preview navigation shows comparison, warnings, summary, and weeks',
    (tester) async {
      await tester.pumpWidget(_app(now: now));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview changes'));
      await tester.pumpAndSettle();

      expect(find.text('Review Goal Changes'), findsOneWidget);
      expect(find.text('Short preparation window'), findsOneWidget);
      expect(find.text('Aggressive target'), findsOneWidget);
      expect(find.text('4 sessions preserved'), findsOneWidget);
      expect(find.text('Week 3'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('editGoalWeek3')));
      await tester.tap(find.byKey(const Key('editGoalWeek3')));
      await tester.pumpAndSettle();
      expect(find.text('Jul 14, 2026 · Easy Run'), findsOneWidget);
    },
  );

  testWidgets(
    'preview renders chronological added removed and before-after details',
    (tester) async {
      await tester.pumpWidget(_app(now: now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview changes'));
      await tester.pumpAndSettle();

      expect(find.text('Added workouts'), findsOneWidget);
      expect(find.text('Removed workouts'), findsOneWidget);
      expect(find.text('Changed workouts'), findsOneWidget);
      expect(find.text('Easy Run → Intervals'), findsOneWidget);
      expect(find.text('Long Run'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('editGoaladdedChange0'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('editGoaladdedChange1'))).dy,
        ),
      );
    },
  );

  testWidgets('preview omits empty detail sections', (tester) async {
    await tester.pumpWidget(
      _app(now: now, proposal: _proposal(includeDetails: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editGoalAddedDetails')), findsNothing);
    expect(find.byKey(const Key('editGoalRemovedDetails')), findsNothing);
    expect(find.byKey(const Key('editGoalChangedDetails')), findsNothing);
    expect(find.text('0 sessions added'), findsOneWidget);
  });

  testWidgets('preview localizes change details in Spanish', (tester) async {
    await tester.pumpWidget(_app(now: now, locale: const Locale('es')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vista previa de cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Sesiones añadidas'), findsOneWidget);
    expect(find.text('Sesiones eliminadas'), findsOneWidget);
    expect(find.text('Sesiones modificadas'), findsOneWidget);
    expect(find.text('Carrera Suave → Intervalos'), findsOneWidget);
  });

  testWidgets('keep current goal returns to form without acceptance', (
    tester,
  ) async {
    var acceptCalls = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        client: (_, {body}) async {
          final action = (body as Map<String, dynamic>)['action'];
          if (action == 'accept') acceptCalls++;
          return FunctionResponse(
            data: action == 'accept' ? _acceptance() : _proposal(),
            status: 200,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep current goal'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Goal'), findsOneWidget);
    expect(acceptCalls, 0);
  });

  testWidgets('expired preview disables apply and offers fresh preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        now: now,
        proposal: _proposal(expiresAt: '2026-07-13T11:00:00Z'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();

    expect(find.text('Generate a fresh preview'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('stale preview reloads source and preserves edited values', (
    tester,
  ) async {
    var loadCount = 0;
    final previewPayloads = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        now: now,
        loader: () async {
          loadCount++;
          return _initialData(
            activePlanId: loadCount == 1 ? 'active-plan' : 'fresh-plan',
          );
        },
        client: (_, {body}) async {
          final payload = body as Map<String, dynamic>;
          if (payload['action'] == 'accept') {
            return FunctionResponse(
              data: {'error': 'source_plan_stale'},
              status: 409,
            );
          }
          previewPayloads.add(payload);
          return FunctionResponse(
            data: _proposal(
              sourcePlanId: payload['sourcePlanVersionId'] as String,
              proposedSeconds: payload['targetTimeSeconds'] as int,
              proposedRace: payload['race'] as String,
              proposedHasRaceDate: payload['hasRaceDate'] as bool,
            ),
            status: 200,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('editGoalTargetTimeField')),
      '0:47:30',
    );
    await tester.tap(find.text('10K'));
    await tester.pump();
    await tester.tap(find.text('No'));
    await tester.pump();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();

    expect(find.text('Generate a fresh preview'), findsOneWidget);
    await tester.tap(find.text('Generate a fresh preview'));
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(previewPayloads.last, {
      'action': 'preview',
      'sourcePlanVersionId': 'fresh-plan',
      'race': 'race_10k',
      'hasRaceDate': false,
      'raceDate': null,
      'targetTimeSeconds': 2850,
      'localDate': '2026-07-13',
      'locale': 'en',
    });
    expect(find.text('0:47:30'), findsOneWidget);
    expect(find.text('10K'), findsOneWidget);
    expect(find.text('Apply changes'), findsOneWidget);
  });

  testWidgets('failed fresh preview remains visible and retryable', (
    tester,
  ) async {
    var loadCount = 0;
    var previewCount = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        loader: () async {
          loadCount++;
          return _initialData(
            activePlanId: loadCount == 1
                ? 'active-plan'
                : 'fresh-plan-$loadCount',
          );
        },
        client: (_, {body}) async {
          final payload = body as Map<String, dynamic>;
          if (payload['action'] == 'accept') {
            return FunctionResponse(
              data: {'error': 'source_plan_stale'},
              status: 409,
            );
          }
          previewCount++;
          if (previewCount == 2) {
            return FunctionResponse(
              data: {'error': 'edit_goal_failed'},
              status: 500,
            );
          }
          return FunctionResponse(
            data: _proposal(
              sourcePlanId: payload['sourcePlanVersionId'] as String,
            ),
            status: 200,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate a fresh preview'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Generate a fresh preview'), findsOneWidget);
    expect(find.text('GOAL COMPARISON'), findsOneWidget);

    await tester.tap(find.text('Generate a fresh preview'));
    await tester.pumpAndSettle();
    expect(find.text('Apply changes'), findsOneWidget);
    expect(loadCount, 3);
    expect(previewCount, 3);
  });

  testWidgets('apply timeout retries same proposal then navigates on success', (
    tester,
  ) async {
    final acceptPayloads = <Object?>[];
    var acceptCount = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        client: (_, {body}) async {
          final payload = body as Map<String, dynamic>;
          if (payload['action'] == 'preview') {
            return FunctionResponse(data: _proposal(), status: 200);
          }
          acceptCount++;
          acceptPayloads.add(body);
          if (acceptCount == 1) {
            throw TimeoutException('response lost');
          }
          return FunctionResponse(data: _acceptance(), status: 200);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();

    expect(find.text('The preview took too long. Try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(acceptPayloads, [
      {'action': 'accept', 'proposalId': 'proposal-1'},
      {'action': 'accept', 'proposalId': 'proposal-1'},
    ]);
    expect(find.text('Plan destination'), findsOneWidget);
  });

  testWidgets('apply prevents duplicate accepts and navigates after success', (
    tester,
  ) async {
    final acceptCompleter = Completer<FunctionResponse>();
    var acceptCalls = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        client: (_, {body}) {
          final action = (body as Map<String, dynamic>)['action'];
          if (action == 'preview') {
            return Future.value(
              FunctionResponse(data: _proposal(), status: 200),
            );
          }
          acceptCalls++;
          return acceptCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply changes'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalApplyButton')));
    await tester.pump();
    expect(acceptCalls, 1);

    acceptCompleter.complete(
      FunctionResponse(data: _acceptance(), status: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan destination'), findsOneWidget);
  });
}

Widget _app({
  required DateTime now,
  Locale locale = const Locale('en'),
  EditGoalFunctionClient? client,
  EditGoalInitialDataLoader? loader,
  Map<String, dynamic>? proposal,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.settingsUpdatePlanEditGoal,
    routes: [
      GoRoute(
        path: RouteNames.settingsUpdatePlanEditGoal,
        builder: (_, _) => const EditGoalFormScreen(),
      ),
      GoRoute(
        path: RouteNames.settingsUpdatePlanEditGoalPreview,
        builder: (_, _) => const EditGoalPreviewScreen(),
      ),
      GoRoute(
        path: RouteNames.plan,
        builder: (_, _) => const Scaffold(body: Text('Plan destination')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      editGoalClockProvider.overrideWithValue(() => now),
      editGoalLocaleCodeProvider.overrideWithValue(locale.languageCode),
      editGoalEvidenceSuggestionProvider.overrideWithValue(
        const EditGoalEvidenceSuggestion(
          race: RunnerGoalRace.halfMarathon,
          targetTime: Duration(hours: 1, minutes: 58),
        ),
      ),
      editGoalInitialDataLoaderProvider.overrideWithValue(
        loader ?? () async => _initialData(),
      ),
      editGoalFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async => FunctionResponse(
              data: (body as Map<String, dynamic>)['action'] == 'accept'
                  ? _acceptance()
                  : proposal ?? _proposal(),
              status: 200,
            ),
      ),
      editGoalCacheReconcilerProvider.overrideWithValue((_) async {}),
      userPreferencesRepositoryProvider.overrideWithValue(
        const _TestUserPreferencesRepository(),
      ),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      routerConfig: router,
    ),
  );
}

Map<String, dynamic> _proposal({
  String expiresAt = '2026-07-13T13:00:00Z',
  bool includeDetails = true,
  String sourcePlanId = 'active-plan',
  int proposedSeconds = 6800,
  String proposedRace = 'race_half_marathon',
  bool proposedHasRaceDate = true,
}) => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': sourcePlanId,
  'expiresAt': expiresAt,
  'currentGoal': _goal(6900),
  'proposedGoal': _goal(
    proposedSeconds,
    race: proposedRace,
    hasRaceDate: proposedHasRaceDate,
  ),
  'candidatePlan': _plan('candidate-plan'),
  'summary': {
    'preservedCount': 4,
    'addedUpcomingCount': includeDetails ? 2 : 0,
    'removedUpcomingCount': includeDetails ? 1 : 0,
    'materiallyChangedUpcomingCount': includeDetails ? 1 : 0,
    'addedUpcomingSessions': includeDetails
        ? [
            _changeRow(
              date: '2026-07-14',
              afterType: 'intervals',
              afterDuration: 25,
              afterDistance: 6.5,
            ),
            _changeRow(
              date: '2026-07-20',
              afterType: 'recoveryRun',
              afterDuration: 30,
              afterDistance: 4,
            ),
          ]
        : <Map<String, dynamic>>[],
    'removedUpcomingSessions': includeDetails
        ? [
            _changeRow(
              date: '2026-07-15',
              beforeType: 'longRun',
              beforeDuration: 60,
              beforeDistance: 12,
            ),
          ]
        : <Map<String, dynamic>>[],
    'materiallyChangedUpcomingSessions': includeDetails
        ? [
            _changeRow(
              date: '2026-07-16',
              beforeType: 'easyRun',
              afterType: 'intervals',
              beforeDuration: 30,
              afterDuration: 35,
              beforeDistance: 5,
              afterDistance: 6,
            ),
          ]
        : <Map<String, dynamic>>[],
    'totalWeeks': 12,
    'endDate': '2026-10-18',
  },
  'warnings': ['short_notice', 'aggressive_target'],
  'suggestedTargetTimeSeconds': 7100,
};

Map<String, dynamic> _changeRow({
  required String date,
  String? beforeType,
  String? afterType,
  int? beforeDuration,
  int? afterDuration,
  double? beforeDistance,
  double? afterDistance,
}) => {
  'localDate': date,
  'beforeSessionType': beforeType,
  'afterSessionType': afterType,
  'beforeDurationMinutes': beforeDuration,
  'afterDurationMinutes': afterDuration,
  'beforeDistanceKm': beforeDistance,
  'afterDistanceKm': afterDistance,
};

Map<String, dynamic> _goal(
  int seconds, {
  String race = 'race_half_marathon',
  bool hasRaceDate = true,
}) => {
  'race': race,
  'hasRaceDate': hasRaceDate,
  'raceDate': hasRaceDate ? '2026-10-18' : null,
  'targetTimeSeconds': seconds,
};

Map<String, dynamic> _plan(String id) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': 12,
  'currentWeekNumber': 3,
  'sessions': [
    {
      'schemaVersion': 1,
      'id': 'session-1',
      'date': '2026-07-14T00:00:00.000Z',
      'type': 'easyRun',
      'status': 'upcoming',
      'weekNumber': 3,
      'distanceKm': 5.0,
      'durationMinutes': 35,
      'workoutSteps': <dynamic>[],
    },
  ],
};

EditGoalInitialData _initialData({String activePlanId = 'active-plan'}) =>
    EditGoalInitialData(
      profile: buildRunnerProfile(),
      acceptedRaceTarget: const AcceptedRaceTarget(
        distanceKm: 21.097,
        primaryTime: Duration(hours: 1, minutes: 55),
      ),
      activePlanId: activePlanId,
    );

Map<String, dynamic> _acceptance() {
  final profile = buildRunnerProfile().toJson();
  profile['acceptedRaceTarget'] = const AcceptedRaceTarget(
    distanceKm: 21.097,
    primaryTime: Duration(hours: 1, minutes: 53, seconds: 20),
  ).toJson();
  return {
    'versionId': 'accepted-plan',
    'plan': _plan('accepted-plan'),
    'profile': profile,
  };
}

class _TestUserPreferencesRepository implements UserPreferencesRepository {
  const _TestUserPreferencesRepository();

  @override
  Future<UserPreferences> load() async => const UserPreferences();

  @override
  Future<void> save(UserPreferences preferences) async {}
}
