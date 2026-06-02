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
}) {
  var syncCallCount = 0;

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
            return FunctionResponse(
              data: _syncPayload,
              status: syncFailureStatus,
            );
          }
          throw FunctionException(
            status: syncFailureStatus,
            details: const {'error': 'sync failed'},
          );
        }
        return FunctionResponse(data: _syncPayload, status: 200);
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

const _syncPayload = {
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

class _FunctionInvocation {
  const _FunctionInvocation({required this.name, this.body});

  final String name;
  final Object? body;
}
