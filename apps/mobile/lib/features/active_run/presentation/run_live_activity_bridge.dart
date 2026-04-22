import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/run_live_activity_data.dart';

class RunLiveActivityBridge {
  RunLiveActivityBridge._();

  static final RunLiveActivityBridge instance = RunLiveActivityBridge._();

  static const channelName = 'com.davidgd616.striviq/live_activity';
  static const eventsChannelName =
      'com.davidgd616.striviq/live_activity_events';
  static const _channel = MethodChannel(channelName);
  static const _eventsChannel = EventChannel(eventsChannelName);

  final _focusController = StreamController<void>.broadcast();

  /// Emits whenever the native side asks to bring the active-run screen into
  /// focus (e.g. the user taps the Live Activity notification banner).
  Stream<void> get focusActiveRunEvents => _focusController.stream;

  /// Must be called once after [WidgetsFlutterBinding.ensureInitialized] to
  /// register the Dart-side method call handler for native→Dart messages.
  /// Call this in `main()` before `runApp()` so the handler is ready before
  /// the first Flutter frame, avoiding dropped messages on warm launch.
  void initNativeCallHandler() {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'focusActiveRun') {
        _focusController.add(null);
      }
    });
    unawaited(
      _channel.invokeMethod<void>('dartReadyForFocus').catchError((error) {
        debugPrint('[RunLiveActivityBridge] dartReadyForFocus failed: $error');
      }),
    );
  }

  Stream<RunServiceEvent> events() {
    if (!Platform.isAndroid) return const Stream.empty();
    return _eventsChannel.receiveBroadcastStream().map((raw) {
      if (raw is Map) {
        return RunServiceEvent.fromMap(raw.cast<Object?, Object?>());
      }
      return const RunServiceEvent.unknown();
    });
  }

  Future<void> startActivity(RunLiveActivityData data) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startActivity', data.toMap());
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] startActivity failed: $e');
    }
  }

  Future<void> updateActivity(RunLiveActivityData data) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateActivity', data.toMap());
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] updateActivity failed: $e');
    }
  }

  Future<void> endActivity() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('endActivity');
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] endActivity failed: $e');
    }
  }

  Future<int?> androidSdkInt() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('androidSdkInt');
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] androidSdkInt failed: $e');
      return null;
    }
  }

  /// Returns the foreground service's authoritative run state (Android only).
  /// Null if no service running or not Android.
  Future<RunServiceState?> getRunState() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getRunState',
      );
      if (raw == null) return null;
      return RunServiceState.fromMap(raw);
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] getRunState failed: $e');
      return null;
    }
  }
}

class RunServiceState {
  const RunServiceState({
    required this.distanceKm,
    required this.elapsedMs,
    required this.isPaused,
    required this.seeded,
    required this.blockIndex,
    required this.blockElapsedMs,
    required this.blockDistanceKm,
  });

  final double distanceKm;
  final int elapsedMs;
  final bool isPaused;
  final bool seeded;
  final int blockIndex;
  final int blockElapsedMs;
  final double blockDistanceKm;

  factory RunServiceState.fromMap(Map<Object?, Object?> map) {
    double dbl(String k) {
      final v = map[k];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return 0;
    }

    int intVal(String k) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return RunServiceState(
      distanceKm: dbl('distanceKm'),
      elapsedMs: intVal('elapsedMs'),
      isPaused: (map['isPaused'] as bool?) ?? false,
      seeded: (map['seeded'] as bool?) ?? false,
      blockIndex: intVal('blockIndex'),
      blockElapsedMs: intVal('blockElapsedMs'),
      blockDistanceKm: dbl('blockDistanceKm'),
    );
  }
}

class RunServiceEvent {
  const RunServiceEvent({
    required this.type,
    this.distanceKm = 0,
    this.elapsedMs = 0,
    this.blockIndex = 0,
  });

  const RunServiceEvent.unknown()
    : type = 'unknown',
      distanceKm = 0,
      elapsedMs = 0,
      blockIndex = 0;

  final String type;
  final double distanceKm;
  final int elapsedMs;
  final int blockIndex;

  bool get isFinished => type == 'finished';

  factory RunServiceEvent.fromMap(Map<Object?, Object?> map) {
    double dbl(String k) {
      final v = map[k];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return 0;
    }

    int intVal(String k) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return RunServiceEvent(
      type: (map['type'] as String?) ?? 'unknown',
      distanceKm: dbl('distanceKm'),
      elapsedMs: intVal('elapsedMs'),
      blockIndex: intVal('blockIndex'),
    );
  }
}
