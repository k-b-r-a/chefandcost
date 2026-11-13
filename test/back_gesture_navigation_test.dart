import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/delete_account_screen.dart';
import 'package:recipetools/screens/home_screen.dart';
import 'package:recipetools/screens/ingredients_screen.dart';
import 'package:recipetools/screens/privacy_policy_screen.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/screens/recipe_list_screen.dart';
import 'package:recipetools/screens/rule_of_three_screen.dart';
import 'package:recipetools/screens/settings_screen.dart';
import 'package:recipetools/screens/tools_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          recipesWithFinancialsStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
          groupsStreamProvider.overrideWith((ref) => Stream.value([])),
          unitsProvider.overrideWith((ref) async => []),
          unitsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const ChefAndCostApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Back gesture on secondary tabs returns to Home tab (index 0) before exiting',
    (WidgetTester tester) async {
      await pumpApp(tester);

      // Initially on Home tab (index 0) with canPop == true
      expect(find.byType(HomeScreen), findsOneWidget);
      final popScopeFinder = find.descendant(
        of: find.byType(MainNavigationScreen),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      );
      expect(tester.widget<PopScope>(popScopeFinder.first).canPop, isTrue);

      // Switch to Ingredients tab (index 2)
      await tester.tap(find.text('Ingredientes').last);
      await tester.pumpAndSettle();
      expect(find.byType(IngredientsScreen), findsOneWidget);

      // PopScope should now have canPop == false
      expect(tester.widget<PopScope>(popScopeFinder.first).canPop, isFalse);

      // Simulate Android system back gesture
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should return to HomeScreen (index 0) without exiting
      expect(find.byType(HomeScreen), findsOneWidget);

      // Switch to Tools tab (index 3) and back
      await tester.tap(find.text('Herramientas').last);
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      // Switch to Settings tab (index 4) and back
      await tester.tap(find.byIcon(Icons.settings_outlined).last);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      // Back on Home tab (index 0): canPop is true again
      expect(tester.widget<PopScope>(popScopeFinder.first).canPop, isTrue);
    },
  );

  testWidgets(
    'Back gesture closes active search bar first, then returns to Home tab',
    (WidgetTester tester) async {
      await pumpApp(tester);

      // Go to Recipes tab (index 1)
      await tester.tap(find.text('Recetas').last);
      await tester.pumpAndSettle();
      expect(find.byType(RecipeListScreen), findsOneWidget);

      // Open search bar
      await tester.tap(find.byKey(const ValueKey('search_button')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // First back closes search bar, stays on Recipes tab
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecipeListScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('search_button')), findsOneWidget);

      // Second back returns to Home tab (index 0)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Back gesture pops pushed Tool screen back to MainNavigationScreen, then returns to Home',
    (WidgetTester tester) async {
      await pumpApp(tester);

      // Navigate to Tools tab
      await tester.tap(find.text('Herramientas').last);
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsOneWidget);

      // Push RuleOfThreeScreen
      await tester.tap(find.text('Regla de Tres').first);
      await tester.pumpAndSettle();
      expect(find.byType(RuleOfThreeScreen), findsOneWidget);

      // First back pops RuleOfThreeScreen back to Tools tab
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RuleOfThreeScreen), findsNothing);
      expect(find.byType(ToolsScreen), findsOneWidget);

      // Second back returns to Home tab (index 0)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Back gesture pops pushed RecipeEditorScreen back to MainNavigationScreen',
    (WidgetTester tester) async {
      await pumpApp(tester);

      // Navigate to Recipes tab
      await tester.tap(find.text('Recetas').last);
      await tester.pumpAndSettle();
      expect(find.byType(RecipeListScreen), findsOneWidget);

      // Tap FAB to push RecipeEditorScreen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeEditorScreen), findsOneWidget);

      // Back gesture pops RecipeEditorScreen (no unsaved changes)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecipeEditorScreen), findsNothing);
      expect(find.byType(RecipeListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'PrivacyPolicyScreen and DeleteAccountScreen fall back to / when stack cannot pop',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();

      for (final screen in const [
        PrivacyPolicyScreen(),
        DeleteAccountScreen(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPrefs),
              recipesWithFinancialsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
              groupsStreamProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              initialRoute: '/target',
              routes: {
                '/': (_) => const Scaffold(body: Text('HOME_FALLBACK')),
                '/target': (_) => screen,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('HOME_FALLBACK'), findsOneWidget);
      }
    },
  );
}
