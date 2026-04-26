import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/run_live_activity_data.dart';

abstract class RunLiveActivityBridgePort {
  Future<void> startActivity(RunLiveActivityData data);
  Future<void> updateActivity(RunLiveActivityData data);
  Future<void> endActivity();
  Stream<void> get focusActiveRunEvents;
  Stream<RunServiceEvent> events();
  Future<RunServiceState?> getRunState();
  void initNativeCallHandler();
}

class RunLiveActivityBridge implements RunLiveActivityBridgePort {
  RunLiveActivityBridge._();

  static RunLiveActivityBridgePort get instance => _instance;

  static void setInstance(RunLiveActivityBridgePort port) {
    _instance = port;
  }

  static RunLiveActivityBridgePort _instance = RunLiveActivityBridge._();

  static const channelName = 'com.davidgd616.striviq/live_activity';
  static const eventsChannelName =
      'com.davidgd616.striviq/live_activity_events';
  static const _channel = MethodChannel(channelName);
  static const _eventsChannel = EventChannel(eventsChannelName);

  final _focusController = StreamController<void>.broadcast();

  /// Emits whenever the native side asks to bring the active-run screen into
  /// focus (e.g. the user taps the Live Activity notification banner).
  @override
  Stream<void> get focusActiveRunEvents => _focusController.stream;

  /// Must be called once after [WidgetsFlutterBinding.ensureInitialized] to
  /// register the Dart-side method call handler for native→Dart messages.
  /// Call this in `main()` before `runApp()` so the handler is ready before
  /// the first Flutter frame, avoiding dropped messages on warm launch.
  @override
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

  @override
  Stream<RunServiceEvent> events() {
    if (!Platform.isAndroid) return const Stream.empty();
    return _eventsChannel.receiveBroadcastStream().map((raw) {
      if (raw is Map) {
        return RunServiceEvent.fromMap(raw.cast<Object?, Object?>());
      }
      return const RunServiceEvent.unknown();
    });
  }

  @override
  Future<void> startActivity(RunLiveActivityData data) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startActivity', data.toMap());
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] startActivity failed: $e');
    }
  }

  @override
  Future<void> updateActivity(RunLiveActivityData data) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateActivity', data.toMap());
    } catch (e) {
      debugPrint('[RunLiveActivityBridge] updateActivity failed: $e');
    }
  }

  @override
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
  @override
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
    required this.isPaused,
    required this.seeded,
  });

  final bool isPaused;
  final bool seeded;

  factory RunServiceState.fromMap(Map<Object?, Object?> map) {
    return RunServiceState(
      isPaused: (map['isPaused'] as bool?) ?? false,
      seeded: (map['seeded'] as bool?) ?? false,
    );
  }
}

class RunServiceEvent {
  const RunServiceEvent({required this.type});

  const RunServiceEvent.unknown() : type = 'unknown';

  final String type;

  bool get isFinished => type == 'finished';

  factory RunServiceEvent.fromMap(Map<Object?, Object?> map) {
    return RunServiceEvent(
      type: (map['type'] as String?) ?? 'unknown',
    );
  }
}
