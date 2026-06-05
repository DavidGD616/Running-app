import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:running_app/core/widgets/app_button.dart';
import 'package:running_app/core/utils/time_source.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/schedule_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/l10n/app_localizations.dart';

import '../../../helpers/runner_profile_fixtures.dart';

class _FixedTimeSource implements TimeSource {
  _FixedTimeSource(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(this.value);

  final RunnerProfileDraft value;
  DateTime? lastPlanStartDate;

  @override
  Future<RunnerProfileDraft> build() async => value;

  @override
  void setSchedule({
    required String trainingDays,
    required String longRunDay,
    required String weekdayTime,
    required String weekendTime,
    required List<String> hardDays,
    String? preferredTimeOfDay,
    DateTime? planStartDate,
  }) {
    lastPlanStartDate = planStartDate;
    super.setSchedule(
      trainingDays: trainingDays,
      longRunDay: longRunDay,
      weekdayTime: weekdayTime,
      weekendTime: weekendTime,
      hardDays: hardDays,
      preferredTimeOfDay: preferredTimeOfDay,
      planStartDate: planStartDate,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    required _TestOnboardingNotifier notifier,
    required ScheduleFlowMode mode,
    required DateTime now,
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/onboarding/schedule',
          builder: (context, state) => ScheduleScreen(mode: mode),
        ),
        GoRoute(
          path: RouteNames.health,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health screen'))),
        ),
      ],
      initialLocation: '/onboarding/schedule',
    );

    return ProviderScope(
      overrides: [
        onboardingProvider.overrideWith(() => notifier),
        timeSourceProvider.overrideWithValue(_FixedTimeSource(now)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
      ),
    );
  }

  test('buildPlanStartDateCandidates resolves Monday logic correctly', () {
    final monday = DateTime(2026, 6, 1);
    final sunday = DateTime(2026, 6, 7);
    final mondayCandidates = buildPlanStartDateCandidates(monday);

    expect(mondayCandidates[0].key, 'planStartToday');
    expect(mondayCandidates[0].date, DateTime(2026, 6, 1));
    expect(mondayCandidates[1].key, 'planStartTomorrow');
    expect(mondayCandidates[1].date, DateTime(2026, 6, 2));
    expect(mondayCandidates[2].key, 'planStartNextMonday');
    expect(mondayCandidates[2].date, DateTime(2026, 6, 8));

    final sundayCandidates = buildPlanStartDateCandidates(sunday);
    expect(sundayCandidates[2].date, DateTime(2026, 6, 8));
    expect(resolveNextMondayDate(sunday), DateTime(2026, 6, 8));

    expect(
      resolveNextMondayDate(DateTime(2026, 6, 1, 9, 30, 30)),
      DateTime(2026, 6, 8),
    );
    expect(resolveNextMondayDate(DateTime(2026, 6, 1, 9, 30, 30)).hour, 0);
    final monthBoundary = buildPlanStartDateCandidates(
      DateTime(2026, 5, 31, 23, 58),
    );
    expect(monthBoundary[1].date, DateTime(2026, 6, 1));
  });

  testWidgets('restored stale plan start date does not satisfy continue', (
    tester,
  ) async {
    final fixedNow = DateTime(2026, 6, 1, 9, 30);
    final draft = buildRunnerProfileDraft().copyWith(
      schedule: ScheduleProfileDraft(planStartDate: DateTime(2026, 5, 30)),
    );
    final notifier = _TestOnboardingNotifier(draft);
    await tester.pumpWidget(
      buildApp(
        notifier: notifier,
        mode: ScheduleFlowMode.onboarding,
        now: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ScheduleScreen));
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat.yMMMd(const Locale('en').toLanguageTag());

    final staleDateLabel = dateFormat.format(DateTime(2026, 5, 30));
    expect(find.textContaining(staleDateLabel), findsNothing);
    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, l10n.continueButton),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.time45min));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.time90min));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, l10n.continueButton),
          )
          .onPressed,
      isNull,
    );

    final todayLabel = l10n.scheduleStartDateToday;
    await tester.scrollUntilVisible(
      find.text(todayLabel),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text(todayLabel));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, l10n.continueButton),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('selected start date option is sent to setSchedule', (
    tester,
  ) async {
    final fixedNow = DateTime(2026, 6, 1, 9, 30);
    final draft = buildRunnerProfileDraft().copyWith(
      schedule: const ScheduleProfileDraft(),
    );
    final notifier = _TestOnboardingNotifier(draft);
    await tester.pumpWidget(
      buildApp(
        notifier: notifier,
        mode: ScheduleFlowMode.onboarding,
        now: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ScheduleScreen));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.time45min));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.time90min));
    await tester.pumpAndSettle();

    final todayLabel = l10n.scheduleStartDateToday;
    await tester.scrollUntilVisible(
      find.text(todayLabel),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text(todayLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, l10n.continueButton));
    await tester.pumpAndSettle();

    expect(notifier.lastPlanStartDate, DateTime(2026, 6, 1));
  });

  testWidgets('non-onboarding schedule mode hides start date controls', (
    tester,
  ) async {
    final fixedNow = DateTime(2026, 6, 1, 9, 30);
    final draft = buildRunnerProfileDraft().copyWith(
      schedule: ScheduleProfileDraft(
        trainingDays: 4,
        longRunDay: WeekdayChoice.monday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        planStartDate: DateTime(2026, 6, 10),
      ),
    );
    final notifier = _TestOnboardingNotifier(draft);
    await tester.pumpWidget(
      buildApp(
        notifier: notifier,
        mode: ScheduleFlowMode.changeSchedule,
        now: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ScheduleScreen));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.scheduleStartDateLabel), findsNothing);
    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, l10n.saveChangesButton),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'start date option cards render in narrow locale/large-text layouts without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(
        () => tester.binding.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final fixedNow = DateTime(2026, 6, 1, 9, 30);
      final draft = buildRunnerProfileDraft().copyWith(
        schedule: const ScheduleProfileDraft(),
      );
      final notifier = _TestOnboardingNotifier(draft);
      await tester.pumpWidget(
        buildApp(
          notifier: notifier,
          mode: ScheduleFlowMode.onboarding,
          now: fixedNow,
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ScheduleScreen));
      final l10n = AppLocalizations.of(context)!;
      final dateFormat = DateFormat.yMMMd('es');

      expect(find.text(l10n.scheduleStartDateLabel), findsOneWidget);
      expect(find.text(l10n.scheduleStartDateToday), findsOneWidget);
      expect(find.text(l10n.scheduleStartDateTomorrow), findsOneWidget);
      expect(find.text(l10n.scheduleStartDateNextMonday), findsOneWidget);
      expect(find.text(dateFormat.format(fixedNow)), findsOneWidget);
      expect(
        find.text(dateFormat.format(DateTime(2026, 6, 2))),
        findsOneWidget,
      );
      expect(
        find.text(dateFormat.format(DateTime(2026, 6, 8))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, l10n.continueButton),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
