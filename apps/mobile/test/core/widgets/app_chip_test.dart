import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/widgets/app_chip.dart';
import 'package:running_app/core/theme/app_colors.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChip(label: 'Monday', isSelected: false, onTap: () {})),
      );
      expect(find.text('Monday'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(AppChip(label: 'Monday', isSelected: false, onTap: () => called = true)),
      );
      await tester.tap(find.byType(AppChip));
      expect(called, isTrue);
    });

    testWidgets('uses accent background when selected', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChip(label: 'Monday', isSelected: true, onTap: () {})),
      );
      await tester.pump(); // allow AnimatedContainer to settle
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.accentPrimary);
    });

    testWidgets('uses card background when not selected', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChip(label: 'Monday', isSelected: false, onTap: () {})),
      );
      await tester.pump();
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.backgroundCard);
    });

    testWidgets('meets minimum 48px tap target height', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChip(label: 'Monday', isSelected: false, onTap: () {})),
      );
      final size = tester.getSize(find.byType(AppChip));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
