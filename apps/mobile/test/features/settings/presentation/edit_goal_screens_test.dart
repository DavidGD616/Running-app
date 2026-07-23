import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/core/widgets/app_header_bar.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/presentation/edit_goal_provider.dart';
import 'package:running_app/features/settings/presentation/screens/edit_goal_form_screen.dart';
import 'package:running_app/features/settings/presentation/screens/edit_goal_preview_screen.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 7, 13, 12);
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('starts with a focused, localized What changed screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(now: now, preferences: preferences, locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar objetivo'), findsOneWidget);
    expect(find.text('¿Qué cambió?'), findsOneWidget);
    expect(find.text('Media Maratón'), findsOneWidget);
    expect(find.textContaining('Tiempo objetivo'), findsNothing);
  });

  testWidgets('asks for evidence when the server says it is insufficient', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        client: (_, {body}) async =>
            FunctionResponse(data: _fitnessCheckResponse(), status: 200),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Race distance').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGoalReviewChanges')));
    await tester.pumpAndSettle();

    expect(find.text('Let’s ground this in your running'), findsOneWidget);
    expect(find.text('Schedule a benchmark'), findsOneWidget);
    expect(find.textContaining('target time'), findsNothing);
  });

  testWidgets('suggested activity requires explicit hard-effort confirmation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          calls++;
          return FunctionResponse(
            data: calls == 1
                ? _fitnessCheckResponse(includeSuggestedActivity: true)
                : _proposal(),
            status: 200,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Race distance').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGoalReviewChanges')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this result').first);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Was this a hard, sustained effort?'), findsOneWidget);
    expect(find.text('Enter a recent result'), findsOneWidget);

    await tester.ensureVisible(find.text('Use this result'));
    await tester.tap(find.text('Use this result'));
    await tester.pump();
    expect(calls, 1);
    expect(
      find.text(
        'Enter a positive distance, a time in HH:MM:SS, and the date of a hard effort.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.ensureVisible(find.text('Use this result'));
    await tester.tap(find.text('Use this result'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Review Goal Changes'), findsOneWidget);
  });

  testWidgets('deselecting distance restores it before preview', (
    tester,
  ) async {
    Object? capturedBody;
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        client: (_, {body}) async {
          capturedBody = body;
          return FunctionResponse(data: _proposal(), status: 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Race distance').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marathon'));
    await tester.pump();

    tester
        .widget<AppDetailHeaderBar>(find.byType(AppDetailHeaderBar))
        .onBack!();
    await tester.pump();
    await tester.tap(find.text('Race distance').first);
    await tester.pump();
    await tester.tap(find.text('Race date').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGoalReviewChanges')));
    await tester.pumpAndSettle();

    expect(
      (capturedBody! as Map<String, dynamic>)['race'],
      'race_half_marathon',
    );
  });

  testWidgets('shows the range, two-week preview, and success recap', (
    tester,
  ) async {
    await tester.pumpWidget(_app(now: now, preferences: preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Race date').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGoalReviewChanges')));
    await tester.pumpAndSettle();

    expect(find.text('Review Goal Changes'), findsOneWidget);
    expect(find.text('Estimated finish range'), findsOneWidget);
    expect(find.text('1:52:00 to 1:58:00'), findsOneWidget);
    expect(find.text('YOUR NEXT TWO WEEKS'), findsOneWidget);
    expect(find.textContaining('target time'), findsNothing);

    await tester.tap(find.byKey(const Key('editGoalApplyButton')));
    await tester.pumpAndSettle();

    expect(find.text('Your updated plan is ready'), findsAtLeastNWidgets(1));
    expect(
      find.text('4 completed or skipped sessions preserved'),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsOneWidget);
  });

  testWidgets('next two weeks starts from the current plan week', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        now: now,
        preferences: preferences,
        client: (_, {body}) async => FunctionResponse(
          data: _proposal(
            candidatePlan: _plan(
              'candidate-plan',
              currentWeekNumber: 5,
              totalWeeks: 7,
            ),
          ),
          status: 200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Race date').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editGoalChangesContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGoalReviewChanges')));
    await tester.pumpAndSettle();

    expect(find.text('Week 5'), findsOneWidget);
    expect(find.text('Week 6'), findsOneWidget);
    expect(find.text('Week 1'), findsNothing);
    expect(find.text('Week 2'), findsNothing);
  });
}

Widget _app({
  required DateTime now,
  required SharedPreferences preferences,
  Locale locale = const Locale('en'),
  EditGoalFunctionClient? client,
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
      sharedPreferencesProvider.overrideWithValue(preferences),
      editGoalClockProvider.overrideWithValue(() => now),
      editGoalLocaleCodeProvider.overrideWithValue(locale.languageCode),
      editGoalInitialDataLoaderProvider.overrideWithValue(
        () async => EditGoalInitialData(
          profile: buildRunnerProfile(),
          activePlanId: 'active-plan',
        ),
      ),
      editGoalFunctionClientProvider.overrideWithValue(
        client ??
            (_, {body}) async => FunctionResponse(
              data: (body! as Map<String, dynamic>)['action'] == 'accept'
                  ? _acceptance()
                  : _proposal(),
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
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Map<String, dynamic> _fitnessCheckResponse({
  bool includeSuggestedActivity = false,
}) => {
  'state': 'fitness_check_required',
  'sourcePlanVersionId': 'active-plan',
  'fitnessCheck': {
    'suggestedActivities': includeSuggestedActivity
        ? [
            {
              'recordedOn': '2026-07-10',
              'distanceKm': 5.0,
              'elapsedSeconds': 1500,
            },
          ]
        : <dynamic>[],
    'benchmark': {
      'kind': 'five_k_run',
      'safeDates': ['2026-07-16'],
    },
  },
};

Map<String, dynamic> _proposal({Map<String, dynamic>? candidatePlan}) => {
  'proposalId': 'proposal-1',
  'sourcePlanVersionId': 'active-plan',
  'expiresAt': '2026-07-13T17:15:00.000Z',
  'currentGoal': _goal(),
  'proposedGoal': _goal(),
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
  'candidatePlan': candidatePlan ?? _plan('candidate-plan'),
  'summary': {
    'preservedCount': 4,
    'addedUpcomingCount': 0,
    'removedUpcomingCount': 0,
    'materiallyChangedUpcomingCount': 0,
    'totalWeeks': 3,
    'endDate': '2026-10-18',
  },
  'warnings': ['short_notice'],
};

Map<String, dynamic> _goal() => {
  'race': 'race_half_marathon',
  'hasRaceDate': true,
  'raceDate': '2026-10-18',
};

Map<String, dynamic> _acceptance() {
  final profile = buildRunnerProfile().toJson();
  profile['acceptedRaceTarget'] = const AcceptedRaceTarget(
    distanceKm: 21.097,
    primaryTime: Duration(hours: 1, minutes: 55),
  ).toJson();
  return {
    'versionId': 'accepted-plan',
    'plan': _plan('accepted-plan'),
    'profile': profile,
  };
}

Map<String, dynamic> _plan(
  String id, {
  int currentWeekNumber = 1,
  int totalWeeks = 3,
}) => {
  'schemaVersion': 1,
  'id': id,
  'raceType': 'halfMarathon',
  'totalWeeks': totalWeeks,
  'currentWeekNumber': currentWeekNumber,
  'sessions': [
    for (var week = 1; week <= totalWeeks; week++)
      {
        'schemaVersion': 1,
        'id': 'session-$week',
        'date':
            '2026-07-${(13 + week).toString().padLeft(2, '0')}T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'upcoming',
        'weekNumber': week,
        'distanceKm': 5.0,
        'durationMinutes': 35,
        'workoutSteps': <dynamic>[],
      },
  ],
};

class _TestUserPreferencesRepository implements UserPreferencesRepository {
  const _TestUserPreferencesRepository();

  @override
  Future<UserPreferences> load() async => const UserPreferences();

  @override
  Future<void> save(UserPreferences preferences) async {}
}
