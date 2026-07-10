import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/activity/activity.dart';
import 'package:running_app/features/localization/presentation/locale_provider.dart';
import 'package:running_app/features/training_plan/data/adaptation_repository.dart';
import 'package:running_app/features/training_plan/data/plan_version_repository.dart';
import 'package:running_app/features/training_plan/data/supabase_plan_version_repository.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/plan_version.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_actions_provider.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_provider.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeLocaleNotifier extends LocaleNotifier {
  @override
  Future<Locale> build() async => const Locale('en');
}

class _FakeAdaptationRepository implements AsyncAdaptationRepository {
  _FakeAdaptationRepository({this.failReviewSave = false});

  final bool failReviewSave;
  List<AdaptationReview> savedReviews = const [];
  List<AdaptationReview> authoritativeReviews = const [];
  int reviewLoadCount = 0;

  @override
  Future<List<AdaptationReview>> loadAdaptationReviews() async {
    reviewLoadCount++;
    return authoritativeReviews;
  }

  @override
  Future<List<PlanAdjustment>> loadPlanAdjustments() async => const [];

  @override
  Future<List<PlanRevision>> loadPlanRevisions() async => const [];

  @override
  Future<List<SessionFeedback>> loadSessionFeedback() async => const [];

  @override
  Future<void> saveAdaptationReviews(List<AdaptationReview> reviews) async {
    if (failReviewSave) throw StateError('review cache unavailable');
    savedReviews = reviews;
  }

  @override
  Future<void> savePlanAdjustments(List<PlanAdjustment> adjustments) async {}

  @override
  Future<void> savePlanRevisions(List<PlanRevision> revisions) async {}

  @override
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback) async {}
}

class _FakePlanVersionRepository implements PlanVersionRepository {
  _FakePlanVersionRepository({this.failSave = false, this.authoritativePlan});

  final bool failSave;
  TrainingPlan? authoritativePlan;
  PlanVersion? savedVersion;
  int asyncLoadCount = 0;

  @override
  bool hasActivePlan() => savedVersion != null;

  @override
  Future<TrainingPlan?> loadActivePlanAsync() async {
    asyncLoadCount++;
    return authoritativePlan ?? savedVersion?.plan;
  }

  @override
  TrainingPlan? loadActivePlanSync() => savedVersion?.plan;

  @override
  Future<void> saveActivePlan(PlanVersion version) async {
    if (failSave) throw StateError('plan cache unavailable');
    savedVersion = version;
  }
}

void main() {
  test(
    'request returns false and retains parse failure for malformed response',
    () async {
      final repository = _FakeAdaptationRepository();
      final container = _container(
        repository: repository,
        functionClient: (_, {body}) async => FunctionResponse(
          data: const {'reviewId': 'review-1', 'review': 'invalid'},
          status: 200,
        ),
      );
      addTearDown(container.dispose);

      final succeeded = await container
          .read(adaptationActionsProvider.notifier)
          .requestWeeklyReview();

      expect(succeeded, isFalse);
      expect(
        container.read(adaptationActionsProvider),
        isA<AdaptationActionFailure>().having(
          (failure) => failure.reason,
          'reason',
          'adaptation_parse_error',
        ),
      );
      expect(repository.savedReviews, isEmpty);
    },
  );

  test(
    'accept returns false and retains failure when function throws',
    () async {
      final repository = _FakeAdaptationRepository();
      final container = _container(
        repository: repository,
        functionClient: (_, {body}) async => throw const FunctionException(
          status: 409,
          details: {'error': 'stale_review'},
        ),
      );
      addTearDown(container.dispose);

      final succeeded = await container
          .read(adaptationActionsProvider.notifier)
          .acceptReview(_review());

      expect(succeeded, isFalse);
      expect(
        container.read(adaptationActionsProvider),
        isA<AdaptationActionFailure>().having(
          (failure) => failure.reason,
          'reason',
          'adaptation_accept_failed',
        ),
      );
    },
  );

  test('accept maps a malformed nested plan to a parse failure', () async {
    final repository = _FakeAdaptationRepository();
    final acceptedReview = _review(
      status: AdaptationReviewStatus.accepted,
      proposedPlanVersionId: 'version-2',
    );
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) async => FunctionResponse(
        data: {
          'versionId': 'version-2',
          'plan': {
            ..._plan().toJson(),
            'raceGuidance': {'raceDayExecution': 42},
          },
          'review': acceptedReview.toJson(),
        },
        status: 200,
      ),
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(adaptationActionsProvider.notifier)
        .acceptReview(_review());

    expect(succeeded, isFalse);
    expect(
      container.read(adaptationActionsProvider),
      isA<AdaptationActionFailure>().having(
        (failure) => failure.reason,
        'reason',
        'adaptation_parse_error',
      ),
    );
  });

  test('dismiss calls the function and rejects a malformed review', () async {
    final repository = _FakeAdaptationRepository();
    Object? requestBody;
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) async {
        requestBody = body;
        return FunctionResponse(
          data: const {
            'review': {'id': 'review-1'},
          },
          status: 200,
        );
      },
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(adaptationActionsProvider.notifier)
        .dismissReview(_review());

    expect(succeeded, isFalse);
    expect(requestBody, {'action': 'dismiss', 'reviewId': 'review-1'});
    expect(repository.savedReviews, isEmpty);
    expect(
      container.read(adaptationActionsProvider),
      isA<AdaptationActionFailure>().having(
        (failure) => failure.reason,
        'reason',
        'adaptation_parse_error',
      ),
    );
  });

  test(
    'accept stays successful when local caches fail after server commit',
    () async {
      final repository = _FakeAdaptationRepository(failReviewSave: true);
      final planRepository = _FakePlanVersionRepository(
        failSave: true,
        authoritativePlan: _plan(id: 'version-1'),
      );
      final acceptedReview = _review(
        status: AdaptationReviewStatus.accepted,
        proposedPlanVersionId: 'version-2',
      );
      final container = _container(
        repository: repository,
        planRepository: planRepository,
        functionClient: (_, {body}) async {
          repository.authoritativeReviews = [acceptedReview];
          planRepository.authoritativePlan = _plan();
          return FunctionResponse(
            data: {
              'versionId': 'version-2',
              'plan': _plan().toJson(),
              'review': acceptedReview.toJson(),
            },
            status: 200,
          );
        },
      );
      addTearDown(container.dispose);
      final reviewSubscription = container.listen(
        adaptationReviewsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final planSubscription = container.listen(
        trainingPlanProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(reviewSubscription.close);
      addTearDown(planSubscription.close);
      await container.read(adaptationReviewsProvider.future);
      expect(
        (await container.read(trainingPlanProvider.future)).id,
        'version-1',
      );
      final initialReviewLoads = repository.reviewLoadCount;
      final initialPlanLoads = planRepository.asyncLoadCount;

      final succeeded = await container
          .read(adaptationActionsProvider.notifier)
          .acceptReview(_review());

      expect(succeeded, isTrue);
      expect(planRepository.savedVersion, isNull);
      expect(
        (await container.read(adaptationReviewsProvider.future)).single.status,
        AdaptationReviewStatus.accepted,
      );
      expect(
        (await container.read(trainingPlanProvider.future)).id,
        'version-2',
      );
      expect(repository.reviewLoadCount, greaterThan(initialReviewLoads));
      expect(planRepository.asyncLoadCount, greaterThan(initialPlanLoads));
      expect(
        container.read(adaptationActionsProvider),
        isA<AdaptationPlanApplied>(),
      );
    },
  );

  test(
    'accept returns true after plan and accepted review are cached',
    () async {
      final repository = _FakeAdaptationRepository();
      final planRepository = _FakePlanVersionRepository();
      final acceptedReview = _review(
        status: AdaptationReviewStatus.accepted,
        proposedPlanVersionId: 'version-2',
      );
      Object? requestBody;
      final container = _container(
        repository: repository,
        planRepository: planRepository,
        functionClient: (_, {body}) async {
          requestBody = body;
          return FunctionResponse(
            data: {
              'versionId': 'version-2',
              'plan': _plan().toJson(),
              'review': acceptedReview.toJson(),
            },
            status: 200,
          );
        },
      );
      addTearDown(container.dispose);

      final succeeded = await container
          .read(adaptationActionsProvider.notifier)
          .acceptReview(_review());

      expect(succeeded, isTrue);
      expect(requestBody, {'action': 'accept', 'reviewId': 'review-1'});
      expect(planRepository.savedVersion?.id, 'version-2');
      expect(
        repository.savedReviews.single.status,
        AdaptationReviewStatus.accepted,
      );
      expect(
        container.read(adaptationActionsProvider),
        isA<AdaptationPlanApplied>(),
      );
    },
  );

  test('dismiss returns true only after the server review is cached', () async {
    final repository = _FakeAdaptationRepository();
    final dismissedReview = _review(status: AdaptationReviewStatus.dismissed);
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) async => FunctionResponse(
        data: {'review': dismissedReview.toJson()},
        status: 200,
      ),
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(adaptationActionsProvider.notifier)
        .dismissReview(_review());

    expect(succeeded, isTrue);
    expect(
      repository.savedReviews.single.status,
      AdaptationReviewStatus.dismissed,
    );
    expect(
      container.read(adaptationActionsProvider),
      isA<AdaptationActionIdle>(),
    );
  });

  test('dismiss stays successful when local review cache fails', () async {
    final repository = _FakeAdaptationRepository(failReviewSave: true);
    final dismissedReview = _review(status: AdaptationReviewStatus.dismissed);
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) async {
        repository.authoritativeReviews = [dismissedReview];
        return FunctionResponse(
          data: {'review': dismissedReview.toJson()},
          status: 200,
        );
      },
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      adaptationReviewsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(adaptationReviewsProvider.future);
    final initialLoads = repository.reviewLoadCount;

    final succeeded = await container
        .read(adaptationActionsProvider.notifier)
        .dismissReview(_review());

    expect(succeeded, isTrue);
    expect(
      container.read(adaptationActionsProvider),
      isA<AdaptationActionIdle>(),
    );
    expect(
      (await container.read(adaptationReviewsProvider.future)).single.status,
      AdaptationReviewStatus.dismissed,
    );
    expect(repository.reviewLoadCount, greaterThan(initialLoads));
  });

  test('request returns true only after the review is cached', () async {
    final repository = _FakeAdaptationRepository();
    final review = _review();
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) async => FunctionResponse(
        data: {'reviewId': review.id, 'review': review.toJson()},
        status: 200,
      ),
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(adaptationActionsProvider.notifier)
        .requestWeeklyReview();

    expect(succeeded, isTrue);
    expect(repository.savedReviews.single.id, review.id);
    expect(
      container.read(adaptationActionsProvider),
      isA<AdaptationReviewReady>(),
    );
  });

  test(
    'request sends explicit local week bounds and survives cache failure',
    () async {
      final repository = _FakeAdaptationRepository(failReviewSave: true);
      final review = _review();
      Object? requestBody;
      final container = _container(
        repository: repository,
        functionClient: (_, {body}) async {
          requestBody = body;
          repository.authoritativeReviews = [review];
          return FunctionResponse(
            data: {'reviewId': review.id, 'review': review.toJson()},
            status: 200,
          );
        },
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        adaptationReviewsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(adaptationReviewsProvider.future);
      final initialLoads = repository.reviewLoadCount;

      final succeeded = await container
          .read(adaptationActionsProvider.notifier)
          .requestWeeklyReview(
            weekStart: DateTime(2026, 6, 29, 23, 30),
            weekEnd: DateTime(2026, 7, 5, 23, 30),
          );

      expect(succeeded, isTrue);
      expect(requestBody, {
        'action': 'review',
        'locale': 'en',
        'timezoneOffsetMinutes': -420,
        'weekStart': '2026-06-29',
        'weekEnd': '2026-07-05',
      });
      expect(
        container.read(adaptationActionsProvider),
        isA<AdaptationReviewReady>(),
      );
      expect(
        (await container.read(adaptationReviewsProvider.future)).single.id,
        review.id,
      );
      expect(repository.reviewLoadCount, greaterThan(initialLoads));
    },
  );

  test('disposed request returns server success without persisting', () async {
    final repository = _FakeAdaptationRepository();
    final response = Completer<FunctionResponse>();
    final container = _container(
      repository: repository,
      functionClient: (_, {body}) => response.future,
    );

    final pending = container
        .read(adaptationActionsProvider.notifier)
        .requestWeeklyReview();
    container.dispose();
    final review = _review();
    response.complete(
      FunctionResponse(
        data: {'reviewId': review.id, 'review': review.toJson()},
        status: 200,
      ),
    );

    expect(await pending, isTrue);
    expect(repository.savedReviews, isEmpty);
  });
}

ProviderContainer _container({
  required _FakeAdaptationRepository repository,
  required AdaptPlanFunctionClient functionClient,
  _FakePlanVersionRepository? planRepository,
  int timezoneOffsetMinutes = -420,
}) {
  return ProviderContainer(
    overrides: [
      localeProvider.overrideWith(_FakeLocaleNotifier.new),
      asyncAdaptationRepositoryProvider.overrideWithValue(repository),
      planVersionRepositoryProvider.overrideWithValue(
        planRepository ?? _FakePlanVersionRepository(),
      ),
      completedActivitiesProvider.overrideWithValue(const []),
      adaptationTimezoneOffsetMinutesProvider.overrideWithValue(
        timezoneOffsetMinutes,
      ),
      adaptPlanFunctionClientProvider.overrideWithValue(functionClient),
    ],
  );
}

AdaptationReview _review({
  AdaptationReviewStatus status = AdaptationReviewStatus.pending,
  String? proposedPlanVersionId,
}) {
  return AdaptationReview(
    id: 'review-1',
    createdAt: DateTime.utc(2026, 7, 9),
    weekStart: DateTime.utc(2026, 7, 6),
    weekEnd: DateTime.utc(2026, 7, 12),
    sourcePlanVersionId: 'version-1',
    proposedPlanVersionId: proposedPlanVersionId,
    status: status,
    classification: AdaptationReviewClassification.onTrack,
    severity: AdaptationReviewSeverity.info,
    summaryKey: 'adapt_summary_on_track',
  );
}

TrainingPlan _plan({String id = 'version-2'}) {
  return TrainingPlan(
    id: id,
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 2,
    sessions: [],
  );
}
