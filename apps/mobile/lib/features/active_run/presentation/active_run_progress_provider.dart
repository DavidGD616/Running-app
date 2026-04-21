import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';

const _activeProgressKey = 'active_run_progress_v1';

class ActiveRunProgressNotifier extends Notifier<ActiveRunProgress?> {
  @override
  ActiveRunProgress? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_activeProgressKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ActiveRunProgress.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ActiveRunProgress progress) async {
    state = progress;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_activeProgressKey, jsonEncode(progress.toJson()));
  }

  Future<void> clear() async {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_activeProgressKey);
  }
}

final activeRunProgressProvider =
    NotifierProvider<ActiveRunProgressNotifier, ActiveRunProgress?>(
  ActiveRunProgressNotifier.new,
);

class ActiveRunProgress {
  const ActiveRunProgress({
    required this.distanceKm,
    required this.accumulatedActiveMs,
    required this.timelineIndex,
    required this.blockElapsedMs,
    required this.blockDistanceKm,
    required this.currentRep,
    required this.isPaused,
    required this.isSurging,
    required this.segmentStartedAtMs,
    required this.lastTickAtMs,
  });

  final double distanceKm;
  final int accumulatedActiveMs;
  final int timelineIndex;
  final int blockElapsedMs;
  final double blockDistanceKm;
  final int currentRep;
  final bool isPaused;
  final bool isSurging;
  final int? segmentStartedAtMs;
  final int? lastTickAtMs;

  Map<String, dynamic> toJson() => {
        'distanceKm': distanceKm,
        'accumulatedActiveMs': accumulatedActiveMs,
        'timelineIndex': timelineIndex,
        'blockElapsedMs': blockElapsedMs,
        'blockDistanceKm': blockDistanceKm,
        'currentRep': currentRep,
        'isPaused': isPaused,
        'isSurging': isSurging,
        'segmentStartedAtMs': segmentStartedAtMs,
        'lastTickAtMs': lastTickAtMs,
      };

  factory ActiveRunProgress.fromJson(Map<String, dynamic> json) {
    return ActiveRunProgress(
      distanceKm: (json['distanceKm'] as num).toDouble(),
      accumulatedActiveMs: json['accumulatedActiveMs'] as int,
      timelineIndex: json['timelineIndex'] as int,
      blockElapsedMs: json['blockElapsedMs'] as int,
      blockDistanceKm: (json['blockDistanceKm'] as num).toDouble(),
      currentRep: json['currentRep'] as int,
      isPaused: json['isPaused'] as bool,
      isSurging: json['isSurging'] as bool,
      segmentStartedAtMs: json['segmentStartedAtMs'] as int?,
      lastTickAtMs: json['lastTickAtMs'] as int?,
    );
  }
}