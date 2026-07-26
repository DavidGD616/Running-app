import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/widgets/app_button.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/settings/presentation/edit_goal_provider.dart';
import 'package:running_app/features/settings/presentation/screens/edit_goal_form_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_manual_result_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_health_evidence_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_intro_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_recommendation_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_fitness_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_proposal_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_success_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_preferences_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_race_date_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_schedule_screen.dart';
import 'package:running_app/features/settings/presentation/screens/new_goal_full_plan_screen.dart';
import 'package:running_app/features/settings/presentation/screens/settings_goal_intro_screen.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/settings/presentation/new_goal_provider.dart';
import 'package:running_app/features/settings/domain/new_goal_models.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/professional_plan_metadata.dart';
import 'package:running_app/core/router/app_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/runner_profile_fixtures.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  @override
  Future<RunnerProfileDraft> build() async => const RunnerProfileDraft();
}

class _StaticNewGoalNotifier extends NewGoalNotifier {
  _StaticNewGoalNotifier(this._state);

  final NewGoalState _state;

  @override
  NewGoalState build() => _state;
}

class _ManualResultSubmissionNotifier extends NewGoalNotifier {
  _ManualResultSubmissionNotifier();

  final List<String> callLog = [];

  @override
  NewGoalState build() => _fitnessCheckStateFixture(
    now: DateTime(2026, 7, 23),
    sourcePlanId: 'active-plan',
  );

  @override
  void useFitnessResult(NewGoalFitnessResult result) {
    callLog.add('useFitnessResult');
    final current = state;
    if (current is NewGoalFitnessCheckRequired) {
      state = NewGoalEditing(
        draft: current.draft.copyWith(
          fitnessResult: result,
          clearFitnessResult: false,
          assessment: null,
          clearAssessment: true,
        ),
        sourcePlanId: current.sourcePlanId,
        hasRestoredDraft: false,
      );
    }
  }

  @override
  Future<bool> recommend() async {
    callLog.add('recommend');
    final current = state;
    if (current is NewGoalEditing) {
      state = NewGoalRecommendationReady(
        draft: current.draft,
        sourcePlanId: current.sourcePlanId,
        recommendation: _proposalRecommendationFixture(
          current.draft.effectiveGoal,
        ),
      );
      return true;
    }
    return false;
  }
}

class _RecommendationTransitionNotifier extends NewGoalNotifier {
  _RecommendationTransitionNotifier(this._state);

  final NewGoalState _state;

  @override
  NewGoalState build() => _state;

  @override
  Future<bool> preview() async {
    if (state is NewGoalRecommendationReady) {
      final current = state as NewGoalRecommendationReady;
      state = NewGoalProposalReady(
        draft: current.draft,
        sourcePlanId: current.sourcePlanId,
        recommendation: current.recommendation,
        proposal: _proposalFixture(
          goal: current.recommendation.proposedGoal,
          candidatePlan: _proposalTrainingPlanFixture(
            distanceKm: 7.2,
            durationMinutes: 70,
            sessionDate: DateTime(2026, 7, 24),
          ),
        ),
      );
      return true;
    }
    return false;
  }
}

class _ApplyTransitionNotifier extends NewGoalNotifier {
  _ApplyTransitionNotifier(this._state);

  final NewGoalState _state;

  @override
  NewGoalState build() => _state;

  @override
  Future<bool> apply() async {
    if (state is NewGoalProposalReady) {
      final current = state as NewGoalProposalReady;
      state = NewGoalSuccess(
        acceptance: NewGoalAcceptance(
          versionId: 'acceptance-test',
          plan: current.proposal.candidatePlan,
          profile: _newGoalProfileWithPlanStart(date: DateTime(2026, 7, 24)),
        ),
        proposal: current.proposal,
      );
      return true;
    }
    return false;
  }
}

class _ApplyTrackingProposalNotifier extends NewGoalNotifier {
  _ApplyTrackingProposalNotifier(this._state);

  final NewGoalState _state;
  bool applyCalled = false;

  @override
  NewGoalState build() => _state;

  @override
  Future<bool> apply() async {
    applyCalled = true;
    if (state is NewGoalProposalReady) {
      final current = state as NewGoalProposalReady;
      state = NewGoalSuccess(
        acceptance: NewGoalAcceptance(
          versionId: 'acceptance-test',
          plan: current.proposal.candidatePlan,
          profile: _newGoalProfileWithPlanStart(date: DateTime(2026, 7, 24)),
        ),
        proposal: current.proposal,
      );
      return true;
    }
    return false;
  }
}

RunnerProfile _newGoalProfileWithPlanStart({required DateTime date}) {
  final profile = buildRunnerProfile();
  return profile.copyWith(
    schedule: ScheduleProfile(
      trainingDays: profile.schedule.trainingDays,
      longRunDay: profile.schedule.longRunDay,
      weekdayTime: profile.schedule.weekdayTime,
      weekendTime: profile.schedule.weekendTime,
      hardDays: profile.schedule.hardDays,
      preferredTimeOfDay: profile.schedule.preferredTimeOfDay,
      planStartDate: date,
    ),
  );
}

NewGoalDraft? _draftFromState(NewGoalState state) => switch (state) {
  NewGoalEditing(:final draft) => draft,
  NewGoalRecommendationLoading(:final draft) => draft,
  NewGoalProposalLoading(:final draft) => draft,
  NewGoalProposalReady(:final draft) => draft,
  NewGoalFitnessCheckRequired(:final draft) => draft,
  NewGoalAssessmentPending(:final draft) => draft,
  NewGoalRecommendationReady(:final draft) => draft,
  NewGoalApplying(:final draft) => draft,
  NewGoalFailure(:final draft) => draft,
  NewGoalLoading() => null,
  NewGoalSuccess() => null,
};

TrainingPlan _proposalTrainingPlanFixture({
  DateTime? sessionDate,
  double distanceKm = 5.5,
  int durationMinutes = 95,
  List<TrainingSession>? sessions,
  List<PhaseStrategy>? phaseStrategy,
}) {
  final resolvedSessionDate = sessionDate ?? DateTime(2026, 7, 23);
  final resolvedSessions =
      sessions ??
      [
        TrainingSession(
          id: 'proposal-session-1',
          date: resolvedSessionDate,
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          distanceKm: distanceKm,
          durationMinutes: durationMinutes,
        ),
      ];
  return TrainingPlan(
    id: 'proposal-plan-1',
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 1,
    sessions: resolvedSessions,
    phaseStrategy: phaseStrategy ?? const <PhaseStrategy>[],
  );
}

NewGoalGoal _proposalGoalFixture() {
  return NewGoalGoal(
    race: RunnerGoalRace.halfMarathon,
    hasRaceDate: true,
    raceDate: DateTime(2026, 10, 18),
  );
}

NewGoalRecommendation _proposalRecommendationFixture(NewGoalGoal goal) {
  return NewGoalRecommendation(
    sourceGoal: goal,
    proposedGoal: goal,
    timelineMode: 'short_term',
    timelineDate: DateTime(2026, 7, 23),
    timelineWeeks: 12,
    timelineEndDate: DateTime(2026, 10, 15),
    timelineHasRaceDate: true,
    timelineRaceDate: DateTime(2026, 10, 18),
    daysToRace: 87,
  );
}

NewGoalProposal _proposalFixture({
  NewGoalGoal? goal,
  TrainingPlan? candidatePlan,
}) {
  final resolvedGoal = goal ?? _proposalGoalFixture();
  final resolvedPlan = candidatePlan ?? _proposalTrainingPlanFixture();
  return NewGoalProposal(
    id: 'proposal-1',
    sourcePlanVersionId: 'active-plan',
    expiresAt: DateTime(2026, 12, 31),
    sourceGoal: resolvedGoal,
    currentGoal: resolvedGoal,
    proposedGoal: resolvedGoal,
    candidatePlan: resolvedPlan,
    summary: const {},
    warnings: const [],
  );
}

NewGoalFitnessCheck _fitnessCheckFixture() {
  return NewGoalFitnessCheck(
    suggestedActivities: [
      NewGoalFitnessSuggestedActivity(
        distanceKm: 8.0,
        elapsed: Duration(minutes: 42),
        recordedOn: DateTime(2026, 8, 1),
      ),
    ],
    benchmarkKind: 'five_k_run',
    safeDates: [DateTime(2026, 8, 2)],
  );
}

NewGoalFitnessCheckRequired _fitnessCheckStateFixture({
  NewGoalDraft? draft,
  String sourcePlanId = 'active-plan',
  DateTime? now,
}) {
  final resolvedDraft =
      draft ??
      NewGoalDraft.fromProfile(
        profile: _newGoalProfileWithPlanStart(
          date: now ?? DateTime(2026, 7, 23),
        ),
      );
  return NewGoalFitnessCheckRequired(
    draft: resolvedDraft,
    sourcePlanId: sourcePlanId,
    fitnessCheck: _fitnessCheckFixture(),
  );
}

NewGoalState _proposalReadyStateFixture({NewGoalProposal? proposal}) {
  final resolvedProposal = proposal ?? _proposalFixture();
  final goal = resolvedProposal.currentGoal;
  return NewGoalProposalReady(
    draft: NewGoalDraft.fromProfile(
      profile: _newGoalProfileWithPlanStart(date: DateTime(2026, 7, 31)),
    ),
    sourcePlanId: 'active-plan',
    recommendation: _proposalRecommendationFixture(goal),
    proposal: resolvedProposal,
  );
}

NewGoalState _recommendationReadyStateFixture() {
  final goal = _proposalGoalFixture();
  final draft = NewGoalDraft.fromProfile(
    profile: _newGoalProfileWithPlanStart(date: DateTime(2026, 7, 31)),
  );
  return NewGoalRecommendationReady(
    draft: draft,
    sourcePlanId: 'active-plan',
    recommendation: _proposalRecommendationFixture(goal),
  );
}

NewGoalState _successStateFixture() {
  final proposal = _proposalFixture();
  return NewGoalSuccess(
    acceptance: NewGoalAcceptance(
      versionId: 'acceptance-1',
      plan: proposal.candidatePlan,
      profile: _newGoalProfileWithPlanStart(date: DateTime(2026, 7, 31)),
    ),
    proposal: proposal,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
  });

  test('loading bootstrap keeps the splash route active', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.loading,
    );

    expect(redirect, isNull);
  });

  test('unauthenticated bootstrap sends splash traffic to welcome', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.unauthenticated,
    );

    expect(redirect, RouteNames.welcome);
  });

  test('unauthenticated bootstrap keeps public auth routes open', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.logIn,
      bootstrapState: AppBootstrapState.unauthenticated,
    );

    expect(redirect, isNull);
  });

  test('unauthenticated bootstrap sends profile routes back to welcome', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.accountSetup,
      bootstrapState: AppBootstrapState.unauthenticated,
    );

    expect(redirect, RouteNames.welcome);
  });

  test('profileless signed-in bootstrap lands on account setup', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.authenticatedNeedsProfile,
    );

    expect(redirect, RouteNames.accountSetup);
  });

  test('profile setup routes stay open while profile is missing', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.onboarding,
      bootstrapState: AppBootstrapState.authenticatedNeedsProfile,
    );

    expect(redirect, isNull);
  });

  test('new onboarding routes stay open while profile is missing', () {
    for (final route in [
      RouteNames.fitnessSource,
      RouteNames.manualFitness,
      RouteNames.stravaAnalysis,
      RouteNames.raceTarget,
      RouteNames.strength,
      RouteNames.preferences,
      RouteNames.generatePlan,
    ]) {
      final redirect = resolveAppRedirect(
        matchedLocation: route,
        bootstrapState: AppBootstrapState.authenticatedNeedsProfile,
      );

      expect(redirect, isNull, reason: route);
    }
  });

  test('legacy onboarding routes resolve to canonical replacements', () {
    expect(
      resolveLegacyOnboardingRedirect(RouteNames.stravaConnect),
      RouteNames.fitnessSource,
    );
    expect(
      resolveLegacyOnboardingRedirect(RouteNames.fitness),
      RouteNames.manualFitness,
    );
    expect(
      resolveLegacyOnboardingRedirect(RouteNames.training),
      RouteNames.preferences,
    );
    expect(
      resolveLegacyOnboardingRedirect(RouteNames.planGeneration),
      RouteNames.generatePlan,
    );
    expect(resolveLegacyOnboardingRedirect(RouteNames.schedule), isNull);
  });

  test('authenticated ready bootstrap sends splash traffic to today', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.authenticatedReady,
    );

    expect(redirect, RouteNames.today);
  });

  test('authenticated ready bootstrap replaces auth and setup routes', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.accountSetup,
      bootstrapState: AppBootstrapState.authenticatedReady,
    );

    expect(redirect, RouteNames.today);
  });

  test('cold-start with active run resumes to active-run instead of today', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.authenticatedReady,
      hasActiveRun: true,
    );

    expect(redirect, RouteNames.activeRun);
  });

  test('active-run route is not redirected away when run is in progress', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.activeRun,
      bootstrapState: AppBootstrapState.authenticatedReady,
      hasActiveRun: true,
    );

    expect(redirect, isNull);
  });

  testWidgets('/onboarding/strength renders strength screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedNeedsProfile,
          ),
          onboardingProvider.overrideWith(_TestOnboardingNotifier.new),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);
    appRouter.go(RouteNames.strength);
    await tester.pumpAndSettle();

    expect(find.text('Strength Preferences'), findsOneWidget);
    expect(find.text('Training Preferences'), findsNothing);
  });

  testWidgets(
    'Edit Goal opens its dedicated form while New Goal keeps its intro',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            editGoalClockProvider.overrideWith(
              (ref) =>
                  () => DateTime(2026, 7, 13, 9),
            ),
            editGoalLocaleCodeProvider.overrideWithValue('en'),
            editGoalInitialDataLoaderProvider.overrideWithValue(
              () async => EditGoalInitialData(
                profile: buildRunnerProfile(),
                activePlanId: 'plan-active',
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );
      final appRouter = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);

      appRouter.go(RouteNames.settingsUpdatePlanEditGoal);
      await tester.pumpAndSettle();

      expect(find.byType(EditGoalFormScreen), findsOneWidget);
      expect(find.byType(SettingsGoalIntroScreen), findsNothing);

      appRouter.go(RouteNames.settingsUpdatePlanNewGoal);
      await tester.pumpAndSettle();

      expect(find.byType(NewGoalIntroScreen), findsOneWidget);
      expect(find.byType(EditGoalFormScreen), findsNothing);
    },
  );

  testWidgets(
    'New Goal input flow advances through race, schedule, training, health, and summary',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            newGoalInitialDataLoaderProvider.overrideWithValue(
              () async => NewGoalInitialData(
                profile: _newGoalProfileWithPlanStart(
                  date: DateTime(2026, 7, 31),
                ),
                activePlanId: 'active-plan',
              ),
            ),
            newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
            newGoalLocaleCodeProvider.overrideWithValue('en'),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );
      final appRouter = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);

      appRouter.go(RouteNames.settingsUpdatePlanNewGoalForm);
      await tester.pumpAndSettle();

      expect(find.byType(NewGoalRaceDateScreen), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(NewGoalScheduleScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(NewGoalPreferencesScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(NewGoalHealthEvidenceScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(NewGoalRecommendationScreen), findsOneWidget);
    },
  );

  testWidgets('New goal manual-result route renders a dedicated form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_fitnessCheckStateFixture()),
          ),
          newGoalLocaleCodeProvider.overrideWithValue('en'),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalManualResult);
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalManualResultScreen), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalManualResultScreen)),
    )!;
    expect(find.text(l10n.newGoalManualResultTitle), findsAtLeastNWidgets(1));
    expect(find.text(l10n.newGoalResultDistance), findsOneWidget);
    expect(find.text(l10n.newGoalResultTime), findsOneWidget);
    expect(find.text(l10n.newGoalResultDate), findsOneWidget);
    expect(find.text(l10n.newGoalHardEffortQuestion), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, l10n.newGoalManualResultUseButton),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('newGoalManualResultDistanceField')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('newGoalManualResultTimeField')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('newGoalManualResultDateField')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Fitness check screen exposes manual-result flow and opens dedicated entry form',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            newGoalProvider.overrideWith(
              () => _StaticNewGoalNotifier(_fitnessCheckStateFixture()),
            ),
            newGoalLocaleCodeProvider.overrideWithValue('en'),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );
      final appRouter = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);

      appRouter.go(RouteNames.settingsUpdatePlanNewGoalSummary);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('newGoalManualResultShortcut')));
      await tester.pumpAndSettle();

      expect(find.byType(NewGoalManualResultScreen), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NewGoalManualResultScreen)),
      )!;
      expect(find.byType(NewGoalManualResultScreen), findsOneWidget);
      expect(find.text(l10n.newGoalEnterRecentResult), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'Manual result submit uses provider boundary and navigates to recommendation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = _ManualResultSubmissionNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            newGoalProvider.overrideWith(() => notifier),
            newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 23)),
            newGoalLocaleCodeProvider.overrideWithValue('en'),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );

      final appRouter = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);

      appRouter.go(RouteNames.settingsUpdatePlanNewGoalManualResult);
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NewGoalManualResultScreen)),
      )!;
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('newGoalManualResultDistanceField')),
          matching: find.byType(TextField),
        ),
        '10',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('newGoalManualResultTimeField')),
          matching: find.byType(TextField),
        ),
        '00:45:00',
      );
      await tester.tap(find.byKey(const Key('newGoalManualResultDateField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('newGoalManualResultHardEffortYes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('newGoalManualResultHardEffortYes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AppButton, l10n.newGoalManualResultUseButton),
      );
      await tester.pumpAndSettle();

      expect(notifier.callLog, equals(['useFitnessResult', 'recommend']));
      expect(find.byType(NewGoalRecommendationScreen), findsOneWidget);
      expect(find.byType(NewGoalManualResultScreen), findsNothing);
    },
  );

  testWidgets('New Goal draft-backed values persist after back navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalInitialDataLoaderProvider.overrideWithValue(
            () async => NewGoalInitialData(
              profile: _newGoalProfileWithPlanStart(
                date: DateTime(2026, 7, 31),
              ),
              activePlanId: 'active-plan',
            ),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
          newGoalLocaleCodeProvider.overrideWithValue('en'),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final appRouter = container.read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalForm);
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalRaceDateScreen), findsOneWidget);

    await tester.tap(find.text('5K'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(NewGoalScheduleScreen), findsOneWidget);

    appRouter.pop();
    await tester.pumpAndSettle();

    final draft = _draftFromState(container.read(newGoalProvider));
    expect(draft, isNotNull);
    expect(draft!.race, RunnerGoalRace.fiveK);
    expect(draft.hasRaceDate, isFalse);
  });

  testWidgets(
    'Proposal mode renders Spanish session values with locale-aware formatting',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            newGoalProvider.overrideWith(
              () => _StaticNewGoalNotifier(_proposalReadyStateFixture()),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('es'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );
      final appRouter = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);

      appRouter.go(RouteNames.settingsUpdatePlanNewGoalProposal);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('23 jul 2026') &&
              widget.data!.contains('Carrera Suave') &&
              widget.data!.contains('5,5') &&
              widget.data!.contains('1h 35m'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Success secondary CTA routes to the plan tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_successStateFixture()),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalReady);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'View Plan'));
    await tester.pumpAndSettle();

    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.plan,
    );
  });

  testWidgets('Success screen renders Spanish strings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_successStateFixture()),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('es'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );

    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalReady);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalSuccessScreen)),
    )!;

    expect(find.text(l10n.newGoalSuccessTitle), findsOneWidget);
    expect(find.text(l10n.newGoalSuccessSubtitle), findsOneWidget);
  });

  testWidgets('New goal screens use dedicated route wrapper widgets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    Future<GoRouter> buildRouter(NewGoalState state) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userPreferencesRepositoryProvider.overrideWithValue(
              SharedPreferencesUserPreferencesRepository(prefs),
            ),
            appBootstrapStateProvider.overrideWithValue(
              AppBootstrapState.authenticatedReady,
            ),
            newGoalProvider.overrideWith(() => _StaticNewGoalNotifier(state)),
            newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final appRouter = ref.watch(appRouterProvider);
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('es')],
                routerConfig: appRouter,
              );
            },
          ),
        ),
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);
    }

    final recommendationRoute = await buildRouter(_proposalReadyStateFixture());
    recommendationRoute.go(RouteNames.settingsUpdatePlanNewGoalSummary);
    await tester.pumpAndSettle();
    expect(find.byType(NewGoalRecommendationScreen), findsOneWidget);

    final generatingRoute = await buildRouter(_fitnessCheckStateFixture());
    generatingRoute.go(RouteNames.settingsUpdatePlanNewGoalGenerating);
    await tester.pumpAndSettle();
    expect(find.byType(NewGoalFitnessScreen), findsOneWidget);

    final proposalRoute = await buildRouter(_proposalReadyStateFixture());
    proposalRoute.go(RouteNames.settingsUpdatePlanNewGoalProposal);
    await tester.pumpAndSettle();
    expect(find.byType(NewGoalProposalScreen), findsOneWidget);

    final successRoute = await buildRouter(_successStateFixture());
    successRoute.go(RouteNames.settingsUpdatePlanNewGoalReady);
    await tester.pumpAndSettle();
    expect(find.byType(NewGoalSuccessScreen), findsOneWidget);
  });

  testWidgets('Recommendation primary CTA moves to proposal route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _RecommendationTransitionNotifier(
              _recommendationReadyStateFixture(),
            ),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalSummary);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalRecommendationScreen)),
    )!;

    await tester.tap(
      find.widgetWithText(AppButton, l10n.newGoalBuildPlanPreview),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalProposalScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalProposal,
    );
  });

  testWidgets('Proposal apply CTA moves to success route', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _ApplyTransitionNotifier(_proposalReadyStateFixture()),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalProposal);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalProposalScreen)),
    )!;

    await tester.tap(
      find.widgetWithText(AppButton, l10n.newGoalReplaceCurrentPlan),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.yes));
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalSuccessScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalReady,
    );
  });

  testWidgets('Recommendation secondary CTA routes back into setup form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_recommendationReadyStateFixture()),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalSummary);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalRecommendationScreen)),
    )!;

    await tester.tap(
      find.widgetWithText(AppButton, l10n.newGoalReviewYourSetup),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalRaceDateScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalForm,
    );
  });

  testWidgets('Proposal screen renders rhythm summary and phase strategy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final proposal = _proposalFixture(
      candidatePlan: _proposalTrainingPlanFixture(
        phaseStrategy: const [
          PhaseStrategy(phase: CoachingPhase.base, weeks: 3),
          PhaseStrategy(phase: CoachingPhase.build, weeks: 4),
          PhaseStrategy(phase: CoachingPhase.specific, weeks: 5),
        ],
        sessions: [
          TrainingSession(
            id: 'proposal-session-1',
            date: DateTime(2026, 7, 24),
            type: SessionType.easyRun,
            status: SessionStatus.upcoming,
            distanceKm: 6.4,
            durationMinutes: 52,
          ),
          TrainingSession(
            id: 'proposal-session-2',
            date: DateTime(2026, 7, 24),
            type: SessionType.easyRun,
            status: SessionStatus.upcoming,
            distanceKm: 6.4,
            durationMinutes: 52,
          ),
          TrainingSession(
            id: 'proposal-session-3',
            date: DateTime(2026, 7, 25),
            type: SessionType.longRun,
            status: SessionStatus.upcoming,
            distanceKm: 16.4,
            durationMinutes: 94,
          ),
          TrainingSession(
            id: 'proposal-session-4',
            date: DateTime(2026, 7, 26),
            type: SessionType.intervals,
            status: SessionStatus.upcoming,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(
              _proposalReadyStateFixture(proposal: proposal),
            ),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );

    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalProposal);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalProposalScreen)),
    )!;

    expect(
      find.textContaining('2× ${l10n.weeklyPlanSessionEasyRun}'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1× ${l10n.weeklyPlanSessionLongRun}'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1× ${l10n.weeklyPlanSessionIntervals}'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l10n.planMetadataPhaseWeeks(l10n.planMetadataPhaseBase, 3),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l10n.planMetadataPhaseWeeks(l10n.planMetadataPhaseBuild, 4),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l10n.planMetadataPhaseWeeks(l10n.planMetadataPhaseSpecific, 5),
      ),
      findsOneWidget,
    );
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalProposal,
    );
  });

  testWidgets('Keep current plan from proposal does not apply proposal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = _ApplyTrackingProposalNotifier(
      _proposalReadyStateFixture(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(() => notifier),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalProposal);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalProposalScreen)),
    )!;

    await tester.tap(
      find.widgetWithText(AppButton, l10n.newGoalKeepCurrentPlan),
    );
    await tester.pumpAndSettle();

    expect(notifier.applyCalled, isFalse);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalSummary,
    );
  });

  testWidgets('Proposal full plan CTA navigates to new-goal full-plan route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_proposalReadyStateFixture()),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final appRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    appRouter.go(RouteNames.settingsUpdatePlanNewGoalProposal);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NewGoalProposalScreen)),
    )!;
    await tester.tap(
      find.widgetWithText(AppButton, l10n.newGoalViewFullProposedPlan),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalFullPlanScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalFullPlan,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          appBootstrapStateProvider.overrideWithValue(
            AppBootstrapState.authenticatedReady,
          ),
          newGoalProvider.overrideWith(
            () => _StaticNewGoalNotifier(_fitnessCheckStateFixture()),
          ),
          newGoalClockProvider.overrideWithValue(() => DateTime(2026, 7, 31)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final appRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              routerConfig: appRouter,
            );
          },
        ),
      ),
    );
    final unavailableRouter = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    unavailableRouter.go(RouteNames.settingsUpdatePlanNewGoalFullPlan);
    await tester.pumpAndSettle();

    expect(find.byType(NewGoalFullPlanScreen), findsOneWidget);
    expect(
      unavailableRouter.routerDelegate.currentConfiguration.uri.path,
      RouteNames.settingsUpdatePlanNewGoalFullPlan,
    );
  });
}
