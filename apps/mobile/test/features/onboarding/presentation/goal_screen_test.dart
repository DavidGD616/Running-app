import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/goal_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  @override
  Future<RunnerProfileDraft> build() async => const RunnerProfileDraft();
}

class _TestUserPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('goal screen hides unsupported custom race option', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingProvider.overrideWith(() => _TestOnboardingNotifier()),
          userPreferencesProvider.overrideWith(
            () => _TestUserPreferencesNotifier(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('es')],
          home: GoalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5K'), findsOneWidget);
    expect(find.text('10K'), findsOneWidget);
    expect(find.text('Half Marathon'), findsOneWidget);
    expect(find.text('Marathon'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
  });
}
