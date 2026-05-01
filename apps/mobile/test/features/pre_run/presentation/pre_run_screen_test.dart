import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/pre_run/presentation/location_permission_service.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/pre_run/presentation/screens/pre_run_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/workout_fixtures.dart';

class _MockLocationPermissionService implements LocationPermissionService {
  _MockLocationPermissionService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget wrap(
    PreRunArgs args, {
    LocationPermissionService? locationPermissionService,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => PreRunScreen(args: args),
        ),
        GoRoute(
          path: '/active-run',
          builder: (context, state) =>
              const Scaffold(body: Text('active-run')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (locationPermissionService != null)
          locationPermissionServiceProvider.overrideWith(
            (ref) => locationPermissionService,
          ),
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

  testWidgets('renders structured interval repeat preview', (tester) async {
    final session = buildStructuredIntervalSession();
    final args = PreRunArgs.fromSession(session);

    await tester.pumpWidget(wrap(args));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PreRunScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.text(l10n.preRunWorkoutPreviewTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.preRunWorkoutPreviewWarmUp(
          l10n.preRunWorkoutPreviewDurationMinutes(10),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.preRunWorkoutPreviewRepeat(
          6,
          l10n.preRunWorkoutPreviewDistanceMeters(400),
          l10n.preRunWorkoutPreviewDurationSeconds(90),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.preRunWorkoutPreviewCoolDown(
          l10n.preRunWorkoutPreviewDurationMinutes(10),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'starts GPS run when distance workout has always permission',
    (tester) async {
      final session = buildStructuredIntervalSession();
      final args = PreRunArgs.fromSession(session);
      final service = _MockLocationPermissionService(
        serviceEnabled: true,
        permission: LocationPermission.always,
      );

      await tester.pumpWidget(
        wrap(args, locationPermissionService: service),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PreRunScreen));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.text(l10n.preRunContinue));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('active-run'), findsOneWidget);
    },
  );

  testWidgets(
    'shows Allow Always dialog when distance workout has whileInUse permission',
    (tester) async {
      final session = buildStructuredIntervalSession();
      final args = PreRunArgs.fromSession(session);
      final service = _MockLocationPermissionService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(
        wrap(args, locationPermissionService: service),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PreRunScreen));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.text(l10n.preRunContinue));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.allowAlwaysLocationTitle), findsOneWidget);
    },
  );

  testWidgets(
    'shows GPS required dialog when distance workout has denied permission',
    (tester) async {
      final session = buildStructuredIntervalSession();
      final args = PreRunArgs.fromSession(session);
      final service = _MockLocationPermissionService(
        serviceEnabled: true,
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );

      await tester.pumpWidget(
        wrap(args, locationPermissionService: service),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PreRunScreen));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.text(l10n.preRunContinue));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.gpsRequiredTitle), findsOneWidget);
    },
  );

  testWidgets(
    'allows timer-only mode for non-distance workout when GPS unavailable',
    (tester) async {
      final session = buildLegacyTempoSession();
      final args = PreRunArgs.fromSession(session);
      final service = _MockLocationPermissionService(
        serviceEnabled: false,
      );

      await tester.pumpWidget(
        wrap(args, locationPermissionService: service),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PreRunScreen));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.text(l10n.preRunContinue));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('active-run'), findsOneWidget);
    },
  );
}
