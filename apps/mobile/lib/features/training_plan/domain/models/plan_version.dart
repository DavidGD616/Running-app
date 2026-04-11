import 'model_json_utils.dart';
import 'training_plan.dart';

class PlanVersion {
  const PlanVersion({
    required this.id,
    required this.generatedAt,
    required this.requestedBy,
    required this.isActive,
    required this.plan,
  });

  static const int schemaVersion = 1;

  final String id;
  final DateTime generatedAt;

  /// Canonical source identifier — 'onboarding' | 'settings_update' | 'retry'
  final String requestedBy;
  final bool isActive;
  final TrainingPlan plan;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'generatedAt': generatedAt.toIso8601String(),
        'requestedBy': requestedBy,
        'isActive': isActive,
        'plan': plan.toJson(),
      };

  static PlanVersion? fromJson(Map<String, dynamic> json) {
    final id = stringOrNull(json['id']);
    final generatedAt = dateTimeFromJson(json['generatedAt']);
    final requestedBy = stringOrNull(json['requestedBy']);
    final isActive = json['isActive'];
    final rawPlan = json['plan'];

    if (id == null || id.isEmpty ||
        generatedAt == null ||
        requestedBy == null || requestedBy.isEmpty ||
        isActive is! bool ||
        rawPlan is! Map<String, dynamic>) {
      return null;
    }

    final plan = TrainingPlan.fromJson(rawPlan);
    if (plan == null) return null;

    return PlanVersion(
      id: id,
      generatedAt: generatedAt,
      requestedBy: requestedBy,
      isActive: isActive,
      plan: plan,
    );
  }

  PlanVersion copyWith({bool? isActive}) => PlanVersion(
        id: id,
        generatedAt: generatedAt,
        requestedBy: requestedBy,
        isActive: isActive ?? this.isActive,
        plan: plan,
      );
}
