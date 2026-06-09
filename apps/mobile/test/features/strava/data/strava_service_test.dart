import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/strava/data/strava_service.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('RealStravaService', () {
    for (final status in [401, 404, 409, 412]) {
      test(
        'starts OAuth and retries sync after initial $status response',
        () async {
          final invocations = <_FunctionInvocation>[];
          var startUrl = '';

          final service = _buildService(
            invocations: invocations,
            syncFailureStatus: status,
            onAuthenticate: ({required callbackUrlScheme, required url}) async {
              startUrl = url;
              return 'striviq://login-callback?strava_status=success';
            },
          );

          final athlete = await service.fetchAthlete();

          expect(athlete.sex, StravaAthleteSex.female);
          expect(invocations.map((invocation) => invocation.name), [
            'strava-sync',
            'strava-oauth',
            'strava-sync',
          ]);
          expect(invocations[1].body, {'action': 'start'});
          expect(
            startUrl,
            contains('https://www.strava.com/oauth/mobile/authorize'),
          );
          expect(startUrl, contains('client_id=12345'));
          expect(startUrl, contains('state=signed-state'));
        },
      );
    }

    test('maps non-reconnect sync failures to syncFailed', () async {
      final service = _buildService(
        invocations: <_FunctionInvocation>[],
        syncFailureStatus: 500,
      );

      await expectLater(
        service.fetchAthlete(),
        throwsA(
          isA<StravaServiceException>().having(
            (error) => error.code,
            'code',
            StravaServiceErrorCode.syncFailed,
          ),
        ),
      );
    });

    test(
      'preserves optional summary activity fields from sync payload',
      () async {
        final service = _buildService(
          invocations: <_FunctionInvocation>[],
          syncFailureStatus: 200,
          syncPayload: _syncPayloadWithOptionalFields,
        );

        final activities = await service.fetchSummaryActivities();
        final activity = activities.single;

        expect(activity.activityId, '987654321001');
        expect(activity.elapsedTimeSeconds, 1560);
        expect(activity.maxSpeedMetersPerSecond, 4.2);
        expect(activity.maxHeartrate, 188);
        expect(activity.totalElevationGainMeters, 120.5);
        expect(activity.workoutType, 3);
        expect(activity.sufferScore, 74);
      },
    );

    test(
      'handles missing optional summary activity fields from payload',
      () async {
        final service = _buildService(
          invocations: <_FunctionInvocation>[],
          syncFailureStatus: 200,
          syncPayload: _syncPayloadMissingOptionalFields,
        );

        final activities = await service.fetchSummaryActivities();
        final activity = activities.single;

        expect(activity.activityId, isNull);
        expect(activity.elapsedTimeSeconds, isNull);
        expect(activity.maxSpeedMetersPerSecond, isNull);
        expect(activity.maxHeartrate, isNull);
        expect(activity.totalElevationGainMeters, isNull);
        expect(activity.workoutType, isNull);
        expect(activity.sufferScore, isNull);
      },
    );

    test(
      'ignores malformed optional summary activity fields from payload',
      () async {
        final service = _buildService(
          invocations: <_FunctionInvocation>[],
          syncFailureStatus: 200,
          syncPayload: _syncPayloadWithInvalidOptionalFields,
        );

        final activities = await service.fetchSummaryActivities();
        final activity = activities.single;

        expect(activity.activityId, isNull);
        expect(activity.elapsedTimeSeconds, isNull);
        expect(activity.maxSpeedMetersPerSecond, isNull);
        expect(activity.maxHeartrate, isNull);
        expect(activity.totalElevationGainMeters, isNull);
        expect(activity.workoutType, isNull);
        expect(activity.sufferScore, isNull);
      },
    );

    test('ignores fractional optional integer fields from payload', () async {
      final service = _buildService(
        invocations: <_FunctionInvocation>[],
        syncFailureStatus: 200,
        syncPayload: _syncPayloadWithFractionalOptionalIntegerFields,
      );

      final activities = await service.fetchSummaryActivities();
      final activity = activities.single;

      expect(activity.activityId, '987654321001');
      expect(activity.elapsedTimeSeconds, isNull);
      expect(activity.maxSpeedMetersPerSecond, 4.2);
      expect(activity.maxHeartrate, 188);
      expect(activity.totalElevationGainMeters, 120.5);
      expect(activity.workoutType, isNull);
      expect(activity.sufferScore, isNull);
    });

    test('maps strava-oauth start failures to oauthFailed', () async {
      final invocations = <_FunctionInvocation>[];
      final service = _buildService(
        invocations: invocations,
        syncFailureStatus: 404,
        oauthStartStatus: 500,
      );

      await expectLater(
        service.fetchAthlete(),
        throwsA(
          isA<StravaServiceException>().having(
            (error) => error.code,
            'code',
            StravaServiceErrorCode.oauthFailed,
          ),
        ),
      );
      expect(invocations.map((invocation) => invocation.name), [
        'strava-sync',
        'strava-oauth',
      ]);
    });

    test(
      'dedupes concurrent sync calls across athlete stats and activities',
      () async {
        final invocations = <_FunctionInvocation>[];
        final service = _buildService(
          invocations: invocations,
          syncFailureStatus: 200,
        );

        final results = await Future.wait<Object>([
          service.fetchAthlete(),
          service.fetchAthleteStats(),
          service.fetchSummaryActivities(),
        ]);

        expect(results[0], isA<StravaAthlete>());
        expect(results[1], isA<StravaAthleteStats>());
        expect(results[2], isA<List<StravaSummaryActivity>>());
        expect(invocations.map((invocation) => invocation.name), [
          'strava-sync',
        ]);
      },
    );

    test('serves cached data without invoking sync again', () async {
      final invocations = <_FunctionInvocation>[];
      final service = _buildService(
        invocations: invocations,
        syncFailureStatus: 200,
      );

      final firstAthlete = await service.fetchAthlete();
      final secondAthlete = await service.fetchAthlete();

      expect(firstAthlete.sex, StravaAthleteSex.female);
      expect(secondAthlete.sex, StravaAthleteSex.female);
      expect(invocations.map((invocation) => invocation.name), ['strava-sync']);
    });

    test('maps disconnect failures to disconnectFailed', () async {
      final invocations = <_FunctionInvocation>[];
      final service = _buildService(
        invocations: invocations,
        syncFailureStatus: 200,
        disconnectStatus: 500,
      );

      await expectLater(
        service.disconnect(),
        throwsA(
          isA<StravaServiceException>().having(
            (error) => error.code,
            'code',
            StravaServiceErrorCode.disconnectFailed,
          ),
        ),
      );
      expect(invocations.map((invocation) => invocation.name), [
        'strava-oauth',
      ]);
    });
  });
}

RealStravaService _buildService({
  required List<_FunctionInvocation> invocations,
  required int syncFailureStatus,
  int oauthStartStatus = 200,
  int disconnectStatus = 200,
  StravaWebAuthenticator? onAuthenticate,
  Map<String, Object?>? syncPayload,
}) {
  var syncCallCount = 0;
  final payload = syncPayload ?? _syncPayloadWithOptionalFields;

  return RealStravaService(
    client: SupabaseClient('https://example.supabase.co', 'anon-key'),
    hasAuthSession: () => true,
    stravaClientId: '12345',
    oauthRedirectUri: 'https://example.supabase.co/functions/v1/strava-oauth',
    webAuthenticator:
        onAuthenticate ??
        ({required callbackUrlScheme, required url}) async {
          return 'striviq://login-callback?strava_status=success';
        },
    functionInvoker: (name, {body}) async {
      invocations.add(_FunctionInvocation(name: name, body: body));

      if (name == 'strava-sync') {
        syncCallCount++;
        if (syncCallCount == 1) {
          if (syncFailureStatus >= 200 && syncFailureStatus < 300) {
            return FunctionResponse(data: payload, status: syncFailureStatus);
          }
          throw FunctionException(
            status: syncFailureStatus,
            details: const {'error': 'sync failed'},
          );
        }
        return FunctionResponse(data: payload, status: 200);
      }

      if (name == 'strava-oauth') {
        final payload = body is Map ? body : const {};
        if (payload['action'] == 'disconnect') {
          if (disconnectStatus < 200 || disconnectStatus >= 300) {
            throw FunctionException(
              status: disconnectStatus,
              details: const {'error': 'disconnect failed'},
            );
          }
          return FunctionResponse(data: const {'success': true}, status: 200);
        }

        if (oauthStartStatus < 200 || oauthStartStatus >= 300) {
          throw FunctionException(
            status: oauthStartStatus,
            details: const {'error': 'oauth failed'},
          );
        }
        return FunctionResponse(
          data: const {'state': 'signed-state'},
          status: 200,
        );
      }

      throw StateError('Unexpected function invocation: $name');
    },
  );
}

const _syncPayloadWithOptionalFields = {
  'athlete': {
    'sex': 'F',
    'weight': 58,
    'heart_rate_zones': {
      'zones': [
        {'max': 138},
        {'min': 139, 'max': 151},
        {'min': 152, 'max': 164},
        {'min': 165, 'max': 176},
        {'min': 177, 'max': -1},
      ],
    },
  },
  'stats': {
    'recent_run_totals': {
      'distance': 34000,
      'moving_time': 12000,
      'count': 4,
      'elevation_gain': 220,
    },
    'ytd_run_totals': {
      'distance': 610000,
      'moving_time': 220000,
      'count': 58,
      'elevation_gain': 4500,
    },
    'all_run_totals': {
      'distance': 1900000,
      'moving_time': 720000,
      'count': 120,
      'elevation_gain': 13800,
    },
  },
  'activities': [
    {
      'distance': 5000,
      'moving_time': 1500,
      'average_speed': 3.33,
      'average_heartrate': 150,
      'id': '987654321001',
      'elapsed_time': 1560,
      'max_speed': 4.2,
      'max_heartrate': 188,
      'total_elevation_gain': 120.5,
      'workout_type': 3,
      'suffer_score': 74,
      'name': 'Morning Run',
      'description': 'Secret route notes',
      'map': {'summary_polyline': 'abc'},
      'start_latlng': [37.7, -122.4],
      'end_latlng': [37.8, -122.3],
      'location_city': 'Boulder',
      'route': {'id': 'route-id'},
      'gear': {'id': 'gear-id'},
      'photos': {'count': 2},
      'start_date': '2026-05-24T12:00:00Z',
      'type': 'Run',
      'sport_type': 'Run',
    },
  ],
};

final _syncPayloadMissingOptionalFields = {
  'athlete': {
    'sex': 'F',
    'weight': 58,
    'heart_rate_zones': {
      'zones': [
        {'max': 138},
        {'min': 139, 'max': 151},
        {'min': 152, 'max': 164},
        {'min': 165, 'max': 176},
        {'min': 177, 'max': -1},
      ],
    },
  },
  'stats': {
    'recent_run_totals': {
      'distance': 34000,
      'moving_time': 12000,
      'count': 4,
      'elevation_gain': 220,
    },
    'ytd_run_totals': {
      'distance': 610000,
      'moving_time': 220000,
      'count': 58,
      'elevation_gain': 4500,
    },
    'all_run_totals': {
      'distance': 1900000,
      'moving_time': 720000,
      'count': 120,
      'elevation_gain': 13800,
    },
  },
  'activities': [
    {
      'distance': 5000,
      'moving_time': 1500,
      'average_speed': 3.33,
      'average_heartrate': 150,
      'start_date': '2026-05-24T12:00:00Z',
      'type': 'Run',
      'sport_type': 'Run',
    },
  ],
};

final _syncPayloadWithInvalidOptionalFields = {
  'athlete': {
    'sex': 'F',
    'weight': 58,
    'heart_rate_zones': {
      'zones': [
        {'max': 138},
        {'min': 139, 'max': 151},
        {'min': 152, 'max': 164},
        {'min': 165, 'max': 176},
        {'min': 177, 'max': -1},
      ],
    },
  },
  'stats': {
    'recent_run_totals': {
      'distance': 34000,
      'moving_time': 12000,
      'count': 4,
      'elevation_gain': 220,
    },
    'ytd_run_totals': {
      'distance': 610000,
      'moving_time': 220000,
      'count': 58,
      'elevation_gain': 4500,
    },
    'all_run_totals': {
      'distance': 1900000,
      'moving_time': 720000,
      'count': 120,
      'elevation_gain': 13800,
    },
  },
  'activities': [
    {
      'distance': 5000,
      'moving_time': 1500,
      'average_speed': 3.33,
      'average_heartrate': 150,
      'id': 'not-a-number',
      'elapsed_time': -1,
      'max_speed': -4.2,
      'max_heartrate': 0,
      'total_elevation_gain': -12.0,
      'workout_type': -3,
      'suffer_score': -5,
      'start_date': '2026-05-24T12:00:00Z',
      'type': 'Run',
      'sport_type': 'Run',
    },
  ],
};

final _syncPayloadWithFractionalOptionalIntegerFields = {
  'athlete': {
    'sex': 'F',
    'weight': 58,
    'heart_rate_zones': {
      'zones': [
        {'max': 138},
        {'min': 139, 'max': 151},
        {'min': 152, 'max': 164},
        {'min': 165, 'max': 176},
        {'min': 177, 'max': -1},
      ],
    },
  },
  'stats': {
    'recent_run_totals': {
      'distance': 34000,
      'moving_time': 12000,
      'count': 4,
      'elevation_gain': 220,
    },
    'ytd_run_totals': {
      'distance': 610000,
      'moving_time': 220000,
      'count': 58,
      'elevation_gain': 4500,
    },
    'all_run_totals': {
      'distance': 1900000,
      'moving_time': 720000,
      'count': 120,
      'elevation_gain': 13800,
    },
  },
  'activities': [
    {
      'distance': 5000,
      'moving_time': 1500,
      'average_speed': 3.33,
      'average_heartrate': 150,
      'id': '987654321001',
      'elapsed_time': 1560.5,
      'max_speed': 4.2,
      'max_heartrate': 188,
      'total_elevation_gain': 120.5,
      'workout_type': 3.5,
      'suffer_score': '4.7',
      'start_date': '2026-05-24T12:00:00Z',
      'type': 'Run',
      'sport_type': 'Run',
    },
  ],
};

class _FunctionInvocation {
  const _FunctionInvocation({required this.name, this.body});

  final String name;
  final Object? body;
}
