abstract interface class CanonicalKeyed {
  String get key;
}

T? enumFromKey<T extends Enum>(
  String? key,
  List<T> values,
  String Function(T value) keyOf,
) {
  if (key == null || key.isEmpty) return null;
  for (final value in values) {
    if (keyOf(value) == key) return value;
  }
  return null;
}

String? stringOrNull(Object? value) => value is String ? value : null;

int? intOrNull(Object? value) {
  return optionalInt(value);
}

DateTime? dateTimeFromJson(Object? value) {
  final raw = stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String? dateTimeToJson(DateTime? value) => value?.toIso8601String();

List<String> stringListOrEmpty(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is String ? item : null)
      .whereType<String>()
      .toList(growable: false);
}

List<String> sortedCanonicalKeys(Iterable<CanonicalKeyed> values) {
  final keys = values.map((value) => value.key).toList(growable: false);
  keys.sort();
  return keys;
}

String requiredString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return raw;
}

int requiredInt(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final parsed = optionalInt(json[key]);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an int.');
  }
  return parsed;
}

Map<String, dynamic> requiredMap(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is! Map) {
    throw FormatException('Invalid $context: $key must be an object.');
  }
  return raw.cast<String, dynamic>();
}

bool requiredBool(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is bool) return raw;
  throw FormatException('Invalid $context: $key must be a bool.');
}

double requiredDouble(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final parsed = optionalDouble(json[key]);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be a double.');
  }
  return parsed;
}

num requiredNum(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is num) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    final intValue = int.tryParse(raw.trim());
    if (intValue != null) return intValue;

    final doubleValue = double.tryParse(raw.trim());
    if (doubleValue != null) return doubleValue;
  }

  throw FormatException('Invalid $context: $key must be a numeric value.');
}

DateTime requiredDateTime(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }
  return parsed;
}

String? optionalString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return raw;
}

int? optionalInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String && value.trim().isNotEmpty) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? optionalDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value.trim());
  }
  return null;
}

DateTime? optionalDateTime(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }
  return parsed;
}

Duration? optionalDurationMs(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;

  final milliseconds = optionalInt(raw);
  if (milliseconds == null) {
    throw FormatException('Invalid $context: $key must be an int duration.');
  }
  return Duration(milliseconds: milliseconds);
}

List<dynamic> requiredList(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw is! List) {
    throw FormatException('Invalid $context: $key must be a list.');
  }
  return raw;
}

T requiredNested<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T Function(Map<String, dynamic>) parse,
}) {
  return parse(requiredMap(json, key, context: context));
}

T? optionalNested<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T Function(Map<String, dynamic>) parse,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! Map) {
    throw FormatException('Invalid $context: $key must be an object.');
  }
  return parse(raw.cast<String, dynamic>());
}

T requiredEnumFromKey<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String?) parse,
}) {
  final raw = requiredString(json, key, context: context);
  final parsed = parse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: unsupported $key "$raw".');
  }
  return parsed;
}

T? optionalEnumFromKey<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String?) parse,
  required String fieldLabel,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException(
      'Invalid $context: $fieldLabel must be a string key.',
    );
  }

  final parsed = parse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: unsupported $fieldLabel "$raw".');
  }
  return parsed;
}

Set<T> optionalCanonicalSet<T extends CanonicalKeyed>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String?) parse,
}) {
  final raw = json[key];
  if (raw == null) return const {};
  if (raw is! List) {
    throw FormatException('Invalid $context: $key must be a list of keys.');
  }

  final parsedValues = <T>{};
  for (final entry in raw) {
    if (entry is! String) {
      throw FormatException('Invalid $context: $key entries must be strings.');
    }
    final parsed = parse(entry);
    if (parsed == null) {
      throw FormatException(
        'Invalid $context: unsupported $key entry "$entry".',
      );
    }
    parsedValues.add(parsed);
  }

  return parsedValues;
}
