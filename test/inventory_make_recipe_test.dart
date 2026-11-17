import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/utils/recipe_utils.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.getAllUnits();
  });

  tearDown(() async {
    await db.close();
  });

  test('executeRecipeProduction deducts converted units, records financial snapshots, and supports revert', () async {
    final units = await db.getAllUnits();
    final gramUnit = units.firstWhere((u) => u.symbol == 'g');
    final kgUnit = units.firstWhere((u) => u.symbol == 'kg');

    // Ingredient: Flour, cost $2.00 per 1000g, stock in kg (2.0 kg = 2000g)
    await db.insertIngredient(
      IngredientsCompanion.insert(
        ingredientPk: const Value('ing_flour'),
        name: 'Flour',
        cost: 2.0,
        quantityForCost: 1000.0,
        unitFk: gramUnit.unitPk,
        currentStock: const Value(2.0),
        minimumStock: const Value(1.0),
        stockUnit: Value(kgUnit.unitPk),
      ),
    );

    await db.insertRecipe(
      RecipesCompanion.insert(
        recipePk: const Value('rec_bread'),
        name: 'Bread',
        defaultYield: 4.0,
        yieldName: 'loaves',
        targetPricePerPortion: const Value(3.0),
      ),
    );

    await db.insertRecipeIngredient(
      RecipeIngredientsCompanion.insert(
        recipeFk: 'rec_bread',
        ingredientFk: 'ing_flour',
        amountNeeded: 500.0, // 500g per 1x batch = 0.5kg
      ),
    );

    // Execute 3x batch -> requires 1500g = 1.5kg -> remaining 0.5kg (triggers lowStockAlert <= 1.0)
    final result = await db.executeRecipeProduction(
      recipePk: 'rec_bread',
      multiplier: 3.0,
    );

    expect(result.portionsProduced, 12.0);
    expect(result.totalCost, closeTo(3.0, 0.001)); // 1.5kg * $2/kg = $3.00
    expect(result.totalRevenue, closeTo(36.0, 0.001)); // 12 * $3.00 = $36.00
    expect(result.totalProfit, closeTo(33.0, 0.001));
    expect(result.lowStockAlerts, ['Flour']);

    final updatedFlour = await db.getIngredientById('ing_flour');
    expect(updatedFlour!.currentStock, closeTo(0.5, 0.001));

    // Check prepared recipe stock (1x = +1)
    final breadDetail = await db.getRecipeDetail('rec_bread');
    expect(breadDetail.recipe.currentStock, closeTo(3.0, 0.001));

    // Check movement ledger
    final movements = await db.watchInventoryMovements(ingredientPk: 'ing_flour').first;
    expect(movements.length, 1);
    expect(movements.first.movementType, 'recipe_production');
    expect(movements.first.deltaStock, closeTo(-1.5, 0.001));

    // Revert production -> restores stock to 2.0kg and recipe stock to 0.0
    await db.revertRecipeProduction(result.productionPk);
    final revertedFlour = await db.getIngredientById('ing_flour');
    expect(revertedFlour!.currentStock, closeTo(2.0, 0.001));
    final revertedBread = await db.getRecipeDetail('rec_bread');
    expect(revertedBread.recipe.currentStock, closeTo(0.0, 0.001));

    // Manual recipe stock adjustment
    await db.updateRecipeStock(
      recipePk: 'rec_bread',
      currentStock: 1.0,
      movementType: 'manual_restock',
    );
    final restockedBread = await db.getRecipeDetail('rec_bread');
    expect(restockedBread.recipe.currentStock, closeTo(1.0, 0.001));
    final recMovements = await db.watchRecipeInventoryMovements(recipePk: 'rec_bread').first;
    expect(recMovements.length, 3); // production, revert, manual_restock

    final summary = await db.getProductionStatisticsSummary(
      from: DateTime.now().subtract(const Duration(days: 1)),
      to: DateTime.now().add(const Duration(days: 1)),
    );
    expect(summary.totalBatches, 0); // Reverted batch excluded
  });

  test('RecipeProductionPreview calculates maxMakeableBatches and bottleneck ingredient', () async {
    final units = await db.getAllUnits();
    final gramUnit = units.firstWhere((u) => u.symbol == 'g');
    final unitMap = {for (final u in units) u.unitPk: u};

    final flour = Ingredient(
      ingredientPk: 'ing_flour',
      name: 'Flour',
      cost: 2.0,
      quantityForCost: 1000.0,
      unitFk: gramUnit.unitPk,
      dateCreated: DateTime.now(),
      isDeleted: false,
      currentStock: 1000.0,
      minimumStock: 200.0,
      stockUnit: gramUnit.unitPk,
    );
    final sugar = Ingredient(
      ingredientPk: 'ing_sugar',
      name: 'Sugar',
      cost: 3.0,
      quantityForCost: 1000.0,
      unitFk: gramUnit.unitPk,
      dateCreated: DateTime.now(),
      isDeleted: false,
      currentStock: 300.0,
      minimumStock: 100.0,
      stockUnit: gramUnit.unitPk,
    );

    final recipe = Recipe(
      recipePk: 'rec_cake',
      name: 'Cake',
      defaultYield: 8.0,
      yieldName: 'slices',
      targetProfitMargin: 0.3,
      targetPricePerPortion: 5.0,
      fixedOverheadCost: 0.0,
      dateCreated: DateTime.now(),
      archived: false,
    );

    final preview = RecipeProductionPreview.calculate(
      recipe: recipe,
      ingredients: [
        RecipeIngredientWithData(
          entry: RecipeIngredient(
            recipeIngredientPk: 'ri_1',
            recipeFk: 'rec_cake',
            ingredientFk: 'ing_flour',
            amountNeeded: 250.0, // 4x possible
          ),
          ingredient: flour,
        ),
        RecipeIngredientWithData(
          entry: RecipeIngredient(
            recipeIngredientPk: 'ri_2',
            recipeFk: 'rec_cake',
            ingredientFk: 'ing_sugar',
            amountNeeded: 150.0, // 2x possible (bottleneck)
          ),
          ingredient: sugar,
        ),
      ],
      unitMap: unitMap,
      allUnits: units,
      multiplier: 1.0,
    );

    expect(preview.maxMakeableBatches, closeTo(2.0, 0.001));
    expect(preview.maxMakeablePortions, closeTo(16.0, 0.001));
    expect(preview.bottleneckIngredientName, 'Sugar');
    expect(preview.hasInsufficient, false);
  });
}
