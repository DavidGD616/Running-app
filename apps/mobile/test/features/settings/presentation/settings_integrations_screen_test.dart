import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/widgets/settings_row.dart';
import 'package:running_app/features/integrations/data/device_connection_repository.dart';
import 'package:running_app/features/integrations/domain/models/device_connection.dart';
import 'package:running_app/features/strava/data/strava_service.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';
import 'package:running_app/features/settings/presentation/screens/settings_integrations_screen.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_values.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/integration_fixtures.dart';

class _DisconnectFailingStravaService implements StravaService {
  int disconnectCallCount = 0;

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    throw const StravaServiceException(StravaServiceErrorCode.disconnectFailed);
  }

  @override
  Future<StravaAthlete> fetchAthlete() {
    throw UnimplementedError();
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() {
    throw UnimplementedError();
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TargetPlatform? previousPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  testWidgets('settings integrations screen renders persisted typed state', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesDeviceConnectionRepository(prefs);
    await repository.saveConnections([
      buildAppleHealthConnection(
        connectedAt: DateTime(2026, 4, 7, 9, 15),
        lastSyncedAt: DateTime(2026, 4, 7, 10, 0),
      ),
      buildGarminWearableConnection(
        connectedAt: DateTime(2026, 4, 6, 7, 30),
        lastSyncedAt: DateTime(2026, 4, 7, 9, 45),
        seededFromOnboarding: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: const SettingsIntegrationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsIntegrationsScreen)),
    )!;
    final rows = tester
        .widgetList<SettingsRow>(find.byType(SettingsRow))
        .toList();

    expect(rows, hasLength(4));

    final appleToggle = rows
        .where((row) {
          return row.label == l10n.settingsAppleHealth &&
              row.variant == SettingsRowVariant.toggleOn;
        })
        .toList(growable: false);
    expect(appleToggle, hasLength(1));
    expect(appleToggle.single.onToggle, isNotNull);

    final garminBadge = rows
        .where((row) {
          return row.label ==
                  OnboardingValues.localizeDevice(
                    OnboardingValues.deviceGarmin,
                    l10n,
                  ) &&
              row.variant == SettingsRowVariant.badge;
        })
        .toList(growable: false);
    expect(garminBadge, hasLength(1));
    expect(garminBadge.single.badgeLabel, l10n.settingsConnected);

    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  testWidgets(
    'failed Strava disconnect keeps local connection state unchanged',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesDeviceConnectionRepository(prefs);
      await repository.saveConnections([
        buildDeviceConnection(
          id: 'strava',
          vendor: IntegrationVendor.strava,
          kind: DeviceConnectionKind.service,
          state: DeviceConnectionState.connected,
          capabilities: {
            IntegrationCapability.autoImport,
            IntegrationCapability.distance,
            IntegrationCapability.heartRate,
            IntegrationCapability.heartRateZones,
            IntegrationCapability.pace,
            IntegrationCapability.elevation,
          },
          connectedAt: DateTime(2026, 4, 7, 9, 15),
          lastSyncedAt: DateTime(2026, 4, 7, 10, 0),
        ),
      ]);

      final stravaService = _DisconnectFailingStravaService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stravaServiceProvider.overrideWithValue(stravaService),
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
            home: const SettingsIntegrationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsIntegrationsScreen)),
      )!;
      final stravaToggle = find.byWidgetPredicate(
        (widget) =>
            widget is Switch && widget.value && widget.onChanged != null,
        description: 'Strava connected toggle',
      );
      expect(stravaToggle, findsOneWidget);

      await tester.tap(stravaToggle);
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStravaDisconnectError), findsOneWidget);
      expect(stravaService.disconnectCallCount, 1);

      final persisted = repository.loadConnectionByVendor(
        IntegrationVendor.strava,
      );
      expect(persisted, isNotNull);
      expect(persisted!.isConnected, isTrue);

      final stravaRows = tester
          .widgetList<SettingsRow>(find.byType(SettingsRow))
          .where((row) => row.label == l10n.settingsStrava)
          .toList(growable: false);
      expect(
        stravaRows.any((row) => row.variant == SettingsRowVariant.toggleOn),
        isTrue,
      );

      debugDefaultTargetPlatformOverride = previousPlatform;
    },
  );
}
