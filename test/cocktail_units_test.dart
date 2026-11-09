import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/utils/unit_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

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

        // Cocktails format oz as fractions (1, 1/2, 1/4, 1 1/2, 1 1/4, etc.)
        expect(RecipeUtils.formatCocktailOunces(0.25), '1/4');
        expect(RecipeUtils.formatCocktailOunces(0.5), '1/2');
        expect(RecipeUtils.formatCocktailOunces(0.75), '3/4');
        expect(RecipeUtils.formatCocktailOunces(1.0), '1');
        expect(RecipeUtils.formatCocktailOunces(1.25), '1 1/4');
        expect(RecipeUtils.formatCocktailOunces(1.5), '1 1/2');
        expect(RecipeUtils.formatCocktailOunces(1.75), '1 3/4');
        expect(RecipeUtils.formatCocktailOunces(2.0), '2');

        expect(RecipeUtils.cocktailOzToMl(1.0), 30.0);
        expect(RecipeUtils.cocktailOzToMl(1.5), 45.0);
        expect(RecipeUtils.cocktailOzToMl(2.0), 60.0);
        expect(RecipeUtils.cocktailOzToMl(0.5), 15.0);
        expect(RecipeUtils.cocktailOzToMl(0.25), 7.5);
        expect(RecipeUtils.cocktailOzToMl(0.75), 22.5);

        // 50 ml converted to cocktail oz -> 1 3/4 oz (rounded to fraction, no decimals)
        final amount50ml = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '50',
          sourceUnit: ml,
          targetUnit: fluidOz,
          preferFraction: true,
        );
        try {
          expect(amount50ml.amountController.text, '1 3/4');
        } finally {
          amount50ml.amountController.dispose();
        }

        // 45 ml converted to cocktail oz -> 1 1/2 oz
        final amount45ml = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '45',
          sourceUnit: ml,
          targetUnit: fluidOz,
          preferFraction: true,
        );
        try {
          expect(amount45ml.amountController.text, '1 1/2');
        } finally {
          amount45ml.amountController.dispose();
        }

        // 60 ml converted to cocktail oz -> 2 oz
        final amount60ml = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '60',
          sourceUnit: ml,
          targetUnit: fluidOz,
          preferFraction: true,
        );
        try {
          expect(amount60ml.amountController.text, '2');
        } finally {
          amount60ml.amountController.dispose();
        }

        // 2 oz converted to ml -> 59.15 ml (max 2 decimals)
        final amount2oz = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '2',
          sourceUnit: fluidOz,
          targetUnit: ml,
        );
        try {
          expect(amount2oz.amountController.text, '59.15');
        } finally {
          amount2oz.amountController.dispose();
        }

        // 1.5 oz converted to ml -> 44.36 ml (max 2 decimals)
        final amount1_5oz = RecipeIngredientData(
          ingredient: ingredient,
          initialAmount: '1.5',
          sourceUnit: fluidOz,
          targetUnit: ml,
        );
        try {
          expect(amount1_5oz.amountController.text, '44.36');
        } finally {
          amount1_5oz.amountController.dispose();
        }
      } finally {
        await db.close();
      }
    },
  );

  testWidgets(
    'Recipe editor converts ml to oz as fractions without decimals and shows ml beside it in cocktails',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      final units = await db.getAllUnits();
      final ml = units.firstWhere((u) => u.name == 'unit_milliliters');

      final rum = Ingredient(
        ingredientPk: 'rum_pk',
        name: 'White Rum',
        cost: 15.0,
        quantityForCost: 750.0,
        unitFk: ml.unitPk,
        dateCreated: DateTime.now(),
        isDeleted: false,
      );
      await db.into(db.ingredients).insert(rum);

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('mojito_recipe_pk'),
          name: 'Mojito',
          category: const drift.Value('cocina'),
          defaultYield: 1.0,
          yieldName: 'portions',
        ),
      );

      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: 'mojito_recipe_pk',
          ingredientFk: 'rum_pk',
          amountNeeded: 50.0, // 50 ml in kitchen
        ),
      );

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
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'mojito_recipe_pk',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in 'cocina', the amount is 50 ml, no extra ml text
      final amountFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '50',
      );
      expect(amountFieldFinder, findsOneWidget);
      expect(find.text('ml'), findsWidgets);
      expect(find.text('(52.5 ml)'), findsNothing);

      // Select 'cocteleria' (Cocktails) category pill
      final cocktailPill = find.byKey(const ValueKey('recipe_category_cocteleria'));
      expect(cocktailPill, findsOneWidget);
      await tester.tap(cocktailPill);
      await tester.pumpAndSettle();

      // 50 ml -> oz: rounded to fraction without decimals: '1 3/4'
      final cocktailAmountFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '1 3/4',
      );
      expect(cocktailAmountFinder, findsOneWidget);
      expect(find.text('oz'), findsWidgets);

      // And beside it shows in ml too: '(52.5 ml)'
      expect(find.text('(52.5 ml)'), findsOneWidget);

      // Now switch back to 'cocina' category
      final cocinaPill = find.byKey(const ValueKey('recipe_category_cocina'));
      expect(cocinaPill, findsOneWidget);
      await tester.tap(cocinaPill);
      await tester.pumpAndSettle();

      // 1 3/4 oz -> ml: 1.75 * 29.5735... = 51.75 ml (max 2 decimals)
      final backToKitchenAmountFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '51.75',
      );
      expect(backToKitchenAmountFinder, findsOneWidget);
      expect(find.text('ml'), findsWidgets);
      expect(find.text('(52.5 ml)'), findsNothing);
    },
  );
}
