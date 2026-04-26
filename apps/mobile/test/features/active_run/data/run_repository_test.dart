import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:running_app/features/active_run/data/run_repository.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late RunRepository repository;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE runs (
              id TEXT PRIMARY KEY,
              status TEXT NOT NULL,
              started_at_ms INTEGER NOT NULL,
              ended_at_ms INTEGER,
              duration_ms INTEGER,
              distance_km REAL,
              session_id TEXT,
              session_type TEXT,
              timer_only INTEGER NOT NULL DEFAULT 0,
              source TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE run_route_points (
              run_id TEXT NOT NULL,
              idx INTEGER NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL,
              accuracy REAL NOT NULL,
              altitude REAL,
              speed REAL,
              heading REAL,
              ts_ms INTEGER NOT NULL,
              PRIMARY KEY (run_id, idx),
              FOREIGN KEY (run_id) REFERENCES runs (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE run_splits (
              run_id TEXT NOT NULL,
              idx INTEGER NOT NULL,
              boundary_meters INTEGER NOT NULL,
              started_at_ms INTEGER NOT NULL,
              ended_at_ms INTEGER NOT NULL,
              duration_ms INTEGER NOT NULL,
              pace_seconds_per_km REAL NOT NULL,
              PRIMARY KEY (run_id, idx),
              FOREIGN KEY (run_id) REFERENCES runs (id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );
    repository = RunRepository(db: db);
  });

  tearDown(() async {
    await repository.deleteRun('test-run-1');
    await repository.deleteRun('test-run-2');
    await repository.deleteRun('batch-test-run');
    await repository.deleteRun('finish-test-run');
  });

  group('RunRepository', () {
    group('insertRun and getRunSummary', () {
      test('inserts and retrieves a run summary', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );

        await repository.insertRun(summary);
        final retrieved = await repository.getRunSummary('test-run-1');

        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'test-run-1');
        expect(retrieved.status, RunStatus.active);
        expect(retrieved.sessionType, 'easy_run');
        expect(retrieved.timerOnly, false);
      });

      test('returns null for non-existent run', () async {
        final retrieved = await repository.getRunSummary('non-existent');
        expect(retrieved, isNull);
      });

      test('stores canonical session type key, not localized text', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );

        await repository.insertRun(summary);
        final retrieved = await repository.getRunSummary('test-run-1');

        expect(retrieved!.sessionType, 'easy_run');
        expect(retrieved.sessionType, isNot(contains('Easy Run')));
        expect(retrieved.sessionType, isNot(contains('Carrera Fácil')));
      });
    });

    group('updateRunSummary', () {
      test('updates existing run summary fields', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );

        await repository.insertRun(summary);

        final updated = summary.copyWith(
          status: RunStatus.completed,
          endedAt: DateTime(2026, 4, 25, 11, 0, 0),
          durationMs: 3600000,
          distanceKm: 5.0,
        );

        await repository.updateRunSummary(updated);
        final retrieved = await repository.getRunSummary('test-run-1');

        expect(retrieved!.status, RunStatus.completed);
        expect(retrieved.endedAt, isNotNull);
        expect(retrieved.durationMs, 3600000);
        expect(retrieved.distanceKm, 5.0);
      });
    });

    group('insertRoutePoints and getRoutePoints', () {
      test('batch inserts and retrieves route points', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        final points = List.generate(
          10,
          (i) => RunRoutePoint(
            runId: 'test-run-1',
            index: i,
            lat: 37.7749 + i * 0.0001,
            lng: -122.4194 + i * 0.0001,
            accuracy: 10.0,
            altitude: 100.0 + i,
            speed: 5.0,
            heading: 0.0,
            timestampMs: DateTime(2026, 4, 25, 10, 0, i).millisecondsSinceEpoch,
          ),
        );

        await repository.insertRoutePoints(points);
        final retrieved = await repository.getRoutePoints('test-run-1');

        expect(retrieved.length, 10);
        expect(retrieved.first.lat, 37.7749);
        expect(retrieved.last.lat, 37.7749 + 9 * 0.0001);
        expect(retrieved[0].accuracy, 10.0);
        expect(retrieved[0].altitude, 100.0);
      });

      test('inserting empty list does not throw', () async {
        await repository.insertRoutePoints([]);
      });

      test('round-trip preserves point data', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        final point = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime(2026, 4, 25, 10, 0, 0),
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );

        final routePoint = RunRoutePoint.fromTrackPoint(
          runId: 'test-run-1',
          index: 0,
          point: point,
        );

        await repository.insertRoutePoints([routePoint]);
        final retrieved = await repository.getRoutePoints('test-run-1');

        expect(retrieved.length, 1);
        expect(retrieved[0].lat, 37.7749);
        expect(retrieved[0].lng, -122.4194);
        expect(retrieved[0].accuracy, 10.0);
        expect(retrieved[0].altitude, 100.0);
        expect(retrieved[0].speed, 5.0);
        expect(retrieved[0].heading, 180.0);
        expect(
          retrieved[0].timestampMs,
          point.timestamp.millisecondsSinceEpoch,
        );
      });

      test('flushPendingRoutePoints appends indexes across calls', () async {
        final summary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        RunTrackPoint point(int offsetSeconds) {
          return RunTrackPoint(
            latitude: 37.7749 + offsetSeconds * 0.00001,
            longitude: -122.4194,
            timestamp: DateTime(2026, 4, 25, 10, 0, offsetSeconds),
            accuracy: 10.0,
            altitude: 100.0,
            speed: 5.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          );
        }

        await repository.flushPendingRoutePoints('test-run-1', [
          point(0),
          point(1),
        ]);
        await repository.flushPendingRoutePoints('test-run-1', [
          point(2),
          point(3),
        ]);

        final retrieved = await repository.getRoutePoints('test-run-1');
        expect(retrieved.map((p) => p.index), [0, 1, 2, 3]);
      });
    });

    group('insertSplits and getSplits', () {
      test('batch inserts and retrieves splits', () async {
        final runSummary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(runSummary);

        final splits = [
          RunSplit(
            runId: 'test-run-1',
            splitIndex: 0,
            boundaryMeters: 1000,
            startedAt: DateTime(2026, 4, 25, 10, 0, 0),
            endedAt: DateTime(2026, 4, 25, 10, 5, 0),
            durationMs: 300000,
            paceSecondsPerKm: 300.0,
          ),
          RunSplit(
            runId: 'test-run-1',
            splitIndex: 1,
            boundaryMeters: 2000,
            startedAt: DateTime(2026, 4, 25, 10, 5, 0),
            endedAt: DateTime(2026, 4, 25, 10, 10, 0),
            durationMs: 300000,
            paceSecondsPerKm: 300.0,
          ),
        ];

        await repository.insertSplits(splits);
        final retrieved = await repository.getSplits('test-run-1');

        expect(retrieved.length, 2);
        expect(retrieved[0].boundaryMeters, 1000);
        expect(retrieved[0].paceSecondsPerKm, 300.0);
        expect(retrieved[1].boundaryMeters, 2000);
      });

      test('inserting empty list does not throw', () async {
        await repository.insertSplits([]);
      });
    });

    group('deleteRun', () {
      test('deleting a run removes runs, route points, and splits', () async {
        final summary = RunSummary(
          id: 'test-run-2',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        final points = [
          RunRoutePoint(
            runId: 'test-run-2',
            index: 0,
            lat: 37.7749,
            lng: -122.4194,
            accuracy: 10.0,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
        await repository.insertRoutePoints(points);

        final splits = [
          RunSplit(
            runId: 'test-run-2',
            splitIndex: 0,
            boundaryMeters: 1000,
            startedAt: DateTime.now(),
            endedAt: DateTime.now(),
            durationMs: 300000,
            paceSecondsPerKm: 300.0,
          ),
        ];
        await repository.insertSplits(splits);

        await repository.deleteRun('test-run-2');

        final retrievedSummary = await repository.getRunSummary('test-run-2');
        final retrievedPoints = await repository.getRoutePoints('test-run-2');
        final retrievedSplits = await repository.getSplits('test-run-2');

        expect(retrievedSummary, isNull);
        expect(retrievedPoints, isEmpty);
        expect(retrievedSplits, isEmpty);
      });
    });

    group('finishRun', () {
      test(
        'updates run to completed and inserts final points and splits',
        () async {
          final summary = RunSummary(
            id: 'finish-test-run',
            status: RunStatus.active,
            startedAt: DateTime(2026, 4, 25, 10, 0, 0),
            sessionType: 'easy_run',
            timerOnly: false,
          );
          await repository.insertRun(summary);

          final finalPoints = [
            RunRoutePoint(
              runId: 'finish-test-run',
              index: 0,
              lat: 37.7749,
              lng: -122.4194,
              accuracy: 10.0,
              timestampMs: DateTime(
                2026,
                4,
                25,
                11,
                0,
                0,
              ).millisecondsSinceEpoch,
            ),
            RunRoutePoint(
              runId: 'finish-test-run',
              index: 1,
              lat: 37.7750,
              lng: -122.4195,
              accuracy: 10.0,
              timestampMs: DateTime(
                2026,
                4,
                25,
                11,
                0,
                30,
              ).millisecondsSinceEpoch,
            ),
          ];

          final splits = [
            RunSplit(
              runId: 'finish-test-run',
              splitIndex: 0,
              boundaryMeters: 1000,
              startedAt: DateTime(2026, 4, 25, 10, 0, 0),
              endedAt: DateTime(2026, 4, 25, 10, 5, 0),
              durationMs: 300000,
              paceSecondsPerKm: 300.0,
            ),
          ];

          await repository.finishRun(
            runId: 'finish-test-run',
            endedAt: DateTime(2026, 4, 25, 11, 0, 0),
            durationMs: 3600000,
            distanceKm: 5.0,
            splits: splits,
            finalPoints: finalPoints,
          );

          final retrieved = await repository.getRunSummary('finish-test-run');
          expect(retrieved, isNotNull);
          expect(retrieved!.status, RunStatus.completed);
          expect(retrieved.durationMs, 3600000);
          expect(retrieved.distanceKm, 5.0);
          expect(retrieved.endedAt, isNotNull);

          final retrievedPoints = await repository.getRoutePoints(
            'finish-test-run',
          );
          expect(retrievedPoints.length, 2);

          final retrievedSplits = await repository.getSplits('finish-test-run');
          expect(retrievedSplits.length, 1);
          expect(retrievedSplits[0].paceSecondsPerKm, 300.0);
        },
      );
    });

    group('getActiveRuns', () {
      test('returns only active runs', () async {
        final activeSummary = RunSummary(
          id: 'test-run-1',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(activeSummary);

        final completedSummary = RunSummary(
          id: 'test-run-2',
          status: RunStatus.completed,
          startedAt: DateTime(2026, 4, 24, 10, 0, 0),
          endedAt: DateTime(2026, 4, 24, 11, 0, 0),
          durationMs: 3600000,
          distanceKm: 5.0,
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(completedSummary);

        final activeRuns = await repository.getActiveRuns();

        expect(activeRuns.length, 1);
        expect(activeRuns[0].id, 'test-run-1');
        expect(activeRuns[0].status, RunStatus.active);
      });
    });

    group('batch insert optimization', () {
      test('batch inserts 25 points at once', () async {
        final summary = RunSummary(
          id: 'batch-test-run',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        final points = List.generate(
          25,
          (i) => RunRoutePoint(
            runId: 'batch-test-run',
            index: i,
            lat: 37.7749 + i * 0.00001,
            lng: -122.4194 + i * 0.00001,
            accuracy: 10.0,
            timestampMs: DateTime.now().millisecondsSinceEpoch + i,
          ),
        );

        await repository.insertRoutePoints(points);
        final retrieved = await repository.getRoutePoints('batch-test-run');

        expect(retrieved.length, 25);
      });

      test('flushes remaining points on finish', () async {
        final summary = RunSummary(
          id: 'batch-test-run',
          status: RunStatus.active,
          startedAt: DateTime(2026, 4, 25, 10, 0, 0),
          sessionType: 'easy_run',
          timerOnly: false,
        );
        await repository.insertRun(summary);

        final points = List.generate(
          30,
          (i) => RunRoutePoint(
            runId: 'batch-test-run',
            index: i,
            lat: 37.7749 + i * 0.00001,
            lng: -122.4194 + i * 0.00001,
            accuracy: 10.0,
            timestampMs: DateTime.now().millisecondsSinceEpoch + i,
          ),
        );

        await repository.finishRun(
          runId: 'batch-test-run',
          endedAt: DateTime(2026, 4, 25, 11, 0, 0),
          durationMs: 3600000,
          distanceKm: 5.0,
          splits: [],
          finalPoints: points,
        );

        final retrieved = await repository.getRoutePoints('batch-test-run');
        expect(retrieved.length, 30);
      });
    });
  });
}
