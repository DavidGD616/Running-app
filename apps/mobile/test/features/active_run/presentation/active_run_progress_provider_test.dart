import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';
import 'package:running_app/features/active_run/presentation/active_run_progress_provider.dart';

void main() {
  group('ActiveRunProgress', () {
    test('toJson and fromJson round-trip preserves all fields', () {
      final progress = ActiveRunProgress(
        runId: 'run_123',
        timerOnlyMode: false,
        startedAtMs: 1714032000000,
        distanceKm: 2.5,
        accumulatedActiveMs: 900000,
        timelineIndex: 2,
        blockElapsedMs: 180000,
        blockDistanceKm: 0.4,
        currentRep: 3,
        isPaused: false,
        isSurging: false,
        segmentStartedAtMs: 1714032900000,
        lastTickAtMs: 1714032950000,
        currentPaceSecondsPerKm: 360,
        gpsStatus: GpsStatus.ready,
        lastAcceptedPoint: RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime(2026, 4, 25, 10, 30, 0),
          accuracy: 5.0,
          altitude: 10.5,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        ),
        splits: [
          SplitEntry(
            splitIndex: 0,
            startedAtMs: 1714032000000,
            endedAtMs: 1714032060000,
            durationMs: 60000,
            distanceKm: 1.0,
            paceSecondsPerKm: 360,
          ),
        ],
      );

      final json = progress.toJson();
      final restored = ActiveRunProgress.fromJson(json);

      expect(restored.runId, progress.runId);
      expect(restored.timerOnlyMode, progress.timerOnlyMode);
      expect(restored.startedAtMs, progress.startedAtMs);
      expect(restored.distanceKm, progress.distanceKm);
      expect(restored.accumulatedActiveMs, progress.accumulatedActiveMs);
      expect(restored.timelineIndex, progress.timelineIndex);
      expect(restored.blockElapsedMs, progress.blockElapsedMs);
      expect(restored.blockDistanceKm, progress.blockDistanceKm);
      expect(restored.currentRep, progress.currentRep);
      expect(restored.isPaused, progress.isPaused);
      expect(restored.isSurging, progress.isSurging);
      expect(restored.segmentStartedAtMs, progress.segmentStartedAtMs);
      expect(restored.lastTickAtMs, progress.lastTickAtMs);
      expect(restored.currentPaceSecondsPerKm, progress.currentPaceSecondsPerKm);
      expect(restored.gpsStatus, progress.gpsStatus);
      expect(restored.lastAcceptedPoint?.latitude,
          progress.lastAcceptedPoint?.latitude);
      expect(restored.lastAcceptedPoint?.longitude,
          progress.lastAcceptedPoint?.longitude);
      expect(restored.splits.length, progress.splits.length);
      expect(restored.splits[0].splitIndex, progress.splits[0].splitIndex);
    });

    test('toJson serializes lastAcceptedPoint as map', () {
      final progress = ActiveRunProgress(
        runId: 'run_123',
        timerOnlyMode: false,
        startedAtMs: 1714032000000,
        distanceKm: 1.0,
        accumulatedActiveMs: 600000,
        timelineIndex: 0,
        blockElapsedMs: 0,
        blockDistanceKm: 0.0,
        currentRep: 0,
        isPaused: false,
        isSurging: false,
        segmentStartedAtMs: null,
        lastTickAtMs: null,
        currentPaceSecondsPerKm: 0,
        gpsStatus: GpsStatus.acquiring,
        lastAcceptedPoint: null,
        splits: const [],
      );

      final json = progress.toJson();
      expect(json['lastAcceptedPoint'], isNull);
    });

    test('fromJson handles null lastAcceptedPoint', () {
      final json = {
        'runId': 'run_123',
        'timerOnlyMode': false,
        'startedAtMs': 1714032000000,
        'distanceKm': 1.0,
        'accumulatedActiveMs': 600000,
        'timelineIndex': 0,
        'blockElapsedMs': 0,
        'blockDistanceKm': 0.0,
        'currentRep': 0,
        'isPaused': false,
        'isSurging': false,
        'segmentStartedAtMs': null,
        'lastTickAtMs': null,
        'currentPaceSecondsPerKm': 0,
        'gpsStatus': 'acquiring',
        'lastAcceptedPoint': null,
        'splits': [],
      };

      final progress = ActiveRunProgress.fromJson(json);
      expect(progress.lastAcceptedPoint, isNull);
    });

    test('fromJson handles missing splits key', () {
      final json = {
        'runId': 'run_123',
        'timerOnlyMode': false,
        'startedAtMs': 1714032000000,
        'distanceKm': 1.0,
        'accumulatedActiveMs': 600000,
        'timelineIndex': 0,
        'blockElapsedMs': 0,
        'blockDistanceKm': 0.0,
        'currentRep': 0,
        'isPaused': false,
        'isSurging': false,
        'segmentStartedAtMs': null,
        'lastTickAtMs': null,
        'currentPaceSecondsPerKm': 0,
        'gpsStatus': 'ready',
      };

      final progress = ActiveRunProgress.fromJson(json);
      expect(progress.splits, isEmpty);
    });

    test('fromJson handles unknown gpsStatus gracefully', () {
      final json = {
        'runId': 'run_123',
        'timerOnlyMode': false,
        'startedAtMs': 1714032000000,
        'distanceKm': 1.0,
        'accumulatedActiveMs': 600000,
        'timelineIndex': 0,
        'blockElapsedMs': 0,
        'blockDistanceKm': 0.0,
        'currentRep': 0,
        'isPaused': false,
        'isSurging': false,
        'segmentStartedAtMs': null,
        'lastTickAtMs': null,
        'currentPaceSecondsPerKm': 0,
        'gpsStatus': 'unknown_status',
        'lastAcceptedPoint': null,
        'splits': [],
      };

      final progress = ActiveRunProgress.fromJson(json);
      expect(progress.gpsStatus, GpsStatus.acquiring);
    });

    group('v1 migration', () {
      test('fromJson migrates v1 data without runId', () {
        final v1Json = {
          'distanceKm': 2.5,
          'accumulatedActiveMs': 900000,
          'timelineIndex': 2,
          'blockElapsedMs': 180000,
          'blockDistanceKm': 0.4,
          'currentRep': 3,
          'isPaused': false,
          'isSurging': false,
          'segmentStartedAtMs': 1714032900000,
          'lastTickAtMs': 1714032950000,
        };

        final progress = ActiveRunProgress.fromJson(v1Json);

        expect(progress.runId, isNull);
        expect(progress.timerOnlyMode, false);
        expect(progress.startedAtMs, isNull);
        expect(progress.distanceKm, 2.5);
        expect(progress.accumulatedActiveMs, 900000);
        expect(progress.timelineIndex, 2);
        expect(progress.blockElapsedMs, 180000);
        expect(progress.blockDistanceKm, 0.4);
        expect(progress.currentRep, 3);
        expect(progress.isPaused, false);
        expect(progress.isSurging, false);
        expect(progress.currentPaceSecondsPerKm, 0);
        expect(progress.gpsStatus, GpsStatus.acquiring);
        expect(progress.lastAcceptedPoint, isNull);
        expect(progress.splits, isEmpty);
      });

      test('fromJson migrates v1 data with missing optional fields', () {
        final v1Json = {
          'distanceKm': 1.0,
          'accumulatedActiveMs': 600000,
          'timelineIndex': 0,
          'blockElapsedMs': 0,
          'blockDistanceKm': 0.0,
          'currentRep': 0,
          'isPaused': true,
          'isSurging': false,
        };

        final progress = ActiveRunProgress.fromJson(v1Json);
        expect(progress.isPaused, true);
        expect(progress.segmentStartedAtMs, isNull);
        expect(progress.lastTickAtMs, isNull);
      });

      test('v1 migration does not crash on empty string runId', () {
        final v1Json = {
          'runId': '',
          'distanceKm': 1.0,
          'accumulatedActiveMs': 600000,
          'timelineIndex': 0,
          'blockElapsedMs': 0,
          'blockDistanceKm': 0.0,
          'currentRep': 0,
          'isPaused': false,
          'isSurging': false,
          'segmentStartedAtMs': null,
          'lastTickAtMs': null,
        };

        final progress = ActiveRunProgress.fromJson(v1Json);
        expect(progress.runId, '');
      });
    });
  });

  group('SplitEntry', () {
    test('toJson and fromJson round-trip preserves all fields', () {
      final split = SplitEntry(
        splitIndex: 2,
        startedAtMs: 1714032000000,
        endedAtMs: 1714032060000,
        durationMs: 60000,
        distanceKm: 1.0,
        paceSecondsPerKm: 360,
      );

      final json = split.toJson();
      final restored = SplitEntry.fromJson(json);

      expect(restored.splitIndex, split.splitIndex);
      expect(restored.startedAtMs, split.startedAtMs);
      expect(restored.endedAtMs, split.endedAtMs);
      expect(restored.durationMs, split.durationMs);
      expect(restored.distanceKm, split.distanceKm);
      expect(restored.paceSecondsPerKm, split.paceSecondsPerKm);
    });

    test('fromJson handles integer distance values', () {
      final json = {
        'splitIndex': 0,
        'startedAtMs': 1714032000000,
        'endedAtMs': 1714032060000,
        'durationMs': 60000,
        'distanceKm': 1,
        'paceSecondsPerKm': 360,
      };

      final split = SplitEntry.fromJson(json);
      expect(split.distanceKm, 1.0);
      expect(split.paceSecondsPerKm, 360);
    });
  });
}
