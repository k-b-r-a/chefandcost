import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Reproduce adding ingredient in recipe editor and closing modal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    final testIngredient = Ingredient(
      ingredientPk: 'ing_1',
      name: 'Harina',
      cost: 10.0,
      quantityForCost: 1000.0,
      unitFk: 'unit_g',
      dateCreated: DateTime.now(),
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
          ingredientsStreamProvider.overrideWith((ref) => Stream.value([testIngredient])),
          unitsProvider.overrideWith((ref) => Future.value([testUnit])),
          unitsStreamProvider.overrideWith((ref) => Stream.value([testUnit])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('es'),
          home: RecipeEditorScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap the add icon to open modal
    final addIngFinder = find.byIcon(Icons.add_rounded);
    expect(addIngFinder, findsWidgets);
    await tester.tap(addIngFinder.first);
    await tester.pumpAndSettle();

    // Now modal is open. Find 'Harina'
    final harinaFinder = find.text('Harina');
    expect(harinaFinder, findsOneWidget);

    // Tap Harina to select it
    await tester.tap(harinaFinder);
    await tester.pumpAndSettle();

    // Now find the Add button in the modal
    final addButtonFinder = find.textContaining('AGREGAR (1)');
    expect(addButtonFinder, findsOneWidget);

    // Tap Add button
    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
  });
}
