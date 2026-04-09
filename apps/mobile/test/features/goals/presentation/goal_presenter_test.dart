import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:running_app/features/goals/presentation/goal_presenter.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/goal_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: Scaffold(body: child),
    );
  }

  testWidgets('goal presenter formats labels from the canonical goal model', (
    tester,
  ) async {
    final goal = buildHalfMarathonTimeGoal();

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Column(
              children: [
                Text(goalRaceLabel(goal, l10n)),
                Text(goalPriorityLabel(goal, l10n)),
                Text(goalDescription(goal, l10n)),
                Text(goalPlanWeeks(goal)),
                Text(formatGoalDate(context, goal)),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('Half Marathon'), findsOneWidget);
    expect(find.text('Improve my time'), findsOneWidget);
    expect(find.text('Complete a Half Marathon'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('October 18, 2026'), findsOneWidget);
  });
}
