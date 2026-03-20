import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/core/widgets/app_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppChoiceCard', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Half Marathon',
          isSelected: false,
          onTap: () {},
        )),
      );
      expect(find.text('Half Marathon'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Half Marathon',
          subtitle: '13.1 miles',
          isSelected: false,
          onTap: () {},
        )),
      );
      expect(find.text('13.1 miles'), findsOneWidget);
    });

    testWidgets('does not render subtitle when omitted', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Half Marathon',
          isSelected: false,
          onTap: () {},
        )),
      );
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders leading widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Option',
          isSelected: false,
          onTap: () {},
          leading: const Icon(Icons.star, key: Key('leading')),
        )),
      );
      expect(find.byKey(const Key('leading')), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Option',
          isSelected: true,
          onTap: () {},
        )),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('hides check icon when not selected', (tester) async {
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Option',
          isSelected: false,
          onTap: () {},
        )),
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(AppChoiceCard(
          title: 'Option',
          isSelected: false,
          onTap: () => called = true,
        )),
      );
      await tester.tap(find.byType(AppChoiceCard));
      expect(called, isTrue);
    });
  });
}
