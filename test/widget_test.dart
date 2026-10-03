import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/screens/home_screen.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App launch and home screen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          // Override stream providers to return empty lists immediately
          recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const RecipetoolsApp(),
      ),
    );

    // Wait for the stream to emit
    await tester.pump();
    await tester.pump();

    // After loading, it should show HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });

  testWidgets('Mobile floating navbar is positioned at the bottom of the screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const RecipetoolsApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify nav bar item is near bottom of screen (844px height), not vertically centered (around 422px)
    final homeNavFinder = find.text('Inicio').last;
    final navPosition = tester.getCenter(homeNavFinder);

    // Should be at the bottom (y > 750), definitely not in the middle (y around 422)
    expect(navPosition.dy, greaterThan(750.0));
  });
}
