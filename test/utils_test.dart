import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/utils/unit_utils.dart';

void main() {
  group('RecipeUtils.parseColor', () {
    test('parses hex colors with leading hash', () {
      final color = RecipeUtils.parseColor('#FF112233');
      expect(color.toARGB32(), 0xFF112233);
    });

    test('parses 6-digit hex color by defaulting alpha', () {
      final color = RecipeUtils.parseColor('#112233');
      expect(color.toARGB32(), 0xFF112233);
    });

    test('returns fallback for null or empty string', () {
      const fallback = Colors.red;
      expect(RecipeUtils.parseColor(null, fallback: fallback), fallback);
      expect(RecipeUtils.parseColor('', fallback: fallback), fallback);
    });

    test('returns fallback for invalid string', () {
      const fallback = Colors.blue;
      expect(RecipeUtils.parseColor('not-a-color', fallback: fallback), fallback);
    });
  });

  group('UnitUtils', () {
    test('category checks', () {
      expect(UnitUtils.isMass('mass'), isTrue);
      expect(UnitUtils.isMass('volume'), isFalse);
      expect(UnitUtils.isVolume('volume'), isTrue);
      expect(UnitUtils.isVolume('mass'), isFalse);
      expect(UnitUtils.isCount('count'), isTrue);
      expect(UnitUtils.isCount(null), isFalse);
    });

    test('getCategoryIcon returns appropriate icons', () {
      expect(UnitUtils.getCategoryIcon('volume'), Icons.water_drop_outlined);
      expect(UnitUtils.getCategoryIcon('mass'), Icons.grain_rounded);
      expect(UnitUtils.getCategoryIcon('count'), Icons.widgets_outlined);
      expect(UnitUtils.getCategoryIcon('other'), Icons.inventory_2_outlined);
    });

    test('filterIngredients correctly filters by category and search query', () {
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

      final unitMap = {
        'u_g': unitG,
        'u_ml': unitMl,
        'u_pcs': unitPcs,
      };

      final ing1 = Ingredient(
        ingredientPk: '1',
        name: 'Harina de trigo',
        cost: 10,
        quantityForCost: 1000,
        unitFk: 'u_g',
        dateCreated: DateTime.now(),
      );
      final ing2 = Ingredient(
        ingredientPk: '2',
        name: 'Leche entera',
        cost: 5,
        quantityForCost: 1000,
        unitFk: 'u_ml',
        dateCreated: DateTime.now(),
      );
      final ing3 = Ingredient(
        ingredientPk: '3',
        name: 'Huevos',
        cost: 3,
        quantityForCost: 6,
        unitFk: 'u_pcs',
        dateCreated: DateTime.now(),
      );

      final ingredients = [ing1, ing2, ing3];

      // All filter
      expect(
        UnitUtils.filterIngredients(
          ingredients: ingredients,
          unitMap: unitMap,
          filter: IngredientFilterType.all,
        ).length,
        3,
      );

      // Solids filter
      final solids = UnitUtils.filterIngredients(
        ingredients: ingredients,
        unitMap: unitMap,
        filter: IngredientFilterType.solids,
      );
      expect(solids.length, 1);
      expect(solids.first.name, 'Harina de trigo');

      // Liquids filter
      final liquids = UnitUtils.filterIngredients(
        ingredients: ingredients,
        unitMap: unitMap,
        filter: IngredientFilterType.liquids,
      );
      expect(liquids.length, 1);
      expect(liquids.first.name, 'Leche entera');

      // Pieces filter
      final pieces = UnitUtils.filterIngredients(
        ingredients: ingredients,
        unitMap: unitMap,
        filter: IngredientFilterType.pieces,
      );
      expect(pieces.length, 1);
      expect(pieces.first.name, 'Huevos');

      // Search query filtering
      final searched = UnitUtils.filterIngredients(
        ingredients: ingredients,
        unitMap: unitMap,
        filter: IngredientFilterType.all,
        searchQuery: 'harina',
      );
      expect(searched.length, 1);
      expect(searched.first.name, 'Harina de trigo');
    });

    test('getTargetUnit matches user preferences', () {
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

      final units = [unitG, unitKg];
      final settings = SettingsState.initial().copyWith(
        defaultMassUnit: 'kg',
      );

      final target = UnitUtils.getTargetUnit(unitG, units, settings);
      expect(target, isNotNull);
      expect(target!.symbol, 'kg');
    });
  });
}
