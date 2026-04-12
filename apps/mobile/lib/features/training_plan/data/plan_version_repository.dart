import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../domain/models/plan_version.dart';
import '../domain/models/training_plan.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract interface class PlanVersionRepository {
  /// Returns the active plan if one is cached locally (fast, offline-safe).
  TrainingPlan? loadActivePlanSync();

  /// Loads the active plan from the remote source of truth.
  Future<TrainingPlan?> loadActivePlanAsync();

  /// Saves a new active plan version (local cache + remote).
  Future<void> saveActivePlan(PlanVersion version);

  /// Returns true if any plan version exists locally.
  bool hasActivePlan();
}

// ---------------------------------------------------------------------------
// SharedPreferences implementation
// ---------------------------------------------------------------------------

/// Local-only cache. Stores the single active plan version as JSON under a
/// fixed SP key. Does not store historical versions.
class SharedPreferencesPlanVersionRepository implements PlanVersionRepository {
  SharedPreferencesPlanVersionRepository(this._prefs);

  static const _activePlanKey = 'active_plan_version_v1';

  final SharedPreferences _prefs;

  @override
  TrainingPlan? loadActivePlanSync() {
    final raw = _prefs.getString(_activePlanKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final version = PlanVersion.fromJson(json);
      return version?.plan;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TrainingPlan?> loadActivePlanAsync() async => loadActivePlanSync();

  @override
  Future<void> saveActivePlan(PlanVersion version) async {
    await _prefs.setString(_activePlanKey, jsonEncode(version.toJson()));
  }

  @override
  bool hasActivePlan() => _prefs.containsKey(_activePlanKey);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final sharedPreferencesPlanVersionRepositoryProvider =
    Provider<SharedPreferencesPlanVersionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesPlanVersionRepository(prefs);
});

// planVersionRepositoryProvider (switching provider) is defined in
// supabase_plan_version_repository.dart once SupabasePlanVersionRepository
// exists — same pattern as asyncAdaptationRepositoryProvider.
