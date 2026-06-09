import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/live_pace_guidance.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

LivePaceGuidanceEvaluator createEvaluator() => LivePaceGuidanceEvaluator();

WorkoutTarget targetForZone(
  TargetZone zone, {
  int paceMin = 300,
  int paceMax = 360,
}) => WorkoutTarget.pace(
  zone,
  paceMinSecPerKm: paceMin,
  paceMaxSecPerKm: paceMax,
);

LivePaceGuidanceInput input({
  DateTime? now,
  required int pace,
  required WorkoutTarget target,
  required Duration runElapsed,
  Duration blockElapsed = const Duration(seconds: 20),
  WorkoutTarget? fallbackTarget,
  int timelineIndex = 0,
  bool isPaused = false,
  bool isTimerOnlyMode = false,
  bool isGpsReady = true,
}) {
  final nowOrDefault =
      now ??
      DateTime(2026, 4, 25, 10).add(Duration(seconds: runElapsed.inSeconds));

  return LivePaceGuidanceInput(
    currentPaceSecondsPerKm: pace,
    currentBlockTarget: target,
    fallbackTarget: fallbackTarget ?? target,
    fallbackZone: target.zone,
    runElapsed: runElapsed,
    blockElapsed: blockElapsed,
    timelineIndex: timelineIndex,
    isPaused: isPaused,
    isTimerOnlyMode: isTimerOnlyMode,
    isGpsReady: isGpsReady,
    now: nowOrDefault,
  );
}

void main() {
  group('LivePaceGuidanceEvaluator', () {
    test('does not warn for tiny deviations', () {
      final evaluator = createEvaluator();
      final easy = targetForZone(TargetZone.easy);

      final result = evaluator.evaluate(
        input(pace: 280, target: easy, runElapsed: const Duration(seconds: 50)),
      );

      expect(result.action, LivePaceGuidanceAction.none);
      expect(result.messageKey, isNull);
      expect(result.severity, LivePaceGuidanceSeverity.none);
    });

    test('ignores a single outlier and requires sustained samples', () {
      final evaluator = createEvaluator();
      final easy = targetForZone(TargetZone.easy);

      evaluator.evaluate(
        input(pace: 300, target: easy, runElapsed: const Duration(seconds: 50)),
      );

      final result = evaluator.evaluate(
        input(pace: 250, target: easy, runElapsed: const Duration(seconds: 55)),
      );

      expect(result.action, LivePaceGuidanceAction.none);
      expect(result.messageKey, isNull);
    });

    test('warns only after sustained too-fast deviation', () {
      final evaluator = createEvaluator();
      final easy = targetForZone(TargetZone.easy);

      evaluator.evaluate(
        input(pace: 300, target: easy, runElapsed: const Duration(seconds: 50)),
      );
      evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 60)),
      );
      evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 70)),
      );
      final result = evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 80)),
      );

      expect(result.action, LivePaceGuidanceAction.tooFast);
      expect(result.messageKey, 'activeRunEaseOffFirm');
      expect(result.severity, LivePaceGuidanceSeverity.firm);
    });

    test('suppresses repeated prompts within cooldown window', () {
      final evaluator = createEvaluator();
      final easy = targetForZone(TargetZone.easy);

      evaluator.evaluate(
        input(pace: 300, target: easy, runElapsed: const Duration(seconds: 50)),
      );
      evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 60)),
      );
      evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 70)),
      );
      evaluator.evaluate(
        input(pace: 255, target: easy, runElapsed: const Duration(seconds: 80)),
      );

      final duringCooldown = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 115),
        ),
      );
      expect(duringCooldown.action, LivePaceGuidanceAction.none);

      evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 150),
        ),
      );
      evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 160),
        ),
      );
      final afterCooldown = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 170),
        ),
      );

      expect(afterCooldown.action, LivePaceGuidanceAction.tooFast);
      expect(afterCooldown.messageKey, 'activeRunEaseOffFirm');
    });

    test(
      'falls back to fallback target paces when block target has only a zone',
      () {
        final evaluator = createEvaluator();
        final blockZoneOnly = WorkoutTarget.pace(TargetZone.interval);
        final fallbackTarget = targetForZone(
          TargetZone.easy,
          paceMin: 300,
          paceMax: 360,
        );

        evaluator.evaluate(
          input(
            pace: 300,
            target: blockZoneOnly,
            runElapsed: const Duration(seconds: 50),
            fallbackTarget: fallbackTarget,
          ),
        );
        evaluator.evaluate(
          input(
            pace: 291,
            target: blockZoneOnly,
            runElapsed: const Duration(seconds: 60),
            fallbackTarget: fallbackTarget,
          ),
        );
        evaluator.evaluate(
          input(
            pace: 291,
            target: blockZoneOnly,
            runElapsed: const Duration(seconds: 70),
            fallbackTarget: fallbackTarget,
          ),
        );
        final result = evaluator.evaluate(
          input(
            pace: 291,
            target: blockZoneOnly,
            runElapsed: const Duration(seconds: 80),
            fallbackTarget: fallbackTarget,
          ),
        );

        expect(result.action, LivePaceGuidanceAction.tooFast);
        expect(result.severity, LivePaceGuidanceSeverity.gentle);
        expect(result.messageKey, 'activeRunEaseOff');
      },
    );

    test('uses block zone when fallback target supplies pace band', () {
      final evaluator = createEvaluator();
      final blockIntervalZoneOnly = WorkoutTarget.pace(TargetZone.interval);
      final fallbackEasy = targetForZone(
        TargetZone.easy,
        paceMin: 320,
        paceMax: 380,
      );

      evaluator.evaluate(
        input(
          pace: 320,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 50),
          fallbackTarget: fallbackEasy,
        ),
      );
      evaluator.evaluate(
        input(
          pace: 312,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 60),
          fallbackTarget: fallbackEasy,
        ),
      );
      final noWarn = evaluator.evaluate(
        input(
          pace: 312,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 70),
          fallbackTarget: fallbackEasy,
        ),
      );
      expect(noWarn.action, LivePaceGuidanceAction.none);

      evaluator.evaluate(
        input(
          pace: 311,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 80),
          fallbackTarget: fallbackEasy,
        ),
      );

      evaluator.evaluate(
        input(
          pace: 311,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 90),
          fallbackTarget: fallbackEasy,
        ),
      );

      final tooFast = evaluator.evaluate(
        input(
          pace: 311,
          target: blockIntervalZoneOnly,
          runElapsed: const Duration(seconds: 100),
          fallbackTarget: fallbackEasy,
        ),
      );
      expect(tooFast.action, LivePaceGuidanceAction.tooFast);
    });

    test('resets sustained state on timeline index change', () {
      final evaluator = createEvaluator();
      final easy = targetForZone(TargetZone.easy);

      evaluator.evaluate(
        input(
          pace: 300,
          target: easy,
          runElapsed: const Duration(seconds: 50),
          timelineIndex: 0,
        ),
      );
      evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 60),
          timelineIndex: 0,
        ),
      );
      evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 70),
          timelineIndex: 0,
        ),
      );
      final preReset = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 80),
          timelineIndex: 0,
        ),
      );
      expect(preReset.action, LivePaceGuidanceAction.tooFast);

      final immediateAfterReset = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 100),
          timelineIndex: 1,
          blockElapsed: const Duration(seconds: 2),
        ),
      );
      expect(immediateAfterReset.action, LivePaceGuidanceAction.none);

      final delayedAfterReset = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 190),
          timelineIndex: 1,
          blockElapsed: const Duration(seconds: 20),
        ),
      );
      final delayedAfterReset2 = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 200),
          timelineIndex: 1,
          blockElapsed: const Duration(seconds: 20),
        ),
      );
      final delayedAfterReset3 = evaluator.evaluate(
        input(
          pace: 255,
          target: easy,
          runElapsed: const Duration(seconds: 210),
          timelineIndex: 1,
          blockElapsed: const Duration(seconds: 20),
        ),
      );

      expect(delayedAfterReset.action, LivePaceGuidanceAction.none);
      expect(delayedAfterReset2.action, LivePaceGuidanceAction.none);
      expect(delayedAfterReset3.action, LivePaceGuidanceAction.tooFast);
    });

    test('flags too-fast as firm and too-slow as gentle for easy/long', () {
      final evaluator = createEvaluator();
      final longRun = targetForZone(TargetZone.longRun);

      evaluator.evaluate(
        input(
          pace: 255,
          target: longRun,
          runElapsed: const Duration(seconds: 60),
        ),
      );
      evaluator.evaluate(
        input(
          pace: 255,
          target: longRun,
          runElapsed: const Duration(seconds: 70),
        ),
      );
      final tooFast = evaluator.evaluate(
        input(
          pace: 255,
          target: longRun,
          runElapsed: const Duration(seconds: 80),
        ),
      );
      expect(tooFast.action, LivePaceGuidanceAction.tooFast);
      expect(tooFast.severity, LivePaceGuidanceSeverity.firm);

      final tooSlow = evaluator.evaluate(
        input(
          pace: 440,
          target: longRun,
          runElapsed: const Duration(seconds: 220),
          blockElapsed: const Duration(seconds: 20),
        ),
      );
      final tooSlow2 = evaluator.evaluate(
        input(
          pace: 440,
          target: longRun,
          runElapsed: const Duration(seconds: 230),
          blockElapsed: const Duration(seconds: 20),
        ),
      );
      final tooSlow3 = evaluator.evaluate(
        input(
          pace: 440,
          target: longRun,
          runElapsed: const Duration(seconds: 240),
          blockElapsed: const Duration(seconds: 20),
        ),
      );
      expect(tooSlow.action, LivePaceGuidanceAction.none);
      expect(tooSlow2.action, LivePaceGuidanceAction.none);
      expect(tooSlow3.action, LivePaceGuidanceAction.tooSlow);
      expect(tooSlow3.severity, LivePaceGuidanceSeverity.gentle);
    });

    test('interval and race tolerances are narrower than easy', () {
      final easy = targetForZone(TargetZone.easy);
      final interval = targetForZone(TargetZone.interval);
      final race = targetForZone(TargetZone.racePace);

      final easyEvaluator = createEvaluator();
      easyEvaluator.evaluate(
        input(pace: 280, target: easy, runElapsed: const Duration(seconds: 60)),
      );
      easyEvaluator.evaluate(
        input(pace: 280, target: easy, runElapsed: const Duration(seconds: 70)),
      );
      final easyResult = easyEvaluator.evaluate(
        input(pace: 280, target: easy, runElapsed: const Duration(seconds: 80)),
      );
      expect(easyResult.action, LivePaceGuidanceAction.none);

      final intervalEvaluator = createEvaluator();
      intervalEvaluator.evaluate(
        input(
          pace: 280,
          target: interval,
          runElapsed: const Duration(seconds: 60),
        ),
      );
      intervalEvaluator.evaluate(
        input(
          pace: 280,
          target: interval,
          runElapsed: const Duration(seconds: 70),
        ),
      );
      final intervalResult = intervalEvaluator.evaluate(
        input(
          pace: 280,
          target: interval,
          runElapsed: const Duration(seconds: 80),
        ),
      );
      expect(intervalResult.action, LivePaceGuidanceAction.tooFast);

      final raceEvaluator = createEvaluator();
      raceEvaluator.evaluate(
        input(pace: 280, target: race, runElapsed: const Duration(seconds: 60)),
      );
      raceEvaluator.evaluate(
        input(pace: 280, target: race, runElapsed: const Duration(seconds: 70)),
      );
      final raceResult = raceEvaluator.evaluate(
        input(pace: 280, target: race, runElapsed: const Duration(seconds: 80)),
      );
      expect(raceResult.action, LivePaceGuidanceAction.tooFast);
    });

    test(
      'never alerts during pause, timer-only, gps-not-ready, or with zero pace',
      () {
        final evaluator = createEvaluator();
        final easy = targetForZone(TargetZone.easy);

        expect(
          evaluator
              .evaluate(
                input(
                  pace: 255,
                  target: easy,
                  runElapsed: const Duration(seconds: 80),
                  isPaused: true,
                ),
              )
              .action,
          LivePaceGuidanceAction.none,
        );
        expect(
          evaluator
              .evaluate(
                input(
                  pace: 255,
                  target: easy,
                  runElapsed: const Duration(seconds: 90),
                  isTimerOnlyMode: true,
                ),
              )
              .action,
          LivePaceGuidanceAction.none,
        );
        expect(
          evaluator
              .evaluate(
                input(
                  pace: 255,
                  target: easy,
                  runElapsed: const Duration(seconds: 100),
                  isGpsReady: false,
                ),
              )
              .action,
          LivePaceGuidanceAction.none,
        );
        expect(
          evaluator
              .evaluate(
                input(
                  pace: 0,
                  target: easy,
                  runElapsed: const Duration(seconds: 110),
                ),
              )
              .action,
          LivePaceGuidanceAction.none,
        );
      },
    );
  });
}
