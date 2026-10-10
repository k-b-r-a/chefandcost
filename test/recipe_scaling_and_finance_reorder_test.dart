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

    test('cleanTrailingZeros strips redundant decimals without affecting whole integer zeros', () {
      expect(RecipeUtils.cleanTrailingZeros('2.0'), '2');
      expect(RecipeUtils.cleanTrailingZeros('2.000'), '2');
      expect(RecipeUtils.cleanTrailingZeros('2,00'), '2');
      expect(RecipeUtils.cleanTrailingZeros('2.50'), '2.5');
      expect(RecipeUtils.cleanTrailingZeros('2,50'), '2,5');
      expect(RecipeUtils.cleanTrailingZeros('20'), '20');
      expect(RecipeUtils.cleanTrailingZeros('100'), '100');
      expect(RecipeUtils.cleanTrailingZeros('1000'), '1000');
      expect(RecipeUtils.cleanTrailingZeros('0.750'), '0.75');
      expect(RecipeUtils.cleanTrailingZeros('1.000,50'), '1.000,5');
    });

    test('formatQuantity cleanly formats numbers without trailing zeros', () {
      expect(RecipeUtils.formatQuantity(2), '2');
      expect(RecipeUtils.formatQuantity(2.0), '2');
      expect(RecipeUtils.formatQuantity(2.5), '2.5');
      expect(RecipeUtils.formatQuantity(0.125), '0.125');
      expect(RecipeUtils.formatQuantity(2.0000000000000004), '2');
      expect(RecipeUtils.formatQuantity(300.0), '300');
      expect(RecipeUtils.formatQuantity(1000.0), '1000');
    });

    test('RecipeIngredientData preserves exact user input without appending zeros', () {
      final ing = RecipeIngredientData(
        ingredient: ingFlour,
        initialAmount: '2',
        sourceUnit: unitG,
        targetUnit: unitG,
      );
      expect(ing.amountController.text, '2');

      final ingWithZeros = RecipeIngredientData(
        ingredient: ingFlour,
        initialAmount: '2.000',
        sourceUnit: unitG,
        targetUnit: unitG,
      );
      expect(ingWithZeros.amountController.text, '2');

      final ingDecimal = RecipeIngredientData(
        ingredient: ingFlour,
        initialAmount: '2.50',
        sourceUnit: unitG,
        targetUnit: unitG,
      );
      expect(ingDecimal.amountController.text, '2.5');
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
      List<InitialStepInput>? initialSteps,
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
            initialSteps: initialSteps,
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

      // Long press Flour ingredient item to expand quick action dropdown
      final flourText = find.text('Flour');
      expect(flourText, findsOneWidget);
      await tester.longPress(flourText);
      await tester.pumpAndSettle();

      // Tap "Scale" action in dropdown
      final scaleOption = find.byKey(const ValueKey('ingredient_action_scale'));
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

      await tester.tap(find.byKey(const ValueKey('ingredient_action_scale')));
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

    test('RecipeUtils portion scaling and number formatting logic', () {
      // Portion scaling factor calculation: target_servings / base_servings
      expect(RecipeUtils.calculatePortionScaleMultiplier(baseServings: 4, targetServings: 2), 0.5);
      expect(RecipeUtils.calculatePortionScaleMultiplier(baseServings: 4, targetServings: 1), 0.25);
      expect(RecipeUtils.calculatePortionScaleMultiplier(baseServings: 4, targetServings: 8), 2.0);
      expect(RecipeUtils.calculatePortionScaleMultiplier(baseServings: 4, targetServings: 6), 1.5);
      expect(RecipeUtils.calculatePortionScaleMultiplier(baseServings: 0, targetServings: 4), 1.0);

      // Clean number formatting without trailing zeros or artifacts
      expect(RecipeUtils.formatQuantity(2.0), '2');
      expect(RecipeUtils.formatQuantity(2), '2');
      expect(RecipeUtils.formatQuantity(2.0000000001), '2');
      expect(RecipeUtils.formatQuantity(0.50000000001), '0.5');
      expect(RecipeUtils.formatQuantity(0.2500000000), '0.25');
      expect(RecipeUtils.formatQuantity(1.5), '1.5');

      // Multiplier formatting
      expect(RecipeUtils.formatMultiplier(0.25), '1/4x');
      expect(RecipeUtils.formatMultiplier(0.5), '1/2x');
      expect(RecipeUtils.formatMultiplier(1.0), '1x');
      expect(RecipeUtils.formatMultiplier(2.0), '2x');
      expect(RecipeUtils.formatMultiplier(3.0), '3x');
      expect(RecipeUtils.formatMultiplier(1.5), '1.5x');

      // Fraction formatting
      expect(RecipeUtils.formatFractionOrDecimal(0.25, preferFraction: true), '1/4');
      expect(RecipeUtils.formatFractionOrDecimal(0.5, preferFraction: true), '1/2');
      expect(RecipeUtils.formatFractionOrDecimal(1.5, preferFraction: true), '1 1/2');
      expect(RecipeUtils.formatFractionOrDecimal(2.0, preferFraction: true), '2');

      // Fraction parsing
      expect(RecipeUtils.parseFormattedNumber('1/2'), 0.5);
      expect(RecipeUtils.parseFormattedNumber('1/4'), 0.25);
      expect(RecipeUtils.parseFormattedNumber('1 1/2'), 1.5);
    });

    testWidgets('Quick scale selector bar scales ingredients with 1/4x and 1/2x fractional multipliers', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 100),
        InitialIngredientInput(ingredient: ingMilk, amount: 200),
      ];

      await tester.pumpWidget(createTestApp(
        initialIngredients: initialIngredients,
      ));
      await tester.pumpAndSettle();

      // Selector bar should be present
      expect(find.byKey(const ValueKey('recipe_scale_selector_bar')), findsOneWidget);

      // Verify preset chips are present
      final chipQuarter = find.byKey(const ValueKey('scale_chip_0_25'));
      final chipHalf = find.byKey(const ValueKey('scale_chip_0_5'));
      final chip1x = find.byKey(const ValueKey('scale_chip_1'));
      final chip2x = find.byKey(const ValueKey('scale_chip_2'));

      expect(chipQuarter, findsOneWidget);
      expect(chipHalf, findsOneWidget);
      expect(chip1x, findsOneWidget);
      expect(chip2x, findsOneWidget);

      // Tap 1/2x chip
      await tester.tap(chipHalf);
      await tester.pumpAndSettle();

      // Flour 100 * 0.5 = 50, Milk 200 * 0.5 = 100
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '50'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '100'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsOneWidget);

      // Tap 1/4x chip
      await tester.tap(chipQuarter);
      await tester.pumpAndSettle();

      // Flour 100 * 0.25 = 25, Milk 200 * 0.25 = 50
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '25'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '50'),
        findsOneWidget,
      );

      // Tap 1x chip to revert
      await tester.tap(chip1x);
      await tester.pumpAndSettle();

      // Restored: Flour 100, Milk 200
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '100'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '200'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsNothing);
    });

    testWidgets('Custom portion scaling calculates scale factor and updates ingredient quantities', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 100),
        InitialIngredientInput(ingredient: ingMilk, amount: 200),
      ];

      await tester.pumpWidget(createTestApp(
        initialIngredients: initialIngredients,
      ));
      await tester.pumpAndSettle();

      // Tap custom portions chip
      final customChip = find.byKey(const ValueKey('scale_chip_custom_portions'));
      expect(customChip, findsOneWidget);
      await tester.ensureVisible(customChip);
      await tester.pumpAndSettle();
      await tester.tap(customChip);
      await tester.pumpAndSettle();

      // Portions dialog opens
      expect(find.byKey(const ValueKey('scale_by_portions_dialog')), findsOneWidget);

      // Enter target portions = 6 (6 / 4 = 1.5x)
      final inputField = find.byKey(const ValueKey('target_portions_input'));
      expect(inputField, findsOneWidget);
      await tester.enterText(inputField, '6');
      await tester.pumpAndSettle();

      // Dynamic scale factor badge in dialog displays 1.5x
      expect(find.text('1.5x'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.byKey(const ValueKey('apply_scale_by_portions_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.byKey(const ValueKey('scale_by_portions_dialog')), findsNothing);

      // Scaled values: Flour 100 * 1.5 = 150, Milk 200 * 1.5 = 300
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '150'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '300'),
        findsOneWidget,
      );

      // Verify custom portions chip is highlighted
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsOneWidget);
    });

    testWidgets('Section headers and items show counters for ingredients and steps', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 100),
        InitialIngredientInput(ingredient: ingMilk, amount: 200),
      ];

      final initialSteps = [
        const InitialStepInput(instruction: 'Mix flour and milk'),
        const InitialStepInput(instruction: 'Bake for 20 minutes'),
      ];

      await tester.pumpWidget(createTestApp(
        initialIngredients: initialIngredients,
        initialSteps: initialSteps,
      ));
      await tester.pumpAndSettle();

      // Verify section header counter badges
      final ingCounterBadge = find.byKey(const ValueKey('ingredients_counter_badge_mobile'));
      expect(ingCounterBadge, findsOneWidget);
      expect(find.descendant(of: ingCounterBadge, matching: find.text('2')), findsOneWidget);

      final stepsCounterBadge = find.byKey(const ValueKey('steps_counter_badge_mobile'));
      expect(stepsCounterBadge, findsOneWidget);
      expect(find.descendant(of: stepsCounterBadge, matching: find.text('2')), findsOneWidget);

      // Verify ingredient items display individual index counters (1 and 2)
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('Long pressing an ingredient item expands inline dropdown instead of opening modal popup', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialIngredients = [
        InitialIngredientInput(ingredient: ingFlour, amount: 100),
        InitialIngredientInput(ingredient: ingMilk, amount: 200),
      ];

      await tester.pumpWidget(createTestApp(
        initialIngredients: initialIngredients,
      ));
      await tester.pumpAndSettle();

      // Before long press, quick action buttons should not be visible
      expect(find.byKey(const ValueKey('ingredient_action_scale')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_edit')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_merge')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_delete')), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      // Long press Flour
      await tester.longPress(find.text('Flour'));
      await tester.pumpAndSettle();

      // Verify NO modal popup / bottom sheet was opened
      expect(find.byType(BottomSheet), findsNothing);

      // Verify inline dropdown actions are visible
      expect(find.byKey(const ValueKey('ingredient_action_scale')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingredient_action_edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingredient_action_merge')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingredient_action_delete')), findsOneWidget);

      // Long press Flour again to collapse inline dropdown
      await tester.longPress(find.text('Flour'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ingredient_action_scale')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_edit')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_merge')), findsNothing);
      expect(find.byKey(const ValueKey('ingredient_action_delete')), findsNothing);
    });
  });
}

