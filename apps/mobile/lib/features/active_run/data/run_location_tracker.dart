import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/models/run_track_point.dart';

const double maxAccuracyMeters = 60.0;
const int distanceFilterMeters = 5;
const Duration intervalDuration = Duration(seconds: 1);

abstract class RunLocationTracker {
  Stream<RunTrackPoint> get points;

  void start();

  void stop();
}

class GeolocatorRunLocationTracker implements RunLocationTracker {
  GeolocatorRunLocationTracker({
    required this.notificationTitle,
    required this.notificationBody,
    required PositionStreamFactory positionStreamFactory,
  })  : _positionStreamFactory = positionStreamFactory;

  final String notificationTitle;
  final String notificationBody;
  final PositionStreamFactory _positionStreamFactory;

  StreamController<RunTrackPoint>? _controller;
  StreamSubscription<Position>? _subscription;
  bool _isStarted = false;

  @override
  Stream<RunTrackPoint> get points {
    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<RunTrackPoint>.broadcast();
    }
    return _controller!.stream;
  }

  @override
  void start() {
    if (_isStarted) return;
    _isStarted = true;

    _controller ??= StreamController<RunTrackPoint>.broadcast();

    final locationSettings = _buildLocationSettings();

    _subscription = _positionStreamFactory(locationSettings).listen(
      _onPosition,
      onError: _onError,
    );
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _isStarted = false;
    _controller?.close();
    _controller = null;
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        intervalDuration: intervalDuration,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationBody,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }

  @protected
  void _onPosition(Position position) {
    if (position.accuracy > maxAccuracyMeters) return;

    final point = RunTrackPoint.fromPosition(position);
    _controller?.add(point);
  }

  void _onError(Object error) {
    _controller?.addError(error);
  }
}

typedef PositionStreamFactory = Stream<Position> Function(
    LocationSettings locationSettings);
