import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../domain/run_live_activity_data.dart';
import 'run_live_activity_bridge.dart';

const _updateRunEvent = 'updateRun';
const _endRunEvent = 'endRun';
const _stopServiceEvent = 'stopService';

// Events forwarded from background isolate → main isolate.
const _forwardUpdateEvent = 'forwardToNativeUpdate';
const _forwardEndEvent = 'forwardToNativeEnd';

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
          foregroundServiceTypes: const [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: runLiveActivityServiceStart,
          onBackground: runLiveActivityIosBackground,
        ),
      );
      _configured = true;

      // On Android: listen for events forwarded from the background isolate
      // and call the bridge on the main engine (where the channel IS registered).
      if (Platform.isAndroid) {
        _service.on(_forwardUpdateEvent).listen((data) async {
          if (data == null) return;
          try {
            final activityData = RunLiveActivityData.fromMap(data);
            await RunLiveActivityBridge.instance.updateActivity(activityData);
          } catch (error) {
            debugPrint(
              '[RunLiveActivityBackgroundService] forward update failed: $error',
            );
          }
        });

        _service.on(_forwardEndEvent).listen((_) async {
          await RunLiveActivityBridge.instance.endActivity();
        });
      }
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

  // Background isolate cannot call MethodChannel directly (no handler
  // registered on the second engine). Forward events to the main isolate
  // via service.invoke; the main isolate listener in configure() picks them
  // up and calls the bridge on the engine that DOES have the handler.
  service.on(_updateRunEvent).listen((event) {
    if (event == null) return;
    service.invoke(_forwardUpdateEvent, event);
  });

  service.on(_endRunEvent).listen((_) {
    service.invoke(_forwardEndEvent, null);
  });

  service.on(_stopServiceEvent).listen((_) {
    service.stopSelf();
  });
}
