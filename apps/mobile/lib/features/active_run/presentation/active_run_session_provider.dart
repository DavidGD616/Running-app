import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../pre_run/presentation/run_flow_context.dart';

const _activeSessionKey = 'active_run_session_v2';

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

  Future<void> save(RunFlowSessionContext session) async {
    state = session;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_activeSessionKey);
  }
}

final activeRunSessionProvider =
    NotifierProvider<ActiveRunSessionNotifier, RunFlowSessionContext?>(
  ActiveRunSessionNotifier.new,
);