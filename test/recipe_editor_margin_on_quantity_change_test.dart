import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _MockDatabaseNotifier(this._db);

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
    'Changing ingredient quantity updates Total Margin % while keeping Portions and Price per Portion unchanged',
    (tester) async {
      SharedPreferences.setMockInitialValues({'decimal_separator': '.'});
      final prefs = await SharedPreferences.getInstance();

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final ingredient = Ingredient(
        ingredientPk: 'ing_1',
        name: 'Test Flour',
        cost: 50.0,
        quantityForCost: 100.0,
        unitFk: 'u_g',
        dateCreated: DateTime.now(),
        isDeleted: false,
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
            unitsProvider.overrideWith((ref) => Future.value([unitG])),
            unitsStreamProvider.overrideWith((ref) => Stream.value([unitG])),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream.value([ingredient]),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: RecipeEditorScreen(
              isTemporary: true,
              initialName: 'Test Recipe',
              initialYield: '10',
              initialPrice: '10.00',
              initialProfitMargin: '100',
              initialIngredients: [
                InitialIngredientInput(
                  ingredient: ingredient,
                  amount: 100.0,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial values: Portions = 10, Price = 10.00, Margin = 100
      expect(find.widgetWithText(TextField, '10'), findsWidgets);
      expect(find.widgetWithText(TextField, '10.00'), findsWidgets);
      expect(find.widgetWithText(TextField, '100'), findsWidgets);

      // Change ingredient quantity from 100 to 160
      // (Cost becomes $80.00, Total Sale = $100.00 -> Margin = 25%)
      final amountField = find.widgetWithText(TextField, '100').first;
      await tester.enterText(amountField, '160');
      await tester.pumpAndSettle();

      // Portions remains 10, Price per Portion remains 10.00, Margin updates to 25
      expect(find.widgetWithText(TextField, '10'), findsWidgets);
      expect(find.widgetWithText(TextField, '10.00'), findsWidgets);
      expect(find.widgetWithText(TextField, '25'), findsWidgets);
    },
  );
}
