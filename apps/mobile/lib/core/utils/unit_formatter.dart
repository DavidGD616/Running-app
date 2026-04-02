import '../../../features/user_preferences/domain/user_preferences.dart';

class UnitFormatter {
  UnitFormatter._();

  /// Label used after a number — e.g. "5 km" suffix part.
  static String unitLabel(UnitSystem unit) =>
      unit == UnitSystem.km ? 'km' : 'mi';

  /// Pace label shown in training plans.
  static String paceLabel(UnitSystem unit) =>
      unit == UnitSystem.km ? 'min/km' : 'min/mi';

  /// Formats a duration in minutes to a human-readable string.
  /// e.g. 30 → '30 min', 75 → '1h 15m', 60 → '1h'
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Formats a distance in km to a human-readable string.
  /// e.g. 5.0 → '5 km', 6.5 → '6.5 km'
  static String formatDistanceKm(double km) {
    final isWhole = km == km.truncateToDouble();
    return isWhole ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }

  static double _convertDistance(double km, UnitSystem unit) =>
      unit == UnitSystem.km ? km : km * 0.621371;

  /// Returns the numeric distance formatted without unit, respecting unit system.
  static String formatDistanceValue(double km, UnitSystem unit) {
    final converted = _convertDistance(km, unit);
    return converted.toStringAsFixed(1);
  }

  /// Returns distance string with unit label (e.g. '5 km' or '3.1 mi').
  static String formatDistanceWithUnit(double km, UnitSystem unit) {
    final value = formatDistanceValue(km, unit);
    return '$value ${unitLabel(unit)}';
  }
}
