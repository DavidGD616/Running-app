import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:running_app/features/active_run/data/run_location_tracker.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';

class FakeRunLocationTracker implements RunLocationTracker {
  FakeRunLocationTracker({
    this.notificationTitle = 'Tracking Run',
    this.notificationBody = 'Recording your run',
  });

  final String notificationTitle;
  final String notificationBody;

  final _controller = StreamController<RunTrackPoint>.broadcast();
  bool _started = false;

  @override
  Stream<RunTrackPoint> get points => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
  }

  @override
  void stop() {
    _started = false;
    _controller.close();
  }

  void addPoint(RunTrackPoint point) {
    _controller.add(point);
  }
}

Stream<Position> fakePositionStreamFactory(LocationSettings settings) {
  final controller = StreamController<Position>();
  return controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunLocationTracker interface', () {
    test('points returns a stream', () {
      final tracker = FakeRunLocationTracker();
      expect(tracker.points, isA<Stream<RunTrackPoint>>());
      tracker.stop();
    });

    test('start() can be called', () {
      final tracker = FakeRunLocationTracker();
      expect(() => tracker.start(), returnsNormally);
      tracker.stop();
    });

    test('stop() can be called', () {
      final tracker = FakeRunLocationTracker();
      tracker.start();
      expect(() => tracker.stop(), returnsNormally);
    });

    test('duplicate start does not throw', () {
      final tracker = FakeRunLocationTracker();
      tracker.start();
      expect(() => tracker.start(), returnsNormally);
      tracker.stop();
    });
  });

  group('GeolocatorRunLocationTracker', () {
    test('start() can be called without throwing', () {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      expect(() => tracker.start(), returnsNormally);
      tracker.stop();
    });

    test('stop() can be called after start without throwing', () {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();
      expect(() => tracker.stop(), returnsNormally);
    });

    test('duplicate start does not throw', () {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();
      expect(() => tracker.start(), returnsNormally);
      tracker.stop();
    });

    test('points returns a broadcast stream', () async {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      final stream1 = tracker.points;
      final stream2 = tracker.points;

      final receivedOnStream1 = <RunTrackPoint>[];
      final receivedOnStream2 = <RunTrackPoint>[];
      stream1.listen(receivedOnStream1.add);
      stream2.listen(receivedOnStream2.add);

      tracker.start();

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      await Future.delayed(Duration.zero);

      expect(receivedOnStream1.length, 1);
      expect(receivedOnStream2.length, 1);
      expect(receivedOnStream1[0].latitude, receivedOnStream2[0].latitude);

      tracker.stop();
    });

    test('emits positions from position stream', () async {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();

      final receivedPoints = <RunTrackPoint>[];
      tracker.points.listen(receivedPoints.add);

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      await Future.delayed(Duration.zero);

      expect(receivedPoints.length, 1);
      expect(receivedPoints[0].latitude, 37.7749);

      tracker.stop();
    });
  });

  group('RunTrackPoint accuracy filtering', () {
    test('points with accuracy > 60m are filtered out', () async {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();

      final receivedPoints = <RunTrackPoint>[];
      tracker.points.listen(receivedPoints.add);

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      controller.add(Position(
        latitude: 37.7750,
        longitude: -122.4195,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      await Future.delayed(Duration.zero);

      expect(receivedPoints.length, 2);
      expect(receivedPoints[0].accuracy, 10.0);
      expect(receivedPoints[1].accuracy, 10.0);

      tracker.stop();
    });

    test('points with accuracy exactly 60m are accepted', () async {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();

      final receivedPoints = <RunTrackPoint>[];
      tracker.points.listen(receivedPoints.add);

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 60.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      await Future.delayed(Duration.zero);

      expect(receivedPoints.length, 1);
      expect(receivedPoints[0].accuracy, 60.0);

      tracker.stop();
    });

    test('points with accuracy exactly 60.01m are filtered out', () async {
      final controller = StreamController<Position>();
      final tracker = GeolocatorRunLocationTracker(
        notificationTitle: 'Test Title',
        notificationBody: 'Test Body',
        positionStreamFactory: (_) => controller.stream,
      );
      tracker.start();

      final receivedPoints = <RunTrackPoint>[];
      tracker.points.listen(receivedPoints.add);

      controller.add(Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 60.01,
        altitude: 100.0,
        heading: 0.0,
        speed: 5.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        speedAccuracy: 1.0,
      ));

      await Future.delayed(Duration.zero);

      expect(receivedPoints.length, 0);

      tracker.stop();
    });
  });
}
