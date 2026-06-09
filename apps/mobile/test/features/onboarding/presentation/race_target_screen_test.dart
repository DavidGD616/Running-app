import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/race_target_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/runner_profile_fixtures.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(this.value);

  final RunnerProfileDraft value;

  @override
  Future<RunnerProfileDraft> build() async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(RunnerProfileDraft draft) {
    return ProviderScope(
      overrides: [
        onboardingProvider.overrideWith(() => _TestOnboardingNotifier(draft)),
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
        home: RaceTargetScreen(),
      ),
    );
  }

  testWidgets('zero accepted target duration keeps Continue disabled', (
    tester,
  ) async {
    final draft = buildRunnerProfileDraft().copyWith(
      acceptedRaceTarget: const AcceptedRaceTarget(
        distanceKm: 21.097,
        primaryTime: Duration.zero,
        confidence: StravaDataConfidence.limited,
      ),
    );

    await tester.pumpWidget(wrap(draft));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'stale accepted target is ignored when race distance mismatches',
    (tester) async {
      final base = buildRunnerProfileDraft();
      final baseFitness = base.fitness;
      final draft = base.copyWith(
        acceptedRaceTarget: const AcceptedRaceTarget(
          distanceKm: 5,
          primaryTime: Duration(minutes: 24),
          confidence: StravaDataConfidence.high,
        ),
        fitness: FitnessProfileDraft(
          experience: baseFitness.experience,
          runningDays: baseFitness.runningDays,
          weeklyVolume: baseFitness.weeklyVolume,
          longestRun: baseFitness.longestRun,
          canCompleteGoalDistance: baseFitness.canCompleteGoalDistance,
          raceDistanceBefore: baseFitness.raceDistanceBefore,
          benchmark: baseFitness.benchmark,
          benchmarkTime: baseFitness.benchmarkTime,
          fitnessSource: 'strava',
          stravaCoachingProfile: _stravaProfileWithRaceTargets(),
        ),
      );

      await tester.pumpWidget(wrap(draft));
      await tester.pumpAndSettle();

      expect(find.text('1:55:00'), findsWidgets);
      expect(find.text('0:24:00'), findsNothing);
    },
  );
}

StravaCoachingProfile _stravaProfileWithRaceTargets() {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 42,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime.utc(2026, 6, 2, 8),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime.utc(2026, 3, 10),
      dataThroughDate: DateTime.utc(2026, 6, 2),
      activityCount: 40,
      runActivityCount: 32,
      confidence: StravaDataConfidence.high,
    ),
    dataConfidence: StravaDataConfidence.high,
    trainingBase: [evidence],
    endurance: const [],
    speedMarkers: const [],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 390, paceMaxSecPerKm: 450),
      easy: StravaPaceZone(paceMinSecPerKm: 350, paceMaxSecPerKm: 390),
      longRun: StravaPaceZone(paceMinSecPerKm: 340, paceMaxSecPerKm: 385),
      steady: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 350),
      tempo: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 325),
      threshold: StravaPaceZone(paceMinSecPerKm: 285, paceMaxSecPerKm: 305),
      racePace: StravaPaceZone(paceMinSecPerKm: 275, paceMaxSecPerKm: 290),
      intervals: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 275),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 250),
    ),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 5,
        primaryTime: const Duration(minutes: 24),
        confidence: StravaDataConfidence.high,
        evidence: [evidence],
      ),
      StravaRaceTargetEstimate(
        distanceKm: 21.097,
        primaryTime: const Duration(hours: 1, minutes: 55),
        confidence: StravaDataConfidence.high,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_threshold_durability',
      summary: 'Protect volume and build tempo durability.',
    ),
  );
}
