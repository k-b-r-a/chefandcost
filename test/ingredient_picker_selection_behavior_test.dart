import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/screens/add_ingredient_screen.dart';
import 'package:recipetools/screens/ingredients_screen.dart';
import 'package:recipetools/widgets/global_ingredient_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPrefs;

  final ing1 = Ingredient(
    ingredientPk: 'ing_1',
    name: 'Harina',
    cost: 10.0,
    quantityForCost: 1000.0,
    unitFk: 'unit_g',
    dateCreated: DateTime.now(),
  );

  final ing2 = Ingredient(
    ingredientPk: 'ing_2',
    name: 'Azúcar',
    cost: 15.0,
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({Widget home = const RecipeEditorScreen()}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ingredientsStreamProvider.overrideWith((ref) => Stream.value([ing1, ing2])),
        unitsProvider.overrideWith((ref) => Future.value([testUnit])),
        unitsStreamProvider.overrideWith((ref) => Stream.value([testUnit])),
        relatedIngredientsProvider.overrideWith((ref, query) => Stream.value(
              [ing1, ing2]
                  .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
                  .toList(),
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: home,
      ),
    );
  }

  testWidgets(
      'Tapping blurred backdrop dismisses blur without selecting item underneath',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Open ingredient picker modal
    final addIngFinder = find.byIcon(Icons.add_rounded);
    expect(addIngFinder, findsWidgets);
    await tester.tap(addIngFinder.first);
    await tester.pumpAndSettle();

    expect(find.text('Harina'), findsOneWidget);
    expect(find.text('Azúcar'), findsOneWidget);

    // Initial state: no dismiss blur overlay exists
    expect(find.byKey(const ValueKey('dismiss_blur_ing_2')), findsNothing);

    // Tap Harina to stage and focus it
    await tester.tap(find.text('Harina'));
    await tester.pumpAndSettle();

    // Azúcar is now blurred with a dismiss gesture overlay
    final blurOverlayAzucar = find.byKey(const ValueKey('dismiss_blur_ing_2'));
    expect(blurOverlayAzucar, findsOneWidget);

    // Tap the blurred overlay of Azúcar
    await tester.tap(blurOverlayAzucar);
    await tester.pumpAndSettle();

    // Blur overlay must be dismissed
    expect(find.byKey(const ValueKey('dismiss_blur_ing_2')), findsNothing);

    // Underneath item (Azúcar) must NOT be selected:
    // Only 1 ingredient is staged (Harina)
    expect(find.textContaining('AGREGAR (1)'), findsOneWidget);
    expect(find.textContaining('AGREGAR (2)'), findsNothing);

    // Now that blur is dismissed, tapping Azúcar directly picks it
    await tester.tap(find.text('Azúcar'));
    await tester.pumpAndSettle();

    // Now both are staged (2)
    expect(find.textContaining('AGREGAR (2)'), findsOneWidget);
  });

  testWidgets(
      'Closing picker with staged ingredients shows confirmation dialog with Cancel, Discard, and Add options',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Open ingredient picker modal
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    // 1. When empty, tapping close ("X") exits immediately without dialog
    final closeBtn = find.byKey(const ValueKey('picker_close_button'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Modal closed
    expect(find.byKey(const ValueKey('picker_close_button')), findsNothing);
    expect(find.byKey(const ValueKey('staged_ingredients_dialog')), findsNothing);

    // Reopen modal and stage an ingredient
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harina'));
    await tester.pumpAndSettle();

    // 2. Click close ("X") with staged ingredient -> confirmation dialog appears
    await tester.tap(find.byKey(const ValueKey('picker_close_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('staged_ingredients_dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('staged_ingredients_cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('staged_ingredients_discard')), findsOneWidget);
    expect(find.byKey(const ValueKey('staged_ingredients_save')), findsOneWidget);

    // 3. Tap Cancel: dialog closes, modal remains open with staged ingredient
    await tester.tap(find.byKey(const ValueKey('staged_ingredients_cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('staged_ingredients_dialog')), findsNothing);
    expect(find.byKey(const ValueKey('picker_close_button')), findsOneWidget);
    expect(find.textContaining('AGREGAR (1)'), findsOneWidget);

    // 4. Tap close ("X") again, then tap Discard: modal closes, ingredient not added
    await tester.tap(find.byKey(const ValueKey('picker_close_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('staged_ingredients_discard')));
    await tester.pumpAndSettle();

    // Picker is closed and recipe has no ingredients
    expect(find.byKey(const ValueKey('picker_close_button')), findsNothing);
    expect(find.text('Harina'), findsNothing);

    // 5. Reopen modal, stage ingredient, tap close ("X"), and tap Save/Add:
    // ingredient is added to recipe!
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harina'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('picker_close_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('staged_ingredients_save')));
    await tester.pumpAndSettle();

    // Picker is closed and Harina is now in the recipe list!
    expect(find.byKey(const ValueKey('picker_close_button')), findsNothing);
    expect(find.text('Harina'), findsOneWidget);
  });

  testWidgets(
      'AddIngredientScreen shows confirmation dialog when modified and back is pressed',
      (tester) async {
    bool closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          unitsProvider.overrideWith((ref) => Future.value([testUnit])),
          unitsStreamProvider.overrideWith((ref) => Stream.value([testUnit])),
          relatedIngredientsProvider.overrideWith((ref, query) => Stream.value([])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: AddIngredientScreen(
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. If not modified, clicking back closes immediately
    final backBtn = find.byTooltip('Volver');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
    expect(closed, isTrue);

    // Reopen and modify
    closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          unitsProvider.overrideWith((ref) => Future.value([testUnit])),
          unitsStreamProvider.overrideWith((ref) => Stream.value([testUnit])),
          relatedIngredientsProvider.overrideWith((ref, query) => Stream.value([])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: AddIngredientScreen(
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type a name
    await tester.enterText(find.byType(TextFormField).first, 'Nuevo Producto');
    await tester.pumpAndSettle();

    // Tap back -> dialog appears!
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unsaved_ingredient_dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('unsaved_ingredient_cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('unsaved_ingredient_discard')), findsOneWidget);

    // Tap cancel
    await tester.tap(find.byKey(const ValueKey('unsaved_ingredient_cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unsaved_ingredient_dialog')), findsNothing);
    expect(closed, isFalse);

    // Tap back again and tap discard
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unsaved_ingredient_discard')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets(
      'Ingredient picker displays fallback "Create new" card when searching without exact match and pre-fills name',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Open picker
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    // Enter partial search query "Choc" in the picker's search field
    final searchField = find.descendant(
      of: find.byType(GlobalIngredientPickerSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'Choc');
    await tester.pumpAndSettle();

    // Fallback card with text "Agregar 'Choc'" is displayed
    final createNewCard = find.byKey(const ValueKey('create_new_ingredient_card'));
    expect(createNewCard, findsOneWidget);
    expect(find.text("Agregar 'Choc'"), findsOneWidget);

    // Tap the card to open creation flow
    await tester.tap(createNewCard);
    await tester.pumpAndSettle();

    // AddIngredientScreen opens with pre-filled name "Choc"
    expect(find.widgetWithText(TextFormField, 'Choc'), findsOneWidget);
  });

  testWidgets(
      'Ingredient picker hides fallback card when search query matches an existing ingredient exactly',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Open picker
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    // Enter exact match "Harina" in the picker's search field
    final searchField = find.descendant(
      of: find.byType(GlobalIngredientPickerSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'Harina');
    await tester.pumpAndSettle();

    // Harina is shown in list, but fallback create new card is hidden
    expect(find.widgetWithText(ListTile, 'Harina'), findsOneWidget);
    expect(find.byKey(const ValueKey('create_new_ingredient_card')), findsNothing);
  });

  testWidgets(
      'IngredientsScreen displays fallback card when searching without exact match and pre-fills name',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestApp(home: const IngredientsScreen()));
    await tester.pumpAndSettle();

    // Set search query in search provider
    final element = tester.element(find.byType(IngredientsScreen));
    final container = ProviderScope.containerOf(element);
    container.read(ingredientSearchQueryProvider.notifier).setQuery('Vainilla');
    await tester.pumpAndSettle();

    // Fallback card with text "Agregar 'Vainilla'" is displayed
    final createNewCard = find.byKey(const ValueKey('create_new_ingredient_card'));
    expect(createNewCard, findsOneWidget);
    expect(find.text("Agregar 'Vainilla'"), findsOneWidget);

    // Tap the card to open AddIngredientScreen
    await tester.tap(createNewCard);
    await tester.pumpAndSettle();

    // AddIngredientScreen opens with pre-filled name "Vainilla"
    expect(find.widgetWithText(TextFormField, 'Vainilla'), findsOneWidget);
  });
}
