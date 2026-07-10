import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../localization/presentation/locale_provider.dart';
import '../data/supabase_plan_version_repository.dart';
import '../domain/models/adaptation_review.dart';
import '../domain/models/plan_version.dart';
import '../domain/models/training_plan.dart';
import 'adaptation_provider.dart';
import 'training_plan_provider.dart';

typedef AdaptPlanFunctionClient =
    Future<FunctionResponse> Function(String name, {Object? body});

final adaptPlanFunctionClientProvider = Provider<AdaptPlanFunctionClient>((
  ref,
) {
  final client = ref.read(supabaseClientProvider);
  return (name, {body}) => client.functions.invoke(name, body: body);
});

final adaptationTimezoneOffsetMinutesProvider = Provider<int>((ref) {
  return DateTime.now().timeZoneOffset.inMinutes;
});

sealed class AdaptationActionState {
  const AdaptationActionState();
}

class AdaptationActionIdle extends AdaptationActionState {
  const AdaptationActionIdle();
}

class AdaptationActionLoading extends AdaptationActionState {
  const AdaptationActionLoading();
}

class AdaptationActionFailure extends AdaptationActionState {
  const AdaptationActionFailure(this.reason);

  final String reason;
}

class AdaptationReviewReady extends AdaptationActionState {
  const AdaptationReviewReady(this.review);

  final AdaptationReview review;
}

class AdaptationPlanApplied extends AdaptationActionState {
  const AdaptationPlanApplied(this.review);

  final AdaptationReview review;
}

class AdaptationActionsNotifier extends Notifier<AdaptationActionState> {
  @override
  AdaptationActionState build() => const AdaptationActionIdle();

  Future<bool> requestWeeklyReview({
    DateTime? weekStart,
    DateTime? weekEnd,
  }) async {
    if (!ref.mounted) return false;
    state = const AdaptationActionLoading();
    final locale = ref.read(localeProvider).value?.languageCode ?? 'en';
    final timezoneOffsetMinutes = ref.read(
      adaptationTimezoneOffsetMinutesProvider,
    );
    late final FunctionResponse response;
    try {
      response = await ref.read(adaptPlanFunctionClientProvider)(
        'adapt-plan',
        body: {
          'action': 'review',
          'locale': locale == 'es' ? 'es' : 'en',
          'timezoneOffsetMinutes': timezoneOffsetMinutes,
          if (weekStart != null) 'weekStart': _dateOnly(weekStart),
          if (weekEnd != null) 'weekEnd': _dateOnly(weekEnd),
        },
      );
    } catch (_) {
      _setFailureIfMounted('adaptation_request_failed');
      return false;
    }

    if (!_isSuccessful(response)) {
      _setFailureIfMounted('adaptation_request_failed');
      return false;
    }
    final parsed = _mapFromDynamic(response.data);
    final review = _reviewFromResponse(response.data);
    if (!_isExpectedReviewEnvelope(
      parsed,
      review: review,
      expectedStatus: AdaptationReviewStatus.pending,
    )) {
      _setFailureIfMounted('adaptation_parse_error');
      return false;
    }
    if (!ref.mounted) return true;

    await _recordReviewBestEffort(review!);
    if (!ref.mounted) return true;

    ref.invalidate(adaptationReviewsProvider);
    state = AdaptationReviewReady(review);
    return true;
  }

  Future<bool> acceptReview(AdaptationReview review) async {
    if (!ref.mounted) return false;
    state = const AdaptationActionLoading();
    late final FunctionResponse response;
    try {
      response = await ref.read(adaptPlanFunctionClientProvider)(
        'adapt-plan',
        body: {'action': 'accept', 'reviewId': review.id},
      );
    } catch (_) {
      _setFailureIfMounted('adaptation_accept_failed');
      return false;
    }

    if (!_isSuccessful(response)) {
      _setFailureIfMounted('adaptation_accept_failed');
      return false;
    }
    late final String versionId;
    late final AdaptationReview acceptedReview;
    late final TrainingPlan plan;
    try {
      final parsed = _mapFromDynamic(response.data);
      final rawVersionId = parsed['versionId'];
      final rawPlan = parsed['plan'];
      final parsedReview = _reviewFromResponse(response.data);
      if (rawVersionId is! String ||
          rawVersionId.isEmpty ||
          rawPlan is! Map ||
          parsedReview == null ||
          parsedReview.id != review.id ||
          parsedReview.status != AdaptationReviewStatus.accepted ||
          parsedReview.proposedPlanVersionId != rawVersionId) {
        throw const FormatException('Invalid accepted adaptation response');
      }
      final parsedPlan = TrainingPlan.fromJson(
        rawPlan.map((key, value) => MapEntry('$key', value)),
      );
      if (parsedPlan == null || parsedPlan.id != rawVersionId) {
        throw const FormatException('Invalid accepted adaptation plan');
      }
      versionId = rawVersionId;
      acceptedReview = parsedReview;
      plan = parsedPlan;
    } catch (_) {
      _setFailureIfMounted('adaptation_parse_error');
      return false;
    }
    if (!ref.mounted) return true;

    await _savePlanBestEffort(
      PlanVersion(
        id: versionId,
        generatedAt: DateTime.now(),
        requestedBy: 'adaptation',
        isActive: true,
        plan: plan,
      ),
    );
    if (!ref.mounted) return true;

    await _recordReviewBestEffort(acceptedReview);
    if (!ref.mounted) return true;

    ref.invalidate(trainingPlanProvider);
    ref.invalidate(adaptationReviewsProvider);
    state = AdaptationPlanApplied(acceptedReview);
    return true;
  }

  Future<bool> dismissReview(AdaptationReview review) async {
    if (!ref.mounted) return false;
    state = const AdaptationActionLoading();
    late final FunctionResponse response;
    try {
      response = await ref.read(adaptPlanFunctionClientProvider)(
        'adapt-plan',
        body: {'action': 'dismiss', 'reviewId': review.id},
      );
    } catch (_) {
      _setFailureIfMounted('adaptation_dismiss_failed');
      return false;
    }

    if (!_isSuccessful(response)) {
      _setFailureIfMounted('adaptation_dismiss_failed');
      return false;
    }
    final dismissedReview = _reviewFromResponse(response.data);
    if (dismissedReview == null ||
        dismissedReview.id != review.id ||
        dismissedReview.status != AdaptationReviewStatus.dismissed) {
      _setFailureIfMounted('adaptation_parse_error');
      return false;
    }
    if (!ref.mounted) return true;

    await _recordReviewBestEffort(dismissedReview);
    if (!ref.mounted) return true;

    ref.invalidate(adaptationReviewsProvider);
    state = const AdaptationActionIdle();
    return true;
  }

  Future<void> _recordReviewBestEffort(AdaptationReview review) async {
    try {
      await ref.read(adaptationReviewsProvider.notifier).recordReview(review);
    } catch (_) {
      // The Edge Function is authoritative; provider invalidation below
      // reconciles a failed local cache write from the server-owned row.
    }
  }

  Future<void> _savePlanBestEffort(PlanVersion version) async {
    try {
      await ref.read(planVersionRepositoryProvider).saveActivePlan(version);
    } catch (_) {
      // The accepted plan is already committed server-side. Reload it through
      // trainingPlanProvider instead of reporting the committed action failed.
    }
  }

  void _setFailureIfMounted(String reason) {
    if (ref.mounted) state = AdaptationActionFailure(reason);
  }
}

final adaptationActionsProvider =
    NotifierProvider<AdaptationActionsNotifier, AdaptationActionState>(
      AdaptationActionsNotifier.new,
    );

final pendingAdaptationReviewProvider = Provider<AdaptationReview?>((ref) {
  final reviews = ref.watch(adaptationReviewsProvider).value ?? const [];
  for (final review in reviews) {
    if (review.status == AdaptationReviewStatus.pending) return review;
  }
  return null;
});

AdaptationReview? _reviewFromResponse(Object? responseData) {
  final map = _mapFromDynamic(responseData);
  final rawReview = map['review'];
  try {
    if (rawReview is Map<String, dynamic>) {
      return AdaptationReview.fromJson(rawReview);
    }
    if (rawReview is Map) {
      return AdaptationReview.fromJson(
        rawReview.map((key, value) => MapEntry('$key', value)),
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}

bool _isExpectedReviewEnvelope(
  Map<String, dynamic> envelope, {
  required AdaptationReview? review,
  required AdaptationReviewStatus expectedStatus,
}) {
  final reviewId = envelope['reviewId'];
  return reviewId is String &&
      reviewId.isNotEmpty &&
      review != null &&
      review.id == reviewId &&
      review.status == expectedStatus;
}

Map<String, dynamic> _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const {};
}

bool _isSuccessful(FunctionResponse response) {
  return response.status >= 200 && response.status < 300;
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
