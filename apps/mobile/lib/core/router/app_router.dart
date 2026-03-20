import 'package:go_router/go_router.dart';
import 'route_names.dart';
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
import '../../features/home/presentation/screens/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.splash,
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
      path: RouteNames.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
