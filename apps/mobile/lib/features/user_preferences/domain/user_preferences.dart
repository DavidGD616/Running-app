enum UnitSystem { km, miles }

enum ShortDistanceUnit { meters, feet }

enum ProfileGender { male, female, other }

class UserPreferences {
  final UnitSystem unitSystem;
  final ShortDistanceUnit shortDistanceUnit;
  final String? displayName;
  final ProfileGender? gender;
  final DateTime? dateOfBirth;

  const UserPreferences({
    this.unitSystem = UnitSystem.km,
    this.shortDistanceUnit = ShortDistanceUnit.meters,
    this.displayName,
    this.gender,
    this.dateOfBirth,
  });

  UserPreferences copyWith({
    UnitSystem? unitSystem,
    ShortDistanceUnit? shortDistanceUnit,
    String? displayName,
    ProfileGender? gender,
    DateTime? dateOfBirth,
  }) => UserPreferences(
    unitSystem: unitSystem ?? this.unitSystem,
    shortDistanceUnit: shortDistanceUnit ?? this.shortDistanceUnit,
    displayName: displayName ?? this.displayName,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
  );
}
