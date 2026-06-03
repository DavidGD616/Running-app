import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/core/widgets/session_row.dart';
import 'package:running_app/features/full_plan/presentation/screens/full_plan_screen.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/domain/models/race_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/support_session.dart';
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

  Widget wrapWithPlan(
    TrainingPlan plan,
    Widget child, {
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        trainingPlanProvider.overrideWith(
          () => _TestTrainingPlanNotifier(plan),
        ),
      ],
      child: wrap(child, locale: locale),
    );
  }

  DateTime currentWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  testWidgets('full plan renders race guidance and pace zones', (tester) async {
    final plan = TrainingPlan(
      id: 'full-plan-guidance',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 1),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 45,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'mobility-1',
          date: DateTime(2026, 6, 2),
          weekNumber: 1,
          type: SupplementalSessionType.mobility,
          status: SupportSessionStatus.planned,
          durationMinutes: 30,
        ),
      ],
      paceZones: const StravaPaceZones(
        recovery: StravaPaceZone(paceMinSecPerKm: 420, paceMaxSecPerKm: 460),
        easy: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
        longRun: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 300),
        steady: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 285),
        tempo: StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
        threshold: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 250),
        racePace: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 230),
        intervals: StravaPaceZone(paceMinSecPerKm: 200, paceMaxSecPerKm: 215),
        strides: StravaPaceZone(paceMinSecPerKm: 180, paceMaxSecPerKm: 190),
      ),
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Run 90% effort in the first half and finish strong.',
        warmup: '10-minute easy jog',
        primaryTarget: Duration(hours: 1, minutes: 35),
      ),
    );

    await tester.pumpWidget(wrapWithPlan(plan, const FullPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.text(l10n.planGuidancePaceZonesTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(l10n.planGuidanceRaceGuidanceTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(plan.raceGuidance!.raceDayExecution), findsOneWidget);
    expect(
      find.text(l10n.onboardingStravaAnalysisPaceZoneRecovery),
      findsOneWidget,
    );
    expect(find.textContaining('7:00'), findsOneWidget);

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(2));
    final rowTitles = rows.map((row) => row.title).toList(growable: false);
    expect(rowTitles, contains(l10n.weeklyPlanSessionEasyRun));
    expect(rowTitles, contains(l10n.planSupportMobilityLabel));
    expect(
      rowTitles,
      isNot(contains(l10n.planGuidanceRaceDayExecutionLabel)),
      reason:
          'Race-day guidance should be in guidance card, not a schedule row.',
    );
  });

  testWidgets('full plan shows support sessions in expanded week card', (
    tester,
  ) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'full-plan-support',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: weekStart,
          type: SessionType.thresholdRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 10,
          durationMinutes: 55,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'strength-1',
          date: weekStart.add(const Duration(days: 2)),
          weekNumber: 1,
          type: SupplementalSessionType.strength,
          status: SupportSessionStatus.planned,
          durationMinutes: 25,
        ),
      ],
      paceZones: null,
      raceGuidance: null,
    );

    await tester.pumpWidget(wrapWithPlan(plan, const FullPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(2));
    final rowTitles = rows.map((row) => row.title).toList(growable: false);
    expect(rowTitles, contains(l10n.sessionTypeThresholdRun));
    expect(rowTitles, contains(l10n.planSupportStrengthLabel));
  });

  testWidgets(
    'support session subtitle localizes metadata and hides canonical keys',
    (tester) async {
      final weekStart = currentWeekStart();
      final plan = TrainingPlan(
        id: 'full-plan-support-localized',
        raceType: TrainingPlanRaceType.halfMarathon,
        totalWeeks: 12,
        currentWeekNumber: 1,
        sessions: [
          TrainingSession(
            id: 'run-1',
            date: weekStart,
            type: SessionType.recoveryRun,
            status: SessionStatus.upcoming,
            weekNumber: 1,
            distanceKm: 6,
            durationMinutes: 35,
          ),
        ],
        supportSessions: [
          SupportSession(
            id: 'strength-1',
            date: weekStart.add(const Duration(days: 2)),
            weekNumber: 1,
            type: SupplementalSessionType.strength,
            status: SupportSessionStatus.planned,
            durationMinutes: 25,
            load: 'moderate',
            timingGuidance: 'on_off_days',
          ),
        ],
        paceZones: null,
        raceGuidance: null,
      );

      await tester.pumpWidget(wrapWithPlan(plan, const FullPlanScreen()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FullPlanScreen));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.textContaining(
          '${l10n.planSupportSessionLoadLabel}: ${l10n.supportSessionLoadModerate}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '${l10n.planSupportSessionTimingLabel}: ${l10n.supportSessionTimingOnOffDays}',
        ),
        findsOneWidget,
      );

      expect(find.textContaining('load: moderate'), findsNothing);
      expect(find.textContaining('timing: on_off_days'), findsNothing);
    },
  );

  testWidgets('support session subtitles are localized in Spanish', (
    tester,
  ) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'full-plan-support-localized-es',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: weekStart,
          type: SessionType.recoveryRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 6,
          durationMinutes: 35,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'strength-1',
          date: weekStart.add(const Duration(days: 2)),
          weekNumber: 1,
          type: SupplementalSessionType.strength,
          status: SupportSessionStatus.planned,
          durationMinutes: 25,
          load: 'moderate',
          timingGuidance: 'on_off_days',
        ),
      ],
      paceZones: null,
      raceGuidance: null,
    );

    await tester.pumpWidget(
      wrapWithPlan(plan, const FullPlanScreen(), locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.textContaining(
        '${l10n.planSupportSessionLoadLabel}: ${l10n.supportSessionLoadModerate}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '${l10n.planSupportSessionTimingLabel}: ${l10n.supportSessionTimingOnOffDays}',
      ),
      findsOneWidget,
    );

    expect(find.textContaining('load: moderate'), findsNothing);
    expect(find.textContaining('timing: on_off_days'), findsNothing);
  });

  testWidgets('weekly plan view includes support sessions', (tester) async {
    final weekStart = currentWeekStart();
    final plan = TrainingPlan(
      id: 'weekly-plan-support',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: weekStart.add(const Duration(days: 1)),
          type: SessionType.recoveryRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 6,
          durationMinutes: 35,
        ),
      ],
      supportSessions: [
        SupportSession(
          id: 'mobility-1',
          date: weekStart.add(const Duration(days: 1, hours: 4)),
          weekNumber: 1,
          type: SupplementalSessionType.mobility,
          status: SupportSessionStatus.planned,
          durationMinutes: 30,
        ),
      ],
      paceZones: null,
      raceGuidance: null,
    );

    await tester.pumpWidget(wrapWithPlan(plan, const WeeklyPlanScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WeeklyPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    final rows = tester
        .widgetList<SessionRow>(find.byType(SessionRow))
        .toList();
    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row.title),
      contains(l10n.planSupportMobilityLabel),
    );
  });

  testWidgets('full plan pace guidance reads in Spanish', (tester) async {
    final plan = TrainingPlan(
      id: 'full-plan-es',
      raceType: TrainingPlanRaceType.halfMarathon,
      totalWeeks: 12,
      currentWeekNumber: 1,
      sessions: [
        TrainingSession(
          id: 'run-1',
          date: DateTime(2026, 6, 1),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 45,
        ),
      ],
      paceZones: const StravaPaceZones(
        recovery: StravaPaceZone(paceMinSecPerKm: null, paceMaxSecPerKm: 420),
        easy: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
        longRun: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 300),
        steady: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 285),
        tempo: StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
        threshold: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 250),
        racePace: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 230),
        intervals: StravaPaceZone(paceMinSecPerKm: 200, paceMaxSecPerKm: 215),
        strides: StravaPaceZone(paceMinSecPerKm: 180, paceMaxSecPerKm: 190),
      ),
      raceGuidance: const RaceGuidance(
        raceDayExecution: 'Mantén ritmo controlado en el primer tramo.',
      ),
    );

    await tester.pumpWidget(
      wrapWithPlan(plan, const FullPlanScreen(), locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FullPlanScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(
      find.text(l10n.planGuidancePaceZonesTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(l10n.onboardingStravaAnalysisPaceZoneRecovery),
      findsOneWidget,
    );
    expect(find.textContaining('7:00'), findsOneWidget);
  });
}
