import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/pre_run/presentation/screens/pre_run_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/workout_fixtures.dart';

void main() {
  Widget wrap(PreRunArgs args) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: PreRunScreen(args: args),
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
}
