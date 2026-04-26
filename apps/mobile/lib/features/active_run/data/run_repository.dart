import 'package:sqflite/sqflite.dart';

import '../../../core/persistence/run_database.dart';
import '../../pre_run/presentation/run_flow_context.dart';
import '../domain/models/run_track_point.dart';

enum RunStatus {
  active,
  completed;

  static RunStatus fromString(String value) {
    return RunStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RunStatus.active,
    );
  }
}

class RunSummary {
  const RunSummary({
    required this.id,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationMs,
    this.distanceKm,
    this.sessionId,
    required this.sessionType,
    required this.timerOnly,
    this.source,
  });

  final String id;
  final RunStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final double? distanceKm;
  final String? sessionId;
  final String sessionType;
  final bool timerOnly;
  final String? source;

  factory RunSummary.fromMap(Map<String, dynamic> map) {
    return RunSummary(
      id: map['id'] as String,
      status: RunStatus.fromString(map['status'] as String),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['started_at_ms'] as int,
      ),
      endedAt: map['ended_at_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['ended_at_ms'] as int)
          : null,
      durationMs: map['duration_ms'] as int?,
      distanceKm: map['distance_km'] as double?,
      sessionId: map['session_id'] as String?,
      sessionType: (map['session_type'] as String?) ?? 'unknown',
      timerOnly: (map['timer_only'] as int) == 1,
      source: map['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.name,
      'started_at_ms': startedAt.millisecondsSinceEpoch,
      'ended_at_ms': endedAt?.millisecondsSinceEpoch,
      'duration_ms': durationMs,
      'distance_km': distanceKm,
      'session_id': sessionId,
      'session_type': sessionType,
      'timer_only': timerOnly ? 1 : 0,
      'source': source,
    };
  }

  RunSummary copyWith({
    String? id,
    RunStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMs,
    double? distanceKm,
    String? sessionId,
    String? sessionType,
    bool? timerOnly,
    String? source,
  }) {
    return RunSummary(
      id: id ?? this.id,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      distanceKm: distanceKm ?? this.distanceKm,
      sessionId: sessionId ?? this.sessionId,
      sessionType: sessionType ?? this.sessionType,
      timerOnly: timerOnly ?? this.timerOnly,
      source: source ?? this.source,
    );
  }
}

class RunSplit {
  const RunSplit({
    required this.runId,
    required this.splitIndex,
    required this.boundaryMeters,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    required this.paceSecondsPerKm,
  });

  final String runId;
  final int splitIndex;
  final int boundaryMeters;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final double paceSecondsPerKm;

  factory RunSplit.fromMap(Map<String, dynamic> map) {
    return RunSplit(
      runId: map['run_id'] as String,
      splitIndex: map['idx'] as int,
      boundaryMeters: map['boundary_meters'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['started_at_ms'] as int,
      ),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at_ms'] as int),
      durationMs: map['duration_ms'] as int,
      paceSecondsPerKm: (map['pace_seconds_per_km'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'run_id': runId,
      'idx': splitIndex,
      'boundary_meters': boundaryMeters,
      'started_at_ms': startedAt.millisecondsSinceEpoch,
      'ended_at_ms': endedAt.millisecondsSinceEpoch,
      'duration_ms': durationMs,
      'pace_seconds_per_km': paceSecondsPerKm,
    };
  }
}

class RunRoutePoint {
  const RunRoutePoint({
    required this.runId,
    required this.index,
    required this.lat,
    required this.lng,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestampMs,
  });

  final String runId;
  final int index;
  final double lat;
  final double lng;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final int timestampMs;

  factory RunRoutePoint.fromMap(Map<String, dynamic> map) {
    return RunRoutePoint(
      runId: map['run_id'] as String,
      index: map['idx'] as int,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      timestampMs: map['ts_ms'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'run_id': runId,
      'idx': index,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'ts_ms': timestampMs,
    };
  }

  factory RunRoutePoint.fromTrackPoint({
    required String runId,
    required int index,
    required RunTrackPoint point,
  }) {
    return RunRoutePoint(
      runId: runId,
      index: index,
      lat: point.latitude,
      lng: point.longitude,
      accuracy: point.accuracy,
      altitude: point.altitude,
      speed: point.speed,
      heading: point.heading,
      timestampMs: point.timestamp.millisecondsSinceEpoch,
    );
  }
}

class RunRepository {
  RunRepository({Database? db}) : _db = db;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await RunDatabase.openDatabase();
    return _db!;
  }

  Future<void> insertRun(RunSummary summary) async {
    final db = await _database;
    await db.insert('runs', summary.toMap());
  }

  Future<void> insertActiveRun({
    required String runId,
    required int startedAtMs,
    required bool timerOnly,
    required RunFlowSessionContext session,
  }) async {
    final db = await _database;
    await db.insert('runs', {
      'id': runId,
      'status': RunStatus.active.name,
      'started_at_ms': startedAtMs,
      'session_id': session.sessionId,
      'session_type': session.sessionType.name,
      'timer_only': timerOnly ? 1 : 0,
    });
  }

  Future<void> updateActiveRunSummary({
    required String runId,
    required int durationMs,
    required double distanceKm,
  }) async {
    final db = await _database;
    await db.update(
      'runs',
      {'duration_ms': durationMs, 'distance_km': distanceKm},
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  Future<void> flushPendingRoutePoints(
    String runId,
    List<RunTrackPoint> points,
  ) async {
    if (points.isEmpty) return;
    final db = await _database;
    final maxIndexResult = await db.rawQuery(
      'SELECT MAX(idx) AS max_idx FROM run_route_points WHERE run_id = ?',
      [runId],
    );
    final maxIndex = maxIndexResult.first['max_idx'] as int?;
    final startIndex = (maxIndex ?? -1) + 1;
    final batch = db.batch();
    for (final entry in points.asMap().entries) {
      final point = entry.value;
      batch.insert('run_route_points', {
        'run_id': runId,
        'idx': startIndex + entry.key,
        'lat': point.latitude,
        'lng': point.longitude,
        'accuracy': point.accuracy,
        'altitude': point.altitude,
        'speed': point.speed,
        'heading': point.heading,
        'ts_ms': point.timestamp.millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateRunSummary(RunSummary summary) async {
    final db = await _database;
    await db.update(
      'runs',
      summary.toMap(),
      where: 'id = ?',
      whereArgs: [summary.id],
    );
  }

  Future<void> insertRoutePoints(List<RunRoutePoint> points) async {
    if (points.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert('run_route_points', point.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertSplits(List<RunSplit> splits) async {
    if (splits.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final split in splits) {
      batch.insert('run_splits', split.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<RunSummary?> getRunSummary(String runId) async {
    final db = await _database;
    final results = await db.query('runs', where: 'id = ?', whereArgs: [runId]);
    if (results.isEmpty) return null;
    return RunSummary.fromMap(results.first);
  }

  Future<CompletedRunData?> getCompletedRun(String runId) async {
    final db = await _database;
    final runs = await db.query(
      'runs',
      where: 'id = ? AND status = ?',
      whereArgs: [runId, RunStatus.completed.name],
    );
    if (runs.isEmpty) return null;
    final run = runs.first;

    final splitsResult = await db.query(
      'run_splits',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'idx ASC',
    );

    final splits = splitsResult.map((s) {
      return CompletedRunSplit(
        splitIndex: s['idx'] as int,
        startedAtMs: s['started_at_ms'] as int,
        endedAtMs: s['ended_at_ms'] as int,
        durationMs: s['duration_ms'] as int,
        distanceKm: (s['boundary_meters'] as int) / 1000.0,
        paceSecondsPerKm: (s['pace_seconds_per_km'] as num).toInt(),
      );
    }).toList();

    final distanceKm = (run['distance_km'] as num?)?.toDouble() ?? 0.0;
    final durationMs = (run['duration_ms'] as num?)?.toInt() ?? 0;
    final avgPace = distanceKm > 0 && durationMs > 0
        ? ((durationMs / 1000) / distanceKm).round()
        : 0;

    return CompletedRunData(
      runId: runId,
      duration: Duration(milliseconds: durationMs),
      distanceKm: distanceKm,
      averagePaceSecondsPerKm: avgPace,
      splits: splits,
    );
  }

  Future<List<RunSummary>> getActiveRuns() async {
    final db = await _database;
    final results = await db.query(
      'runs',
      where: 'status = ?',
      whereArgs: [RunStatus.active.name],
    );
    return results.map((m) => RunSummary.fromMap(m)).toList();
  }

  Future<List<RunRoutePoint>> getRoutePoints(String runId) async {
    final db = await _database;
    final results = await db.query(
      'run_route_points',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'idx ASC',
    );
    return results.map((m) => RunRoutePoint.fromMap(m)).toList();
  }

  Future<List<RunSplit>> getSplits(String runId) async {
    final db = await _database;
    final results = await db.query(
      'run_splits',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'idx ASC',
    );
    return results.map((m) => RunSplit.fromMap(m)).toList();
  }

  Future<void> deleteRun(String runId) async {
    final db = await _database;
    await db.delete('runs', where: 'id = ?', whereArgs: [runId]);
  }

  Future<void> finishRun({
    required String runId,
    required DateTime endedAt,
    required int durationMs,
    required double distanceKm,
    required List<RunSplit> splits,
    required List<RunRoutePoint> finalPoints,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'runs',
        {
          'status': RunStatus.completed.name,
          'ended_at_ms': endedAt.millisecondsSinceEpoch,
          'duration_ms': durationMs,
          'distance_km': distanceKm,
        },
        where: 'id = ?',
        whereArgs: [runId],
      );

      if (finalPoints.isNotEmpty) {
        final batch = txn.batch();
        for (final point in finalPoints) {
          batch.insert('run_route_points', point.toMap());
        }
        await batch.commit(noResult: true);
      }

      if (splits.isNotEmpty) {
        final batch = txn.batch();
        for (final split in splits) {
          batch.insert('run_splits', split.toMap());
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
