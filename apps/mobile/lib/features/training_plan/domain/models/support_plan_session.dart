import '../../../profile/domain/models/runner_profile.dart';

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
    final id = _requiredString(json, 'id', context: context);
    final date = _requiredDateTime(json, 'date', context: context);
    final weekNumber = _requiredInt(json, 'weekNumber', context: context);
    if (weekNumber <= 0) {
      throw const FormatException(
        'Invalid support plan session: weekNumber must be > 0.',
      );
    }

    final categoryKey = _requiredString(json, 'category', context: context);
    final category = StrengthCategory.fromKey(categoryKey);
    if (category == null) {
      throw FormatException(
        'Invalid support plan session: unsupported category "$categoryKey".',
      );
    }

    final durationMinutes = _optionalInt(
      json,
      'durationMinutes',
      context: context,
    );
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
      load: _optionalString(json, 'load', context: context),
      timingGuidance: _optionalString(json, 'timingGuidance', context: context),
      interferenceRule: _optionalString(
        json,
        'interferenceRule',
        context: context,
      ),
      taperAdjustment: _optionalString(
        json,
        'taperAdjustment',
        context: context,
      ),
      durationMinutes: durationMinutes,
      notes: _optionalString(json, 'notes', context: context),
    );
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

DateTime _requiredDateTime(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = _requiredString(json, key, context: context);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }
  return parsed;
}

int _requiredInt(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = _optionalInt(json, key, context: context);
  if (value == null) {
    throw FormatException('Invalid $context: $key must be an int.');
  }
  return value;
}

int? _optionalInt(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is double && raw.isFinite && raw == raw.roundToDouble()) {
    return raw.toInt();
  }
  if (raw is String && raw.isNotEmpty) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid $context: $key must be an int.');
}
