import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/utils/firestore_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final old = DateTime.utc(2020);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final unit in [
      (id: 'g-test', category: 'mass', factor: 1.0),
      (id: 'kg-test', category: 'mass', factor: 1000.0),
      (id: 'l-test', category: 'volume', factor: 1000.0),
      (id: 'bad-test', category: 'mass', factor: 0.0),
    ]) {
      await db.insertUnit(
        UnitsCompanion.insert(
          unitPk: Value(unit.id),
          name: unit.id,
          symbol: unit.id,
          category: Value(unit.category),
          factorToBase: Value(unit.factor),
        ),
      );
    }
    for (final ingredient in [
      (id: 'source', unit: 'g-test'),
      (id: 'target', unit: 'kg-test'),
    ]) {
      await db.insertIngredient(
        IngredientsCompanion.insert(
          ingredientPk: Value(ingredient.id),
          name: ingredient.id,
          cost: 10,
          quantityForCost: 1,
          unitFk: ingredient.unit,
        ),
      );
    }
    for (final id in ['one', 'both', 'steps-only', 'unrelated']) {
      await db.insertRecipe(
        RecipesCompanion.insert(
          recipePk: Value(id),
          name: id,
          defaultYield: 1,
          yieldName: 'portion',
          dateTimeModified: Value(old),
          dateCreated: Value(old),
        ),
      );
    }
    for (final id in ['one', 'both']) {
      await db
          .into(db.recipeIngredients)
          .insert(
            RecipeIngredientsCompanion.insert(
              recipeFk: id,
              ingredientFk: 'source',
              amountNeeded: 100,
            ),
          );
    }
    await db
        .into(db.recipeIngredients)
        .insert(
          RecipeIngredientsCompanion.insert(
            recipeFk: 'both',
            ingredientFk: 'target',
            amountNeeded: 1,
          ),
        );
    await db
        .into(db.recipeSteps)
        .insert(
          RecipeStepsCompanion.insert(
            recipeFk: 'steps-only',
            stepNumber: 1,
            instruction: 'Use [source]',
            dateTimeModified: Value(old),
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'converts grams to kg, combines duplicates, timestamps all affected recipes and sync DTO',
    () async {
      await db.mergeIngredients(
        (await db.getIngredientById('source'))!,
        (await db.getIngredientById('target'))!,
      );
      final one = await db.getRecipeDetail('one');
      expect(one.ingredients.single.ingredient.ingredientPk, 'target');
      expect(one.ingredients.single.entry.amountNeeded, closeTo(0.1, 1e-10));
      final both = await db.getRecipeDetail('both');
      expect(both.ingredients, hasLength(1));
      expect(both.ingredients.single.entry.amountNeeded, closeTo(1.1, 1e-10));
      for (final id in ['one', 'both', 'steps-only']) {
        expect(
          (await db.getRecipeDetail(id)).recipe.dateTimeModified!.isAfter(old),
          isTrue,
        );
      }
      expect(
        (await db.getRecipeDetail(
          'unrelated',
        )).recipe.dateTimeModified!.toUtc(),
        old,
      );
      expect(
        (await db.getRecipeDetail('steps-only')).steps.single.instruction,
        'Use [target]',
      );
      expect(
        (await db.getIngredientById('source', includeDeleted: true))!.isDeleted,
        isTrue,
      );
      final dto = FirestoreSyncService.recipeFromFirestore(
        FirestoreSyncService.recipeToFirestore(both),
      );
      expect(dto.ingredients.single.ingredientFk, 'target');
      expect(dto.ingredients.single.amountNeeded, closeTo(1.1, 1e-10));
      expect(
        (await db.getAllRecipeDetails(
          modifiedSince: old.add(const Duration(days: 1)),
        )).map((d) => d.recipe.recipePk),
        unorderedEquals(['one', 'both', 'steps-only']),
      );
    },
  );

  for (final unit in ['l-test', 'bad-test']) {
    test(
      'rejects $unit atomically without changing recipes or deleting source',
      () async {
        await (db.update(db.ingredients)
              ..where((i) => i.ingredientPk.equals('target')))
            .write(IngredientsCompanion(unitFk: Value(unit)));
        await expectLater(
          db.mergeIngredients(
            (await db.getIngredientById('source'))!,
            (await db.getIngredientById('target'))!,
          ),
          throwsArgumentError,
        );
        expect(
          (await db.getRecipeDetail(
            'one',
          )).ingredients.single.entry.amountNeeded,
          100,
        );
        expect(
          (await db.getRecipeDetail('one')).recipe.dateTimeModified!.toUtc(),
          old,
        );
        expect(await db.getIngredientById('source'), isNotNull);
      },
    );
  }
  test('rejects self merge without deleting ingredient', () async {
    final ingredient = (await db.getIngredientById('source'))!;
    await expectLater(
      db.mergeIngredients(ingredient, ingredient),
      throwsArgumentError,
    );
    expect(await db.getIngredientById('source'), isNotNull);
  });
}
