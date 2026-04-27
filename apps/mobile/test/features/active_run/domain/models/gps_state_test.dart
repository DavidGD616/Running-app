import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';

void main() {
  group('GpsState.initial', () {
    test('creates acquiring state', () {
      final state = GpsState.initial();
      expect(state.status, GpsStatus.acquiring);
      expect(state.lastFix, isNull);
    });
  });

  group('GpsStatus transitions', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    GpsFix accurateFix() => GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          timestamp: now,
        );

    GpsFix weakFix() => GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 45,
          timestamp: now,
        );

    GpsFix poorFix() => GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 100,
          timestamp: now,
        );

    test('recordFix with accuracy <= 30m transitions to ready', () {
      final state = GpsState.initial();
      final updated = state.recordFix(accurateFix());
      expect(updated.status, GpsStatus.ready);
      expect(updated.lastFix?.accuracy, 10);
      expect(updated.isReady, true);
    });

    test('recordFix with 30m < accuracy <= 60m transitions to weak', () {
      final state = GpsState.initial();
      final updated = state.recordFix(weakFix());
      expect(updated.status, GpsStatus.weak);
      expect(updated.lastFix?.accuracy, 45);
      expect(updated.isWeak, true);
    });

    test('recordFix with accuracy > 60m transitions to lost', () {
      final state = GpsState.initial();
      final updated = state.recordFix(poorFix());
      expect(updated.status, GpsStatus.lost);
      expect(updated.lastFix?.accuracy, 100);
      expect(updated.isLost, true);
    });

    test('accurate fix from weak transitions to ready', () {
      final state = GpsState.initial().recordFix(weakFix());
      expect(state.status, GpsStatus.weak);
      final updated = state.recordFix(accurateFix());
      expect(updated.status, GpsStatus.ready);
    });

    test('weak fix from ready transitions to weak', () {
      final state = GpsState.initial().recordFix(accurateFix());
      expect(state.status, GpsStatus.ready);
      final updated = state.recordFix(weakFix());
      expect(updated.status, GpsStatus.weak);
    });

    test('poor fix from ready transitions to lost', () {
      final state = GpsState.initial().recordFix(accurateFix());
      expect(state.status, GpsStatus.ready);
      final updated = state.recordFix(poorFix());
      expect(updated.status, GpsStatus.lost);
    });

    test('accurate fix after poor fix transitions to ready', () {
      final state = GpsState.initial().recordFix(poorFix());
      expect(state.status, GpsStatus.lost);
      final updated = state.recordFix(accurateFix());
      expect(updated.status, GpsStatus.ready);
    });
  });

  group('disable/enable', () {
    test('disable transitions to disabled', () {
      final state = GpsState.initial().recordFix(
            GpsFix(
              latitude: 37.7749,
              longitude: -122.4194,
              accuracy: 10,
              timestamp: DateTime.now(),
            ),
          );
      expect(state.status, GpsStatus.ready);
      final disabled = state.disable();
      expect(disabled.status, GpsStatus.disabled);
      expect(disabled.lastFix, isNotNull);
    });

    test('enable transitions to acquiring and clears lastFix', () {
      final state = GpsState.initial()
          .recordFix(GpsFix(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            timestamp: DateTime.now(),
          ))
          .disable();
      expect(state.status, GpsStatus.disabled);
      final reenabled = state.enable();
      expect(reenabled.status, GpsStatus.acquiring);
      expect(reenabled.lastFix, isNull);
    });
  });

  group('checkLost', () {
    test('transitions to lost when no fix received', () {
      final state = GpsState.initial();
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.lost);
    });

    test('transitions to lost when last fix is older than 10 seconds', () {
      final oldTimestamp = DateTime.now().subtract(const Duration(seconds: 11));
      final state = GpsState(
        status: GpsStatus.ready,
        lastFix: GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          timestamp: oldTimestamp,
        ),
        lastStatusChange: oldTimestamp,
      );
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.lost);
    });

    test('stays ready when last fix is recent', () {
      final recentTimestamp = DateTime.now().subtract(const Duration(seconds: 5));
      final state = GpsState(
        status: GpsStatus.ready,
        lastFix: GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          timestamp: recentTimestamp,
        ),
        lastStatusChange: recentTimestamp,
      );
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.ready);
    });

    test('stays weak when last fix is recent', () {
      final recentTimestamp = DateTime.now().subtract(const Duration(seconds: 5));
      final state = GpsState(
        status: GpsStatus.weak,
        lastFix: GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 45,
          timestamp: recentTimestamp,
        ),
        lastStatusChange: recentTimestamp,
      );
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.weak);
    });

    test('disabled state is not affected by checkLost', () {
      final state = GpsState(
        status: GpsStatus.disabled,
        lastFix: GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          timestamp: DateTime.now().subtract(const Duration(seconds: 20)),
        ),
        lastStatusChange: DateTime.now(),
      );
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.disabled);
    });

    test('already lost state is not affected by checkLost', () {
      final state = GpsState(
        status: GpsStatus.lost,
        lastFix: GpsFix(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          timestamp: DateTime.now().subtract(const Duration(seconds: 20)),
        ),
        lastStatusChange: DateTime.now(),
      );
      final updated = state.checkLost();
      expect(updated.status, GpsStatus.lost);
    });
  });

  group('lastStatusChange', () {
    test('updates when status changes', () {
      final initial = GpsState.initial();
      final before = initial.lastStatusChange;
      final now = DateTime.now().add(const Duration(seconds: 1));

      final updated = initial.recordFix(GpsFix(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10,
        timestamp: now,
      ));

      expect(
        updated.lastStatusChange.isAfter(before) ||
            updated.lastStatusChange.isAtSameMomentAs(before),
        true,
      );
    });

    test('does not update when status stays the same', () {
      final now = DateTime.now();
      final fix = GpsFix(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10,
        timestamp: now,
      );
      final state = GpsState.initial().recordFix(fix);
      final statusChangeTime = state.lastStatusChange;

      final updated = state.recordFix(GpsFix(
        latitude: 37.7750,
        longitude: -122.4195,
        accuracy: 15,
        timestamp: now.add(const Duration(seconds: 1)),
      ));

      expect(updated.lastStatusChange, statusChangeTime);
    });
  });

  group('GpsFix helpers', () {
    test('isAccurate returns true when accuracy <= 30', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 30,
        timestamp: DateTime.now(),
      );
      expect(fix.isAccurate, true);
    });

    test('isAccurate returns false when accuracy > 30', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 31,
        timestamp: DateTime.now(),
      );
      expect(fix.isAccurate, false);
    });

    test('isWeak returns true when 30 < accuracy <= 60', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 60,
        timestamp: DateTime.now(),
      );
      expect(fix.isWeak, true);
    });

    test('isWeak returns false when accuracy <= 30', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 30,
        timestamp: DateTime.now(),
      );
      expect(fix.isWeak, false);
    });

    test('isWeak returns false when accuracy > 60', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 61,
        timestamp: DateTime.now(),
      );
      expect(fix.isWeak, false);
    });

    test('isPoor returns true when accuracy > 60', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 61,
        timestamp: DateTime.now(),
      );
      expect(fix.isPoor, true);
    });

    test('isPoor returns false when accuracy <= 60', () {
      final fix = GpsFix(
        latitude: 0,
        longitude: 0,
        accuracy: 60,
        timestamp: DateTime.now(),
      );
      expect(fix.isPoor, false);
    });
  });

  group('copyWith', () {
    test('preserves status when not overridden', () {
      final state = GpsState.initial().recordFix(GpsFix(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10,
        timestamp: DateTime.now(),
      ));
      final copied = state.copyWith();
      expect(copied.status, state.status);
    });

    test('preserves lastFix when not overridden', () {
      final fix = GpsFix(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10,
        timestamp: DateTime.now(),
      );
      final state = GpsState.initial().recordFix(fix);
      final copied = state.copyWith();
      expect(copied.lastFix?.latitude, fix.latitude);
    });

    test('can update status', () {
      final state = GpsState.initial();
      final copied = state.copyWith(status: GpsStatus.disabled);
      expect(copied.status, GpsStatus.disabled);
    });

    test('can update lastFix', () {
      final state = GpsState.initial();
      final newFix = GpsFix(
        latitude: 40.0,
        longitude: -80.0,
        accuracy: 5,
        timestamp: DateTime.now(),
      );
      final copied = state.copyWith(lastFix: newFix);
      expect(copied.lastFix?.latitude, 40.0);
    });
  });
}
