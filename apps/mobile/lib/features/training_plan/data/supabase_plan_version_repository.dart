import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../domain/models/plan_version.dart';
import '../domain/models/training_plan.dart';
import 'plan_version_repository.dart';

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

/// Reads from `plan_versions`. On a successful async load the result is also
/// written to the local SP cache so subsequent cold starts are instant.
///
/// Flutter does NOT write directly to `plan_versions` — the Edge Function owns
/// all inserts. Flutter only reads via [loadActivePlanAsync] and caches locally
/// via [saveActivePlan] (called after the Edge Function returns).
class SupabasePlanVersionRepository implements PlanVersionRepository {
  SupabasePlanVersionRepository({
    required SupabaseClient client,
    required SharedPreferencesPlanVersionRepository localCache,
  })  : _client = client,
        _localCache = localCache;

  static const _table = 'plan_versions';

  final SupabaseClient _client;
  final SharedPreferencesPlanVersionRepository _localCache;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  TrainingPlan? loadActivePlanSync() => _localCache.loadActivePlanSync();

  @override
  Future<TrainingPlan?> loadActivePlanAsync() async {
    final uid = _uid;
    if (uid == null) return _localCache.loadActivePlanSync();

    try {
      final row = await _client
          .from(_table)
          .select('id, generated_at, requested_by, is_active, data')
          .eq('user_id', uid)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) return null;

      final version = _versionFromRow(row);
      if (version != null) await _localCache.saveActivePlan(version);
      return version?.plan;
    } catch (_) {
      return _localCache.loadActivePlanSync();
    }
  }

  @override
  Future<void> saveActivePlan(PlanVersion version) async {
    // Remote write is handled by the Edge Function; Flutter only caches here.
    await _localCache.saveActivePlan(version);
  }

  @override
  bool hasActivePlan() => _localCache.hasActivePlan();

  PlanVersion? _versionFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final generatedAt = row['generated_at'];
    final requestedBy = row['requested_by'];
    final isActive = row['is_active'];
    final data = row['data'];

    if (id is! String || id.isEmpty) return null;
    if (requestedBy is! String || requestedBy.isEmpty) return null;
    if (isActive is! bool) return null;

    DateTime? parsedAt;
    if (generatedAt is String) {
      parsedAt = DateTime.tryParse(generatedAt);
    }
    if (parsedAt == null) return null;

    Map<String, dynamic>? planJson;
    if (data is Map<String, dynamic>) {
      planJson = data;
    } else if (data is Map) {
      planJson = data.map((k, v) => MapEntry('$k', v));
    }
    if (planJson == null) return null;

    final plan = TrainingPlan.fromJson(planJson);
    if (plan == null) return null;

    return PlanVersion(
      id: id,
      generatedAt: parsedAt,
      requestedBy: requestedBy,
      isActive: isActive,
      plan: plan,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final supabasePlanVersionRepositoryProvider =
    Provider<SupabasePlanVersionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final localCache = ref.watch(sharedPreferencesPlanVersionRepositoryProvider);
  return SupabasePlanVersionRepository(client: client, localCache: localCache);
});

/// Switching provider: [SupabasePlanVersionRepository] when signed in,
/// [SharedPreferencesPlanVersionRepository] when signed out.
///
/// Follows the same pattern as [asyncAdaptationRepositoryProvider].
final planVersionRepositoryProvider = Provider<PlanVersionRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return ref.watch(sharedPreferencesPlanVersionRepositoryProvider);
  }
  return ref.watch(supabasePlanVersionRepositoryProvider);
});
