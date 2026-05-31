import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/core/widgets/settings_row.dart';
import 'package:running_app/features/integrations/data/device_connection_repository.dart';
import 'package:running_app/features/settings/presentation/screens/settings_integrations_screen.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_values.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/integration_fixtures.dart';

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

    final appleToggle = rows.where((row) {
      return row.label == l10n.settingsAppleHealth &&
          row.variant == SettingsRowVariant.toggleOn;
    }).toList(growable: false);
    expect(appleToggle, hasLength(1));
    expect(appleToggle.single.onToggle, isNotNull);

    final garminBadge = rows.where((row) {
      return row.label ==
              OnboardingValues.localizeDevice(OnboardingValues.deviceGarmin, l10n) &&
          row.variant == SettingsRowVariant.badge;
    }).toList(growable: false);
    expect(garminBadge, hasLength(1));
    expect(garminBadge.single.badgeLabel, l10n.settingsConnected);

    debugDefaultTargetPlatformOverride = previousPlatform;
  });
}
