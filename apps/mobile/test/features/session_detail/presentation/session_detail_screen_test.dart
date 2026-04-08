import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/session_detail/presentation/screens/session_detail_screen.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/activity_fixtures.dart';
import '../../../helpers/workout_fixtures.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.value);

  final TrainingPlan value;

  @override
  TrainingPlan build() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithPlan(TrainingPlan plan, TrainingSession session) {
    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(() => _TestTrainingPlanNotifier(plan)),
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
        home: SessionDetailScreen(session: session, showStartWorkout: false),
      ),
    );
  }

  testWidgets('structured session detail renders typed workout steps', (
    tester,
  ) async {
    final session = buildStructuredIntervalSession();
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.sessionDetailWorkoutStructure), findsOneWidget);
    expect(find.text(l10n.sessionDetailWarmUp), findsOneWidget);
    expect(find.text(l10n.sessionDetailCoolDown), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseIntervalsMainNote(6, '400 m')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.sessionPhaseIntervalsMainRecovery(90)),
      findsOneWidget,
    );
  });

  testWidgets('legacy session detail still renders without structured data', (
    tester,
  ) async {
    final session = buildLegacyTempoSession();
    final plan = buildTestTrainingPlan(sessions: [session]);

    await tester.pumpWidget(wrapWithPlan(plan, session));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SessionDetailScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.sessionDetailWorkoutStructure), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseTempoRunWarmDuration(10)),
      findsNWidgets(2),
    );
    expect(find.text(l10n.sessionPhaseTempoRunMainNote), findsOneWidget);
    expect(
      find.text(l10n.sessionPhaseTempoRunCoolDuration(10)),
      findsNWidgets(2),
    );
  });
}
