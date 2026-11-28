import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/initialize_default_database.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/timers_provider.dart';
import 'package:recipetools/utils/ingredient_text_editing_controller.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Drift schema v3 migration heals >10.0 profit margins and fluid oz symbol', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await initializeDefaultDatabase(db);
    await db.insertRecipe(
      RecipesCompanion.insert(
        recipePk: const Value('legacy-margin-recipe'),
        name: 'Legacy Margin',
        defaultYield: 4.0,
        yieldName: 'portions',
        targetProfitMargin: const Value(50.0),
      ),
    );
    await db.customStatement(
      "UPDATE units SET symbol = 'oz' WHERE name = 'unit_fluid_ounces';",
    );

    await db.customStatement(
      'UPDATE recipes SET target_profit_margin = target_profit_margin / 100.0 WHERE target_profit_margin > 10.0;',
    );
    await db.customStatement(
      "UPDATE units SET symbol = 'fl oz' WHERE name = 'unit_fluid_ounces' AND symbol = 'oz';",
    );

    final recipes = await db.getAllRecipes();
    final healed = recipes.firstWhere((r) => r.recipePk == 'legacy-margin-recipe');
    expect(healed.targetProfitMargin, closeTo(0.50, 0.0001));

    final units = await db.getAllUnits();
    final flOz = units.firstWhere((u) => u.name == 'unit_fluid_ounces');
    expect(flOz.symbol, 'fl oz');
  });

  test('RecipeUtils.calculateSummaryFromDetail includes fixedOverheadCost', () {
    final now = DateTime.now();
    final detail = RecipeDetail(
      recipe: Recipe(
        recipePk: 'r1',
        name: 'Test',
        defaultYield: 2.0,
        yieldName: 'portions',
        targetProfitMargin: 0.5,
        targetPricePerPortion: 10.0,
        fixedOverheadCost: 4.0,
        dateCreated: now,
        archived: false,
      ),
      ingredients: [
        RecipeIngredientWithData(
          entry: RecipeIngredient(
            recipeIngredientPk: 'ri1',
            recipeFk: 'r1',
            ingredientFk: 'i1',
            amountNeeded: 2.0,
          ),
          ingredient: Ingredient(
            ingredientPk: 'i1',
            name: 'Flour',
            cost: 3.0,
            quantityForCost: 1.0,
            unitFk: 'unit_def_grams',
            dateCreated: now,
            isDeleted: false,
          ),
        ),
      ],
      steps: const [],
    );

    final summary = RecipeUtils.calculateSummaryFromDetail(detail);
    // 2 * $3 + $4 overhead = $10 total cost -> $5 per portion
    expect(summary.totalCost, closeTo(10.0, 0.0001));
    expect(summary.costPerPortion, closeTo(5.0, 0.0001));
  });

  test('IngredientTextEditingController matches Unicode non-Latin scripts', () {
    final now = DateTime.now();
    final controller = IngredientTextEditingController(
      colorScheme: const ColorScheme.light(),
      ingredients: [
        Ingredient(
          ingredientPk: 'ru1',
          name: 'Мука',
          cost: 1.0,
          quantityForCost: 1.0,
          unitFk: 'g',
          dateCreated: now,
          isDeleted: false,
        ),
      ],
    );
    addTearDown(controller.dispose);

    final matches = controller.cachedRegex!.allMatches('Добавить Мука 200г').toList();
    expect(matches.length, 1);
    expect(matches.first.group(0), 'Мука');
  });

  test('KitchenTimersNotifier stores wall-clock targetEndTime', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(kitchenTimersProvider.notifier);
    notifier.addTimer('Bake', 120);

    final timers = container.read(kitchenTimersProvider);
    expect(timers.length, 1);
    expect(timers.first.targetEndTime, isNotNull);
    expect(timers.first.remainingSeconds, 120);
  });
}
