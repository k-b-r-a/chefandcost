import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/add_ingredient_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Tapping Cost and Quantity inputs in AddIngredientScreen selects full text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();

      final testIngredient = Ingredient(
        ingredientPk: 'ing_1',
        name: 'Harina',
        cost: 1500.0,
        quantityForCost: 1000.0,
        unitFk: 'unit_g',
        dateCreated: DateTime.now(),
        isDeleted: false,
      );

      const testUnit = Unit(
        unitPk: 'unit_g',
        name: 'Gramos',
        symbol: 'g',
        category: 'mass',
        factorToBase: 1.0,
        isMutable: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream.value([testIngredient]),
            ),
            unitsProvider.overrideWith((ref) => Future.value([testUnit])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddIngredientScreen(ingredient: testIngredient),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final costFinder = find.byKey(const ValueKey('ingredient_cost_input'));
      expect(costFinder, findsOneWidget);
      await tester.tap(costFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final costField = tester.widget<TextField>(
        find.descendant(of: costFinder, matching: find.byType(TextField)),
      );
      final costController = costField.controller!;
      expect(costController.text, isNotEmpty);
      expect(costController.selection.baseOffset, 0);
      expect(costController.selection.extentOffset, costController.text.length);

      final quantityFinder = find.byKey(
        const ValueKey('ingredient_quantity_input'),
      );
      expect(quantityFinder, findsOneWidget);
      await tester.tap(quantityFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final quantityField = tester.widget<TextField>(
        find.descendant(of: quantityFinder, matching: find.byType(TextField)),
      );
      final quantityController = quantityField.controller!;
      expect(quantityController.text, isNotEmpty);
      expect(quantityController.selection.baseOffset, 0);
      expect(
        quantityController.selection.extentOffset,
        quantityController.text.length,
      );
    },
  );
}
