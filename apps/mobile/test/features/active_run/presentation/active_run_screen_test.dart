import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/theme/app_theme.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';
import 'package:running_app/features/active_run/presentation/screens/active_run_screen.dart';
import 'package:running_app/l10n/app_localizations.dart';

Widget buildGpsStatusCard({
  required GpsStatus gpsStatus,
  required bool timerOnlyMode,
  String label = 'Pace',
  String value = '5:30',
  String unit = '/km',
  String guidance = 'Run easy',
  Color color = Colors.blue,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: Scaffold(
        body: GpsStatusHeroPaceCard(
          gpsStatus: gpsStatus,
          timerOnlyMode: timerOnlyMode,
          label: label,
          value: value,
          unit: unit,
          guidance: guidance,
          color: color,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('_GpsStatusHeroPaceCard GPS status chips', () {
    testWidgets('acquiring shows acquiring chip and wait guidance',
        (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.acquiring,
        timerOnlyMode: false,
      ));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

      expect(find.text(l10n.gpsAcquiringTitle), findsOneWidget);
      expect(find.text(l10n.gpsWaitForSignal), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('weak shows weak signal chip and actual guidance',
        (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.weak,
        timerOnlyMode: false,
        guidance: 'Run easy',
      ));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

      expect(find.text(l10n.gpsWeakTitle), findsOneWidget);
      expect(find.text('Run easy'), findsOneWidget);
    });

    testWidgets('lost shows signal lost chip and wait guidance',
        (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.lost,
        timerOnlyMode: false,
      ));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

      expect(find.text(l10n.gpsLostTitle), findsOneWidget);
      expect(find.text(l10n.gpsWaitForSignal), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('ready shows no chip and displays pace value', (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.ready,
        timerOnlyMode: false,
        value: '5:30',
      ));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

      expect(find.text(l10n.gpsAcquiringTitle), findsNothing);
      expect(find.text(l10n.gpsWeakTitle), findsNothing);
      expect(find.text(l10n.gpsLostTitle), findsNothing);
      expect(find.text('5:30'), findsOneWidget);
    });

    testWidgets('timerOnlyMode shows timer only label chip and wait guidance',
        (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.disabled,
        timerOnlyMode: true,
      ));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

      expect(find.text(l10n.activeRunTimerOnlyLabel), findsOneWidget);
      expect(find.text(l10n.gpsWaitForSignal), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('timerOnlyMode pace is always --:-- regardless of value param',
        (tester) async {
      await tester.pumpWidget(buildGpsStatusCard(
        gpsStatus: GpsStatus.disabled,
        timerOnlyMode: true,
        value: '5:30',
      ));
      await tester.pumpAndSettle();

      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('5:30'), findsNothing);
    });
  });

  group('_GpsStatusChip', () {
    testWidgets('chip displays text with correct styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpsStatusChip(
              text: 'Weak Signal',
              color: Colors.orange,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weak Signal'), findsOneWidget);
    });
  });
}