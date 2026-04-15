import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/run_live_activity_data.dart';

class RunLiveActivityBridge {
  RunLiveActivityBridge._();

  static final RunLiveActivityBridge instance = RunLiveActivityBridge._();

  static const channelName = 'com.example.runningApp/live_activity';
  static const _channel = MethodChannel(channelName);

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
}
