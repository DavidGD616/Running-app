import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../pre_run/presentation/run_flow_context.dart';

const _activeSessionKey = 'active_run_session_v3';
const _activeCheckInKey = 'active_run_checkin_v3';

class ActiveRunSessionNotifier extends Notifier<RunFlowSessionContext?> {
  @override
  RunFlowSessionContext? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_activeSessionKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RunFlowSessionContext.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  PreRunCheckIn? get checkIn {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_activeCheckInKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PreRunCheckIn.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RunFlowSessionContext session, [PreRunCheckIn? checkIn]) async {
    state = session;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
    if (checkIn != null) {
      await prefs.setString(_activeCheckInKey, jsonEncode(checkIn.toJson()));
    }
  }

  Future<void> clear() async {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_activeSessionKey);
    await prefs.remove(_activeCheckInKey);
  }
}

final activeRunSessionProvider =
    NotifierProvider<ActiveRunSessionNotifier, RunFlowSessionContext?>(
  ActiveRunSessionNotifier.new,
);