import '../../../features/user_preferences/domain/user_preferences.dart';
import '../../l10n/app_localizations.dart';

class UnitFormatter {
  UnitFormatter._();

  /// Label used after a number — e.g. "5 km" suffix part.
  static String unitLabel(UnitSystem unit, AppLocalizations l10n) =>
      unit == UnitSystem.km ? l10n.unitKm : l10n.unitMi;

  /// Pace label shown in training plans.
  static String paceLabel(UnitSystem unit, AppLocalizations l10n) =>
      unit == UnitSystem.km
      ? '${l10n.logSessionMinUnit}/${l10n.unitKm}'
      : '${l10n.logSessionMinUnit}/${l10n.unitMi}';

  /// Formats a duration in minutes to a human-readable string.
  /// e.g. 30 → '30 min', 75 → '1h 15m', 60 → '1h'
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static double _convertDistance(double km, UnitSystem unit) =>
      unit == UnitSystem.km ? km : km * 0.621371;

  /// Returns distance converted to the active unit system without formatting.
  static double distanceValue(double km, UnitSystem unit) =>
      _convertDistance(km, unit);

  /// Returns the numeric distance formatted without unit, respecting unit system.
  static String formatDistanceValue(double km, UnitSystem unit) {
    final converted = _convertDistance(km, unit);
    return converted.toStringAsFixed(1);
  }

  /// Returns distance string with unit label (e.g. '5 km' or '3.1 mi').
  static String formatDistanceWithUnit(
    double km,
    UnitSystem unit,
    AppLocalizations l10n,
  ) {
    final value = formatDistanceValue(km, unit);
    return '$value ${unitLabel(unit, l10n)}';
  }

  static String formatDistanceLabel(
    double km,
    UnitSystem unit,
    AppLocalizations l10n,
  ) {
    final value = formatDistanceValue(km, unit);
    return '$value ${unitLabel(unit, l10n)}';
  }
}
