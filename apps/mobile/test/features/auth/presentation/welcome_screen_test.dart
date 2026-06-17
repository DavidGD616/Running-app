import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() {
    return const ProviderScope(
      child: MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('es')],
        home: WelcomeScreen(),
      ),
    );
  }

  testWidgets('Google sign-in button exposes a stable semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WelcomeScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.continueWithGoogle), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.continueWithGoogle), findsOneWidget);
  });
}
