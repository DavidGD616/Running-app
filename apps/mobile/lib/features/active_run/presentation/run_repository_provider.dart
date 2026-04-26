import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/persistence/run_database.dart';
import '../data/run_repository.dart';

final runDatabaseProvider = FutureProvider<Database>((ref) async {
  return RunDatabase.openDatabase();
});

final runRepositoryProvider = Provider<RunRepository>((ref) {
  return RunRepository();
});
