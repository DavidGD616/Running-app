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

  static String shortDistanceUnitLabel(
    ShortDistanceUnit unit,
    AppLocalizations l10n,
  ) => unit == ShortDistanceUnit.meters ? l10n.unitM : l10n.unitFt;

  static String formatDistanceCompactValue(double km, UnitSystem unit) {
    final converted = _convertDistance(km, unit);
    final isWhole = converted == converted.roundToDouble();
    return isWhole
        ? converted.round().toString()
        : converted.toStringAsFixed(1);
  }

  /// Formats a duration in minutes to a human-readable string.
  /// e.g. 30 → '30 min', 75 → '1h 15m', 60 → '1h'
  static String formatDuration(int minutes, AppLocalizations l10n) {
    if (minutes < 60) return '$minutes ${l10n.logSessionMinUnit}';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h${l10n.progressHourUnit}';
    return '$h${l10n.progressHourUnit} $m${l10n.progressMinuteUnit}';
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

  static String formatDistanceCompactLabel(
    double km,
    UnitSystem unit,
    AppLocalizations l10n,
  ) {
    final value = formatDistanceCompactValue(km, unit);
    return '$value ${unitLabel(unit, l10n)}';
  }

  static String formatWorkoutRepDistance(
    int meters,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    if (unitSystem == UnitSystem.km) {
      return '$meters ${l10n.unitM}';
    }

    const metersPerMile = 1609.344;
    if (meters < metersPerMile) {
      return '$meters ${l10n.unitM}';
    }

    final miles = meters / metersPerMile;
    final rounded = (miles * 100).round() / 100;
    final value = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(2);
    return '$value ${l10n.unitMi}';
  }

  static double _convertShortDistance(double meters, ShortDistanceUnit unit) =>
      unit == ShortDistanceUnit.meters ? meters : meters * 3.28084;

  static String formatShortDistanceValue(
    double meters,
    ShortDistanceUnit unit,
  ) {
    final converted = _convertShortDistance(meters, unit);
    return converted.round().toString();
  }

  static String formatShortDistanceLabel(
    double meters,
    ShortDistanceUnit unit,
    AppLocalizations l10n,
  ) {
    final value = formatShortDistanceValue(meters, unit);
    return '$value ${shortDistanceUnitLabel(unit, l10n)}';
  }
}
