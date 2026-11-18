import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/widgets/global_ingredient_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Selected ingredient quantity TextField stays above keyboard on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final now = DateTime(2026, 1, 1);
      final units = <Unit>[
        const Unit(
          unitPk: 'u-g',
          name: 'Gram',
          symbol: 'g',
          category: 'weight',
          factorToBase: 1.0,
          isMutable: false,
        ),
      ];

      final ingredients = List<Ingredient>.generate(
        15,
        (i) => Ingredient(
          ingredientPk: 'ing-$i',
          name: 'Ingredient $i',
          cost: 10.0,
          quantityForCost: 100.0,
          unitFk: 'u-g',
          dateCreated: now,
          isDeleted: false,
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream<List<Ingredient>>.value(ingredients),
            ),
            unitsProvider.overrideWith((ref) async => units),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => GlobalIngredientPickerSheet(
                          currentIngredients: const [],
                          onAddIngredients: (_) {},
                          showPickerIngredientOptionsModal:
                              (_, _, _, _, _, _, _) {},
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Scroll down to an ingredient near the bottom of the list.
      await tester.scrollUntilVisible(
        find.text('Ingredient 12'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      // Tap the ingredient to select and focus its quantity TextField.
      await tester.tap(find.text('Ingredient 12'));
      await tester.pump();

      // Simulate the on-screen keyboard rising to 300px height.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final quantityField = find.byType(TextField).last;
      expect(quantityField, findsOneWidget);

      final rect = tester.getRect(quantityField);
      expect(rect.bottom, lessThanOrEqualTo(640 - 300));
    },
  );
}
