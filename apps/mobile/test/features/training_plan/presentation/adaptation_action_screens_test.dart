import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_patch.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/weekly_training_summary.dart';
import 'package:running_app/features/training_plan/presentation/adaptation_actions_provider.dart';
import 'package:running_app/features/training_plan/presentation/screens/adaptation_diff_screen.dart';
import 'package:running_app/features/training_plan/presentation/screens/adaptation_review_screen.dart';
import 'package:running_app/features/training_plan/presentation/training_plan_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';
import 'package:running_app/l10n/app_localizations.dart';

enum _Action { request, accept, dismiss }

class _StubActionsNotifier extends AdaptationActionsNotifier {
  _StubActionsNotifier({required this.action, required this.succeeds});

  final _Action action;
  final bool succeeds;
  DateTime? requestedWeekStart;
  DateTime? requestedWeekEnd;

  @override
  AdaptationActionState build() => const AdaptationActionIdle();

  @override
  Future<bool> requestWeeklyReview({DateTime? weekStart, DateTime? weekEnd}) {
    expect(action, _Action.request);
    requestedWeekStart = weekStart;
    requestedWeekEnd = weekEnd;
    return _finish();
  }

  @override
  Future<bool> acceptReview(AdaptationReview review) {
    expect(action, _Action.accept);
    return _finish();
  }

  @override
  Future<bool> dismissReview(AdaptationReview review) {
    expect(action, _Action.dismiss);
    return _finish();
  }

  Future<bool> _finish() async {
    state = succeeds
        ? const AdaptationActionIdle()
        : const AdaptationActionFailure('adaptation_action_failed');
    return succeeds;
  }
}

class _FakeUserPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferences> build() async => const UserPreferences();
}

class _FakeTrainingPlanNotifier extends TrainingPlanNotifier {
  _FakeTrainingPlanNotifier(this.plan);

  final TrainingPlan plan;

  @override
  Future<TrainingPlan> build() async => plan;
}

void main() {
  for (final locale in const [Locale('en'), Locale('es')]) {
    testWidgets(
      'failed accept stays on diff and shows localized error in $locale',
      (tester) async {
        final router = _screenRouter(const AdaptationDiffScreen());
        await tester.pumpWidget(
          _app(
            router: router,
            locale: locale,
            review: _review(),
            notifier: _StubActionsNotifier(
              action: _Action.accept,
              succeeds: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_l10n(locale).adaptationApplyChanges));
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/test');
        expect(find.text(_l10n(locale).adaptationActionError), findsOneWidget);
      },
    );
  }

  testWidgets('successful accept navigates to today', (tester) async {
    final router = _screenRouter(const AdaptationDiffScreen());
    await tester.pumpWidget(
      _app(
        router: router,
        review: _review(),
        notifier: _StubActionsNotifier(action: _Action.accept, succeeds: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(_l10n(const Locale('en')).adaptationApplyChanges),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.today);
  });

  testWidgets('failed dismiss stays on review and shows error', (tester) async {
    final router = _screenRouter(const AdaptationReviewScreen());
    await tester.pumpWidget(
      _app(
        router: router,
        review: _review(),
        notifier: _StubActionsNotifier(
          action: _Action.dismiss,
          succeeds: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(_l10n(const Locale('en')).adaptationKeepOriginal),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/test');
    expect(
      find.text(_l10n(const Locale('en')).adaptationActionError),
      findsOneWidget,
    );
  });

  testWidgets('successful dismiss navigates to today', (tester) async {
    final router = _screenRouter(const AdaptationReviewScreen());
    await tester.pumpWidget(
      _app(
        router: router,
        review: _review(),
        notifier: _StubActionsNotifier(action: _Action.dismiss, succeeds: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(_l10n(const Locale('en')).adaptationKeepOriginal),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.today);
  });

  testWidgets('empty review request uses the local summary week bounds', (
    tester,
  ) async {
    final notifier = _StubActionsNotifier(
      action: _Action.request,
      succeeds: true,
    );
    final router = _screenRouter(const AdaptationReviewScreen());
    await tester.pumpWidget(
      _app(router: router, review: null, notifier: notifier),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(_l10n(const Locale('en')).adaptationGenerateReview),
    );
    await tester.pumpAndSettle();

    expect(notifier.requestedWeekStart, _summary().weekStart);
    expect(notifier.requestedWeekEnd, _summary().weekEnd);
  });

  for (final locale in const [Locale('en'), Locale('es')]) {
    testWidgets('move patch shows localized plan dates in $locale', (
      tester,
    ) async {
      final currentDate = DateTime(2026, 7, 10);
      final targetDate = DateTime(2026, 7, 12);
      final review = _review().copyWith(
        patches: [
          AdaptationPatch(
            type: AdaptationPatchType.moveSession,
            reasonKey: 'adapt_reason_missed_sessions',
            sessionId: 'session-1',
            date: targetDate,
          ),
        ],
      );
      final router = _screenRouter(const AdaptationDiffScreen());
      await tester.pumpWidget(
        _app(
          router: router,
          locale: locale,
          review: review,
          notifier: _StubActionsNotifier(
            action: _Action.accept,
            succeeds: true,
          ),
          plan: _plan(sessionDate: currentDate),
        ),
      );
      await tester.pumpAndSettle();

      final formatter = DateFormat.yMMMd(locale.toLanguageTag());
      expect(
        find.text(
          _l10n(locale).adaptationBeforeAfter(
            formatter.format(currentDate),
            formatter.format(targetDate),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('metric patch uses active plan values in $locale', (
      tester,
    ) async {
      final review = _review().copyWith(
        patches: const [
          AdaptationPatch(
            type: AdaptationPatchType.replaceSession,
            reasonKey: 'adapt_reason_high_effort_recovery',
            sessionId: 'session-1',
            beforeSessionType: SessionType.tempoRun,
            afterSessionType: SessionType.recoveryRun,
            beforeDistanceKm: 99,
            afterDistanceKm: 5,
            beforeDurationMinutes: 999,
            afterDurationMinutes: 30,
          ),
        ],
      );
      final router = _screenRouter(const AdaptationDiffScreen());
      await tester.pumpWidget(
        _app(
          router: router,
          locale: locale,
          review: review,
          notifier: _StubActionsNotifier(
            action: _Action.accept,
            succeeds: true,
          ),
          plan: _plan(),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = _l10n(locale);
      expect(
        find.text(
          l10n.adaptationBeforeAfter(
            l10n.weeklyPlanSessionEasyRun,
            l10n.weeklyPlanSessionRecoveryRun,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.adaptationBeforeAfter('8.0 km', '5.0 km')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.adaptationBeforeAfter('45 min', '30 min')),
        findsOneWidget,
      );
      expect(find.textContaining('99.0'), findsNothing);
      expect(find.textContaining('999'), findsNothing);
    });
  }

  test('adaptation flag counts use localized ICU plurals', () {
    final en = _l10n(const Locale('en'));
    final es = _l10n(const Locale('es'));

    expect(en.adaptationRecoveryFlags(0), 'No recovery flags');
    expect(en.adaptationRecoveryFlags(1), '1 recovery flag');
    expect(en.adaptationRecoveryFlags(2), '2 recovery flags');
    expect(en.adaptationPainFlags(0), 'No pain flags');
    expect(en.adaptationPainFlags(1), '1 pain flag');
    expect(en.adaptationPainFlags(2), '2 pain flags');
    expect(es.adaptationRecoveryFlags(0), 'Ninguna señal de recuperación');
    expect(es.adaptationRecoveryFlags(1), '1 señal de recuperación');
    expect(es.adaptationRecoveryFlags(2), '2 señales de recuperación');
    expect(es.adaptationPainFlags(0), 'Ninguna señal de dolor');
    expect(es.adaptationPainFlags(1), '1 señal de dolor');
    expect(es.adaptationPainFlags(2), '2 señales de dolor');
  });
}

Widget _app({
  required GoRouter router,
  required AdaptationReview? review,
  required _StubActionsNotifier notifier,
  Locale locale = const Locale('en'),
  TrainingPlan? plan,
}) {
  return ProviderScope(
    overrides: [
      adaptationActionsProvider.overrideWith(() => notifier),
      pendingAdaptationReviewProvider.overrideWithValue(review),
      weeklyTrainingSummaryProvider.overrideWithValue(_summary()),
      trainingPlanProvider.overrideWith(
        () => _FakeTrainingPlanNotifier(plan ?? _plan()),
      ),
      userPreferencesProvider.overrideWith(_FakeUserPreferencesNotifier.new),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      routerConfig: router,
    ),
  );
}

GoRouter _screenRouter(Widget screen) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: RouteNames.today,
        builder: (_, _) => const Scaffold(body: Text('today destination')),
      ),
    ],
  );
}

AppLocalizations _l10n(Locale locale) {
  return lookupAppLocalizations(locale);
}

AdaptationReview _review() {
  return AdaptationReview(
    id: 'review-1',
    createdAt: DateTime.utc(2026, 7, 9),
    weekStart: DateTime.utc(2026, 7, 6),
    weekEnd: DateTime.utc(2026, 7, 12),
    sourcePlanVersionId: 'version-1',
    status: AdaptationReviewStatus.pending,
    classification: AdaptationReviewClassification.onTrack,
    severity: AdaptationReviewSeverity.info,
    summaryKey: 'adapt_summary_on_track',
  );
}

TrainingPlan _plan({DateTime? sessionDate}) {
  return TrainingPlan(
    id: 'version-1',
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 2,
    sessions: [
      TrainingSession(
        id: 'session-1',
        date: sessionDate ?? DateTime(2026, 7, 10),
        type: SessionType.easyRun,
        status: SessionStatus.upcoming,
        weekNumber: 2,
        distanceKm: 8,
        durationMinutes: 45,
      ),
    ],
  );
}

WeeklyTrainingSummary _summary() {
  return WeeklyTrainingSummary(
    weekStart: DateTime.utc(2026, 7, 6),
    weekEnd: DateTime.utc(2026, 7, 12),
    plannedSessions: 3,
    completedSessions: 3,
    plannedDistanceKm: 20,
    completedDistanceKm: 20,
    plannedDurationMinutes: 120,
    completedDurationMinutes: 120,
    hardSessionCount: 1,
    skippedSessionCount: 0,
    veryHardSessionCount: 0,
    poorRecoveryCount: 0,
    painCount: 0,
  );
}
