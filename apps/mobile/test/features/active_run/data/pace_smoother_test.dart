import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/data/pace_smoother.dart';

void main() {
  group('PaceSmoother', () {
    final start = DateTime(2026, 4, 25, 8);

    test('returns pace after enough recent distance and samples', () {
      final smoother = PaceSmoother()
          .add(20, 6000, at: start.add(const Duration(seconds: 6)))
          .add(20, 6000, at: start.add(const Duration(seconds: 12)))
          .add(20, 6000, at: start.add(const Duration(seconds: 18)));

      expect(smoother.currentPaceSecondsPerKm, 300);
    });

    test('returns null until minimum sample count is reached', () {
      final smoother = PaceSmoother()
          .add(20, 6000, at: start.add(const Duration(seconds: 6)))
          .add(20, 6000, at: start.add(const Duration(seconds: 12)));

      expect(smoother.currentPaceSecondsPerKm, null);
    });

    test('returns null until minimum distance is reached', () {
      final smoother = PaceSmoother()
          .add(5, 1500, at: start.add(const Duration(seconds: 2)))
          .add(5, 1500, at: start.add(const Duration(seconds: 4)))
          .add(5, 1500, at: start.add(const Duration(seconds: 6)));

      expect(smoother.currentPaceSecondsPerKm, null);
    });

    test('keeps only points inside trailing time window', () {
      var smoother = PaceSmoother()
          .add(20, 6000, at: start.add(const Duration(seconds: 6)))
          .add(20, 6000, at: start.add(const Duration(seconds: 12)))
          .add(20, 6000, at: start.add(const Duration(seconds: 18)));

      expect(smoother.currentPaceSecondsPerKm, 300);

      smoother = smoother
          .add(30, 6000, at: start.add(const Duration(seconds: 55)))
          .add(30, 6000, at: start.add(const Duration(seconds: 61)))
          .add(30, 6000, at: start.add(const Duration(seconds: 67)));

      expect(smoother.validPoints.length, 3);
      expect(smoother.currentPaceSecondsPerKm, 200);
    });

    test('rejects unrealistic speed deltas', () {
      final smoother = PaceSmoother()
          .add(20, 6000, at: start.add(const Duration(seconds: 6)))
          .add(20, 6000, at: start.add(const Duration(seconds: 12)))
          .add(90, 5000, at: start.add(const Duration(seconds: 17)))
          .add(20, 6000, at: start.add(const Duration(seconds: 23)));

      expect(smoother.validPoints.length, 3);
      expect(smoother.currentPaceSecondsPerKm, 300);
    });

    test('reset clears all points', () {
      final smoother = PaceSmoother()
          .add(20, 6000, at: start.add(const Duration(seconds: 6)))
          .add(20, 6000, at: start.add(const Duration(seconds: 12)))
          .add(20, 6000, at: start.add(const Duration(seconds: 18)));

      final reset = smoother.reset();
      expect(reset.validPoints, isEmpty);
      expect(reset.currentPaceSecondsPerKm, null);
    });

    test('resetWithInitial starts with one accepted point', () {
      final smoother = PaceSmoother().resetWithInitial(
        20,
        6000,
        at: start.add(const Duration(seconds: 6)),
      );

      expect(smoother.validPoints.length, 1);
      expect(smoother.currentPaceSecondsPerKm, null);
    });

    test('rejects non-positive input', () {
      expect(PaceSmoother().add(0, 6000).validPoints, isEmpty);
      expect(PaceSmoother().add(-1, 6000).validPoints, isEmpty);
      expect(PaceSmoother().add(20, 0).validPoints, isEmpty);
      expect(PaceSmoother().add(20, -1).validPoints, isEmpty);
    });
  });
}
