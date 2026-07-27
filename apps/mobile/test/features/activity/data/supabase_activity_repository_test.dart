import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/activity/data/supabase_activity_repository.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'SupabaseActivityRepository writes and reads canonical plan provenance',
    () async {
      final requests = <_RecordedRequest>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(
          _RecordedRequest(
            method: request.method,
            uri: request.uri,
            body: body,
          ),
        );

        request.response.headers.contentType = ContentType.json;
        if (request.method == 'GET') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode([
                _activityRow(
                  id: 'owned-activity',
                  linkedSessionId: 'source-session',
                  planVersionId: 'source-plan',
                ),
                _activityRow(
                  id: 'legacy-activity',
                  linkedSessionId: 'historical-session',
                  planVersionId: null,
                  dataPlanVersionId: 'stale-data-plan',
                ),
              ]),
            );
        } else {
          request.response
            ..statusCode = HttpStatus.created
            ..write('[]');
        }
        await request.response.close();
      });

      final client = SupabaseClient(
        'http://${server.address.host}:${server.port}',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(_sessionJson());
      final repository = SupabaseActivityRepository(client);

      await repository.saveActivity(
        RunActivity(
          id: 'new-activity',
          source: ActivitySource.plannedSession,
          completionStatus: ActivityCompletionStatus.completed,
          recordedAt: DateTime.utc(2026, 7, 13, 7, 30),
          linkedSessionId: 'source-session',
          planVersionId: 'source-plan',
        ),
      );

      final upsert = requests.firstWhere((request) => request.method == 'POST');
      final upsertBody = jsonDecode(upsert.body) as Map<String, dynamic>;
      expect(upsertBody['plan_version_id'], 'source-plan');
      expect(
        (upsertBody['data'] as Map<String, dynamic>)['planVersionId'],
        'source-plan',
      );

      final activities = await repository.loadAllActivities();
      final owned = activities.singleWhere(
        (activity) => activity.id == 'owned-activity',
      );
      final legacy = activities.singleWhere(
        (activity) => activity.id == 'legacy-activity',
      );
      expect(owned.planVersionId, 'source-plan');
      expect(legacy.planVersionId, isNull);

      final load = requests.firstWhere((request) => request.method == 'GET');
      expect(load.uri.queryParameters['select'], contains('plan_version_id'));
    },
  );
}

Map<String, dynamic> _activityRow({
  required String id,
  required String linkedSessionId,
  required String? planVersionId,
  String? dataPlanVersionId,
}) {
  return {
    'id': id,
    'recorded_at': '2026-07-13T07:30:00.000Z',
    'linked_session_id': linkedSessionId,
    'plan_version_id': planVersionId,
    'activity_type': 'activity_run',
    'data': {
      'schemaVersion': 1,
      'kind': 'activity_run',
      'id': id,
      'source': 'planned_session',
      'completionStatus': 'completed',
      'recordedAt': '2026-07-13T07:30:00.000Z',
      'planVersionId': ?dataPlanVersionId,
    },
  };
}

String _sessionJson() {
  final expiresAt = DateTime.now().add(const Duration(hours: 1));
  final expirySeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'exp': expirySeconds,
        'sub': 'user-1',
        'role': 'authenticated',
      }),
    ),
  );
  final accessToken = 'any.$payload.any';
  return jsonEncode({
    'access_token': accessToken,
    'expires_in': 3600,
    'refresh_token': 'refresh-token',
    'token_type': 'bearer',
    'user': {
      'id': 'user-1',
      'app_metadata': const <String, dynamic>{},
      'user_metadata': const <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-07-13T00:00:00.000Z',
    },
  });
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.uri,
    required this.body,
  });

  final String method;
  final Uri uri;
  final String body;
}
