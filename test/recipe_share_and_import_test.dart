import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/services/recipe_share_service.dart';
import 'package:recipetools/widgets/share_recipe_sheet.dart';
import 'package:recipetools/widgets/import_recipe_dialog.dart';

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

  final testRecipe = Recipe(
    recipePk: 'rec_apple_pie',
    name: 'Apple Pie',
    description: 'Classic cinnamon apple pie',
    defaultYield: 8.0,
    yieldName: 'portions',
    targetProfitMargin: 40.0,
    targetPricePerPortion: 6.5,
    fixedOverheadCost: 1.0,
    colour: '#FF5722',
    dateCreated: DateTime(2026, 1, 1),
    dateTimeModified: DateTime(2026, 1, 2),
    archived: false,
  );

  final ingApple = Ingredient(
    ingredientPk: 'ing_apple',
    name: 'Apples',
    cost: 5.0,
    quantityForCost: 1000.0,
    unitFk: 'u_g',
    dateCreated: DateTime(2026, 1, 1),
  );

  final ingFlour = Ingredient(
    ingredientPk: 'ing_flour',
    name: 'Flour',
    cost: 2.0,
    quantityForCost: 1000.0,
    unitFk: 'u_g',
    dateCreated: DateTime(2026, 1, 1),
  );

  final recipeIngredients = [
    RecipeIngredientWithData(
      entry: RecipeIngredient(
        recipeIngredientPk: 'ri_1',
        recipeFk: 'rec_apple_pie',
        ingredientFk: 'ing_apple',
        amountNeeded: 600.0,
      ),
      ingredient: ingApple,
    ),
    RecipeIngredientWithData(
      entry: RecipeIngredient(
        recipeIngredientPk: 'ri_2',
        recipeFk: 'rec_apple_pie',
        ingredientFk: 'ing_flour',
        amountNeeded: 300.0,
      ),
      ingredient: ingFlour,
    ),
  ];

  final recipeSteps = [
    RecipeStep(
      stepPk: 'step_1',
      recipeFk: 'rec_apple_pie',
      stepNumber: 1,
      instruction: 'Peel and slice [Apples].',
    ),
    RecipeStep(
      stepPk: 'step_2',
      recipeFk: 'rec_apple_pie',
      stepNumber: 2,
      instruction: '[timer:Bake Pie|2700] Bake pie in oven at 180°C.',
    ),
  ];

  final sampleDetail = RecipeDetail(
    recipe: testRecipe,
    ingredients: recipeIngredients,
    steps: recipeSteps,
  );

  group('RecipeShareService Unit Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.units).insert(unitG);
      await db.into(db.units).insert(unitKg);
    });

    tearDown(() async {
      await db.close();
    });

    test('exportAsChefy exports valid JSON matching schema', () {
      final bytes = RecipeShareService.exportAsChefy(sampleDetail, [unitG, unitKg]);
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(data['format'], equals('chefy_recipe'));
      expect(data['version'], equals(1));
      expect(data['recipe']['name'], equals('Apple Pie'));
      expect(data['recipe']['defaultYield'], equals(8.0));
      expect(data['recipe']['yieldName'], equals('portions'));
      expect((data['ingredients'] as List).length, equals(2));
      expect((data['steps'] as List).length, equals(2));

      final firstIng = (data['ingredients'] as List).first as Map<String, dynamic>;
      expect(firstIng['name'], equals('Apples'));
      expect(firstIng['amountNeeded'], equals(600.0));
      expect(firstIng['unit']['symbol'], equals('g'));
    });

    test('previewRecipeFromJson extracts preview and detects collision', () {
      final bytes = RecipeShareService.exportAsChefy(sampleDetail, [unitG, unitKg]);
      final jsonStr = utf8.decode(bytes);

      // Without existing recipes
      final preview1 = RecipeShareService.previewRecipeFromJson(jsonStr, []);
      expect(preview1.name, equals('Apple Pie'));
      expect(preview1.hasExistingRecipeWithSameName, isFalse);
      expect(preview1.suggestedName, equals('Apple Pie'));
      expect(preview1.ingredientsCount, equals(2));
      expect(preview1.stepsCount, equals(2));
      expect(preview1.timersCount, equals(1));

      // With collision
      final preview2 = RecipeShareService.previewRecipeFromJson(jsonStr, [testRecipe]);
      expect(preview2.hasExistingRecipeWithSameName, isTrue);
      expect(preview2.suggestedName, equals('Apple Pie (1)'));
    });

    test('importRecipeFromJson successfully creates recipe, ingredients, and steps in database', () async {
      final bytes = RecipeShareService.exportAsChefy(sampleDetail, [unitG, unitKg]);
      final jsonStr = utf8.decode(bytes);

      final result = await RecipeShareService.importRecipeFromJson(
        jsonContent: jsonStr,
        db: db,
      );

      expect(result.recipe.name, equals('Apple Pie'));
      expect(result.ingredientsCount, equals(2));
      expect(result.stepsCount, equals(2));
      expect(result.newIngredientsCreated, equals(2)); // Apples & Flour didn't exist in DB
      expect(result.newUnitsCreated, equals(0)); // Unit 'g' already existed

      // Verify DB contents
      final savedRecipes = await db.getAllRecipes();
      expect(savedRecipes.length, equals(1));
      expect(savedRecipes.first.name, equals('Apple Pie'));

      final detail = await db.getRecipeDetail(savedRecipes.first.recipePk);
      expect(detail.ingredients.length, equals(2));
      expect(detail.steps.length, equals(2));
      expect(detail.steps.first.instruction, equals('Peel and slice [Apples].'));
    });

    test('importRecipeFromJson renames on collision when override name provided', () async {
      final bytes = RecipeShareService.exportAsChefy(sampleDetail, [unitG, unitKg]);
      final jsonStr = utf8.decode(bytes);

      // Import once
      await RecipeShareService.importRecipeFromJson(jsonContent: jsonStr, db: db);

      // Import again with override name
      final result2 = await RecipeShareService.importRecipeFromJson(
        jsonContent: jsonStr,
        db: db,
        overrideRecipeName: 'Apple Pie (Imported)',
      );

      expect(result2.wasRenamed, isTrue);
      expect(result2.recipe.name, equals('Apple Pie (Imported)'));
      expect(result2.newIngredientsCreated, equals(0)); // Reused existing ingredients

      final allRecipes = await db.getAllRecipes();
      expect(allRecipes.length, equals(2));
    });

    test('exportAsCsv exports valid CSV with BOM header', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final bytes = RecipeShareService.exportAsCsv(
        detail: sampleDetail,
        allUnits: [unitG, unitKg],
        currency: r'$',
        l10n: l10n,
      );

      expect(bytes.isNotEmpty, isTrue);
      // Verify BOM [0xEF, 0xBB, 0xBF]
      expect(bytes[0], equals(0xEF));
      expect(bytes[1], equals(0xBB));
      expect(bytes[2], equals(0xBF));

      final text = utf8.decode(bytes.sublist(3));
      expect(text.contains('Apple Pie'), isTrue);
      expect(text.contains('Apples'), isTrue);
      expect(text.contains('Flour'), isTrue);
      expect(text.contains('Peel and slice [Apples].'), isTrue);
    });

    test('exportAsPdf generates non-empty PDF bytes', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final bytes = await RecipeShareService.exportAsPdf(
        detail: sampleDetail,
        allUnits: [unitG, unitKg],
        currency: r'$',
        l10n: l10n,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(100));
    });
  });

  group('Share & Import UI Widget Tests', () {
    testWidgets('ShareRecipeSheet renders options for Chefy, PDF, and CSV', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ShareRecipeSheet(recipeDetail: sampleDetail),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Recipe'), findsOneWidget);
      expect(find.text('Apple Pie'), findsOneWidget);
      expect(find.text('Chef&Cost Recipe (.chefy)'), findsOneWidget);
      expect(find.text('PDF Recipe Sheet (.pdf)'), findsOneWidget);
      expect(find.text('CSV Spreadsheet (.csv)'), findsOneWidget);
      expect(find.text('Chef&Cost'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('ImportRecipeDialog renders recipe preview with metadata badges and confirm action', (tester) async {
      final preview = RecipeImportPreview(
        name: 'French Croissants',
        description: 'Authentic bakery croissants',
        defaultYield: 12.0,
        yieldName: 'units',
        targetProfitMargin: 35.0,
        targetPricePerPortion: 3.5,
        ingredientsCount: 5,
        stepsCount: 4,
        timersCount: 2,
        hasExistingRecipeWithSameName: true,
        suggestedName: 'French Croissants (1)',
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await ImportRecipeDialog.show(context, preview: preview);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Import Recipe'), findsOneWidget);
      expect(find.text('French Croissants'), findsOneWidget);
      expect(find.text('Authentic bakery croissants'), findsOneWidget);
      expect(find.text('Yield: 12 units'), findsOneWidget);
      expect(find.text('5 ingredients'), findsOneWidget);
      expect(find.text('4 steps'), findsOneWidget);

      // Warning for existing recipe name conflict
      expect(
        find.text('A recipe with this name already exists. It will be imported as "French Croissants (1)".'),
        findsOneWidget,
      );

      // Tap Confirm
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });
  });
}
