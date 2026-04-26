import 'package:sqflite/sqflite.dart' hide openDatabase;
import 'package:sqflite/sqflite.dart' as sqflite show openDatabase;
import 'package:path/path.dart' as path;

abstract class RunDatabaseCallbacks {
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
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
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {}
}

class RunDatabase {
  static const String databaseName = 'runflow_runs.db';
  static const int databaseVersion = 1;

  static Future<Database> openDatabase() async {
    final dbPath = await getDatabasesPath();
    return sqflite.openDatabase(
      path.join(dbPath, databaseName),
      version: databaseVersion,
      onConfigure: RunDatabaseCallbacks.onConfigure,
      onCreate: RunDatabaseCallbacks.onCreate,
      onUpgrade: RunDatabaseCallbacks.onUpgrade,
    );
  }
}