import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/initialize_default_database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

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
  const unitKg = Unit(
    unitPk: 'u_kg',
    name: 'Kilogramos',
    symbol: 'kg',
    category: 'mass',
    factorToBase: 1000.0,
    isMutable: false,
  );

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'defaultMassUnit': 'g',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.units).insert(unitG);
    await db.into(db.units).insert(unitKg);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecipeIngredientData target amount preservation tests', () {
    test('RecipeIngredientData preserves initialTargetAmount without 1000x multiplication', () {
      final flourKg = Ingredient(
        ingredientPk: 'flour_pk',
        name: 'Flour',
        cost: 10.0,
        quantityForCost: 1.0,
        unitFk: 'u_kg',
        dateCreated: DateTime.now(),
      );

      // Construct with initialTargetAmount: '10' (meaning 10 grams)
      final data = RecipeIngredientData(
        ingredient: flourKg,
        initialTargetAmount: '10',
        sourceUnit: unitKg,
        targetUnit: unitG,
      );

      expect(data.amountController.text, '10');
      // Amount in source unit (kg) should be 0.01 kg (10 g)
      expect(data.amount, 0.01);
      // Total cost should be 0.01 * (10 / 1) = 0.10
      expect(data.totalCost, closeTo(0.10, 0.001));
    });

    test('RecipeIngredientData without initialTargetAmount converts source to target correctly', () {
      final flourKg = Ingredient(
        ingredientPk: 'flour_pk',
        name: 'Flour',
        cost: 10.0,
        quantityForCost: 1.0,
        unitFk: 'u_kg',
        dateCreated: DateTime.now(),
      );

      // Loading from DB where amountNeeded is stored in source unit (0.01 kg)
      final data = RecipeIngredientData(
        ingredient: flourKg,
        initialAmount: '0.01',
        sourceUnit: unitKg,
        targetUnit: unitG,
      );

      // Should display as 10 grams
      expect(data.amountController.text, '10');
      expect(data.amount, 0.01);
    });
  });

  group('Database updateIngredient proportionality and stream reaction tests', () {
    test('updateIngredient scales recipe ingredients proportionately when unit changes', () async {
      // Create ingredient with kg
      await db.into(db.ingredients).insert(
        IngredientsCompanion.insert(
          ingredientPk: drift.Value('butter_pk'),
          name: 'Butter',
          cost: 20.0,
          quantityForCost: 1.0,
          unitFk: 'u_kg',
        ),
      );

      // Create recipe with 0.01 kg of butter (10 g)
      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: drift.Value('cake_pk'),
          name: 'Cake',
          description: const drift.Value('Delicious cake'),
          defaultYield: 1.0,
          yieldName: 'portions',
          targetProfitMargin: const drift.Value(0.3),
          targetPricePerPortion: const drift.Value(5.0),
        ),
      );
      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: 'cake_pk',
          ingredientFk: 'butter_pk',
          amountNeeded: 0.01,
        ),
      );

      // Now update Butter to be sold in grams (e.g. 1000 g)
      final existingButter = await db.getIngredientById('butter_pk');
      expect(existingButter, isNotNull);
      await db.updateIngredient(
        existingButter!.copyWith(
          unitFk: 'u_g',
          quantityForCost: 1000.0,
        ),
      );

      // The recipe ingredient amountNeeded should have been scaled to 10 g (0.01 * 1000 / 1)
      final recipeDetail = await db.getRecipeDetail('cake_pk');
      expect(recipeDetail.ingredients.first.entry.amountNeeded, 10.0);
    });

    testWidgets('Editing an ingredient updates recipe editor and financials in web layout without 10g changing to 10000g', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Insert ingredient Flour (1 kg for $10)
      final flour = Ingredient(
        ingredientPk: 'flour_web_pk',
        name: 'Flour',
        cost: 10.0,
        quantityForCost: 1.0,
        unitFk: 'u_kg',
        dateCreated: DateTime.now(),
      );
      await db.into(db.ingredients).insert(flour);

      // Create Recipe with 0.01 kg of Flour (which is 10g)
      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: drift.Value('cookie_recipe_pk'),
          name: 'Cookies',
          description: const drift.Value('Sweet cookies'),
          defaultYield: 1.0,
          yieldName: 'portions',
          targetProfitMargin: const drift.Value(0.5),
          targetPricePerPortion: const drift.Value(2.0),
        ),
      );
      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: 'cookie_recipe_pk',
          ingredientFk: 'flour_web_pk',
          amountNeeded: 0.01,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'cookie_recipe_pk',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify recipe loaded with 10 g
      final amountFieldFinder = find.widgetWithText(TextField, '10');
      expect(amountFieldFinder, findsOneWidget);

      // Now simulate updating the ingredient: cost changes from $10 to $20
      await db.updateIngredient(
        flour.copyWith(
          cost: 20.0,
        ),
      );
      // Invalidate stream provider to notify listeners
      container.invalidate(ingredientsStreamProvider);
      await tester.pumpAndSettle();

      // Verify that after ingredient update, the amount is STILL 10, NOT 10000!
      expect(find.widgetWithText(TextField, '10'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10000'), findsNothing);

      // Verify that total cost in the recipe was updated for 10g @ $20/kg (0.01 * 20 = $0.20)
      // Check that the updated cost appears
      expect(find.textContaining('0,20').evaluate().isNotEmpty || find.textContaining('0.20').evaluate().isNotEmpty, isTrue);
    });

    test('initializeDefaultDatabase consolidates duplicate units and removes legacy unit_spoonfuls', () async {
      // Insert duplicate unit_grams and legacy unit_spoonfuls
      await db.into(db.units).insert(
        UnitsCompanion(
          unitPk: const drift.Value('dup_g_1'),
          name: const drift.Value('unit_grams'),
          symbol: const drift.Value('g'),
          category: const drift.Value('mass'),
          factorToBase: const drift.Value(1.0),
          isMutable: const drift.Value(false),
        ),
      );
      await db.into(db.units).insert(
        UnitsCompanion(
          unitPk: const drift.Value('dup_g_2'),
          name: const drift.Value('unit_grams'),
          symbol: const drift.Value('g'),
          category: const drift.Value('mass'),
          factorToBase: const drift.Value(1.0),
          isMutable: const drift.Value(false),
        ),
      );
      await db.into(db.units).insert(
        UnitsCompanion(
          unitPk: const drift.Value('dup_spoonfuls'),
          name: const drift.Value('unit_spoonfuls'),
          symbol: const drift.Value('cuch'),
          category: const drift.Value('volume'),
          factorToBase: const drift.Value(15.0),
          isMutable: const drift.Value(false),
        ),
      );

      // Re-run initializeDefaultDatabase
      await initializeDefaultDatabase(db);

      final allUnits = await db.getAllUnits();
      final gramUnits = allUnits.where((u) => u.name == 'unit_grams').toList();
      expect(gramUnits.length, 1);

      final spoonfuls = allUnits.where((u) => u.name == 'unit_spoonfuls').toList();
      expect(spoonfuls.length, 0);

      final tbsp = allUnits.where((u) => u.name == 'unit_tablespoons').toList();
      expect(tbsp.length, 1);
    });
  });
}
