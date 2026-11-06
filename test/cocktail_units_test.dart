import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/utils/unit_utils.dart';
import 'package:recipetools/utils/recipe_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cocktails use fluid ounces for volume while mass remains separate',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final units = await db.getAllUnits();
        final ml = units.firstWhere((u) => u.name == 'unit_milliliters');
        final massOz = units.firstWhere((u) => u.name == 'unit_ounces');
        final settings = SettingsState.initial();
        final fluidOz = UnitUtils.getTargetUnit(
          ml,
          units,
          settings,
          cocktail: true,
        )!;
        expect(fluidOz.symbol, 'oz');
        expect(fluidOz.category, 'volume');
        expect(fluidOz.factorToBase, 29.5735295625);
        expect(fluidOz.unitPk, isNot(massOz.unitPk));
        expect(UnitUtils.getTargetUnit(ml, units, settings)!.symbol, 'ml');
        expect(
          UnitUtils.getTargetUnit(
            massOz,
            units,
            settings,
            cocktail: true,
          )!.category,
          'mass',
        );
        final ingredient = Ingredient(
          ingredientPk: 'liquid',
          name: 'Rum',
          cost: 20,
          quantityForCost: 1000,
          unitFk: ml.unitPk,
          dateCreated: DateTime.now(),
          isDeleted: false,
        );
        final amount = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '59.147059125',
          sourceUnit: ml,
          targetUnit: fluidOz,
        );
        try {
          expect(double.parse(amount.amountController.text), 2);
          expect(amount.amount, closeTo(59.147059125, 0.000001));
          expect(amount.totalCost, closeTo(59.147059125 * 0.02, 0.000001));
        } finally {
          amount.amountController.dispose();
        }
      } finally {
        await db.close();
      }
    },
  );
}
