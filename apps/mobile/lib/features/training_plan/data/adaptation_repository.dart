import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';

abstract interface class AdaptationRepository {
  List<SessionFeedback> loadSessionFeedback();
  List<PlanAdjustment> loadPlanAdjustments();
  List<PlanRevision> loadPlanRevisions();
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback);
  Future<void> savePlanAdjustments(List<PlanAdjustment> adjustments);
  Future<void> savePlanRevisions(List<PlanRevision> revisions);
}

class SharedPreferencesAdaptationRepository implements AdaptationRepository {
  SharedPreferencesAdaptationRepository(this._prefs);

  static const sessionFeedbackKey = 'session_feedback_v1';
  static const planAdjustmentsKey = 'plan_adjustments_v1';
  static const planRevisionsKey = 'plan_revisions_v1';

  final SharedPreferences _prefs;

  @override
  List<SessionFeedback> loadSessionFeedback() =>
      _decodeList(
        key: sessionFeedbackKey,
        fromJson: SessionFeedback.fromJson,
        sortBy: (a, b) => b.recordedAt.compareTo(a.recordedAt),
      );

  @override
  List<PlanAdjustment> loadPlanAdjustments() =>
      _decodeList(
        key: planAdjustmentsKey,
        fromJson: PlanAdjustment.fromJson,
        sortBy: (a, b) => b.createdAt.compareTo(a.createdAt),
      );

  @override
  List<PlanRevision> loadPlanRevisions() =>
      _decodeList(
        key: planRevisionsKey,
        fromJson: PlanRevision.fromJson,
        sortBy: (a, b) => b.createdAt.compareTo(a.createdAt),
      );

  @override
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback) async {
    await _prefs.setString(
      sessionFeedbackKey,
      jsonEncode(feedback.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> savePlanAdjustments(List<PlanAdjustment> adjustments) async {
    await _prefs.setString(
      planAdjustmentsKey,
      jsonEncode(
        adjustments.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  @override
  Future<void> savePlanRevisions(List<PlanRevision> revisions) async {
    await _prefs.setString(
      planRevisionsKey,
      jsonEncode(revisions.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  List<T> _decodeList<T>({
    required String key,
    required T? Function(Map<String, dynamic> json) fromJson,
    required int Function(T a, T b) sortBy,
  }) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <T>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final parsed = fromJson(item);
          if (parsed != null) items.add(parsed);
        } else if (item is Map) {
          final parsed = fromJson(
            item.map((mapKey, value) => MapEntry('$mapKey', value)),
          );
          if (parsed != null) items.add(parsed);
        }
      }
      items.sort(sortBy);
      return items;
    } catch (_) {
      return const [];
    }
  }
}

final adaptationRepositoryProvider = Provider<AdaptationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesAdaptationRepository(prefs);
});
