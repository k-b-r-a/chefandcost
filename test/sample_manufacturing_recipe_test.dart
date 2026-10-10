import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/sample_manufacturing_recipe.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_list_screen.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/recipe_utils.dart';

import 'package:recipetools/services/app_tutorial_service.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _mockDb;
  MockDatabaseNotifier(this._mockDb);

  @override
  AppDatabase build() => _mockDb;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sample Manufacturing Recipe DB Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('ensureSampleManufacturingRecipe creates 3 ingredients and 1 manufacturing recipe', () async {
      final created = await ensureSampleManufacturingRecipe(
        db,
        prefs: prefs,
        locale: const Locale('es'),
      );
      expect(created, isTrue);

      final recipes = await db.getAllRecipes();
      expect(recipes.length, 1);
      final recipe = recipes.first;
      expect(recipe.recipePk, kSampleManufacturingRecipePk);
      expect(recipe.name, contains('Galletas de Mantequilla'));
      expect(recipe.defaultYield, 24.0);
      expect(recipe.targetProfitMargin, 50.0);

      // Verify exactly 3 manufacturing raw materials
      final detail = await db.getRecipeDetail(recipe.recipePk);
      expect(detail.ingredients.length, 3);

      final ingNames = detail.ingredients.map((i) => i.ingredient.name).toList();
      expect(ingNames, containsAll([
        'Harina de Trigo 0000',
        'Mantequilla sin Sal',
        'Azúcar Blanca Refinada',
      ]));

      // Verify amounts (300g flour, 200g butter, 100g sugar)
      final flour = detail.ingredients.firstWhere((i) => i.ingredient.name == 'Harina de Trigo 0000');
      final butter = detail.ingredients.firstWhere((i) => i.ingredient.name == 'Mantequilla sin Sal');
      final sugar = detail.ingredients.firstWhere((i) => i.ingredient.name == 'Azúcar Blanca Refinada');
      expect(flour.entry.amountNeeded, 300.0);
      expect(butter.entry.amountNeeded, 200.0);
      expect(sugar.entry.amountNeeded, 100.0);

      // Verify manufacturing steps and timers
      expect(detail.steps.length, 3);
      expect(detail.steps.any((s) => s.instruction.contains('[timer:Cremado Industrial|240]')), isTrue);
      expect(detail.steps.any((s) => s.instruction.contains('[timer:Horneado de Lote|900]')), isTrue);
    });

    test('ensureSampleManufacturingRecipe is idempotent and does not recreate if recipes exist', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);
      final secondRun = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(secondRun, isFalse);

      final recipes = await db.getAllRecipes();
      expect(recipes.length, 1);
    });

    test('ensureSampleManufacturingRecipe does not create sample recipe or ingredients if database already contains ingredients', () async {
      final units = await db.getAllUnits();
      await db.insertIngredient(
        IngredientsCompanion(
          ingredientPk: const Value('pre_existing_ingredient'),
          name: const Value('Harina Leudante'),
          cost: const Value(2.0),
          quantityForCost: const Value(1000.0),
          unitFk: Value(units.first.unitPk),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );

      final created = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(created, isFalse);

      final recipes = await db.getAllRecipes();
      expect(recipes, isEmpty);

      final ingredients = await db.getAllIngredients();
      expect(ingredients.length, 1);
      expect(ingredients.first.ingredientPk, 'pre_existing_ingredient');
    });

    test('ensureSampleManufacturingRecipe does not create sample recipe or ingredients if database already contains recipes', () async {
      await db.insertRecipe(
        RecipesCompanion(
          recipePk: const Value('pre_existing_recipe'),
          name: const Value('Pre-existing Cake'),
          defaultYield: const Value(1.0),
          yieldName: const Value('portions'),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );

      final created = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(created, isFalse);

      final recipes = await db.getAllRecipes();
      expect(recipes.length, 1);
      expect(recipes.first.recipePk, 'pre_existing_recipe');

      final ingredients = await db.getAllIngredients();
      expect(ingredients, isEmpty);
    });

    test('ensureSampleManufacturingRecipe respects dismissed SharedPreferences key', () async {
      await prefs.setBool(kSampleManufacturingRecipeDismissedKey, true);
      final created = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(created, isFalse);

      final recipes = await db.getAllRecipes();
      expect(recipes, isEmpty);
    });

    test('dismissSampleManufacturingRecipe deletes recipe, sample ingredients, and sets dismissed key when database was empty', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect((await db.getAllRecipes()).length, 1);
      expect((await db.getAllIngredients()).length, 3);

      await dismissSampleManufacturingRecipe(db, prefs: prefs);
      expect((await db.getAllRecipes()), isEmpty);
      expect((await db.getAllIngredients()), isEmpty);
      expect(prefs.getBool(kSampleManufacturingRecipeDismissedKey), isTrue);

      // Next ensure run should not resurrect it
      final tryRecreate = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(tryRecreate, isFalse);
      expect((await db.getAllRecipes()), isEmpty);
      expect((await db.getAllIngredients()), isEmpty);
    });

    test('dismissSampleManufacturingRecipe preserves sample ingredients if database already contains other recipes', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect((await db.getAllRecipes()).length, 1);
      expect((await db.getAllIngredients()).length, 3);

      // Insert another recipe into the DB
      await db.insertRecipe(
        RecipesCompanion(
          recipePk: const Value('custom_user_recipe_1'),
          name: const Value('Custom User Cake'),
          defaultYield: const Value(1.0),
          yieldName: const Value('portions'),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );

      await dismissSampleManufacturingRecipe(db, prefs: prefs);
      // Sample recipe is deleted, custom recipe remains
      final recipes = await db.getAllRecipes();
      expect(recipes.length, 1);
      expect(recipes.first.recipePk, 'custom_user_recipe_1');
      // Ingredients must be preserved because DB had existing recipe data
      final ingredients = await db.getAllIngredients();
      expect(ingredients.length, 3);
    });

    test('dismissSampleManufacturingRecipe preserves sample ingredients if database already contains other ingredients', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect((await db.getAllRecipes()).length, 1);
      expect((await db.getAllIngredients()).length, 3);

      final units = await db.getAllUnits();

      // Insert another ingredient created by user
      await db.insertIngredient(
        IngredientsCompanion(
          ingredientPk: const Value('custom_user_ingredient_1'),
          name: const Value('Huevos de Campo'),
          cost: const Value(3.0),
          quantityForCost: const Value(12.0),
          unitFk: Value(units.first.unitPk),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );

      await dismissSampleManufacturingRecipe(db, prefs: prefs);
      // Sample recipe is deleted
      expect(await db.getAllRecipes(), isEmpty);
      // All ingredients (3 sample + 1 custom) are preserved
      final ingredients = await db.getAllIngredients();
      expect(ingredients.length, 4);
      expect(ingredients.any((i) => i.ingredientPk == 'custom_user_ingredient_1'), isTrue);
    });

    test('dismissSampleManufacturingRecipe preserves sample ingredients if another recipe uses them', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);

      // Insert another recipe that references kSampleFlourPk
      await db.insertRecipe(
        RecipesCompanion(
          recipePk: const Value('user_recipe_using_flour'),
          name: const Value('Pan Casero'),
          defaultYield: const Value(1.0),
          yieldName: const Value('portions'),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );
      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: 'user_recipe_using_flour',
          ingredientFk: kSampleFlourPk,
          amountNeeded: 500.0,
        ),
      );

      await dismissSampleManufacturingRecipe(db, prefs: prefs);
      // Sample recipe is deleted, other recipe remains
      expect((await db.getAllRecipes()).length, 1);
      // Sample ingredients preserved because they are in use and DB has recipe data
      final ingredients = await db.getAllIngredients();
      expect(ingredients.length, 3);
    });

    test('convertSampleRecipeToPermanent clones to new UUID and deletes temporary record', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);

      final newPk = await convertSampleRecipeToPermanent(
        db,
        prefs: prefs,
        customName: 'Galletas de Producción Guardadas',
      );

      expect(newPk, isNot(equals(kSampleManufacturingRecipePk)));
      expect(prefs.getBool(kSampleManufacturingRecipeDismissedKey), isTrue);

      final recipes = await db.getAllRecipes();
      expect(recipes.length, 1);
      expect(recipes.first.recipePk, newPk);
      expect(recipes.first.name, 'Galletas de Producción Guardadas');

      final detail = await db.getRecipeDetail(newPk);
      expect(detail.ingredients.length, 3);
      expect(detail.steps.length, 3);
    });

    test('ensureSampleManufacturingRecipe adapts to device language (English)', () async {
      final created = await ensureSampleManufacturingRecipe(
        db,
        prefs: prefs,
        locale: const Locale('en'),
      );
      expect(created, isTrue);

      final recipe = (await db.getAllRecipes()).first;
      expect(recipe.name, 'Butter Cookies (Manufacturing Batch)');
      expect(recipe.yieldName, 'pieces');

      final detail = await db.getRecipeDetail(recipe.recipePk);
      final ingNames = detail.ingredients.map((i) => i.ingredient.name).toList();
      expect(ingNames, containsAll([
        'All-Purpose Wheat Flour',
        'Unsalted Butter',
        'Refined White Sugar',
      ]));
      expect(detail.steps.any((s) => s.instruction.contains('[timer:Industrial Creaming|240]')), isTrue);
      expect(detail.steps.any((s) => s.instruction.contains('[timer:Batch Baking|900]')), isTrue);
    });

    test('ensureSampleManufacturingRecipe auto removes existing sample if tutorial was completed', () async {
      await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect((await db.getAllRecipes()).length, 1);

      // Mark editor tutorial completed
      await prefs.setBool(AppTutorialService.kTutorialRecipeEditorCompletedKey, true);

      // ensureSampleManufacturingRecipe should auto-remove it
      final ran = await ensureSampleManufacturingRecipe(db, prefs: prefs);
      expect(ran, isFalse);
      expect((await db.getAllRecipes()), isEmpty);
    });
  });

  group('Sample Manufacturing Recipe UI & Widget Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late List<Unit> testUnits;
    late List<Ingredient> testIngredients;
    late List<Recipe> testRecipes;
    late RecipeDetail testDetail;
    late RecipeFinancialSummary testFinancials;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppTutorialService.kTutorialCompletedKey: true,
        AppTutorialService.kTutorialRecipeListCompletedKey: true,
        AppTutorialService.kTutorialRecipeEditorCompletedKey: false,
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await ensureSampleManufacturingRecipe(db, prefs: prefs, locale: const Locale('es'));

      testUnits = await db.getAllUnits();
      testIngredients = await db.getAllIngredients();
      testRecipes = await db.getAllRecipes();
      testDetail = await db.getRecipeDetail(testRecipes.first.recipePk);
      testFinancials = RecipeUtils.calculateSummaryFromDetail(testDetail);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('RecipeListScreen renders temporary sample badge for manufacturing recipe', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
            unitsProvider.overrideWith((ref) => Future.value(testUnits)),
            unitsStreamProvider.overrideWith((ref) => Stream.value(testUnits)),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
            recipesWithFinancialsStreamProvider.overrideWith(
              (ref) => Stream.value([
                RecipeWithFinancials(
                  recipe: testRecipes.first,
                  financials: testFinancials,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('es'),
            home: RecipeListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Card should be rendered
      expect(find.textContaining('Galletas de Mantequilla'), findsOneWidget);
      // Temporary sample badge should be visible
      expect(find.text('Muestra Temporal'), findsOneWidget);
    });

    testWidgets('RecipeEditorScreen renders sample banner with save & dismiss buttons', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
            unitsProvider.overrideWith((ref) => Future.value(testUnits)),
            unitsStreamProvider.overrideWith((ref) => Stream.value(testUnits)),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value(testIngredients)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('es'),
            home: RecipeEditorScreen(
              recipeId: kSampleManufacturingRecipePk,
              isTemporary: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Temporary banner should be visible
      expect(find.byKey(const ValueKey('sample_manufacturing_recipe_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('save_sample_recipe_permanently_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('dismiss_sample_recipe_button')), findsOneWidget);

      // Ingredients should be loaded
      expect(find.text('Harina de Trigo 0000'), findsOneWidget);
      expect(find.text('Mantequilla sin Sal'), findsOneWidget);
      expect(find.text('Azúcar Blanca Refinada'), findsOneWidget);
    });

    testWidgets('RecipeEditorScreen auto removes sample recipe when tutorial completes', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
            unitsProvider.overrideWith((ref) => Future.value(testUnits)),
            unitsStreamProvider.overrideWith((ref) => Stream.value(testUnits)),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value(testIngredients)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('es'),
            home: RecipeEditorScreen(
              recipeId: kSampleManufacturingRecipePk,
              isTemporary: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final state = tester.state(find.byType(RecipeEditorScreen)) as dynamic;
      await state.handleTutorialEnd();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Recipe should now be dismissed from database
      final recipesAfter = await db.getAllRecipes();
      expect(recipesAfter, isEmpty);
      expect(prefs.getBool(kSampleManufacturingRecipeDismissedKey), isTrue);
    });

    testWidgets('RecipeEditorScreen adapts to English locale', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
            unitsProvider.overrideWith((ref) => Future.value(testUnits)),
            unitsStreamProvider.overrideWith((ref) => Stream.value(testUnits)),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value(testIngredients)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: RecipeEditorScreen(
              recipeId: kSampleManufacturingRecipePk,
              isTemporary: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Localized English recipe and ingredients should be rendered
      expect(find.text('Butter Cookies (Manufacturing Batch)'), findsOneWidget);
      expect(find.text('All-Purpose Wheat Flour'), findsOneWidget);
      expect(find.text('Unsalted Butter'), findsOneWidget);
      expect(find.text('Refined White Sugar'), findsOneWidget);
      expect(find.text('Temporary Sample'), findsOneWidget);
    });
  });
}
