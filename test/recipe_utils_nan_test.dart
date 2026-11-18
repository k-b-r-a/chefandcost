import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/utils/recipe_utils.dart';

void main() {
  group('0-quantity / 0-cost ingredient NaN prevention', () {
    final now = DateTime(2026, 1, 1);

    final zeroIngredient = Ingredient(
      ingredientPk: 'ing-zero',
      name: 'Water',
      cost: 0.0,
      quantityForCost: 0.0,
      unitFk: 'unit_milliliters',
      isDeleted: false,
      dateCreated: now,
    );

    final normalIngredient = Ingredient(
      ingredientPk: 'ing-normal',
      name: 'Flour',
      cost: 10.0,
      quantityForCost: 100.0,
      unitFk: 'unit_grams',
      isDeleted: false,
      dateCreated: now,
    );

    test('RecipeIngredientData unitCost and totalCost are 0.0 for 0/0 ingredient', () {
      final zeroData = RecipeIngredientData(
        ingredient: zeroIngredient,
        initialAmount: '50',
      );
      expect(zeroData.unitCost, 0.0);
      expect(zeroData.unitCost.isNaN, isFalse);
      expect(zeroData.totalCost, 0.0);
      expect(zeroData.totalCost.isNaN, isFalse);
    });

    test('calculateSummaryFromIngredients keeps both ingredients and sums to 10.0', () {
      final zeroData = RecipeIngredientData(
        ingredient: zeroIngredient,
        initialAmount: '50',
      );
      final normalData = RecipeIngredientData(
        ingredient: normalIngredient,
        initialAmount: '100',
      );

      final summary = RecipeUtils.calculateSummaryFromIngredients(
        ingredients: [normalData, zeroData],
        yieldText: '2',
        priceText: '10',
      );

      expect(summary.totalCost, 10.0);
      expect(summary.totalCost.isNaN, isFalse);
      expect(summary.costPerPortion, 5.0);
      expect(summary.totalRevenue, 20.0);
      expect(summary.totalProfit, 10.0);
      expect(RecipeUtils.formatNumber(zeroData.totalCost), '0,00');
      expect(RecipeUtils.formatNumber(summary.totalCost), '10,00');
    });

    test('calculateSummaryFromDetail keeps both ingredients and sums to 10.0', () {
      final recipe = Recipe(
        recipePk: 'rec-1',
        name: 'Test Recipe',
        description: '',
        defaultYield: 2.0,
        yieldName: 'portions',
        targetPricePerPortion: 10.0,
        targetProfitMargin: 100.0,
        archived: false,
        dateCreated: now,
        fixedOverheadCost: 0.0,
      );

      final detail = RecipeDetail(
        recipe: recipe,
        ingredients: [
          RecipeIngredientWithData(
            entry: RecipeIngredient(
              recipeIngredientPk: 'ri-1',
              recipeFk: 'rec-1',
              ingredientFk: 'ing-normal',
              amountNeeded: 100.0,
            ),
            ingredient: normalIngredient,
          ),
          RecipeIngredientWithData(
            entry: RecipeIngredient(
              recipeIngredientPk: 'ri-2',
              recipeFk: 'rec-1',
              ingredientFk: 'ing-zero',
              amountNeeded: 50.0,
            ),
            ingredient: zeroIngredient,
          ),
        ],
        steps: const [],
      );

      final summary = RecipeUtils.calculateSummaryFromDetail(detail);
      expect(summary.totalCost, 10.0);
      expect(summary.totalCost.isNaN, isFalse);
      expect(summary.costPerPortion, 5.0);
    });

    test('formatNumber, formatQuantity, and formatFractionOrDecimal sanitize NaN', () {
      expect(RecipeUtils.formatNumber(double.nan), '0,00');
      expect(RecipeUtils.formatNumber(double.nan, decimalDigits: 0), '0');
      expect(RecipeUtils.formatQuantity(double.nan), '0');
      expect(RecipeUtils.formatFractionOrDecimal(double.nan), '0');
    });
  });
}
