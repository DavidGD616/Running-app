DateTime normalizeDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class DatePickerBounds {
  const DatePickerBounds({
    required this.firstDate,
    required this.lastDate,
    required this.fallbackDate,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime fallbackDate;
}

DatePickerBounds buildRaceDatePickerBounds({required DateTime clock}) {
  final today = normalizeDateOnly(clock);
  return DatePickerBounds(
    firstDate: today,
    lastDate: DateTime(today.year + 3, today.month, today.day),
    fallbackDate: today.add(const Duration(days: 90)),
  );
}

DatePickerBounds buildPlanStartDatePickerBounds({required DateTime clock}) {
  final today = normalizeDateOnly(clock);
  return DatePickerBounds(
    firstDate: today,
    lastDate: DateTime(today.year + 2, today.month, today.day),
    fallbackDate: today,
  );
}

DateTime clampDateForPicker({
  required DateTime requested,
  required DateTime minDate,
  required DateTime maxDate,
}) {
  final normalized = normalizeDateOnly(requested);
  if (normalized.isBefore(minDate)) return minDate;
  if (normalized.isAfter(maxDate)) return maxDate;
  return normalized;
}

DateTime pickInitialDate({
  DateTime? selectedDate,
  required DateTime minDate,
  required DateTime maxDate,
  required DateTime fallbackDate,
}) {
  return clampDateForPicker(
    requested: selectedDate ?? fallbackDate,
    minDate: minDate,
    maxDate: maxDate,
  );
}
