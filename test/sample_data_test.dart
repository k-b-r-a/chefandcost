import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/sample_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('loadSampleData populates units, ingredients and recipes', () async {
    final result = await loadSampleData(db);

    expect(result.ingredientsAdded, 14);
    expect(result.recipesAdded, 4);

    final ingredients = await db.getAllIngredients();
    expect(ingredients.length, 14);

    final recipes = await db.getAllRecipes();
    expect(recipes.length, 4);

    // Verify recipe detail for Torta Húmeda de Chocolate
    final torta = recipes.firstWhere((r) => r.name.contains('Torta Húmeda'));
    final detail = await db.getRecipeDetail(torta.recipePk);
    expect(detail.ingredients.length, 9);
    expect(detail.steps.length, 5);
    expect(detail.steps.any((s) => s.instruction.contains('[timer:')), isTrue);
  });

  test('loadSampleData clearFirst: false does not duplicate entries', () async {
    await loadSampleData(db, clearFirst: false);
    final result2 = await loadSampleData(db, clearFirst: false);

    expect(result2.ingredientsAdded, 0);
    expect(result2.recipesAdded, 0);

    final ingredients = await db.getAllIngredients();
    expect(ingredients.length, 14);
    final recipes = await db.getAllRecipes();
    expect(recipes.length, 4);
  });

  test('loadSampleData clearFirst: true resets and repopulates cleanly', () async {
    await loadSampleData(db, clearFirst: false);
    final result = await loadSampleData(db, clearFirst: true);

    expect(result.ingredientsAdded, 14);
    expect(result.recipesAdded, 4);

    final ingredients = await db.getAllIngredients();
    expect(ingredients.length, 14);
    final recipes = await db.getAllRecipes();
    expect(recipes.length, 4);
  });
}
