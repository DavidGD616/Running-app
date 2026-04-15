import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../domain/run_live_activity_data.dart';
import 'run_live_activity_bridge.dart';

const _updateRunEvent = 'updateRun';
const _endRunEvent = 'endRun';
const _stopServiceEvent = 'stopService';
const _notificationId = 61001;

class RunLiveActivityBackgroundService {
  RunLiveActivityBackgroundService._();

  static final RunLiveActivityBackgroundService instance =
      RunLiveActivityBackgroundService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _configured = false;

  Future<void> configure() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (_configured) return;

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: runLiveActivityServiceStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: false,
          foregroundServiceNotificationId: _notificationId,
          foregroundServiceTypes: const [AndroidForegroundType.health],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: runLiveActivityServiceStart,
          onBackground: runLiveActivityIosBackground,
        ),
      );
      _configured = true;
    } catch (error) {
      debugPrint('[RunLiveActivityBackgroundService] configure failed: $error');
    }
  }

  Future<void> start(RunLiveActivityData data) async {
    await _send(_updateRunEvent, data.toMap(), startIfNeeded: true);
  }

  Future<void> update(RunLiveActivityData data) async {
    await _send(_updateRunEvent, data.toMap(), startIfNeeded: true);
  }

  Future<void> stop() async {
    await _send(_endRunEvent, null, startIfNeeded: false);
    await _send(_stopServiceEvent, null, startIfNeeded: false);
  }

  Future<void> _send(
    String event,
    Map<String, dynamic>? payload, {
    required bool startIfNeeded,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      await configure();
      if (!_configured) return;
      if (startIfNeeded && !await _service.isRunning()) {
        await _service.startService();
      }
      _service.invoke(event, payload);
    } catch (error) {
      debugPrint('[RunLiveActivityBackgroundService] $event failed: $error');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> runLiveActivityIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void runLiveActivityServiceStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  service.on(_updateRunEvent).listen((event) async {
    await _invokeLiveActivityMethod('updateActivity', event);
  });

  service.on(_endRunEvent).listen((_) async {
    await _invokeLiveActivityMethod('endActivity');
  });

  service.on(_stopServiceEvent).listen((_) {
    service.stopSelf();
  });
}

Future<void> _invokeLiveActivityMethod(
  String method, [
  Map<String, dynamic>? payload,
]) async {
  try {
    await const MethodChannel(
      RunLiveActivityBridge.channelName,
    ).invokeMethod<void>(method, payload);
  } catch (error) {
    debugPrint('[RunLiveActivityBackgroundService] $method failed: $error');
  }
}
