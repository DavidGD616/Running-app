import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/core/widgets/session_row.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/features/weekly_plan/presentation/screens/weekly_plan_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

class _TestTrainingPlanNotifier extends TrainingPlanNotifier {
  _TestTrainingPlanNotifier(this.plan);

  final TrainingPlan plan;

  @override
  Future<TrainingPlan> build() async => plan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(TrainingPlan plan, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: const WeeklyPlanScreen(),
      ),
    );
  }

  testWidgets('weekly plan title uses total plan weeks', (tester) async {
    final plan = TrainingPlan(
      id: 'weekly-plan-title',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 14,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 18),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 45,
        ),
      ],
    );

    await tester.pumpWidget(wrap(plan));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WeeklyPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.weeklyPlanTitle('1', '14')), findsOneWidget);
    expect(find.text(l10n.weeklyPlanTitle('1', '18')), findsNothing);
    expect(find.byType(SessionRow), findsOneWidget);
  });
}
