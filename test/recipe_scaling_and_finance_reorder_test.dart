import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
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
  const unitKg = Unit(
    unitPk: 'u_kg',
    name: 'Kilogramos',
    symbol: 'kg',
    category: 'mass',
    factorToBase: 1000.0,
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
  const unitL = Unit(
    unitPk: 'u_l',
    name: 'Litros',
    symbol: 'l',
    category: 'volume',
    factorToBase: 1000.0,
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

  final allUnits = [unitG, unitKg, unitMl, unitL, unitPcs];

  final ingFlour = Ingredient(
    ingredientPk: 'ing_flour',
    name: 'Flour',
    cost: 10,
    quantityForCost: 1000,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
  );
  final ingSugar = Ingredient(
    ingredientPk: 'ing_sugar',
    name: 'Sugar',
    cost: 20,
    quantityForCost: 1000,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
  );
  final ingMilk = Ingredient(
    ingredientPk: 'ing_milk',
    name: 'Milk',
    cost: 5,
    quantityForCost: 1000,
    unitFk: 'u_ml',
    dateCreated: DateTime.now(),
  );
  final ingEggs = Ingredient(
    ingredientPk: 'ing_eggs',
    name: 'Eggs',
    cost: 12,
    quantityForCost: 12,
    unitFk: 'u_pcs',
    dateCreated: DateTime.now(),
  );

  group('Recipe Scaling & Weight/Volume Unit Tests', () {
    test('calculateScaleMultiplier calculates accurate proportions', () {
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: 50, targetAmount: 100), 2.0);
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: 100, targetAmount: 50), 0.5);
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: 75, targetAmount: 225), 3.0);
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: 0, targetAmount: 100), 1.0);
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: 50, targetAmount: 0), 1.0);
      expect(RecipeUtils.calculateScaleMultiplier(currentAmount: -10, targetAmount: 50), 1.0);
    });

    test('calculateTotalWeightAndVolume sums mass and volume correctly and ignores count', () {
      final ingredients = [
        RecipeIngredientData(
          ingredient: ingFlour,
          initialAmount: '500',
          sourceUnit: unitG,
        ),
        RecipeIngredientData(
          ingredient: ingSugar,
          initialAmount: '1,5',
          sourceUnit: unitKg,
        ),
        RecipeIngredientData(
          ingredient: ingMilk,
          initialAmount: '750',
          sourceUnit: unitMl,
        ),
        RecipeIngredientData(
          ingredient: ingEggs,
          initialAmount: '4',
          sourceUnit: unitPcs,
        ),
      ];

      final totals = RecipeUtils.calculateTotalWeightAndVolume(
        ingredients: ingredients,
        units: allUnits,
      );

      // 500g + 1.5kg (1500g) = 2000g
      expect(totals.totalWeightGrams, 2000.0);
      // 750ml = 750ml
      expect(totals.totalVolumeMl, 750.0);
    });

    test('formatWeight and formatVolume format quantities cleanly', () {
      expect(RecipeUtils.formatWeight(500), '500 g');
      expect(RecipeUtils.formatWeight(1000), '1 kg');
      expect(RecipeUtils.formatWeight(1500), '1,5 kg');

      expect(RecipeUtils.formatVolume(250), '250 ml');
      expect(RecipeUtils.formatVolume(1000), '1 l');
      expect(RecipeUtils.formatVolume(2500), '2,5 l');
    });
  });

  group('RecipeEditorScreen Finance Reordering & Target Scaling Widget Tests', () {
    late SharedPreferences sharedPrefs;
    late AppDatabase testDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPrefs = await SharedPreferences.getInstance();
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      for (final ing in [ingFlour, ingMilk, ingEggs]) {
        await testDb.into(testDb.ingredients).insert(ing);
      }
    });

    tearDown(() async {
      // testDb is closed by Riverpod's onDispose
    });

    Widget createTestApp({
      required List<InitialIngredientInput> initialIngredients,
      bool isTemporary = true,
      String? recipeId,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(testDb)),
          unitsProvider.overrideWith((ref) => Future.value(allUnits)),
          unitsStreamProvider.overrideWith((ref) => Stream.value(allUnits)),
          ingredientsStreamProvider.overrideWith(
            (ref) => Stream.value([ingFlour, ingMilk, ingEggs]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: RecipeEditorScreen(
            recipeId: recipeId,
            isTemporary: isTemporary,
            initialName: 'Test Cake',
            initialYield: '4',
            initialProfitMargin: '30',
            initialPrice: '10',
            initialIngredients: initialIngredients,
          ),
        ),
      );
    }

    testWidgets('Finance cards are ordered Margin, Portions, Price per portion in mobile view', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 50),
        InitialIngredientInput(ingredient: ingMilk, amount: 100),
      ];

      await tester.pumpWidget(createTestApp(initialIngredients: initialIngredients));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Open bottom financials sheet if collapsed
      final collapsedFinder = find.byKey(const ValueKey('collapsed_financials'));
      if (collapsedFinder.evaluate().isNotEmpty) {
        await tester.tap(collapsedFinder);
        await tester.pumpAndSettle();
      }

      final marginFinder = find.text('Total Margin');
      final portionsFinder = find.text('Portions');
      final priceFinder = find.text('Price per Portion');

      expect(marginFinder, findsOneWidget);
      expect(portionsFinder, findsOneWidget);
      expect(priceFinder, findsOneWidget);

      final marginOffset = tester.getTopLeft(marginFinder);
      final portionsOffset = tester.getTopLeft(portionsFinder);
      final priceOffset = tester.getTopLeft(priceFinder);

      // Verify horizontal order: Margin (left) < Portions (middle) < Price (right)
      expect(marginOffset.dx < portionsOffset.dx, isTrue,
          reason: 'Margin must appear to the left of Portions');
      expect(portionsOffset.dx < priceOffset.dx, isTrue,
          reason: 'Portions must appear to the left of Price per portion');
    });

    testWidgets('Reactive recalculation occurs immediately when editing ingredient amount', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Flour cost: 10 per 1000g -> 0.01 per gram. 50g = 0.50 cost.
      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 50),
      ];

      await tester.pumpWidget(createTestApp(initialIngredients: initialIngredients));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify initial total cost of 0.50 in ingredient row
      expect(find.textContaining('0,50'), findsWidgets);

      // Find the TextField for ingredient amount and change from 50 to 200
      final flourAmountField = find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text == '50,00' || w.controller?.text == '50'),
      );
      expect(flourAmountField, findsOneWidget);

      // Enter 200 in the amount field (200 * 0.01 = 2.00 cost)
      await tester.enterText(flourAmountField, '200');
      await tester.pumpAndSettle();

      // Verify immediate recalculation: ingredient row cost should now show 2,00
      expect(find.textContaining('2,00'), findsWidgets);
    });

    testWidgets('Target scaling by ingredient scales all quantities and yield proportionally', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 50),
        InitialIngredientInput(ingredient: ingMilk, amount: 100),
      ];

      await tester.pumpWidget(createTestApp(initialIngredients: initialIngredients));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Long press Flour ingredient item to open options modal
      final flourText = find.text('Flour');
      expect(flourText, findsOneWidget);
      await tester.longPress(flourText);
      await tester.pumpAndSettle();

      // Tap "Scale by Ingredient" option in modal
      final scaleOption = find.text('Scale by Ingredient');
      expect(scaleOption, findsOneWidget);
      await tester.tap(scaleOption);
      await tester.pumpAndSettle();

      // The Scale by Ingredient dialog should now be visible
      expect(find.text('Target Quantity'), findsOneWidget);
      expect(find.text('Scale Factor: 1,00x'), findsOneWidget);

      // Find target quantity field within dialog and input 100 (which doubles Flour from 50 to 100 = 2.0x)
      final targetField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(targetField, findsOneWidget);
      await tester.enterText(targetField, '100');
      await tester.pumpAndSettle();

      // Verify dynamic scale factor calculation in dialog
      expect(find.text('Scale Factor: 2,00x'), findsOneWidget);

      // Tap Apply
      final applyButton = find.byKey(const ValueKey('apply_scale_by_ingredient_button'));
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify scaled amounts on recipe view:
      // Flour was 50 -> now 100
      // Milk was 100 -> now 200
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '100' || w.controller?.text == '100,00')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '200' || w.controller?.text == '200,00')),
        findsOneWidget,
      );

      // Open bottom financials to inspect scaled yield
      final collapsedFin = find.byKey(const ValueKey('collapsed_financials'));
      if (collapsedFin.evaluate().isNotEmpty) {
        await tester.tap(collapsedFin);
        await tester.pumpAndSettle();
      }

      // Yield was 4 -> now 8
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '8' || w.controller?.text == '8,00')),
        findsOneWidget,
      );

      // Verify that the temporary scale banner is displayed
      final bannerFinder = find.byKey(const ValueKey('temporary_scale_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(
        find.text('This scaling is temporary and does not change your real recipe in the database.'),
        findsOneWidget,
      );

      // Verify revert and save buttons are in the banner
      final revertButton = find.byKey(const ValueKey('revert_scaled_recipe_button'));
      final saveButton = find.byKey(const ValueKey('save_scaled_recipe_permanently_button'));
      expect(revertButton, findsOneWidget);
      expect(saveButton, findsOneWidget);

      // Tap revert button to restore original amounts
      await tester.tap(revertButton);
      await tester.pumpAndSettle();

      // Verify banner is dismissed
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsNothing);

      // Verify amounts and yield are reverted back to base values
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '50' || w.controller?.text == '50,00')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '100' || w.controller?.text == '100,00')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.controller?.text == '4' || w.controller?.text == '4,00')),
        findsOneWidget,
      );
    });

    testWidgets('Temporary scale banner offers Save as Real Recipe button which permanently commits the scaled recipe', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 50),
        InitialIngredientInput(ingredient: ingMilk, amount: 100),
      ];

      await tester.pumpWidget(createTestApp(initialIngredients: initialIngredients));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Scale Flour to 150 (3.0x factor)
      await tester.longPress(find.text('Flour'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scale by Ingredient'));
      await tester.pumpAndSettle();

      final targetField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(targetField, '150');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('apply_scale_by_ingredient_button')));
      await tester.pumpAndSettle();

      // Banner should be visible
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsOneWidget);

      // Tap Save as Real Recipe
      final saveButton = find.byKey(const ValueKey('save_scaled_recipe_permanently_button'));
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Banner should now be dismissed after successful commit
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsNothing);

      // Verify that recipe was saved into the database with scaled values (Flour 150, Milk 300, Yield 12)
      final savedRecipes = await testDb.getAllRecipes();
      expect(savedRecipes, isNotEmpty);
      final savedRecipe = savedRecipes.first;
      expect(savedRecipe.defaultYield, 12.0); // 4 * 3.0x = 12

      final savedIngs = await testDb.getIngredientsForRecipe(savedRecipe.recipePk);
      expect(savedIngs.length, 2);
      final flourItem = savedIngs.firstWhere((i) => i.ingredientFk == ingFlour.ingredientPk);
      expect(flourItem.amountNeeded, 150.0);
      final milkItem = savedIngs.firstWhere((i) => i.ingredientFk == ingMilk.ingredientPk);
      expect(milkItem.amountNeeded, 300.0);
    });
  });
}
