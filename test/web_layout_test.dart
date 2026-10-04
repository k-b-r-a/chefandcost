import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/web_layout_provider.dart';
import 'package:recipetools/screens/home_screen.dart';
import 'package:recipetools/screens/add_ingredient_screen.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/widgets/global_ingredient_picker_sheet.dart';
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

    test('when a recipe is open, setMiddleTab keeps recipe open in right pane', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openRecipe('recipe_123');

      // Change to ingredients tab
      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.ingredients);
      var state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.selectedRecipeId, 'recipe_123');

      // Change to tools tab
      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.tools);
      state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.tools);
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.selectedRecipeId, 'recipe_123');

      // Change back to recipes tab
      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.recipes);
      state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.recipes);
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.selectedRecipeId, 'recipe_123');
    });

    test('when a new recipe is open, setMiddleTab keeps newRecipe open in right pane', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openNewRecipe();

      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.ingredients);
      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
      expect(state.rightPaneView, WebRightPaneView.newRecipe);
    });

    test('openTool changes right pane to tool and middle tab to tools', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openTool(0);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.tools);
      expect(state.rightPaneView, WebRightPaneView.tool);
      expect(state.selectedToolIndex, 0);
    });
    test('openIngredient sets leftPaneIngredient and middle tab to ingredients', () {
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
      expect(state.leftPaneIngredient, ingredient);
      expect(state.isCreatingLeftPaneIngredient, false);
      expect(state.isHomeActive, false);
    });

    test('openNewIngredient sets isCreatingLeftPaneIngredient and middle tab to ingredients', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openNewIngredient();

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.ingredients);
      expect(state.leftPaneIngredient, isNull);
      expect(state.isCreatingLeftPaneIngredient, true);
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
      expect(container.read(webLayoutProvider).leftPaneIngredient, ingredient);

      container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.settings);

      final state = container.read(webLayoutProvider);
      expect(state.middleTab, WebMiddleTab.settings);
      expect(state.rightPaneView, WebRightPaneView.settingsGeneral);
      expect(state.leftPaneIngredient, isNull);
    });

    test('when a recipe is open, openIngredient preserves recipe and sets leftPaneIngredient', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openRecipe('recipe_123');

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
      expect(state.selectedRecipeId, 'recipe_123');
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.leftPaneIngredient, ingredient);

      container.read(webLayoutProvider.notifier).closeIngredientDetail();
      final closedState = container.read(webLayoutProvider);
      expect(closedState.selectedRecipeId, 'recipe_123');
      expect(closedState.rightPaneView, WebRightPaneView.recipe);
      expect(closedState.leftPaneIngredient, isNull);
    });

    test('when a recipe is open, openNewIngredient preserves recipe and sets isCreatingLeftPaneIngredient', () {
      final container = ProviderContainer();
      container.read(webLayoutProvider.notifier).openRecipe('recipe_123');

      container.read(webLayoutProvider.notifier).openNewIngredient();

      final state = container.read(webLayoutProvider);
      expect(state.selectedRecipeId, 'recipe_123');
      expect(state.rightPaneView, WebRightPaneView.recipe);
      expect(state.isCreatingLeftPaneIngredient, true);

      container.read(webLayoutProvider.notifier).closeIngredientDetail();
      final closedState = container.read(webLayoutProvider);
      expect(closedState.selectedRecipeId, 'recipe_123');
      expect(closedState.rightPaneView, WebRightPaneView.recipe);
      expect(closedState.isCreatingLeftPaneIngredient, false);
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

      // Redundant SegmentedButton navbar is removed from middle column
      expect(find.byType(SegmentedButton<WebMiddleTab>), findsNothing);
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

      // Verify portions stepper and scale buttons exist in right financial list
      final decBtn = find.byKey(const ValueKey('decrement_portions_button'));
      final incBtn = find.byKey(const ValueKey('increment_portions_button'));
      final yieldField = find.byKey(const ValueKey('right_panel_yield_field'));
      final scaleChipX2 = find.byKey(const ValueKey('scale_preset_x2'));

      expect(decBtn, findsOneWidget);
      expect(incBtn, findsOneWidget);
      expect(yieldField, findsOneWidget);
      expect(scaleChipX2, findsOneWidget);

      // Initial portions is '1'
      expect(find.descendant(of: yieldField, matching: find.text('1')), findsOneWidget);

      // Tap increment button [+]
      await tester.tap(incBtn);
      await tester.pump();
      await tester.pump();

      // Portions incremented to '2'
      expect(find.descendant(of: yieldField, matching: find.text('2')), findsOneWidget);

      // Tap decrement button [-]
      await tester.tap(decBtn);
      await tester.pump();
      await tester.pump();

      // Portions decremented back to '1'
      expect(find.descendant(of: yieldField, matching: find.text('1')), findsOneWidget);

      // Tap scale preset x2 button
      await tester.tap(scaleChipX2);
      await tester.pump();
      await tester.pump();

      // Scaled recipe dialog opens in the middle (Dialog, not full screen route)
      expect(find.byKey(const ValueKey('scaled_recipe_dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_scaled_recipe_button')), findsOneWidget);

      // Tap Apply to Recipe button
      await tester.tap(find.byKey(const ValueKey('apply_scaled_recipe_button')));
      await tester.pump();
      await tester.pump();

      // Dialog is dismissed and portions is now updated to 2
      expect(find.byKey(const ValueKey('scaled_recipe_dialog')), findsNothing);
      expect(find.descendant(of: yieldField, matching: find.text('2')), findsOneWidget);
    });

    testWidgets('Adding ingredient inside recipe opens picker in right panel without full screen modal',
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
      await tester.tap(addRecipeBtn.first);
      await tester.pump();
      await tester.pump();

      // Right pane displays RecipeEditorScreen with financial summary initially
      expect(find.text('Resumen Financiero'), findsOneWidget);

      // Tap "Añadir ingrediente" button in recipe editor form
      final addIngredientBtn = find.widgetWithIcon(FilledButton, Icons.add_rounded);
      expect(addIngredientBtn, findsWidgets);
      await tester.tap(addIngredientBtn.first);
      await tester.pump();
      await tester.pump();

      // GlobalIngredientPickerSheet is displayed in the right panel (isPanel: true)
      expect(find.byType(GlobalIngredientPickerSheet), findsOneWidget);

      // No modal bottom sheet route is open
      expect(find.byType(ModalBottomSheetRoute), findsNothing);

      // Close the picker via the close button
      final closeBtn = find.byIcon(Icons.close);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();
      await tester.pump();

      // Returns to financial summary in right panel
      expect(find.text('Resumen Financiero'), findsOneWidget);
      expect(find.byType(GlobalIngredientPickerSheet), findsNothing);
    });

    testWidgets('Leaving recipe with unsaved changes prompts confirmation dialog',
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

      // Tap New Recipe add button
      final addRecipeBtn = find.byIcon(Icons.add);
      await tester.tap(addRecipeBtn.first);
      await tester.pump();
      await tester.pump();

      // Enter recipe name to create unsaved changes
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Delicious Pie');
      await tester.pump();

      // Attempt to navigate to Settings in NavigationRail
      final settingsRailItem = find.byIcon(Icons.settings_outlined);
      await tester.tap(settingsRailItem.first);
      await tester.pump();
      await tester.pump();

      // Unsaved changes confirmation dialog appears!
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);

      // Tap Discard
      await tester.tap(find.text('Descartar'));
      await tester.pump();
      await tester.pump();

      // Dialog is dismissed and navigation proceeded to Settings
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('web_settings_list')), findsOneWidget);
    });

    testWidgets('When no recipe is open, opening an ingredient shows HomeScreen in middle and AddIngredientScreen in right panel',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();

      final sugar = Ingredient(
        ingredientPk: 'ing_sugar',
        name: 'Sugar',
        cost: 2.5,
        quantityForCost: 1000,
        unitFk: 'unit_g',
        dateCreated: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value([sugar])),
            unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
            unitsStreamProvider.overrideWith((ref) => Stream.value(<Unit>[])),
            relatedIngredientsProvider.overrideWith((ref, query) => Stream.value(<Ingredient>[])),
          ],
          child: const RecipetoolsApp(),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Open an ingredient while no recipe is active
      final container = ProviderScope.containerOf(tester.element(find.byType(RecipetoolsApp)));
      container.read(webLayoutProvider.notifier).openIngredient(sugar);
      await tester.pump();
      await tester.pump();

      // Left panel shows AddIngredientScreen
      expect(find.byKey(const ValueKey('left_pane_ing_ing_sugar')), findsOneWidget);
      expect(find.byType(AddIngredientScreen), findsOneWidget);
      expect(find.text('Sugar'), findsWidgets);

      // Right panel shows HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('When a recipe is open, opening an ingredient opens inside the left pane, preserving recipe in center and finance view in right',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();

      final sugar = Ingredient(
        ingredientPk: 'ing_sugar',
        name: 'Sugar',
        cost: 2.5,
        quantityForCost: 1000,
        unitFk: 'unit_g',
        dateCreated: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value([sugar])),
            unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
            unitsStreamProvider.overrideWith((ref) => Stream.value(<Unit>[])),
            relatedIngredientsProvider.overrideWith((ref, query) => Stream.value(<Ingredient>[])),
          ],
          child: const RecipetoolsApp(),
        ),
      );

      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(RecipetoolsApp)));

      // Open new recipe
      container.read(webLayoutProvider.notifier).openNewRecipe();
      await tester.pump();
      await tester.pump();

      // Recipe is present in center and finance view in right
      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      expect(find.text('Resumen Financiero'), findsOneWidget);

      // Open an ingredient from left navbar ("Ingredients")
      container.read(webLayoutProvider.notifier).openIngredient(sugar);
      await tester.pump();
      await tester.pump();

      // Ingredient editor is open in the left pane
      expect(find.byKey(const ValueKey('left_pane_ing_ing_sugar')), findsOneWidget);
      expect(find.byType(AddIngredientScreen), findsOneWidget);

      // Recipe is STILL present in center pane
      expect(find.byType(RecipeEditorScreen), findsOneWidget);

      // Financial summary is STILL present in right pane
      expect(find.text('Resumen Financiero'), findsOneWidget);

      // Closing ingredient in left pane returns to ingredients list
      container.read(webLayoutProvider.notifier).closeIngredientDetail();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('web_ingredients_list')), findsOneWidget);
      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      expect(find.text('Resumen Financiero'), findsOneWidget);
    });

    testWidgets('Recipe name is kept only at top of page and redundant title in body is deleted', (WidgetTester tester) async {
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
            unitsStreamProvider.overrideWith((ref) => Stream.value(<Unit>[])),
            relatedIngredientsProvider.overrideWith((ref, query) => Stream.value(<Ingredient>[])),
          ],
          child: const RecipetoolsApp(),
        ),
      );

      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(RecipetoolsApp)));
      container.read(webLayoutProvider.notifier).openNewRecipe();
      await tester.pump();
      await tester.pump();

      // Top app bar has the name edit TextField
      final appBarNameField = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextField),
      );
      expect(appBarNameField, findsOneWidget);

      await tester.enterText(appBarNameField, 'Lemon Cake');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // In the AppBar, the title is now 'Lemon Cake'
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Lemon Cake')), findsOneWidget);

      // In the body, there is NO redundant recipe name card with Icons.restaurant_menu_rounded
      expect(find.byIcon(Icons.restaurant_menu_rounded), findsNothing);
    });
  });
}

