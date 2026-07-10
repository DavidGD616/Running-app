import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/data/adaptation_repository.dart';
import 'package:running_app/features/training_plan/data/supabase_adaptation_repository.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LocalCache implements AdaptationRepository {
  List<AdaptationReview> reviews = const [];

  @override
  List<AdaptationReview> loadAdaptationReviews() => reviews;

  @override
  List<PlanAdjustment> loadPlanAdjustments() => const [];

  @override
  List<PlanRevision> loadPlanRevisions() => const [];

  @override
  List<SessionFeedback> loadSessionFeedback() => const [];

  @override
  Future<void> saveAdaptationReviews(List<AdaptationReview> reviews) async {
    this.reviews = reviews;
  }

  @override
  Future<void> savePlanAdjustments(List<PlanAdjustment> adjustments) async {}

  @override
  Future<void> savePlanRevisions(List<PlanRevision> revisions) async {}

  @override
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback) async {}
}

void main() {
  test(
    'saveAdaptationReviews only updates local cache for signed-in users',
    () async {
      var remoteRequestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        remoteRequestCount++;
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write('[]');
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://${server.address.host}:${server.port}',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(_sessionJson());
      final cache = _LocalCache();
      final repository = SupabaseAdaptationRepository(
        client,
        localCache: cache,
      );
      final review = AdaptationReview(
        id: 'review-1',
        createdAt: DateTime.utc(2026, 7, 9),
        weekStart: DateTime.utc(2026, 7, 6),
        weekEnd: DateTime.utc(2026, 7, 12),
        status: AdaptationReviewStatus.pending,
        classification: AdaptationReviewClassification.onTrack,
        severity: AdaptationReviewSeverity.info,
        summaryKey: 'adapt_summary_on_track',
      );

      await repository.saveAdaptationReviews([review]);

      expect(cache.reviews, [review]);
      expect(remoteRequestCount, 0);
    },
  );
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
      'created_at': '2026-07-09T00:00:00.000Z',
    },
  });
}
