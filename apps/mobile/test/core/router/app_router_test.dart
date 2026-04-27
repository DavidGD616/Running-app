import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/router/app_router.dart';
import 'package:running_app/core/router/route_names.dart';

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
}
