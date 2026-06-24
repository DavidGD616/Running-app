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

  Future<void> requestWeeklyReview({
    DateTime? weekStart,
    DateTime? weekEnd,
  }) async {
    state = const AdaptationActionLoading();
    try {
      final locale = ref.read(localeProvider).value?.languageCode ?? 'en';
      final response = await ref.read(adaptPlanFunctionClientProvider)(
        'adapt-plan',
        body: {
          'action': 'review',
          'locale': locale == 'es' ? 'es' : 'en',
          if (weekStart != null) 'weekStart': _dateOnly(weekStart),
          if (weekEnd != null) 'weekEnd': _dateOnly(weekEnd),
        },
      );
      final review = _reviewFromResponse(response.data);
      if (review == null) {
        state = const AdaptationActionFailure('adaptation_parse_error');
        return;
      }
      await ref.read(adaptationReviewsProvider.notifier).recordReview(review);
      state = AdaptationReviewReady(review);
    } catch (_) {
      state = const AdaptationActionFailure('adaptation_request_failed');
    }
  }

  Future<void> acceptReview(AdaptationReview review) async {
    state = const AdaptationActionLoading();
    try {
      final response = await ref.read(adaptPlanFunctionClientProvider)(
        'adapt-plan',
        body: {'action': 'accept', 'reviewId': review.id},
      );
      final parsed = _mapFromDynamic(response.data);
      final versionId = parsed['versionId'];
      final rawPlan = parsed['plan'];
      final acceptedReview = _reviewFromResponse(response.data);
      if (versionId is! String || rawPlan is! Map) {
        state = const AdaptationActionFailure('adaptation_parse_error');
        return;
      }
      final plan = TrainingPlan.fromJson(
        rawPlan.map((key, value) => MapEntry('$key', value)),
      );
      if (plan == null) {
        state = const AdaptationActionFailure('adaptation_parse_error');
        return;
      }
      await ref
          .read(planVersionRepositoryProvider)
          .saveActivePlan(
            PlanVersion(
              id: versionId,
              generatedAt: DateTime.now(),
              requestedBy: 'adaptation',
              isActive: true,
              plan: plan,
            ),
          );
      final nextReview =
          acceptedReview ??
          review.copyWith(
            status: AdaptationReviewStatus.accepted,
            proposedPlanVersionId: versionId,
          );
      await ref
          .read(adaptationReviewsProvider.notifier)
          .recordReview(nextReview);
      ref.invalidate(trainingPlanProvider);
      ref.invalidate(adaptationReviewsProvider);
      state = AdaptationPlanApplied(nextReview);
    } catch (_) {
      state = const AdaptationActionFailure('adaptation_accept_failed');
    }
  }

  Future<void> dismissReview(AdaptationReview review) async {
    final dismissed = review.copyWith(status: AdaptationReviewStatus.dismissed);
    await ref.read(adaptationReviewsProvider.notifier).recordReview(dismissed);
    state = const AdaptationActionIdle();
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
  if (rawReview is Map<String, dynamic>) {
    return AdaptationReview.fromJson(rawReview);
  }
  if (rawReview is Map) {
    return AdaptationReview.fromJson(
      rawReview.map((key, value) => MapEntry('$key', value)),
    );
  }
  return AdaptationReview.fromJson(map);
}

Map<String, dynamic> _mapFromDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const {};
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
