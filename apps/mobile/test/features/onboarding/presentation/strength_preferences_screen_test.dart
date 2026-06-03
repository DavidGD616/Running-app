import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/screens/strength_preferences_screen.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/l10n/app_localizations.dart';

class _SavedStrength {
  const _SavedStrength({
    required this.lifts,
    this.weeklyFrequency,
    this.categories,
    this.preferredDays,
    this.sameDayOrder,
  });

  final bool lifts;
  final String? weeklyFrequency;
  final List<String>? categories;
  final List<String>? preferredDays;
  final String? sameDayOrder;
}

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(this.value);

  final RunnerProfileDraft value;
  _SavedStrength? savedStrength;

  @override
  Future<RunnerProfileDraft> build() async => value;

  @override
  void setStrength({
    required bool lifts,
    String? weeklyFrequency,
    List<String>? categories,
    List<String>? preferredDays,
    String? sameDayOrder,
  }) {
    savedStrength = _SavedStrength(
      lifts: lifts,
      weeklyFrequency: weeklyFrequency,
      categories: categories,
      preferredDays: preferredDays,
      sameDayOrder: sameDayOrder,
    );
    state = AsyncData(
      value.copyWith(
        strength: RunnerProfileDraft.strengthFromInput(
          lifts: lifts,
          weeklyFrequency: weeklyFrequency,
          categories: categories,
          preferredDays: preferredDays,
          sameDayOrder: sameDayOrder,
        ),
      ),
    );
  }
}

Widget _wrap({
  required _TestOnboardingNotifier notifier,
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: RouteNames.strength,
    routes: [
      GoRoute(
        path: RouteNames.strength,
        builder: (context, state) => const StrengthPreferencesScreen(),
      ),
      GoRoute(
        path: RouteNames.preferences,
        builder: (context, state) =>
            const Scaffold(body: Text('preferences-target')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [onboardingProvider.overrideWith(() => notifier)],
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

ElevatedButton _continueButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(find.byType(ElevatedButton));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('English screen renders', (tester) async {
    final notifier = _TestOnboardingNotifier(const RunnerProfileDraft());

    await tester.pumpWidget(_wrap(notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('Strength Preferences'), findsOneWidget);
    expect(find.text('Do you lift or do strength training?'), findsOneWidget);
    expect(find.text('6 / 9'), findsOneWidget);
  });

  testWidgets('Spanish screen renders', (tester) async {
    final notifier = _TestOnboardingNotifier(const RunnerProfileDraft());

    await tester.pumpWidget(
      _wrap(notifier: notifier, locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferencias de Fuerza'), findsOneWidget);
    expect(
      find.text('¿Levantas pesas o haces entrenamiento de fuerza?'),
      findsOneWidget,
    );
  });

  testWidgets('Continue disabled until required lifting fields are complete', (
    tester,
  ) async {
    final notifier = _TestOnboardingNotifier(const RunnerProfileDraft());

    await tester.pumpWidget(_wrap(notifier: notifier));
    await tester.pumpAndSettle();

    expect(_continueButton(tester).onPressed, isNull);

    await _tapText(tester, 'Yes');
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('1 days'), findsNothing);
    expect(_continueButton(tester).onPressed, isNull);

    await _tapText(tester, '2 days');
    expect(_continueButton(tester).onPressed, isNull);

    await _tapText(tester, 'Lower body');
    expect(_continueButton(tester).onPressed, isNull);

    await _tapText(tester, 'Mon');
    expect(_continueButton(tester).onPressed, isNull);

    await _tapText(tester, 'Run first');
    expect(_continueButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'no-lifting path stores canonical false and routes to preferences',
    (tester) async {
      final notifier = _TestOnboardingNotifier(const RunnerProfileDraft());

      await tester.pumpWidget(_wrap(notifier: notifier));
      await tester.pumpAndSettle();

      await _tapText(tester, 'No');
      expect(_continueButton(tester).onPressed, isNotNull);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(notifier.savedStrength?.lifts, isFalse);
      expect(notifier.savedStrength?.weeklyFrequency, isNull);
      expect(notifier.savedStrength?.categories, isEmpty);
      expect(notifier.savedStrength?.preferredDays, isEmpty);
      expect(notifier.savedStrength?.sameDayOrder, isNull);
      expect(find.text('preferences-target'), findsOneWidget);
    },
  );

  testWidgets(
    'lifting path stores canonical values and routes to preferences',
    (tester) async {
      final notifier = _TestOnboardingNotifier(const RunnerProfileDraft());

      await tester.pumpWidget(_wrap(notifier: notifier));
      await tester.pumpAndSettle();

      await _tapText(tester, 'Yes');
      await _tapText(tester, '2 days');
      await _tapText(tester, 'Lower body');
      await _tapText(tester, 'Core / mobility');
      await _tapText(tester, 'Mon');
      await _tapText(tester, 'Thu');
      await _tapText(tester, 'Run first');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(notifier.savedStrength?.lifts, isTrue);
      expect(notifier.savedStrength?.weeklyFrequency, '2');
      expect(
        notifier.savedStrength?.categories,
        unorderedEquals([
          StrengthCategory.lowerBody.key,
          StrengthCategory.coreMobility.key,
        ]),
      );
      expect(
        notifier.savedStrength?.preferredDays,
        unorderedEquals([WeekdayChoice.monday.key, WeekdayChoice.thursday.key]),
      );
      expect(
        notifier.savedStrength?.sameDayOrder,
        SameDayOrderPreference.runFirst.key,
      );
      expect(find.text('preferences-target'), findsOneWidget);
    },
  );
}
