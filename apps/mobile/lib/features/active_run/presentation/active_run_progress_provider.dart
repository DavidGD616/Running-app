import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../domain/models/gps_state.dart';
import '../domain/models/run_track_point.dart';

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
    this.runId,
    this.timerOnlyMode = false,
    this.startedAtMs,
    required this.distanceKm,
    required this.accumulatedActiveMs,
    required this.timelineIndex,
    required this.blockElapsedMs,
    required this.blockDistanceKm,
    required this.currentRep,
    required this.isPaused,
    required this.isSurging,
    this.segmentStartedAtMs,
    this.lastTickAtMs,
    this.currentPaceSecondsPerKm = 0,
    this.gpsStatus = GpsStatus.acquiring,
    this.lastAcceptedPoint,
    this.splits = const [],
  });

  final String? runId;
  final bool timerOnlyMode;
  final int? startedAtMs;
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
  final int currentPaceSecondsPerKm;
  final GpsStatus gpsStatus;
  final RunTrackPoint? lastAcceptedPoint;
  final List<SplitEntry> splits;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'timerOnlyMode': timerOnlyMode,
        'startedAtMs': startedAtMs,
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
        'currentPaceSecondsPerKm': currentPaceSecondsPerKm,
        'gpsStatus': gpsStatus.name,
        'lastAcceptedPoint': lastAcceptedPoint?.toMap(),
        'splits': splits.map((s) => s.toJson()).toList(),
      };

  factory ActiveRunProgress.fromJson(Map<String, dynamic> json) {
    final hasRunId = json.containsKey('runId');
    if (!hasRunId) {
      return _migrateFromV1(json);
    }
    return ActiveRunProgress(
      runId: json['runId'] as String?,
      timerOnlyMode: (json['timerOnlyMode'] as bool?) ?? false,
      startedAtMs: json['startedAtMs'] as int?,
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
      currentPaceSecondsPerKm:
          (json['currentPaceSecondsPerKm'] as num?)?.toInt() ?? 0,
      gpsStatus: _parseGpsStatus(json['gpsStatus'] as String?),
      lastAcceptedPoint: json['lastAcceptedPoint'] != null
          ? RunTrackPoint.fromMap(
              json['lastAcceptedPoint'] as Map<String, dynamic>)
          : null,
      splits: _parseSplits(json['splits']),
    );
  }

  static GpsStatus _parseGpsStatus(String? value) {
    if (value == null) return GpsStatus.acquiring;
    return GpsStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GpsStatus.acquiring,
    );
  }

  static List<SplitEntry> _parseSplits(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value
        .map((e) => e is Map<String, dynamic> ? SplitEntry.fromJson(e) : null)
        .whereType<SplitEntry>()
        .toList();
  }

  static ActiveRunProgress _migrateFromV1(Map<String, dynamic> json) {
    return ActiveRunProgress(
      runId: null,
      timerOnlyMode: false,
      startedAtMs: null,
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
      currentPaceSecondsPerKm: 0,
      gpsStatus: GpsStatus.acquiring,
      lastAcceptedPoint: null,
      splits: const [],
    );
  }
}

class SplitEntry {
  const SplitEntry({
    required this.splitIndex,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.durationMs,
    required this.distanceKm,
    required this.paceSecondsPerKm,
  });

  final int splitIndex;
  final int startedAtMs;
  final int endedAtMs;
  final int durationMs;
  final double distanceKm;
  final int paceSecondsPerKm;

  Map<String, dynamic> toJson() => {
        'splitIndex': splitIndex,
        'startedAtMs': startedAtMs,
        'endedAtMs': endedAtMs,
        'durationMs': durationMs,
        'distanceKm': distanceKm,
        'paceSecondsPerKm': paceSecondsPerKm,
      };

  factory SplitEntry.fromJson(Map<String, dynamic> json) {
    return SplitEntry(
      splitIndex: json['splitIndex'] as int,
      startedAtMs: json['startedAtMs'] as int,
      endedAtMs: json['endedAtMs'] as int,
      durationMs: json['durationMs'] as int,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      paceSecondsPerKm: (json['paceSecondsPerKm'] as num).toInt(),
    );
  }
}