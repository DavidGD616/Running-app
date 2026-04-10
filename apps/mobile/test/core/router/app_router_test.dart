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

  test('authenticated ready bootstrap sends splash traffic to today', () {
    final redirect = resolveAppRedirect(
      matchedLocation: RouteNames.splash,
      bootstrapState: AppBootstrapState.authenticatedReady,
    );

    expect(redirect, RouteNames.today);
  });
}
