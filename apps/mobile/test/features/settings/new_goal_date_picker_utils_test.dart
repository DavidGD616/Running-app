import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/settings/presentation/new_goal_date_picker_utils.dart';

void main() {
  group('pickInitialDate', () {
    test('clamps selected dates before the minimum', () {
      final minDate = DateTime(2026, 7, 2);
      final maxDate = DateTime(2026, 10, 2);
      final picked = pickInitialDate(
        selectedDate: DateTime(2026, 7, 1, 18, 30),
        minDate: minDate,
        maxDate: maxDate,
        fallbackDate: maxDate,
      );

      expect(picked, DateTime(2026, 7, 2));
    });

    test('clamps selected dates after the maximum', () {
      final minDate = DateTime(2026, 7, 2);
      final maxDate = DateTime(2026, 10, 2);
      final picked = pickInitialDate(
        selectedDate: DateTime(2026, 10, 3, 8, 15),
        minDate: minDate,
        maxDate: maxDate,
        fallbackDate: minDate,
      );

      expect(picked, DateTime(2026, 10, 2));
    });

    test('clamps selected past clock-backed date to today', () {
      final bounds = buildRaceDatePickerBounds(
        clock: DateTime(2026, 7, 31, 14, 20),
      );
      final picked = pickInitialDate(
        selectedDate: DateTime(2026, 7, 24),
        minDate: bounds.firstDate,
        maxDate: bounds.lastDate,
        fallbackDate: bounds.fallbackDate,
      );

      expect(picked, DateTime(2026, 7, 31));
    });
  });

  group('buildRaceDatePickerBounds', () {
    test('normalizes clock input to date-only boundaries', () {
      final bounds = buildRaceDatePickerBounds(
        clock: DateTime(2026, 7, 31, 23, 59, 59),
      );

      expect(bounds.firstDate, DateTime(2026, 7, 31));
      expect(bounds.lastDate, DateTime(2029, 7, 31));
      expect(bounds.fallbackDate, DateTime(2026, 10, 29));
    });
  });
}
