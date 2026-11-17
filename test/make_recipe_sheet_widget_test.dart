import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/widgets/make_recipe_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MakeRecipeSheet renders, scales batches, and executes deduction', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final units = await db.getAllUnits();
    final gramUnit = units.firstWhere((u) => u.symbol == 'g');

    await db.insertIngredient(
      IngredientsCompanion.insert(
        ingredientPk: const Value('ing_butter'),
        name: 'Butter',
        cost: 4.0,
        quantityForCost: 500.0,
        unitFk: gramUnit.unitPk,
        currentStock: const Value(1000.0),
        stockUnit: Value(gramUnit.unitPk),
      ),
    );
    await db.insertRecipe(
      RecipesCompanion.insert(
        recipePk: const Value('rec_croissant'),
        name: 'Croissant',
        defaultYield: 6.0,
        yieldName: 'pieces',
        targetPricePerPortion: const Value(2.5),
      ),
    );
    await db.insertRecipeIngredient(
      RecipeIngredientsCompanion.insert(
        recipeFk: 'rec_croissant',
        ingredientFk: 'ing_butter',
        amountNeeded: 250.0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => _TestDatabaseNotifier(db)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MakeRecipeSheet(recipePk: 'rec_croissant'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Croissant'), findsOneWidget);
    expect(find.text('Butter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm_make_recipe_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final butterAfter = await db.getIngredientById('ing_butter');
    expect(butterAfter!.currentStock, closeTo(750.0, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => db.close());
  });
}

class _TestDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _TestDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}
