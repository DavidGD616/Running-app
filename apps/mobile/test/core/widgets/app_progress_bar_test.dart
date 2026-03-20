import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/widgets/app_progress_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, child: child),
      ),
    );

void main() {
  group('AppProgressBar', () {
    testWidgets('renders a LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 3, total: 9),
      ));
      await tester.pump(); // settle TweenAnimationBuilder
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress is 0.0 at step 0', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 0, total: 9),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.0, 0.01));
    });

    testWidgets('progress is 1.0 at final step', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 9, total: 9),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(1.0, 0.01));
    });

    testWidgets('progress is 0.5 at halfway', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 4, total: 8),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 0.01));
    });

    testWidgets('clamps to 1.0 when current exceeds total', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 12, total: 9),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(1.0, 0.01));
    });

    testWidgets('has 4px height', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppProgressBar(current: 1, total: 9),
      ));
      final sized = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AppProgressBar),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sized.height, 4);
    });
  });
}
