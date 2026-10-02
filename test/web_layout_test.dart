import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/web_layout_provider.dart';
import 'package:recipetools/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WebLayoutProvider tests', () {
    test('Initial state has recipes in middle and home in right pane', () {
      final container = ProviderContainer();
      final state = container.read(webLayoutProvider);

      expect(state.middleTab, WebMiddleTab.recipes);
      expect(state.rightPaneView, WebRightPaneView.home);
      expect(state.selectedRecipeId, isNull);
    });

    test('openRecipe sets right pane to recipe detail with selected recipeId', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openRecipe('recipe_abc');

      final state = container.read(webLayoutProvider);
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.selectedRecipeId, 'recipe_abc');
      expect(state.middleTab, WebMiddleTab.recipes);
    });

    test('closeDetail returns right pane to home and clears recipe selection', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openRecipe('recipe_abc');
      container.read(webLayoutProvider.notifier).closeDetail();

      final state = container.read(webLayoutProvider);
      expect(state.rightPaneView, WebRightPaneView.home);
      expect(state.selectedRecipeId, isNull);
    });

    test('openNewRecipe sets right pane to newRecipe', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openNewRecipe();

      final state = container.read(webLayoutProvider);
      expect(state.rightPaneView, WebRightPaneView.newRecipe);
      expect(state.selectedRecipeId, isNull);
    });

    test('setMiddleTab changes middle tab', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.ingredients);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
    });

    test('openTool changes right pane to tool and middle tab to tools', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openTool(0);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.tools);
      expect(state.rightPaneView, WebRightPaneView.tool);
      expect(state.selectedToolIndex, 0);
    });
    test('openIngredient sets right pane to ingredient and middle tab to ingredients', () {
      final container = ProviderContainer();
      final ingredient = Ingredient(
        ingredientPk: 'ing_1',
        name: 'Sugar',
        cost: 2.5,
        quantityForCost: 1000,
        unitFk: 'unit_g',
        dateCreated: DateTime.now(),
      );
      container.read(webLayoutProvider.notifier).openIngredient(ingredient);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
      expect(state.rightPaneView, WebRightPaneView.ingredient);
      expect(state.selectedIngredient, ingredient);
      expect(state.isHomeActive, false);
    });

    test('openNewIngredient sets right pane to newIngredient', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openNewIngredient();

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
      expect(state.rightPaneView, WebRightPaneView.newIngredient);
      expect(state.selectedIngredient, isNull);
      expect(state.isHomeActive, false);
    });

    test('openSettingsDetail sets middleTab to settings and opens detail view', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openSettingsDetail(WebRightPaneView.settingsGeneral);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.settings);
      expect(state.rightPaneView, WebRightPaneView.settingsGeneral);
      expect(state.isHomeActive, false);
    });

    test('setMiddleTab(settings) switches right pane to settingsGeneral and clears previous ingredient', () {
      final container = ProviderContainer();
      final ingredient = Ingredient(
        ingredientPk: 'ing_1',
        name: 'Sugar',
        cost: 2.5,
        quantityForCost: 1000,
        unitFk: 'unit_g',
        dateCreated: DateTime.now(),
      );
      container.read(webLayoutProvider.notifier).openIngredient(ingredient);
      expect(container.read(webLayoutProvider).rightPaneView, WebRightPaneView.ingredient);

      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.settings);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.settings);
      expect(state.rightPaneView, WebRightPaneView.settingsGeneral);
      expect(state.selectedIngredient, isNull);
    });
  });

  group('Web 3-Column Layout Widget tests', () {
    testWidgets('Wide screen layout displays NavigationRail, middle changer, and right HomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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

      await tester.pump();
      await tester.pump();

      // NavigationRail is present on wide layout
      expect(find.byType(NavigationRail), findsOneWidget);

      // HomeScreen is present in the right pane
      expect(find.byType(HomeScreen), findsOneWidget);

      // Top changer SegmentedButton is present in middle column
      expect(find.byType(SegmentedButton<WebMiddleTab>), findsOneWidget);
    });

    testWidgets('Clicking Settings in NavigationRail opens SettingsScreen in middle and SettingsGeneralScreen in right',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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

      await tester.pump();
      await tester.pump();

      // Tap Settings in NavigationRail (5th destination icon)
      final settingsRailItem = find.byIcon(Icons.settings_outlined);
      expect(settingsRailItem, findsWidgets);
      await tester.tap(settingsRailItem.first);
      await tester.pump();
      await tester.pump();

      // Middle column now shows SettingsScreen
      expect(find.byKey(const ValueKey('web_settings_list')), findsOneWidget);

      // Right pane shows SettingsGeneralScreen
      expect(find.byKey(const ValueKey('settings_general')), findsOneWidget);
    });

    testWidgets('Opening new recipe in wide screen displays web layout with persistent right financial panel and no bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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
            unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
          ],
          child: const RecipetoolsApp(),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Tap New Recipe add button in middle column toolbar
      final addRecipeBtn = find.byIcon(Icons.add);
      expect(addRecipeBtn, findsWidgets);
      await tester.tap(addRecipeBtn.first);
      await tester.pump();
      await tester.pump();

      // Right pane displays RecipeEditorScreen
      expect(find.byKey(const ValueKey('recipe_new')), findsOneWidget);

      // Financial summary is persistently displayed on the right
      expect(find.text('Resumen Financiero'), findsOneWidget);

      // Collapsible bottom sheets are NOT shown
      expect(find.byKey(const ValueKey('expanded_financials')), findsNothing);
      expect(find.byKey(const ValueKey('collapsed_financials')), findsNothing);
    });
  });
}
