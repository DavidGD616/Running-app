enum UnitSystem { km, miles }

enum ShortDistanceUnit { meters, feet }

class UserPreferences {
  final UnitSystem unitSystem;
  final ShortDistanceUnit shortDistanceUnit;
  final String? gender;
  final DateTime? dateOfBirth;

  const UserPreferences({
    this.unitSystem = UnitSystem.km,
    this.shortDistanceUnit = ShortDistanceUnit.meters,
    this.gender,
    this.dateOfBirth,
  });

  UserPreferences copyWith({
    UnitSystem? unitSystem,
    ShortDistanceUnit? shortDistanceUnit,
    String? gender,
    DateTime? dateOfBirth,
  }) => UserPreferences(
    unitSystem: unitSystem ?? this.unitSystem,
    shortDistanceUnit: shortDistanceUnit ?? this.shortDistanceUnit,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
  );
}
