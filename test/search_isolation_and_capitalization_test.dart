import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/web_layout_provider.dart';
import 'package:recipetools/screens/recipe_list_screen.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/screens/add_ingredient_screen.dart';
import 'package:recipetools/screens/ingredients_screen.dart';
import 'package:recipetools/screens/kitchen_timers_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/widgets/global_ingredient_picker_sheet.dart';
import 'package:recipetools/utils/ui_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPrefs;

  final ing1 = Ingredient(
    ingredientPk: 'ing_1',
    name: 'Harina',
    cost: 10.0,
    quantityForCost: 1000.0,
    unitFk: 'unit_g',
    dateCreated: DateTime.now(),
  );

  final ing2 = Ingredient(
    ingredientPk: 'ing_2',
    name: 'Azúcar',
    cost: 15.0,
    quantityForCost: 1000.0,
    unitFk: 'unit_g',
    dateCreated: DateTime.now(),
  );

  const testUnit = Unit(
    unitPk: 'unit_g',
    name: 'Gramos',
    symbol: 'g',
    category: 'mass',
    factorToBase: 1.0,
    isMutable: false,
  );

  final testRecipeWithFinancials1 = RecipeWithFinancials(
    recipe: Recipe(
      recipePk: 'rec_1',
      name: 'Torta de Chocolate',
      description: 'Deliciosa torta',
      defaultYield: 8,
      yieldName: 'porciones',
      targetProfitMargin: 30,
      targetPricePerPortion: 16.25,
      fixedOverheadCost: 0,
      dateCreated: DateTime.now(),
      archived: false,
    ),
    financials: RecipeFinancialSummary(
      totalCost: 100,
      totalRevenue: 130,
      totalProfit: 30,
      costPerPortion: 12.5,
      profitPerPortion: 3.75,
      profitMargin: 30,
    ),
  );

  final testRecipeWithFinancials2 = RecipeWithFinancials(
    recipe: Recipe(
      recipePk: 'rec_2',
      name: 'Pan Casero',
      description: 'Pan horneado',
      defaultYield: 4,
      yieldName: 'porciones',
      targetProfitMargin: 30,
      targetPricePerPortion: 16.25,
      fixedOverheadCost: 0,
      dateCreated: DateTime.now(),
      archived: false,
    ),
    financials: RecipeFinancialSummary(
      totalCost: 50,
      totalRevenue: 65,
      totalProfit: 15,
      costPerPortion: 12.5,
      profitPerPortion: 3.75,
      profitMargin: 30,
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({
    required Widget home,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ingredientsStreamProvider.overrideWith((ref) => Stream.value([ing1, ing2])),
        unitsProvider.overrideWith((ref) => Future.value([testUnit])),
        unitsStreamProvider.overrideWith((ref) => Stream.value([testUnit])),
        recipesWithFinancialsStreamProvider.overrideWith(
          (ref) => Stream.value([testRecipeWithFinancials1, testRecipeWithFinancials2]),
        ),
        relatedIngredientsProvider.overrideWith((ref, query) => Stream.value(
              [ing1, ing2]
                  .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
                  .toList(),
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: home,
      ),
    );
  }

  group('Requirement 2: Search State Isolation', () {
    test('recipeSearchQueryProvider and ingredientSearchQueryProvider are independent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(recipeSearchQueryProvider), '');
      expect(container.read(ingredientSearchQueryProvider), '');

      // Update recipe query
      container.read(recipeSearchQueryProvider.notifier).setQuery('Torta');
      expect(container.read(recipeSearchQueryProvider), 'Torta');
      expect(container.read(ingredientSearchQueryProvider), '');

      // Update ingredient query
      container.read(ingredientSearchQueryProvider.notifier).setQuery('Harina');
      expect(container.read(recipeSearchQueryProvider), 'Torta');
      expect(container.read(ingredientSearchQueryProvider), 'Harina');

      // Clear recipe query
      container.read(recipeSearchQueryProvider.notifier).setQuery('');
      expect(container.read(recipeSearchQueryProvider), '');
      expect(container.read(ingredientSearchQueryProvider), 'Harina');
    });

    testWidgets(
      'Searching ingredients does NOT filter recipes in RecipeListScreen',
      (tester) async {
        await tester.pumpWidget(buildTestApp(home: const RecipeListScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Torta de Chocolate'), findsOneWidget);
        expect(find.text('Pan Casero'), findsOneWidget);

        // Update ingredient search query to something that does NOT match 'Torta'
        final element = tester.element(find.byType(RecipeListScreen));
        final container = ProviderScope.containerOf(element);
        container.read(ingredientSearchQueryProvider.notifier).setQuery('Harina');
        await tester.pumpAndSettle();

        // Recipes are STILL present and unaffected!
        expect(find.text('Torta de Chocolate'), findsOneWidget);
        expect(find.text('Pan Casero'), findsOneWidget);

        // Now update recipe search query
        container.read(recipeSearchQueryProvider.notifier).setQuery('Pan');
        await tester.pumpAndSettle();

        // Recipe list filtered by recipeSearchQueryProvider
        expect(find.text('Pan Casero'), findsOneWidget);
        expect(find.text('Torta de Chocolate'), findsNothing);
      },
    );

    testWidgets(
      'Searching recipes does NOT filter ingredients in IngredientsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestApp(home: const IngredientsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Harina'), findsOneWidget);
        expect(find.text('Azúcar'), findsOneWidget);

        // Update recipe search query to something that does not match ingredients
        final element = tester.element(find.byType(IngredientsScreen));
        final container = ProviderScope.containerOf(element);
        container.read(recipeSearchQueryProvider.notifier).setQuery('Torta');
        await tester.pumpAndSettle();

        // Ingredients are STILL present and unaffected!
        expect(find.text('Harina'), findsOneWidget);
        expect(find.text('Azúcar'), findsOneWidget);

        // Now update ingredient search query
        container.read(ingredientSearchQueryProvider.notifier).setQuery('Azúcar');
        await tester.pumpAndSettle();

        // Ingredients filtered by ingredientSearchQueryProvider
        expect(find.text('Azúcar'), findsOneWidget);
        expect(find.text('Harina'), findsNothing);
      },
    );

    testWidgets(
      'Web layout search bar binds to correct controller and provider per tab',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestApp(home: const MainNavigationScreen()));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MainNavigationScreen));
        final container = ProviderScope.containerOf(element);

        // In web layout, select recipes tab
        container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.recipes);
        await tester.pumpAndSettle();

        final searchFieldRecipe = find.byKey(const ValueKey('web_search_WebMiddleTab.recipes'));
        expect(searchFieldRecipe, findsOneWidget);

        await tester.enterText(searchFieldRecipe, 'Chocolate');
        await tester.pumpAndSettle();

        // recipe query updated, ingredient query empty
        expect(container.read(recipeSearchQueryProvider), 'Chocolate');
        expect(container.read(ingredientSearchQueryProvider), '');

        // Switch to ingredients tab
        container.read(webLayoutProvider.notifier).setMiddleTab(WebMiddleTab.ingredients);
        await tester.pumpAndSettle();

        final searchFieldIngredient = find.byKey(const ValueKey('web_search_WebMiddleTab.ingredients'));
        expect(searchFieldIngredient, findsOneWidget);

        await tester.enterText(searchFieldIngredient, 'Vainilla');
        await tester.pumpAndSettle();

        // Both queries are independently set without overriding each other
        expect(container.read(recipeSearchQueryProvider), 'Chocolate');
        expect(container.read(ingredientSearchQueryProvider), 'Vainilla');
      },
    );
  });

  group('Requirement 1: Text Field Auto-Capitalization', () {
    testWidgets('AddIngredientScreen name input has TextCapitalization.sentences', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AddIngredientScreen()));
      await tester.pumpAndSettle();

      final nameTextField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(nameTextField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('GlobalIngredientPickerSheet search field has TextCapitalization.sentences', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: GlobalIngredientPickerSheet(
              currentIngredients: const [],
              showPickerIngredientOptionsModal: (a, b, c, d, e, f, g) {},
              onAddIngredients: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pickerSearchField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(GlobalIngredientPickerSheet),
          matching: find.byType(TextField),
        ).first,
      );
      expect(pickerSearchField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('GlobalIngredientPickerSheet positions Add [query] card directly below search bar when empty', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: GlobalIngredientPickerSheet(
              currentIngredients: const [],
              showPickerIngredientOptionsModal: (a, b, c, d, e, f, g) {},
              onAddIngredients: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.descendant(
        of: find.byType(GlobalIngredientPickerSheet),
        matching: find.byType(TextField),
      ).first;
      await tester.enterText(searchField, 'NonExistentIngredient');
      await tester.pumpAndSettle();

      final createCardFinder = find.byKey(const ValueKey('create_new_ingredient_card'));
      expect(createCardFinder, findsOneWidget);

      final searchBoxBottom = tester.getBottomLeft(searchField).dy;
      final createCardTop = tester.getTopLeft(createCardFinder).dy;
      expect(createCardTop, greaterThan(searchBoxBottom));

      final emptyStateFinder = find.byType(AppEmptyState);
      if (emptyStateFinder.evaluate().isNotEmpty) {
        final emptyStateTop = tester.getTopLeft(emptyStateFinder).dy;
        expect(createCardTop, lessThan(emptyStateTop));
      }
    });

    testWidgets('RecipeEditorScreen fields have TextCapitalization.sentences', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
      await tester.pumpAndSettle();

      // For a new recipe, name editing TextField is active in AppBar by default
      final nameField = tester.widget<TextField>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)),
      );
      expect(nameField.textCapitalization, TextCapitalization.sentences);

      // Description field
      final descInnerField = tester.widget<TextField>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is TextFormField && w.controller?.text == '',
          ),
          matching: find.byType(TextField),
        ).first,
      );
      expect(descInnerField.textCapitalization, TextCapitalization.sentences);

      // Step instruction field
      final stepInstructionField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(RecipeEditorScreen),
          matching: find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText != null && (w.decoration!.hintText!.toLowerCase().contains('paso') || w.decoration!.hintText!.toLowerCase().contains('step')),
          ),
        ),
      );
      expect(stepInstructionField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('KitchenTimersScreen add timer dialog has TextCapitalization.sentences', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const KitchenTimersScreen()));
      await tester.pumpAndSettle();

      // Tap Floating Action Button to add timer
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Find timer label textfield
      final timerNameField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText != null && w.decoration!.labelText!.toLowerCase().contains('temporizador'),
        ),
      );
      expect(timerNameField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('Web layout search TextField has TextCapitalization.sentences', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(home: const MainNavigationScreen()));
      await tester.pumpAndSettle();

      final searchField = tester.widget<TextField>(
        find.byKey(const ValueKey('web_search_WebMiddleTab.recipes')),
      );
      expect(searchField.textCapitalization, TextCapitalization.sentences);
    });
  });
}
