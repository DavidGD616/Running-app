enum UnitSystem { km, miles }

class UserPreferences {
  final UnitSystem unitSystem;
  final String? gender;
  final DateTime? dateOfBirth;

  const UserPreferences({
    this.unitSystem = UnitSystem.km,
    this.gender,
    this.dateOfBirth,
  });

  UserPreferences copyWith({
    UnitSystem? unitSystem,
    String? gender,
    DateTime? dateOfBirth,
  }) =>
      UserPreferences(
        unitSystem: unitSystem ?? this.unitSystem,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      );
}
