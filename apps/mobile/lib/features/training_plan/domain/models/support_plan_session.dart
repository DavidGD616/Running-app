import '../../../profile/domain/models/runner_profile.dart';
import 'model_json_utils.dart';

class SupportPlanSession {
  const SupportPlanSession({
    required this.id,
    required this.date,
    required this.weekNumber,
    required this.category,
    this.load,
    this.timingGuidance,
    this.interferenceRule,
    this.taperAdjustment,
    this.durationMinutes,
    this.notes,
  });

  final String id;
  final DateTime date;
  final int weekNumber;
  final StrengthCategory category;
  final String? load;
  final String? timingGuidance;
  final String? interferenceRule;
  final String? taperAdjustment;
  final int? durationMinutes;
  final String? notes;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'date': date.toIso8601String(),
      'weekNumber': weekNumber,
      'category': category.key,
      if (load != null) 'load': load,
      if (timingGuidance != null) 'timingGuidance': timingGuidance,
      if (interferenceRule != null) 'interferenceRule': interferenceRule,
      if (taperAdjustment != null) 'taperAdjustment': taperAdjustment,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (notes != null) 'notes': notes,
    };
  }

  factory SupportPlanSession.fromJson(Map<String, dynamic> json) {
    const context = 'support plan session';
    final id = requiredString(json, 'id', context: context);
    final date = requiredDateTime(json, 'date', context: context);
    final weekNumber = requiredInt(json, 'weekNumber', context: context);
    if (weekNumber <= 0) {
      throw const FormatException(
        'Invalid support plan session: weekNumber must be > 0.',
      );
    }

    final categoryKey = requiredString(json, 'category', context: context);
    final category = StrengthCategory.fromKey(categoryKey);
    if (category == null) {
      throw FormatException(
        'Invalid support plan session: unsupported category "$categoryKey".',
      );
    }

    final rawDurationMinutes = json['durationMinutes'];
    final durationMinutes = optionalInt(rawDurationMinutes);
    if (rawDurationMinutes != null && durationMinutes == null) {
      throw const FormatException(
        'Invalid support plan session: durationMinutes must be an int.',
      );
    }
    if (durationMinutes != null && durationMinutes <= 0) {
      throw const FormatException(
        'Invalid support plan session: durationMinutes must be > 0 when present.',
      );
    }

    return SupportPlanSession(
      id: id,
      date: date,
      weekNumber: weekNumber,
      category: category,
      load: optionalString(json, 'load', context: context),
      timingGuidance: optionalString(json, 'timingGuidance', context: context),
      interferenceRule: optionalString(
        json,
        'interferenceRule',
        context: context,
      ),
      taperAdjustment: optionalString(
        json,
        'taperAdjustment',
        context: context,
      ),
      durationMinutes: durationMinutes,
      notes: optionalString(json, 'notes', context: context),
    );
  }
}
