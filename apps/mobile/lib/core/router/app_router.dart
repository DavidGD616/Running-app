import 'package:go_router/go_router.dart';
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

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/sign-up',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/log-in',
      builder: (context, state) => const LogInScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/account-setup',
      builder: (context, state) => const AccountSetupScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingIntroScreen(),
    ),
    GoRoute(
      path: '/onboarding/goal',
      builder: (context, state) => const GoalScreen(),
    ),
    GoRoute(
      path: '/onboarding/fitness',
      builder: (context, state) => const CurrentFitnessScreen(),
    ),
    GoRoute(
      path: '/onboarding/schedule',
      builder: (context, state) => const ScheduleScreen(),
    ),
    GoRoute(
      path: '/onboarding/health',
      builder: (context, state) => const HealthInjuryScreen(),
    ),
    GoRoute(
      path: '/onboarding/training',
      builder: (context, state) => const TrainingPreferencesScreen(),
    ),
    GoRoute(
      path: '/onboarding/device',
      builder: (context, state) => const WatchDeviceScreen(),
    ),
    GoRoute(
      path: '/onboarding/recovery',
      builder: (context, state) => const RecoveryLifestyleScreen(),
    ),
    GoRoute(
      path: '/onboarding/motivation',
      builder: (context, state) => const MotivationScreen(),
    ),
    GoRoute(
      path: '/onboarding/summary',
      builder: (context, state) => const SummaryScreen(),
    ),
  ],
);
