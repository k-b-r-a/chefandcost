import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/theme/app_theme.dart';
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

  testWidgets(
    'Recipe ingredient list item quantity field uses UnderlineInputBorder instead of OutlineInputBorder',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'defaultMassUnit': 'g',
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.into(db.units).insert(unitG);
      final flour = Ingredient(
        ingredientPk: 'flour_test_pk',
        name: 'Flour',
        cost: 5.0,
        quantityForCost: 1000.0,
        unitFk: 'u_g',
        dateCreated: DateTime.now(),
        isDeleted: false,
      );
      await db.into(db.ingredients).insert(flour);

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('test_recipe_pk'),
          name: 'Pancakes',
          defaultYield: 1.0,
          yieldName: 'portions',
        ),
      );
      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: 'test_recipe_pk',
          ingredientFk: 'flour_test_pk',
          amountNeeded: 250.0,
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
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'test_recipe_pk',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the TextField displaying the quantity 250
      final quantityFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == '250' &&
            widget.decoration?.hintText == '0',
      );

      expect(quantityFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(quantityFieldFinder);
      final decoration = textField.decoration;

      expect(decoration, isNotNull);
      expect(decoration!.border, isA<UnderlineInputBorder>());
      expect(decoration.enabledBorder, isA<UnderlineInputBorder>());
      expect(decoration.focusedBorder, isA<UnderlineInputBorder>());

      expect(decoration.border is OutlineInputBorder, isFalse);
      expect(decoration.enabledBorder is OutlineInputBorder, isFalse);
      expect(decoration.focusedBorder is OutlineInputBorder, isFalse);
    },
  );
}
