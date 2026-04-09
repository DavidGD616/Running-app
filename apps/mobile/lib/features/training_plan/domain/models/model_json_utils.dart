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
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
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

