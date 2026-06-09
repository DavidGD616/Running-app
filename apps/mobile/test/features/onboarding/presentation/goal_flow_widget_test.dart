import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/goals/domain/models/goal.dart';
import 'package:running_app/features/goals/presentation/goal_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/plan_ready_screen.dart';
import 'package:running_app/features/onboarding/presentation/screens/summary_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/presentation/screens/settings_goal_review_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/goal_fixtures.dart';
import '../../../helpers/runner_profile_fixtures.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(
    this.value, {
    this.saveProfileResult = true,
    this.markCompletedResult = true,
  });

  final RunnerProfileDraft value;
  final bool saveProfileResult;
  final bool markCompletedResult;

  @override
  Future<RunnerProfileDraft> build() async => value;

  @override
  Future<bool> saveProfile({
    bool markOnboardingComplete = false,
    DateTime? clock,
  }) async {
    return saveProfileResult;
  }

  @override
  Future<bool> markCompleted({DateTime? clock}) async {
    return markCompletedResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  Widget wrap(Widget child, {required RunnerProfileDraft draft, Goal? goal}) {
    return ProviderScope(
      overrides: [
        onboardingProvider.overrideWith(() => _TestOnboardingNotifier(draft)),
        onboardingGoalProvider.overrideWithValue(goal),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Scaffold(body: child),
      ),
    );
  }

  Widget wrapWithRouter({
    required RunnerProfileDraft draft,
    Goal? goal,
    bool saveProfileResult = true,
    bool markCompletedResult = true,
  }) {
    final router = GoRouter(
      initialLocation: RouteNames.planReady,
      routes: [
        GoRoute(
          path: RouteNames.planReady,
          builder: (context, state) => const PlanReadyScreen(),
        ),
        GoRoute(
          path: RouteNames.today,
          builder: (context, state) => const Scaffold(body: Text('Today')),
        ),
        GoRoute(
          path: RouteNames.plan,
          builder: (context, state) => const Scaffold(body: Text('Plan')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        onboardingProvider.overrideWith(
          () => _TestOnboardingNotifier(
            draft,
            saveProfileResult: saveProfileResult,
            markCompletedResult: markCompletedResult,
          ),
        ),
        onboardingGoalProvider.overrideWithValue(goal),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
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

  testWidgets(
    'summary Strava fitness edit pushes Strava screen and returns to summary',
    (tester) async {
      final draft = buildRunnerProfileDraft().copyWith(
        fitness: const FitnessProfileDraft(
          experience: RunnerExperience.intermediate,
          runningDays: 4,
          weeklyVolume: WeeklyVolumeRange.volume3,
          longestRun: LongestRunRange.run3,
          canCompleteGoalDistance: TernaryChoice.notSure,
          raceDistanceBefore: RaceDistanceExperience.never,
          fitnessSource: 'strava',
          stravaRunsPerWeek: 4,
        ),
      );
      final goal = buildHalfMarathonTimeGoal();

      final router = GoRouter(
        initialLocation: RouteNames.summary,
        routes: [
          GoRoute(
            path: RouteNames.summary,
            builder: (context, state) => const SummaryScreen(),
          ),
          GoRoute(
            path: RouteNames.fitnessSource,
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('strava-screen'),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('back-button'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingProvider.overrideWith(
              () => _TestOnboardingNotifier(draft),
            ),
            onboardingGoalProvider.overrideWithValue(goal),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('es')],
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the edit pencil inside the fitness (From Strava) card by
      // scoping to the card's main Row, then tapping its edit GestureDetector.
      final fitnessCardRow = find
          .ancestor(of: find.text('From Strava'), matching: find.byType(Row))
          .first;
      final editButton = find.descendant(
        of: fitnessCardRow,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(editButton.last);
      await tester.pumpAndSettle();

      expect(find.text('strava-screen'), findsOneWidget);

      // Returning lands back on Summary rather than orphaning the stack.
      await tester.tap(find.text('back-button'));
      await tester.pumpAndSettle();

      expect(find.text('strava-screen'), findsNothing);
      expect(find.text('From Strava'), findsOneWidget);
    },
  );

  testWidgets('summary screen reads goal data from the goal provider', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft().copyWith(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fiveK,
        hasRaceDate: true,
        raceDate: DateTime(2026, 5, 1),
      ),
    );
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(
      wrap(const SummaryScreen(), draft: draft, goal: goal),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goal Race'), findsOneWidget);
    expect(find.text('Half Marathon'), findsOneWidget);
    expect(find.text('October 18, 2026'), findsOneWidget);
    expect(find.text('5K'), findsNothing);
  });

  testWidgets('plan ready screen uses the derived goal for its subtitle', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft().copyWith(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fiveK,
        hasRaceDate: true,
        raceDate: DateTime(2026, 5, 1),
      ),
    );
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(
      wrap(const PlanReadyScreen(), draft: draft, goal: goal),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your plan is ready'), findsOneWidget);
    expect(find.text('12-Week Half Marathon • Intermediate'), findsOneWidget);
    expect(find.text('Complete a Half Marathon'), findsOneWidget);
    expect(find.text('12 weeks • 4 runs/week'), findsOneWidget);
    expect(find.text('5K'), findsNothing);
  });

  testWidgets('settings goal review screen renders from the goal provider', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft().copyWith(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fiveK,
        hasRaceDate: true,
        raceDate: DateTime(2026, 5, 1),
      ),
    );
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(
      wrap(
        const SettingsGoalReviewScreen(mode: SettingsGoalReviewMode.editGoal),
        draft: draft,
        goal: goal,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review Changes'), findsOneWidget);
    expect(find.text('Half Marathon'), findsOneWidget);
    expect(find.text('October 18, 2026'), findsOneWidget);
    expect(find.text('5K'), findsNothing);
  });

  testWidgets('plan ready primary button routes to today when save succeeds', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft();
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(wrapWithRouter(draft: draft, goal: goal));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets(
    'plan ready primary button shows an error when profile save fails',
    (tester) async {
      final draft = buildRunnerProfileDraft();
      final goal = buildHalfMarathonTimeGoal();

      await tester.pumpWidget(
        wrapWithRouter(draft: draft, goal: goal, saveProfileResult: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Plan'));
      await tester.pumpAndSettle();

      expect(find.text('Your plan is ready'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('plan ready does not render a secondary weekly-plan button', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft();
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(wrapWithRouter(draft: draft, goal: goal));
    await tester.pumpAndSettle();

    expect(find.text('View Full Week'), findsNothing);
    expect(find.text('Start Plan'), findsOneWidget);
  });
}
