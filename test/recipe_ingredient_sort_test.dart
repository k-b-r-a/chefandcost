import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const unitG = Unit(
    unitPk: 'u_g',
    name: 'Gramos',
    symbol: 'g',
    category: 'mass',
    factorToBase: 1.0,
    isMutable: false,
  );
  const unitMl = Unit(
    unitPk: 'u_ml',
    name: 'Mililitros',
    symbol: 'ml',
    category: 'volume',
    factorToBase: 1.0,
    isMutable: false,
  );
  const unitPcs = Unit(
    unitPk: 'u_pcs',
    name: 'Piezas',
    symbol: 'pcs',
    category: 'count',
    factorToBase: 1.0,
    isMutable: false,
  );
  const unitCustom = Unit(
    unitPk: 'u_custom',
    name: 'Custom',
    symbol: 'cst',
    category: null,
    factorToBase: 1.0,
    isMutable: false,
  );

  final allUnits = [unitG, unitMl, unitPcs, unitCustom];

  final ingFlour = Ingredient(
    ingredientPk: 'ing_flour',
    name: 'Flour',
    cost: 10,
    quantityForCost: 1000,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
  );
  final ingMilk = Ingredient(
    ingredientPk: 'ing_milk',
    name: 'Milk',
    cost: 5,
    quantityForCost: 1000,
    unitFk: 'u_ml',
    dateCreated: DateTime.now(),
  );
  final ingEggs = Ingredient(
    ingredientPk: 'ing_eggs',
    name: 'Eggs',
    cost: 12,
    quantityForCost: 12,
    unitFk: 'u_pcs',
    dateCreated: DateTime.now(),
  );
  final ingSugar = Ingredient(
    ingredientPk: 'ing_sugar',
    name: 'Sugar',
    cost: 8,
    quantityForCost: 1000,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
  );
  final ingWater = Ingredient(
    ingredientPk: 'ing_water',
    name: 'Water',
    cost: 1,
    quantityForCost: 1000,
    unitFk: 'u_ml',
    dateCreated: DateTime.now(),
  );

  group('RecipeIngredientSort unit tests', () {
    test('getIngredientTypeRank categorizes units correctly', () {
      final dataSolid = RecipeIngredientData(ingredient: ingFlour, sourceUnit: unitG);
      final dataLiquid = RecipeIngredientData(ingredient: ingMilk, sourceUnit: unitMl);
      final dataPieces = RecipeIngredientData(ingredient: ingEggs, sourceUnit: unitPcs);
      final dataOther = RecipeIngredientData(
        ingredient: Ingredient(
          ingredientPk: 'ing_cst',
          name: 'Mystery',
          cost: 1,
          quantityForCost: 1,
          unitFk: 'u_custom',
          dateCreated: DateTime.now(),
        ),
        sourceUnit: unitCustom,
      );

      expect(RecipeUtils.getIngredientTypeRank(dataSolid, allUnits), 0);
      expect(RecipeUtils.getIngredientTypeRank(dataLiquid, allUnits), 1);
      expect(RecipeUtils.getIngredientTypeRank(dataPieces, allUnits), 2);
      expect(RecipeUtils.getIngredientTypeRank(dataOther, allUnits), 3);
    });

    test('getSortedIngredientIndices does NOT mutate the original list', () {
      final list = [
        RecipeIngredientData(ingredient: ingMilk, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingFlour, sourceUnit: unitG),
        RecipeIngredientData(ingredient: ingEggs, sourceUnit: unitPcs),
      ];

      // Store references to verify original list is unmutated
      final firstBefore = list[0];
      final secondBefore = list[1];
      final thirdBefore = list[2];

      final sortedAlpha = RecipeUtils.getSortedIngredientIndices(
        ingredients: list,
        sort: RecipeIngredientSort.alphabetical,
        units: allUnits,
      );

      // Verify returned indices order
      // Alphabetical: Eggs (idx 2), Flour (idx 1), Milk (idx 0)
      expect(sortedAlpha, [2, 1, 0]);

      // Verify original list has not been mutated
      expect(list.length, 3);
      expect(list[0], same(firstBefore));
      expect(list[1], same(secondBefore));
      expect(list[2], same(thirdBefore));
    });

    test('getSortedIngredientIndices with Default order preserves insertion sequence', () {
      final list = [
        RecipeIngredientData(ingredient: ingMilk, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingFlour, sourceUnit: unitG),
        RecipeIngredientData(ingredient: ingSugar, sourceUnit: unitG),
        RecipeIngredientData(ingredient: ingEggs, sourceUnit: unitPcs),
      ];

      final defaultIndices = RecipeUtils.getSortedIngredientIndices(
        ingredients: list,
        sort: RecipeIngredientSort.defaultOrder,
        units: allUnits,
      );

      expect(defaultIndices, [0, 1, 2, 3]);
    });

    test('getSortedIngredientIndices with Type order sorts Solid -> Liquid -> Pieces', () {
      // Input in mixed order: Milk (Liquid), Eggs (Pieces), Sugar (Solid), Water (Liquid), Flour (Solid)
      final list = [
        RecipeIngredientData(ingredient: ingMilk, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingEggs, sourceUnit: unitPcs),
        RecipeIngredientData(ingredient: ingSugar, sourceUnit: unitG),
        RecipeIngredientData(ingredient: ingWater, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingFlour, sourceUnit: unitG),
      ];

      final typeIndices = RecipeUtils.getSortedIngredientIndices(
        ingredients: list,
        sort: RecipeIngredientSort.type,
        units: allUnits,
      );

      // Solids (Flour, Sugar) -> Liquids (Milk, Water) -> Pieces (Eggs)
      // Solid: Flour (index 4), Sugar (index 2)
      // Liquid: Milk (index 0), Water (index 3)
      // Pieces: Eggs (index 1)
      expect(typeIndices, [4, 2, 0, 3, 1]);

      final sortedNames = typeIndices.map((i) => list[i].ingredient.name).toList();
      expect(sortedNames, ['Flour', 'Sugar', 'Milk', 'Water', 'Eggs']);
    });

    test('getSortedIngredientIndices with Alphabetical order sorts names A to Z', () {
      final list = [
        RecipeIngredientData(ingredient: ingWater, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingFlour, sourceUnit: unitG),
        RecipeIngredientData(ingredient: ingMilk, sourceUnit: unitMl),
        RecipeIngredientData(ingredient: ingEggs, sourceUnit: unitPcs),
        RecipeIngredientData(ingredient: ingSugar, sourceUnit: unitG),
      ];

      final alphaIndices = RecipeUtils.getSortedIngredientIndices(
        ingredients: list,
        sort: RecipeIngredientSort.alphabetical,
        units: allUnits,
      );

      final sortedNames = alphaIndices.map((i) => list[i].ingredient.name).toList();
      expect(sortedNames, ['Eggs', 'Flour', 'Milk', 'Sugar', 'Water']);
    });
  });

  group('RecipeScreen Ingredient Sorting Controls Widget tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Renders sorting controls chips and toggles state correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(
          ingredient: ingMilk,
          amount: 250,
        ),
        InitialIngredientInput(
          ingredient: ingFlour,
          amount: 500,
        ),
        InitialIngredientInput(
          ingredient: ingEggs,
          amount: 3,
        ),
      ];

      final sharedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            unitsProvider.overrideWith((ref) => Future.value(allUnits)),
            unitsStreamProvider.overrideWith((ref) => Stream.value(allUnits)),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream.value([ingMilk, ingFlour, ingEggs]),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecipeEditorScreen(
              isTemporary: true,
              initialIngredients: initialIngredients,
              initialName: 'Pancake Recipe',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Verify sort controls exist
      expect(find.byKey(const ValueKey('recipe_ingredient_sort_controls')), findsOneWidget);
      expect(find.byKey(const ValueKey('sort_ingredient_default')), findsOneWidget);
      expect(find.byKey(const ValueKey('sort_ingredient_type')), findsOneWidget);
      expect(find.byKey(const ValueKey('sort_ingredient_alphabetical')), findsOneWidget);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Flour'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Milk')).dy < tester.getTopLeft(find.text('Flour')).dy, isTrue);
      expect(tester.getTopLeft(find.text('Flour')).dy < tester.getTopLeft(find.text('Eggs')).dy, isTrue);

      // 2. Tap Alphabetical sort
      await tester.tap(find.byKey(const ValueKey('sort_ingredient_alphabetical')));
      await tester.pumpAndSettle();

      // Verify alphabetical order: Eggs -> Flour -> Milk
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Flour'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Eggs')).dy < tester.getTopLeft(find.text('Flour')).dy, isTrue);
      expect(tester.getTopLeft(find.text('Flour')).dy < tester.getTopLeft(find.text('Milk')).dy, isTrue);

      // 3. Tap Type sort (Solid: Flour -> Liquid: Milk -> Pieces: Eggs)
      await tester.tap(find.byKey(const ValueKey('sort_ingredient_type')));
      await tester.pumpAndSettle();

      expect(find.text('Flour'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Flour')).dy < tester.getTopLeft(find.text('Milk')).dy, isTrue);
      expect(tester.getTopLeft(find.text('Milk')).dy < tester.getTopLeft(find.text('Eggs')).dy, isTrue);

      // 4. Tap Default sort (Milk -> Flour -> Eggs)
      await tester.tap(find.byKey(const ValueKey('sort_ingredient_default')));
      await tester.pumpAndSettle();

      // Restored to default insertion order
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Flour'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Milk')).dy < tester.getTopLeft(find.text('Flour')).dy, isTrue);
      expect(tester.getTopLeft(find.text('Flour')).dy < tester.getTopLeft(find.text('Eggs')).dy, isTrue);
    });
  });
}
