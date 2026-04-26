import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/data/pace_smoother.dart';

void main() {
  group('PaceSmoother', () {
    group('steady pace', () {
      test('returns pace after 5 valid points', () {
        final smoother = PaceSmoother();

        // 1000m in 300000ms (5 min) = 300 sec/km
        // 1000m in 300000ms (5 min) = 300 sec/km
        // 1000m in 300000ms (5 min) = 300 sec/km
        // 1000m in 300000ms (5 min) = 300 sec/km
        // 1000m in 300000ms (5 min) = 300 sec/km
        final result = smoother
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000);

        expect(result.currentPaceSecondsPerKm, 300);
      });

      test('returns null until 5 points collected', () {
        var smoother = PaceSmoother();

        smoother = smoother.add(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, null);

        smoother = smoother.add(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, null);

        smoother = smoother.add(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, null);

        smoother = smoother.add(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, null);

        smoother = smoother.add(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, 300);
      });
    });

    group('rolling window', () {
      test('uses last 5 points when more are added', () {
        var smoother = PaceSmoother();

        // First 5 points: 5 min/km (300 sec/km)
        smoother = smoother
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000);

        expect(smoother.currentPaceSecondsPerKm, 300);

        // 6th point: 4 min/km (240 sec/km)
        smoother = smoother.add(1000.0, 240000);

        // Should now use last 5: 4 + 300*4 = 1440 / 5 = 288 sec/km
        expect(
            smoother.currentPaceSecondsPerKm,
            allOf(
              greaterThan(280),
              lessThan(290),
            ));
      });
    });

    group('reset', () {
      test('reset clears all points', () {
        final smoother = PaceSmoother()
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000)
            .add(1000.0, 300000);

        expect(smoother.currentPaceSecondsPerKm, 300);

        final reset = smoother.reset();
        expect(reset.currentPaceSecondsPerKm, null);
        expect(reset.validPoints, isEmpty);
      });

      test('resetWithInitial starts with one point', () {
        final smoother =
            PaceSmoother().resetWithInitial(1000.0, 300000);
        expect(smoother.currentPaceSecondsPerKm, null);
        expect(smoother.validPoints.length, 1);
      });
    });

    group('invalid data filtering', () {
      test('rejects zero distance', () {
        final smoother =
            PaceSmoother().add(0.0, 300000);
        expect(smoother.validPoints, isEmpty);
        expect(smoother.currentPaceSecondsPerKm, null);
      });

      test('rejects negative distance', () {
        final smoother =
            PaceSmoother().add(-100.0, 300000);
        expect(smoother.validPoints, isEmpty);
        expect(smoother.currentPaceSecondsPerKm, null);
      });

      test('rejects zero duration', () {
        final smoother =
            PaceSmoother().add(1000.0, 0);
        expect(smoother.validPoints, isEmpty);
        expect(smoother.currentPaceSecondsPerKm, null);
      });

      test('rejects negative duration', () {
        final smoother =
            PaceSmoother().add(1000.0, -100);
        expect(smoother.validPoints, isEmpty);
        expect(smoother.currentPaceSecondsPerKm, null);
      });
    });

    group('pace calculation edge cases', () {
      test('handles very slow pace', () {
        // 1000m in 600000ms (10 min) = 600 sec/km
        final smoother = PaceSmoother()
            .add(1000.0, 600000)
            .add(1000.0, 600000)
            .add(1000.0, 600000)
            .add(1000.0, 600000)
            .add(1000.0, 600000);

        expect(smoother.currentPaceSecondsPerKm, 600);
      });

      test('handles very fast pace', () {
        // 1000m in 150000ms (2.5 min) = 150 sec/km
        final smoother = PaceSmoother()
            .add(1000.0, 150000)
            .add(1000.0, 150000)
            .add(1000.0, 150000)
            .add(1000.0, 150000)
            .add(1000.0, 150000);

        expect(smoother.currentPaceSecondsPerKm, 150);
      });

      test('handles varying distances in window', () {
        var smoother = PaceSmoother();

        // p1: 500m in 150s = 300 sec/km
        smoother = smoother.add(500.0, 150000);
        // p2: 1500m in 450s = 300 sec/km
        smoother = smoother.add(1500.0, 450000);
        // p3: 1000m in 300s = 300 sec/km
        smoother = smoother.add(1000.0, 300000);
        // p4: 800m in 240s = 300 sec/km
        smoother = smoother.add(800.0, 240000);
        // p5: 1200m in 360s = 300 sec/km
        smoother = smoother.add(1200.0, 360000);

        expect(smoother.currentPaceSecondsPerKm, 300);
      });
    });
  });
}
