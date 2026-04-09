import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RunningApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialAppFinder = find.byType(MaterialApp);
    expect(materialAppFinder, findsOneWidget);

    final app = tester.widget<MaterialApp>(materialAppFinder);
    expect(app.title, 'RunFlow');
  });
}
