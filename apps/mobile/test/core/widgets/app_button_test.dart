import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/widgets/app_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppButton — primary', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Continue', onPressed: () {})),
      );
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Go', onPressed: () => called = true)),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(called, isTrue);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Go', onPressed: null)),
      );
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('applies 0.38 opacity when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Go', onPressed: null)),
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(ElevatedButton), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.38);
    });

    testWidgets('shows spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Go', onPressed: () {}, isLoading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
    });

    testWidgets('has 48px height', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Go', onPressed: () {})),
      );
      final sized = tester.widget<SizedBox>(
        find.ancestor(of: find.byType(ElevatedButton), matching: find.byType(SizedBox)).first,
      );
      expect(sized.height, 48);
    });
  });

  group('AppButton — secondary', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Edit',
          onPressed: () {},
          variant: AppButtonVariant.secondary,
        )),
      );
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('uses OutlinedButton', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Edit',
          onPressed: () {},
          variant: AppButtonVariant.secondary,
        )),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Edit',
          onPressed: null,
          variant: AppButtonVariant.secondary,
        )),
      );
      final btn = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(btn.onPressed, isNull);
    });
  });

  group('AppButton — text', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Skip',
          onPressed: () {},
          variant: AppButtonVariant.text,
        )),
      );
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('uses TextButton', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Skip',
          onPressed: () {},
          variant: AppButtonVariant.text,
        )),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
