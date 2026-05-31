enum StravaAthleteSex {
  male('M'),
  female('F'),
  nonBinary('X');

  const StravaAthleteSex(this.apiValue);

  final String apiValue;

  static StravaAthleteSex? fromApiValue(String? value) {
    if (value == null || value.isEmpty) return null;

    for (final candidate in values) {
      if (candidate.apiValue == value) {
        return candidate;
      }
    }

    return null;
  }
}

class StravaHeartRateZone {
  static const int unboundedMaxBpmSentinel = -1;

  const StravaHeartRateZone({this.minBpm, required this.maxBpm});

  final int? minBpm;
  final int maxBpm;

  bool get hasUnboundedUpperBound => maxBpm == unboundedMaxBpmSentinel;

  factory StravaHeartRateZone.fromJson(Map<String, dynamic> json) {
    final maxBpm = _intFromJson(json['max']);
    if (maxBpm == null) {
      throw const FormatException('Strava HR zone max must be a positive int.');
    }

    final minBpm = _intFromJson(json['min']);
    if (minBpm != null && minBpm < 0) {
      throw const FormatException('Strava HR zone min must be >= 0.');
    }

    if (maxBpm == unboundedMaxBpmSentinel) {
      if (minBpm == null || minBpm <= 0) {
        throw const FormatException(
          'Strava unbounded top HR zone must include a positive min.',
        );
      }
      return StravaHeartRateZone(minBpm: minBpm, maxBpm: maxBpm);
    }

    if (maxBpm <= 0) {
      throw const FormatException('Strava HR zone max must be a positive int.');
    }

    if (minBpm != null && minBpm >= maxBpm) {
      throw const FormatException(
        'Strava HR zone min must be smaller than max.',
      );
    }

    return StravaHeartRateZone(minBpm: minBpm, maxBpm: maxBpm);
  }
}

class StravaHeartRateZones {
  const StravaHeartRateZones({
    this.zone1,
    this.zone2,
    this.zone3,
    this.zone4,
    this.zone5,
  });

  final StravaHeartRateZone? zone1;
  final StravaHeartRateZone? zone2;
  final StravaHeartRateZone? zone3;
  final StravaHeartRateZone? zone4;
  final StravaHeartRateZone? zone5;

  List<StravaHeartRateZone> get orderedZones => [
    ?zone1,
    ?zone2,
    ?zone3,
    ?zone4,
    ?zone5,
  ];

  factory StravaHeartRateZones.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'];
    if (rawZones is! List) {
      throw const FormatException('Strava HR zones must include a zones list.');
    }

    final zones = rawZones
        .whereType<Map>()
        .map((zone) => zone.cast<String, dynamic>())
        .map(StravaHeartRateZone.fromJson)
        .toList(growable: false);

    return StravaHeartRateZones(
      zone1: zones.isNotEmpty ? zones[0] : null,
      zone2: zones.length > 1 ? zones[1] : null,
      zone3: zones.length > 2 ? zones[2] : null,
      zone4: zones.length > 3 ? zones[3] : null,
      zone5: zones.length > 4 ? zones[4] : null,
    );
  }
}

class StravaAthlete {
  const StravaAthlete({this.sex, this.weightKg, this.heartRateZones});

  final StravaAthleteSex? sex;
  final double? weightKg;
  final StravaHeartRateZones? heartRateZones;

  factory StravaAthlete.fromJson(Map<String, dynamic> json) {
    final weightKg = _doubleFromJson(json['weight']);
    if (weightKg != null && weightKg <= 0) {
      throw const FormatException('Strava athlete weight must be > 0.');
    }

    final rawHeartRateZones = json['heart_rate_zones'];
    return StravaAthlete(
      sex: StravaAthleteSex.fromApiValue(_stringFromJson(json['sex'])),
      weightKg: weightKg,
      heartRateZones: rawHeartRateZones is Map
          ? StravaHeartRateZones.fromJson(
              rawHeartRateZones.cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class StravaRunTotals {
  const StravaRunTotals({
    required this.distanceMeters,
    required this.movingTimeSeconds,
    required this.activityCount,
    required this.elevationGainMeters,
  });

  final double distanceMeters;
  final int movingTimeSeconds;
  final int activityCount;
  final double elevationGainMeters;

  double get distanceKm => distanceMeters / 1000.0;

  factory StravaRunTotals.fromJson(Map<String, dynamic> json) {
    final distanceMeters = _doubleFromJson(json['distance']);
    final movingTimeSeconds = _intFromJson(json['moving_time']);
    final activityCount = _intFromJson(json['count']);
    final elevationGainMeters = _doubleFromJson(json['elevation_gain']);

    if (distanceMeters == null ||
        movingTimeSeconds == null ||
        activityCount == null ||
        elevationGainMeters == null) {
      throw const FormatException(
        'Strava run totals require distance, moving_time, count, and elevation_gain.',
      );
    }

    if (distanceMeters < 0 ||
        movingTimeSeconds < 0 ||
        activityCount < 0 ||
        elevationGainMeters < 0) {
      throw const FormatException('Strava run totals fields must be >= 0.');
    }

    return StravaRunTotals(
      distanceMeters: distanceMeters,
      movingTimeSeconds: movingTimeSeconds,
      activityCount: activityCount,
      elevationGainMeters: elevationGainMeters,
    );
  }
}

class StravaAthleteStats {
  const StravaAthleteStats({
    required this.recentRunTotals,
    required this.ytdRunTotals,
    required this.allRunTotals,
  });

  final StravaRunTotals recentRunTotals;
  final StravaRunTotals ytdRunTotals;
  final StravaRunTotals allRunTotals;

  factory StravaAthleteStats.fromJson(Map<String, dynamic> json) {
    final recent = json['recent_run_totals'];
    final ytd = json['ytd_run_totals'];
    final all = json['all_run_totals'];
    if (recent is! Map || ytd is! Map || all is! Map) {
      throw const FormatException(
        'Strava athlete stats require recent/ytd/all run totals maps.',
      );
    }

    return StravaAthleteStats(
      recentRunTotals: StravaRunTotals.fromJson(recent.cast<String, dynamic>()),
      ytdRunTotals: StravaRunTotals.fromJson(ytd.cast<String, dynamic>()),
      allRunTotals: StravaRunTotals.fromJson(all.cast<String, dynamic>()),
    );
  }
}

class StravaSummaryActivity {
  const StravaSummaryActivity({
    required this.distanceMeters,
    required this.movingTimeSeconds,
    required this.averageSpeedMetersPerSecond,
    this.averageHeartrate,
    required this.startDate,
    required this.type,
    this.sportType,
  });

  final double distanceMeters;
  final int movingTimeSeconds;
  final double averageSpeedMetersPerSecond;
  final double? averageHeartrate;
  final DateTime startDate;
  final String type;
  final String? sportType;

  double get distanceKm => distanceMeters / 1000.0;

  bool get isRun {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType == 'run') return true;

    final normalizedSportType = sportType?.trim().toLowerCase();
    if (normalizedSportType == null || normalizedSportType.isEmpty) {
      return false;
    }

    return normalizedSportType == 'run' ||
        normalizedSportType == 'trailrun' ||
        normalizedSportType == 'virtualrun';
  }

  factory StravaSummaryActivity.fromJson(Map<String, dynamic> json) {
    final distanceMeters = _doubleFromJson(json['distance']);
    final movingTimeSeconds = _intFromJson(json['moving_time']);
    final averageSpeedMetersPerSecond = _doubleFromJson(json['average_speed']);
    final averageHeartrate = _doubleFromJson(json['average_heartrate']);
    final startDate = DateTime.tryParse(
      _stringFromJson(json['start_date']) ?? '',
    );
    final type = _stringFromJson(json['type']);

    if (distanceMeters == null ||
        movingTimeSeconds == null ||
        averageSpeedMetersPerSecond == null ||
        startDate == null ||
        type == null ||
        type.isEmpty) {
      throw const FormatException(
        'Strava summary activity requires distance, moving_time, average_speed, start_date, and type.',
      );
    }

    if (distanceMeters < 0 ||
        movingTimeSeconds < 0 ||
        averageSpeedMetersPerSecond < 0) {
      throw const FormatException(
        'Strava summary activity numeric fields must be >= 0.',
      );
    }

    if (averageHeartrate != null && averageHeartrate <= 0) {
      throw const FormatException(
        'Average heart rate must be > 0 when present.',
      );
    }

    return StravaSummaryActivity(
      distanceMeters: distanceMeters,
      movingTimeSeconds: movingTimeSeconds,
      averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
      averageHeartrate: averageHeartrate,
      startDate: startDate,
      type: type,
      sportType: _stringFromJson(json['sport_type']),
    );
  }
}

String? _stringFromJson(Object? value) => value is String ? value : null;

int? _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleFromJson(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
