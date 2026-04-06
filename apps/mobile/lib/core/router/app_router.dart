import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/onboarding/presentation/onboarding_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/log_in_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/account_setup/presentation/screens/account_setup_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_intro_screen.dart';
import '../../features/onboarding/presentation/screens/goal_screen.dart';
import '../../features/onboarding/presentation/screens/current_fitness_screen.dart';
import '../../features/onboarding/presentation/screens/schedule_screen.dart';
import '../../features/onboarding/presentation/screens/health_injury_screen.dart';
import '../../features/onboarding/presentation/screens/training_preferences_screen.dart';
import '../../features/onboarding/presentation/screens/watch_device_screen.dart';
import '../../features/onboarding/presentation/screens/recovery_lifestyle_screen.dart';
import '../../features/onboarding/presentation/screens/motivation_screen.dart';
import '../../features/onboarding/presentation/screens/summary_screen.dart';
import '../../features/onboarding/presentation/screens/plan_generation_screen.dart';
import '../../features/onboarding/presentation/screens/plan_ready_screen.dart';
import '../../features/home/presentation/screens/app_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/weekly_plan/presentation/screens/weekly_plan_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/settings_goal_intro_screen.dart';
import '../../features/settings/presentation/screens/settings_goal_review_screen.dart';
import '../../features/settings/presentation/screens/settings_update_plan_screen.dart';
import '../../features/settings/presentation/screens/settings_language_screen.dart';
import '../../features/settings/presentation/screens/settings_units_screen.dart';
import '../../features/settings/presentation/screens/settings_account_screen.dart';
import '../../features/settings/presentation/screens/settings_account_name_screen.dart';
import '../../features/settings/presentation/screens/settings_account_sex_screen.dart';
import '../../features/settings/presentation/screens/settings_account_security_info_screen.dart';
import '../../features/session_detail/presentation/screens/session_detail_screen.dart';
import '../../features/pre_run/presentation/screens/pre_run_screen.dart';
import '../../features/log_run/presentation/screens/log_run_screen.dart';
import '../../features/full_plan/presentation/screens/full_plan_screen.dart';
import '../../features/progress/presentation/screens/training_history_screen.dart';
import '../../features/progress/presentation/screens/completed_sessions_screen.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  redirect: (context, state) async {
    if (state.matchedLocation != RouteNames.splash) return null;
    final completed = await OnboardingNotifier.isCompleted();
    return completed ? RouteNames.today : null;
  },
  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RouteNames.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: RouteNames.signUp,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: RouteNames.logIn,
      builder: (context, state) => const LogInScreen(),
    ),
    GoRoute(
      path: RouteNames.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: RouteNames.accountSetup,
      builder: (context, state) => const AccountSetupScreen(),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      builder: (context, state) => const OnboardingIntroScreen(),
    ),
    GoRoute(
      path: RouteNames.goal,
      builder: (context, state) => const GoalScreen(),
    ),
    GoRoute(
      path: RouteNames.fitness,
      builder: (context, state) => const CurrentFitnessScreen(),
    ),
    GoRoute(
      path: RouteNames.schedule,
      builder: (context, state) => const ScheduleScreen(),
    ),
    GoRoute(
      path: RouteNames.health,
      builder: (context, state) => const HealthInjuryScreen(),
    ),
    GoRoute(
      path: RouteNames.training,
      builder: (context, state) => const TrainingPreferencesScreen(),
    ),
    GoRoute(
      path: RouteNames.device,
      builder: (context, state) => const WatchDeviceScreen(),
    ),
    GoRoute(
      path: RouteNames.recovery,
      builder: (context, state) => const RecoveryLifestyleScreen(),
    ),
    GoRoute(
      path: RouteNames.motivation,
      builder: (context, state) => const MotivationScreen(),
    ),
    GoRoute(
      path: RouteNames.summary,
      builder: (context, state) => const SummaryScreen(),
    ),
    GoRoute(
      path: RouteNames.planGeneration,
      builder: (context, state) => const PlanGenerationScreen(),
    ),
    GoRoute(
      path: RouteNames.planReady,
      builder: (context, state) => const PlanReadyScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsAccount,
      builder: (context, state) => const SettingsAccountScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsAccountName,
      builder: (context, state) => const SettingsAccountNameScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsAccountSex,
      builder: (context, state) => const SettingsAccountSexScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsAccountEmail,
      builder: (context, state) => const SettingsAccountSecurityInfoScreen(
        mode: SettingsAccountSecurityInfoMode.email,
      ),
    ),
    GoRoute(
      path: RouteNames.settingsAccountPassword,
      builder: (context, state) => const SettingsAccountSecurityInfoScreen(
        mode: SettingsAccountSecurityInfoMode.password,
      ),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlan,
      builder: (context, state) => const SettingsUpdatePlanScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanEditGoal,
      builder: (context, state) =>
          const SettingsGoalIntroScreen(mode: SettingsGoalIntroMode.editGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanEditGoalForm,
      builder: (context, state) =>
          const GoalScreen(mode: GoalFlowMode.editGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanEditGoalTraining,
      builder: (context, state) => const TrainingPreferencesScreen(
        mode: TrainingPreferencesFlowMode.editGoal,
      ),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanEditGoalSummary,
      builder: (context, state) =>
          const SettingsGoalReviewScreen(mode: SettingsGoalReviewMode.editGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanNewGoal,
      builder: (context, state) =>
          const SettingsGoalIntroScreen(mode: SettingsGoalIntroMode.newGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanNewGoalForm,
      builder: (context, state) => const GoalScreen(mode: GoalFlowMode.newGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanNewGoalTraining,
      builder: (context, state) => const TrainingPreferencesScreen(
        mode: TrainingPreferencesFlowMode.newGoal,
      ),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanNewGoalSummary,
      builder: (context, state) =>
          const SettingsGoalReviewScreen(mode: SettingsGoalReviewMode.newGoal),
    ),
    GoRoute(
      path: RouteNames.settingsUpdatePlanSchedule,
      builder: (context, state) =>
          const ScheduleScreen(isEditingPlanInfo: true),
    ),
    GoRoute(
      path: RouteNames.settingsLanguage,
      builder: (context, state) => const SettingsLanguageScreen(),
    ),
    GoRoute(
      path: RouteNames.settingsUnits,
      builder: (context, state) => const SettingsUnitsScreen(),
    ),
    GoRoute(
      path: RouteNames.sessionDetail,
      builder: (context, state) {
        final args = state.extra as SessionDetailArgs;
        return SessionDetailScreen(
          session: args.session,
          showStartWorkout: args.showStartWorkout,
        );
      },
    ),
    GoRoute(
      path: RouteNames.fullPlan,
      builder: (context, state) => const FullPlanScreen(),
    ),
    GoRoute(
      path: RouteNames.trainingHistory,
      builder: (context, state) => const TrainingHistoryScreen(),
    ),
    GoRoute(
      path: RouteNames.completedSessions,
      builder: (context, state) => const CompletedSessionsScreen(),
    ),
    GoRoute(
      path: RouteNames.preRun,
      builder: (context, state) => const PreRunScreen(),
    ),
    GoRoute(
      path: RouteNames.logRun,
      builder: (context, state) => const LogRunScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.today,
              builder: (_, _) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.plan,
              builder: (_, _) => const WeeklyPlanScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
