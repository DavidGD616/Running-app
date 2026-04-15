import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/run_live_activity_data.dart';

void main() {
  test('toMap serialises all fields including null optionals', () {
    const data = RunLiveActivityData(
      workoutName: 'INTERVALS',
      statusLabel: 'PUSH',
      elapsedSeconds: 512,
      elapsedLabel: '08:32',
      distanceLabel: '1.42 km',
      currentPaceLabel: '5:06/km',
      avgPaceLabel: '5:57/km',
      currentBlockLabel: 'Fast rep',
      nextBlockLabel: 'Recover',
      repLabel: '3 / 6',
      isPaused: false,
    );

    final map = data.toMap();

    expect(map['workoutName'], 'INTERVALS');
    expect(map['statusLabel'], 'PUSH');
    expect(map['elapsedSeconds'], 512);
    expect(map['elapsedLabel'], '08:32');
    expect(map['distanceLabel'], '1.42 km');
    expect(map['currentPaceLabel'], '5:06/km');
    expect(map['avgPaceLabel'], '5:57/km');
    expect(map['currentBlockLabel'], 'Fast rep');
    expect(map['nextBlockLabel'], 'Recover');
    expect(map['repLabel'], '3 / 6');
    expect(map['isPaused'], false);
  });

  test('toMap serialises null optionals as null', () {
    const data = RunLiveActivityData(
      workoutName: 'EASY RUN',
      statusLabel: 'ON TARGET',
      elapsedSeconds: 1800,
      elapsedLabel: '30:00',
      distanceLabel: '5.0 km',
      currentPaceLabel: '6:00/km',
      avgPaceLabel: '6:00/km',
      currentBlockLabel: 'Easy',
      nextBlockLabel: null,
      repLabel: null,
      isPaused: true,
    );

    final map = data.toMap();

    expect(map['nextBlockLabel'], null);
    expect(map['repLabel'], null);
  });

  test('copyWith produces correct partial updates', () {
    const original = RunLiveActivityData(
      workoutName: 'INTERVALS',
      statusLabel: 'PUSH',
      elapsedSeconds: 300,
      elapsedLabel: '05:00',
      distanceLabel: '0.5 km',
      currentPaceLabel: '5:00/km',
      avgPaceLabel: '6:00/km',
      currentBlockLabel: 'Fast rep',
      nextBlockLabel: null,
      repLabel: null,
      isPaused: false,
    );

    final paused = original.copyWith(isPaused: true, statusLabel: 'PAUSED');
    expect(paused.isPaused, true);
    expect(paused.statusLabel, 'PAUSED');
    expect(paused.elapsedSeconds, 300);
    expect(paused.workoutName, 'INTERVALS');

    final updated = original.copyWith(
      elapsedSeconds: 360,
      elapsedLabel: '06:00',
      distanceLabel: '0.6 km',
    );
    expect(updated.elapsedSeconds, 360);
    expect(updated.elapsedLabel, '06:00');
    expect(updated.distanceLabel, '0.6 km');
    expect(updated.workoutName, 'INTERVALS');
  });

  test('copyWith can clear nullable labels', () {
    const original = RunLiveActivityData(
      workoutName: 'INTERVALS',
      statusLabel: 'PUSH',
      elapsedSeconds: 300,
      elapsedLabel: '05:00',
      distanceLabel: '0.5 km',
      currentPaceLabel: '5:00/km',
      avgPaceLabel: '6:00/km',
      currentBlockLabel: 'Fast rep',
      nextBlockLabel: 'Recover',
      repLabel: 'Rep 2 / 6',
      isPaused: false,
    );

    final cleared = original.copyWith(nextBlockLabel: null, repLabel: null);

    expect(cleared.nextBlockLabel, null);
    expect(cleared.repLabel, null);
    expect(cleared.workoutName, 'INTERVALS');
  });

  test('round-trip: toMap output can be reconstructed', () {
    const original = RunLiveActivityData(
      workoutName: 'TEMPO RUN',
      statusLabel: 'STEADY',
      elapsedSeconds: 2700,
      elapsedLabel: '45:00',
      distanceLabel: '7.5 km',
      currentPaceLabel: '6:00/km',
      avgPaceLabel: '6:00/km',
      currentBlockLabel: 'Tempo',
      nextBlockLabel: 'Cool-down',
      repLabel: null,
      isPaused: false,
    );

    final map = original.toMap();
    final reconstructed = RunLiveActivityData(
      workoutName: map['workoutName'] as String,
      statusLabel: map['statusLabel'] as String,
      elapsedSeconds: map['elapsedSeconds'] as int,
      elapsedLabel: map['elapsedLabel'] as String,
      distanceLabel: map['distanceLabel'] as String,
      currentPaceLabel: map['currentPaceLabel'] as String,
      avgPaceLabel: map['avgPaceLabel'] as String,
      currentBlockLabel: map['currentBlockLabel'] as String,
      nextBlockLabel: map['nextBlockLabel'] as String?,
      repLabel: map['repLabel'] as String?,
      isPaused: map['isPaused'] as bool,
    );

    expect(reconstructed.workoutName, original.workoutName);
    expect(reconstructed.statusLabel, original.statusLabel);
    expect(reconstructed.elapsedSeconds, original.elapsedSeconds);
    expect(reconstructed.elapsedLabel, original.elapsedLabel);
    expect(reconstructed.distanceLabel, original.distanceLabel);
    expect(reconstructed.currentPaceLabel, original.currentPaceLabel);
    expect(reconstructed.avgPaceLabel, original.avgPaceLabel);
    expect(reconstructed.currentBlockLabel, original.currentBlockLabel);
    expect(reconstructed.nextBlockLabel, original.nextBlockLabel);
    expect(reconstructed.repLabel, original.repLabel);
    expect(reconstructed.isPaused, original.isPaused);
  });
}
