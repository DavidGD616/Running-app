import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/features/settings/presentation/screens/settings_goal_intro_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(393, 852);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: child,
    );
  }

  testWidgets('new goal intro copy does not promise custom distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SettingsGoalIntroScreen(mode: SettingsGoalIntroMode.newGoal),
        locale: const Locale('es'),
      ),
    );

    expect(find.textContaining('personalizada'), findsNothing);
    expect(find.textContaining('prioridad'), findsNothing);
    expect(find.textContaining('tiempos objetivo'), findsNothing);
    expect(find.textContaining('distancia de carrera'), findsOneWidget);
  });
}
