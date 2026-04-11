import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';
import 'adaptation_repository.dart';

class SupabaseAdaptationRepository implements AsyncAdaptationRepository {
  SupabaseAdaptationRepository(this._client, {AdaptationRepository? localCache})
    : _localCache = localCache;

  final SupabaseClient _client;
  final AdaptationRepository? _localCache;

  static const _planRevisionRecordedStatus = 'recorded';

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<List<SessionFeedback>> loadSessionFeedback() async {
    return _loadList<SessionFeedback>(
      table: 'session_feedback',
      orderColumn: 'recorded_at',
      fromRow: _sessionFeedbackFromRow,
      cacheLoad: () => _localCache?.loadSessionFeedback() ?? const [],
      cacheSave: (items) async {
        if (_localCache != null) {
          await _localCache.saveSessionFeedback(items);
        }
      },
    );
  }

  @override
  Future<List<PlanAdjustment>> loadPlanAdjustments() async {
    return _loadList<PlanAdjustment>(
      table: 'plan_adjustments',
      orderColumn: 'created_at',
      fromRow: _planAdjustmentFromRow,
      cacheLoad: () => _localCache?.loadPlanAdjustments() ?? const [],
      cacheSave: (items) async {
        if (_localCache != null) {
          await _localCache.savePlanAdjustments(items);
        }
      },
    );
  }

  @override
  Future<List<PlanRevision>> loadPlanRevisions() async {
    return _loadList<PlanRevision>(
      table: 'plan_revisions',
      orderColumn: 'created_at',
      fromRow: _planRevisionFromRow,
      cacheLoad: () => _localCache?.loadPlanRevisions() ?? const [],
      cacheSave: (items) async {
        if (_localCache != null) {
          await _localCache.savePlanRevisions(items);
        }
      },
    );
  }

  @override
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback) async {
    await _localCache?.saveSessionFeedback(feedback);

    final uid = _uid;
    if (uid == null || feedback.isEmpty) return;

    await _client
        .from('session_feedback')
        .upsert(
          feedback
              .map(
                (item) => {
                  'id': item.id,
                  'user_id': uid,
                  'linked_session_id': item.plannedSessionId,
                  'recorded_at': item.recordedAt.toUtc().toIso8601String(),
                  'data': item.toJson(),
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  @override
  Future<void> savePlanAdjustments(List<PlanAdjustment> adjustments) async {
    await _localCache?.savePlanAdjustments(adjustments);

    final uid = _uid;
    if (uid == null || adjustments.isEmpty) return;

    await _client
        .from('plan_adjustments')
        .upsert(
          adjustments
              .map(
                (item) => {
                  'id': item.id,
                  'user_id': uid,
                  'linked_session_id': item.plannedSessionId,
                  'status': item.status.key,
                  'created_at': item.createdAt.toUtc().toIso8601String(),
                  'data': item.toJson(),
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  @override
  Future<void> savePlanRevisions(List<PlanRevision> revisions) async {
    await _localCache?.savePlanRevisions(revisions);

    final uid = _uid;
    if (uid == null || revisions.isEmpty) return;

    await _client
        .from('plan_revisions')
        .upsert(
          revisions
              .map(
                (item) => {
                  'id': item.id,
                  'user_id': uid,
                  'status': _planRevisionRecordedStatus,
                  'created_at': item.createdAt.toUtc().toIso8601String(),
                  'data': item.toJson(),
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  Future<List<T>> _loadList<T>({
    required String table,
    required String orderColumn,
    required T? Function(Map<String, dynamic> row) fromRow,
    required List<T> Function() cacheLoad,
    required Future<void> Function(List<T> items) cacheSave,
  }) async {
    final uid = _uid;
    if (uid == null) return cacheLoad();

    try {
      final response = await _client
          .from(table)
          .select()
          .eq('user_id', uid)
          .order(orderColumn, ascending: false);

      final items = _rowsFromResponse(
        response,
      ).map(fromRow).whereType<T>().toList(growable: false);
      await cacheSave(items);
      return items;
    } catch (_) {
      return cacheLoad();
    }
  }

  SessionFeedback? _sessionFeedbackFromRow(Map<String, dynamic> row) {
    final data = _jsonMap(row['data']);
    if (row.containsKey('id')) data['id'] = row['id'];
    if (row.containsKey('linked_session_id')) {
      data['plannedSessionId'] = row['linked_session_id'];
    }
    if (row.containsKey('recorded_at')) {
      data['recordedAt'] = row['recorded_at'];
    }
    return SessionFeedback.fromJson(data);
  }

  PlanAdjustment? _planAdjustmentFromRow(Map<String, dynamic> row) {
    final data = _jsonMap(row['data']);
    if (row.containsKey('id')) data['id'] = row['id'];
    if (row.containsKey('linked_session_id')) {
      data['plannedSessionId'] = row['linked_session_id'];
    }
    if (row.containsKey('status')) data['status'] = row['status'];
    if (row.containsKey('created_at')) data['createdAt'] = row['created_at'];
    return PlanAdjustment.fromJson(data);
  }

  PlanRevision? _planRevisionFromRow(Map<String, dynamic> row) {
    final data = _jsonMap(row['data']);
    if (row.containsKey('id')) data['id'] = row['id'];
    if (row.containsKey('created_at')) data['createdAt'] = row['created_at'];
    return PlanRevision.fromJson(data);
  }
}

List<Map<String, dynamic>> _rowsFromResponse(dynamic response) {
  if (response is! List) return const [];
  return response.map(_rowFromDynamic).toList(growable: false);
}

Map<String, dynamic> _rowFromDynamic(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return const {};
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

final supabaseAdaptationRepositoryProvider =
    Provider<AsyncAdaptationRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      final localCache = ref.watch(adaptationRepositoryProvider);
      return SupabaseAdaptationRepository(client, localCache: localCache);
    });
