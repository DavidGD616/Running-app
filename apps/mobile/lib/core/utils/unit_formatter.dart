import '../../../features/user_preferences/domain/user_preferences.dart';

class UnitFormatter {
  UnitFormatter._();

  /// Label used after a number — e.g. "5 km" suffix part.
  static String unitLabel(UnitSystem unit) =>
      unit == UnitSystem.km ? 'km' : 'mi';

  /// Pace label shown in training plans.
  static String paceLabel(UnitSystem unit) =>
      unit == UnitSystem.km ? 'min/km' : 'min/mi';

  /// Subtitle shown on each race card in GoalScreen.
  static String raceSubtitle(String raceName, UnitSystem unit) {
    const km = {
      '5K': '5 km',
      '10K': '10 km',
      'Half Marathon': '21.1 km',
      'Marathon': '42.2 km',
      'Other': 'Custom distance',
    };
    const mi = {
      '5K': '3.1 mi',
      '10K': '6.2 mi',
      'Half Marathon': '13.1 mi',
      'Marathon': '26.2 mi',
      'Other': 'Custom distance',
    };
    final map = unit == UnitSystem.km ? km : mi;
    return map[raceName] ?? raceName;
  }

  /// Options for "Average weekly volume" in CurrentFitnessScreen.
  static List<String> weeklyVolumeOptions(UnitSystem unit) =>
      unit == UnitSystem.km
          ? ['0 km', '1–13 km', '10–16 km', '17–24 km', '25–32 km', '33–48 km', '49+']
          : ['0 mi', '1–5 mi', '6–10 mi', '11–15 mi', '16–20 mi', '21–30 mi', '31+'];

  /// Options for the optional benchmark picker in CurrentFitnessScreen.
  static List<String> benchmarkOptions(UnitSystem unit) =>
      unit == UnitSystem.km
          ? ['1-km run time', '1-km walk time', '5K time', '10K time', 'Half marathon time', 'Skip for now']
          : ['1-mile run time', '1-mile walk time', '5K time', '10K time', 'Half marathon time', 'Skip for now'];

  /// Options for "Longest recent run" in CurrentFitnessScreen.
  static List<String> longestRunOptions(UnitSystem unit) =>
      unit == UnitSystem.km
          ? ["I haven't done one", 'Less than 5 km', '5–8 km', '9–13 km', '14–16 km', '17–21 km', '21+ km']
          : ["I haven't done one", 'Less than 3 mi', '3–5 mi', '6–8 mi', '9–10 mi', '11–13 mi', '13+ mi'];
}
