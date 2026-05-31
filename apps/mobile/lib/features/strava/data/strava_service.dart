import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/strava_athlete.dart';

class StravaAthleteDataBundle {
  const StravaAthleteDataBundle({
    required this.athlete,
    required this.stats,
    required this.activities,
  });

  final StravaAthlete athlete;
  final StravaAthleteStats stats;
  final List<StravaSummaryActivity> activities;
}

abstract interface class StravaService {
  Future<StravaAthlete> fetchAthlete();

  Future<StravaAthleteStats> fetchAthleteStats();

  Future<List<StravaSummaryActivity>> fetchSummaryActivities();

  Future<void> disconnect();
}

enum StravaServiceErrorCode {
  missingClientId,
  missingSupabase,
  missingAuthSession,
  oauthDenied,
  oauthStateInvalid,
  oauthMissingScope,
  oauthFailed,
  syncFailed,
  disconnectFailed,
}

class StravaServiceException implements Exception {
  const StravaServiceException(this.code, {this.detail});

  final StravaServiceErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'StravaServiceException(code: $code, detail: ${detail ?? "n/a"})';
}

class MockStravaService implements StravaService {
  const MockStravaService();

  @override
  Future<StravaAthlete> fetchAthlete() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const StravaAthlete(
      sex: StravaAthleteSex.female,
      weightKg: 62,
      heartRateZones: StravaHeartRateZones(
        zone1: StravaHeartRateZone(minBpm: null, maxBpm: 136),
        zone2: StravaHeartRateZone(minBpm: 137, maxBpm: 149),
        zone3: StravaHeartRateZone(minBpm: 150, maxBpm: 162),
        zone4: StravaHeartRateZone(minBpm: 163, maxBpm: 174),
        zone5: StravaHeartRateZone(minBpm: 175, maxBpm: 192),
      ),
    );
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const StravaAthleteStats(
      recentRunTotals: StravaRunTotals(
        distanceMeters: 34_200,
        movingTimeSeconds: 12_420,
        activityCount: 3,
        elevationGainMeters: 260,
      ),
      ytdRunTotals: StravaRunTotals(
        distanceMeters: 1_160_000,
        movingTimeSeconds: 435_000,
        activityCount: 104,
        elevationGainMeters: 8_600,
      ),
      allRunTotals: StravaRunTotals(
        distanceMeters: 3_980_000,
        movingTimeSeconds: 1_520_000,
        activityCount: 326,
        elevationGainMeters: 24_400,
      ),
    );
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _buildMockActivities(DateTime.now().toUtc());
  }

  @override
  Future<void> disconnect() async {}
}

class RealStravaService implements StravaService {
  RealStravaService({required SupabaseClient client}) : _client = client;

  static const String _stravaClientId = String.fromEnvironment(
    'STRAVA_CLIENT_ID',
  );
  static const String _redirectUri =
      'https://hedwyrmfeaqcqqwbexzf.supabase.co/functions/v1/strava-oauth';
  static const String _scopes = 'read,activity:read_all,profile:read_all';
  static const String _authorizeBaseUrl =
      'https://www.strava.com/oauth/mobile/authorize';

  final SupabaseClient _client;

  StravaAthleteDataBundle? _cachedBundle;
  Future<StravaAthleteDataBundle>? _inFlightSync;

  @override
  Future<StravaAthlete> fetchAthlete() async {
    final bundle = await _ensureSyncedBundle();
    return bundle.athlete;
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() async {
    final bundle = await _ensureSyncedBundle();
    return bundle.stats;
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() async {
    final bundle = await _ensureSyncedBundle();
    return bundle.activities;
  }

  @override
  Future<void> disconnect() async {
    final response = await _client.functions.invoke(
      'strava-oauth',
      body: {'action': 'disconnect'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StravaServiceException(
        StravaServiceErrorCode.disconnectFailed,
        detail: response.data?.toString(),
      );
    }
    _cachedBundle = null;
  }

  Future<StravaAthleteDataBundle> _ensureSyncedBundle() {
    final cachedBundle = _cachedBundle;
    if (cachedBundle != null) return Future.value(cachedBundle);

    final inFlight = _inFlightSync;
    if (inFlight != null) return inFlight;

    final syncFuture = _syncBundle().then((bundle) {
      _cachedBundle = bundle;
      return bundle;
    }).whenComplete(() {
      _inFlightSync = null;
    });
    _inFlightSync = syncFuture;
    return syncFuture;
  }

  Future<StravaAthleteDataBundle> _syncBundle() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const StravaServiceException(
        StravaServiceErrorCode.missingAuthSession,
      );
    }

    final initialSync = await _invokeSync();
    if (initialSync.status >= 200 && initialSync.status < 300) {
      return _bundleFromSyncResponse(initialSync.data);
    }

    if (initialSync.status != 404 && initialSync.status != 401) {
      throw StravaServiceException(
        StravaServiceErrorCode.syncFailed,
        detail: initialSync.data?.toString(),
      );
    }

    await _runOauthFlow();

    final postOauthSync = await _invokeSync();
    if (postOauthSync.status < 200 || postOauthSync.status >= 300) {
      throw StravaServiceException(
        StravaServiceErrorCode.syncFailed,
        detail: postOauthSync.data?.toString(),
      );
    }

    return _bundleFromSyncResponse(postOauthSync.data);
  }

  Future<FunctionResponse> _invokeSync() {
    return _client.functions.invoke('strava-sync');
  }

  Future<void> _runOauthFlow() async {
    if (!SupabaseConfig.isConfigured) {
      throw const StravaServiceException(
        StravaServiceErrorCode.missingSupabase,
      );
    }
    if (_stravaClientId.isEmpty) {
      throw const StravaServiceException(
        StravaServiceErrorCode.missingClientId,
      );
    }

    final startResponse = await _client.functions.invoke(
      'strava-oauth',
      body: {'action': 'start'},
    );
    if (startResponse.status < 200 || startResponse.status >= 300) {
      throw StravaServiceException(
        StravaServiceErrorCode.oauthFailed,
        detail: startResponse.data?.toString(),
      );
    }

    final startData = _asStringMap(startResponse.data);
    final state = startData['state'];
    if (state is! String || state.isEmpty) {
      throw const StravaServiceException(StravaServiceErrorCode.oauthFailed);
    }

    final authorizationUrl = Uri.parse(_authorizeBaseUrl).replace(
      queryParameters: {
        'client_id': _stravaClientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': _scopes,
        'state': state,
      },
    );

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authorizationUrl.toString(),
      callbackUrlScheme: 'striviq',
    );

    final callbackUri = Uri.parse(callbackUrl);
    final status = callbackUri.queryParameters['strava_status'];
    final error = callbackUri.queryParameters['strava_error'];
    final detail = callbackUri.queryParameters['strava_detail'];

    if (status == 'success') {
      return;
    }

    if (status == 'denied') {
      throw StravaServiceException(
        StravaServiceErrorCode.oauthDenied,
        detail: error,
      );
    }

    if (status == 'missing_scope') {
      throw StravaServiceException(
        StravaServiceErrorCode.oauthMissingScope,
        detail: detail,
      );
    }

    if (status == 'invalid_state') {
      throw const StravaServiceException(StravaServiceErrorCode.oauthStateInvalid);
    }

    throw StravaServiceException(
      StravaServiceErrorCode.oauthFailed,
      detail: error ?? detail,
    );
  }

  StravaAthleteDataBundle _bundleFromSyncResponse(dynamic payload) {
    final root = _asStringMap(payload);
    final athlete = StravaAthlete.fromJson(_asStringMap(root['athlete']));
    final stats = StravaAthleteStats.fromJson(_asStringMap(root['stats']));
    final rawActivities = root['activities'];
    final activities = switch (rawActivities) {
      List<dynamic> list => list
          .map(_asStringMap)
          .map(StravaSummaryActivity.fromJson)
          .toList(growable: false),
      _ => const <StravaSummaryActivity>[],
    };

    return StravaAthleteDataBundle(
      athlete: athlete,
      stats: stats,
      activities: activities,
    );
  }
}

final stravaServiceProvider = Provider<StravaService>(
  (ref) {
    if (!SupabaseConfig.isConfigured) {
      return const MockStravaService();
    }
    final client = ref.watch(supabaseClientProvider);
    return RealStravaService(client: client);
  },
);

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return const {};
}

List<StravaSummaryActivity> _buildMockActivities(DateTime nowUtc) {
  final currentWeekStart = _mondayOf(nowUtc);
  final activities = <StravaSummaryActivity>[];

  for (var weeksAgo = 7; weeksAgo >= 0; weeksAgo--) {
    activities.addAll([
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 1)),
        distanceKm: 8,
        paceSecPerKm: 355,
      ),
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 3)),
        distanceKm: 6,
        paceSecPerKm: 365,
      ),
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 6)),
        distanceKm: 12,
        paceSecPerKm: 345,
      ),
    ]);
  }

  return activities;
}

StravaSummaryActivity _runActivity({
  required DateTime date,
  required double distanceKm,
  required int paceSecPerKm,
}) {
  final distanceMeters = distanceKm * 1000;
  final movingTimeSeconds = (distanceKm * paceSecPerKm).round();
  return StravaSummaryActivity(
    distanceMeters: distanceMeters,
    movingTimeSeconds: movingTimeSeconds,
    averageSpeedMetersPerSecond: distanceMeters / movingTimeSeconds,
    averageHeartrate: 154,
    startDate: date,
    type: 'Run',
    sportType: 'Run',
  );
}

DateTime _mondayOf(DateTime date) {
  final normalized = DateTime.utc(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
