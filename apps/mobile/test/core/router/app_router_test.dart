import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/core/router/app_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  @override
  Future<RunnerProfileDraft> build() async => const RunnerProfileDraft();
}

void main() {
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
}
