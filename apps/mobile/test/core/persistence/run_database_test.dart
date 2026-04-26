import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:running_app/core/persistence/run_database.dart';

void main() {
  group('RunDatabase', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('openDatabase creates database with version 1', () async {
      final db = await RunDatabase.openDatabase();
      try {
        expect(await db.getVersion(), 1);
      } finally {
        await db.close();
      }
    });

    test('onCreate creates runs table', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='runs'",
        );
        expect(result, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    test('onCreate creates run_route_points table', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='run_route_points'",
        );
        expect(result, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    test('onCreate creates run_splits table', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='run_splits'",
        );
        expect(result, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    test('runs table has correct columns', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery('PRAGMA table_info(runs)');
        final columns = result.map((r) => r['name'] as String).toList();
        expect(columns, contains('id'));
        expect(columns, contains('status'));
        expect(columns, contains('started_at_ms'));
        expect(columns, contains('ended_at_ms'));
        expect(columns, contains('duration_ms'));
        expect(columns, contains('distance_km'));
        expect(columns, contains('session_id'));
        expect(columns, contains('session_type'));
        expect(columns, contains('timer_only'));
        expect(columns, contains('source'));
      } finally {
        await db.close();
      }
    });

    test('run_route_points has composite primary key (run_id, idx)', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery(
          'PRAGMA index_list(run_route_points)',
        );
        final indexes = result.map((r) => r['name'] as String).toList();
        expect(
          indexes,
          contains('sqlite_autoindex_run_route_points_1'),
        );
      } finally {
        await db.close();
      }
    });

    test('run_splits has composite primary key (run_id, idx)', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery(
          'PRAGMA index_list(run_splits)',
        );
        final indexes = result.map((r) => r['name'] as String).toList();
        expect(
          indexes,
          contains('sqlite_autoindex_run_splits_1'),
        );
      } finally {
        await db.close();
      }
    });

    test('foreign keys are enabled', () async {
      final db = await RunDatabase.openDatabase();
      try {
        final result = await db.rawQuery('PRAGMA foreign_keys');
        expect(result.first['foreign_keys'], 1);
      } finally {
        await db.close();
      }
    });

    test('onUpgrade callback has correct signature and is called on version change',
        () async {
      bool upgradeCalled = false;
      int capturedOldVersion = 0;
      int capturedNewVersion = 0;

      final testPath = '${inMemoryDatabasePath}_upgrade_test';
      await databaseFactoryFfi.deleteDatabase(testPath);

      await databaseFactoryFfi.openDatabase(
        testPath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: RunDatabaseCallbacks.onConfigure,
          onCreate: RunDatabaseCallbacks.onCreate,
          onUpgrade: (db, oldVersion, newVersion) async {
            upgradeCalled = true;
            capturedOldVersion = oldVersion;
            capturedNewVersion = newVersion;
          },
        ),
      ).then((db) => db.close());

      expect(upgradeCalled, isFalse);

      final upgradedDb = await databaseFactoryFfi.openDatabase(
        testPath,
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: RunDatabaseCallbacks.onConfigure,
          onCreate: RunDatabaseCallbacks.onCreate,
          onUpgrade: (db, oldVersion, newVersion) async {
            upgradeCalled = true;
            capturedOldVersion = oldVersion;
            capturedNewVersion = newVersion;
          },
        ),
      );
      try {
        expect(upgradeCalled, isTrue);
        expect(capturedOldVersion, 1);
        expect(capturedNewVersion, 2);
      } finally {
        await upgradedDb.close();
        await databaseFactoryFfi.deleteDatabase(testPath);
      }
    });

    test('cascade delete works via foreign key', () async {
      final db = await RunDatabase.openDatabase();

      await db.insert('runs', {
        'id': 'test-run-id',
        'status': 'active',
        'started_at_ms': DateTime.now().millisecondsSinceEpoch,
        'timer_only': 0,
      });

      await db.insert('run_route_points', {
        'run_id': 'test-run-id',
        'idx': 0,
        'lat': 37.7749,
        'lng': -122.4194,
        'accuracy': 5.0,
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
      });

      await db.delete('runs', where: 'id = ?', whereArgs: ['test-run-id']);

      final routePoints = await db.query(
        'run_route_points',
        where: 'run_id = ?',
        whereArgs: ['test-run-id'],
      );
      expect(routePoints, isEmpty);

      await db.close();
    });
  });
}