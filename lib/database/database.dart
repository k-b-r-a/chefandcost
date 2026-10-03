import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'tables.dart';
import 'initialize_default_database.dart';
import '../utils/recipe_utils.dart' hide uuid;

part 'database.g.dart';

@DriftDatabase(
  tables: [Recipes, Ingredients, RecipeIngredients, RecipeSteps, Units],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forFile(File file) : super(NativeDatabase(file));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await initializeDefaultDatabase(this);
      },
    );
  }

  // --- Unit Queries ---
  Future<List<Unit>> getAllUnits() => select(units).get();
  Stream<List<Unit>> watchAllUnits() => select(units).watch();
  Future<int> insertUnit(UnitsCompanion unit) => into(units).insert(unit);
  Future<bool> updateUnit(Unit unit) => update(units).replace(unit);

  // --- Recipe Queries ---
  Future<List<Recipe>> getAllRecipes() =>
      (select(recipes)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  Stream<List<Recipe>> watchAllRecipes() =>
      (select(recipes)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Stream<List<RecipeWithFinancials>> watchAllRecipesWithFinancials() {
    final recipeStream = watchAllRecipes();
    
    return recipeStream.asyncMap((recipeList) async {
      final List<RecipeWithFinancials> results = [];
      
      for (var recipe in recipeList) {
        final detail = await getRecipeDetail(recipe.recipePk);
        final financials = RecipeUtils.calculateSummaryFromDetail(detail);
        
        results.add(RecipeWithFinancials(
          recipe: recipe,
          financials: financials,
        ));
      }
      
      return results;
    });
  }

  Future<int> insertRecipe(RecipesCompanion recipe) =>
      into(recipes).insert(recipe);
  Future<bool> updateRecipe(Recipe recipe) => update(recipes).replace(recipe);
  Future<int> deleteRecipe(Recipe recipe) => delete(recipes).delete(recipe);

  Future<void> duplicateRecipe(String sourcePk, String newName) async {
    final detail = await getRecipeDetail(sourcePk);
    final newPk = const Uuid().v4();
    await transaction(() async {
      await insertRecipe(RecipesCompanion(
        recipePk: Value(newPk),
        name: Value(newName),
        description: Value(detail.recipe.description ?? ''),
        defaultYield: Value(detail.recipe.defaultYield),
        yieldName: Value(detail.recipe.yieldName),
        targetProfitMargin: Value(detail.recipe.targetProfitMargin),
        targetPricePerPortion: Value(detail.recipe.targetPricePerPortion),
        colour: Value(detail.recipe.colour),
        dateTimeModified: Value(DateTime.now()),
      ));
      for (final ing in detail.ingredients) {
        await into(recipeIngredients).insert(RecipeIngredientsCompanion.insert(
          recipeFk: newPk,
          ingredientFk: ing.ingredient.ingredientPk,
          amountNeeded: ing.entry.amountNeeded,
        ));
      }
      for (int i = 0; i < detail.steps.length; i++) {
        await into(recipeSteps).insert(RecipeStepsCompanion.insert(
          recipeFk: newPk,
          stepNumber: detail.steps[i].stepNumber,
          instruction: detail.steps[i].instruction,
        ));
      }
    });
  }

  // --- Ingredient Queries ---
  Future<List<Ingredient>> getAllIngredients() =>
      (select(ingredients)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  Future<Ingredient?> getIngredientById(String pk) =>
      (select(ingredients)..where((t) => t.ingredientPk.equals(pk))).getSingleOrNull();
  Stream<List<Ingredient>> watchAllIngredients() =>
      (select(ingredients)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  Future<int> insertIngredient(IngredientsCompanion ingredient) =>
      into(ingredients).insert(ingredient);
  Future<bool> updateIngredient(Ingredient ingredient) =>
      update(ingredients).replace(ingredient);
  Future<int> deleteIngredient(Ingredient ingredient) =>
      delete(ingredients).delete(ingredient);

  Stream<List<Ingredient>> searchIngredients(String query) {
    if (query.isEmpty) return Stream.value([]);
    
    final trimmedQuery = query.trim().toLowerCase();
    // split query into words and filter out small connectors
    final terms = trimmedQuery.split(' ')
        .where((term) => term.length > 2)
        .toList();
    
    if (terms.isEmpty) {
      // fallback to simple contains
      return (select(ingredients)
            ..where((t) => t.name.contains(trimmedQuery))
            ..limit(5))
          .watch();
    }

    return (select(ingredients)
          ..where((t) {
            final expressions = terms.map((term) => t.name.contains(term)).toList();
            return expressions.reduce((a, b) => a | b);
          }))
        .watch()
        .map((list) {
          // Sort by relevance in Dart
          list.sort((a, b) {
            final nameA = a.name.toLowerCase();
            final nameB = b.name.toLowerCase();
            
            // 1. Exact match
            if (nameA == trimmedQuery && nameB != trimmedQuery) return -1;
            if (nameB == trimmedQuery && nameA != trimmedQuery) return 1;
            
            // 2. Starts with
            if (nameA.startsWith(trimmedQuery) && !nameB.startsWith(trimmedQuery)) return -1;
            if (nameB.startsWith(trimmedQuery) && !nameA.startsWith(trimmedQuery)) return 1;
            
            // 3. Count matching terms
            int matchesA = terms.where((t) => nameA.contains(t)).length;
            int matchesB = terms.where((t) => nameB.contains(t)).length;
            if (matchesA != matchesB) return matchesB.compareTo(matchesA);
            
            // 4. Alphabetical fallback
            return nameA.compareTo(nameB);
          });
          return list.take(15).toList(); // Return more results now that they are sorted
        });
  }

  // --- Relationship Queries ---
  Future<List<RecipeIngredient>> getIngredientsForRecipe(String recipePk) {
    return (select(
      recipeIngredients,
    )..where((t) => t.recipeFk.equals(recipePk))).get();
  }

  // --- Complex Queries ---
  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(recipeIngredients).go();
      await delete(recipeSteps).go();
      await delete(recipes).go();
      await delete(ingredients).go();
      await delete(units).go();
      await initializeDefaultDatabase(this);
    });
  }

  Future<void> mergeIngredients(
    Ingredient oldIngredient,
    Ingredient newIngredient,
  ) async {
    await transaction(() async {
      // 1. update recipeingredients
      final recipeIngredientsToUpdate = await (select(recipeIngredients)
            ..where((t) => t.ingredientFk.equals(oldIngredient.ingredientPk)))
          .get();

      for (final entry in recipeIngredientsToUpdate) {
        final existingNewEntry = await (select(recipeIngredients)
              ..where((t) => t.recipeFk.equals(entry.recipeFk))
              ..where((t) => t.ingredientFk.equals(newIngredient.ingredientPk)))
            .getSingleOrNull();

        if (existingNewEntry != null) {
          await (update(recipeIngredients)
                ..where(
                  (t) => t.recipeIngredientPk.equals(
                    existingNewEntry.recipeIngredientPk,
                  ),
                ))
              .write(
            RecipeIngredientsCompanion(
              amountNeeded:
                  Value(existingNewEntry.amountNeeded + entry.amountNeeded),
            ),
          );
          await (delete(recipeIngredients)
                ..where(
                  (t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk),
                ))
              .go();
        } else {
          await (update(recipeIngredients)
                ..where(
                  (t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk),
                ))
              .write(
            RecipeIngredientsCompanion(
              ingredientFk: Value(newIngredient.ingredientPk),
            ),
          );
        }
      }

      // 2. update recipesteps instructions
      final oldTag = '[${oldIngredient.name}]';
      final newTag = '[${newIngredient.name}]';

      await customStatement(
        'UPDATE recipe_steps SET instruction = REPLACE(instruction, ?, ?)',
        [oldTag, newTag],
      );

      // 3. delete the old ingredient
      await deleteIngredient(oldIngredient);
    });
  }

  Future<RecipeDetail> getRecipeDetail(String recipePk) async {
    final recipe = await (select(
      recipes,
    )..where((t) => t.recipePk.equals(recipePk))).getSingle();

    final ingredientList = await (select(recipeIngredients).join([
      innerJoin(
        ingredients,
        ingredients.ingredientPk.equalsExp(recipeIngredients.ingredientFk),
      ),
    ])..where(recipeIngredients.recipeFk.equals(recipePk))).get();

    final stepList =
        await (select(recipeSteps)
              ..where((t) => t.recipeFk.equals(recipePk))
              ..orderBy([(t) => OrderingTerm(expression: t.stepNumber)]))
            .get();

    return RecipeDetail(
      recipe: recipe,
      ingredients: ingredientList.map((row) {
        return RecipeIngredientWithData(
          entry: row.readTable(recipeIngredients),
          ingredient: row.readTable(ingredients),
        );
      }).toList(),
      steps: stepList,
    );
  }

  /// Performs a two-way, non-destructive merge of [remoteDb] into this database.
  /// Recipe conflicts are resolved using "last-write-wins" based on timestamps (updated_at).
  /// Local records and newer local edits are never wiped or overwritten.
  Future<SyncMergeResult> mergeWithDatabase(AppDatabase remoteDb) async {
    final remoteUnits = await remoteDb.getAllUnits();
    final remoteIngredients = await remoteDb.getAllIngredients();
    final remoteRecipes = await remoteDb.getAllRecipes();
    final allRemoteRecipeIngredients =
        await (remoteDb.select(remoteDb.recipeIngredients)).get();
    final allRemoteRecipeSteps =
        await (remoteDb.select(remoteDb.recipeSteps)).get();

    final remoteIngsByRecipe = <String, List<RecipeIngredient>>{};
    for (final ri in allRemoteRecipeIngredients) {
      remoteIngsByRecipe.putIfAbsent(ri.recipeFk, () => []).add(ri);
    }

    final remoteStepsByRecipe = <String, List<RecipeStep>>{};
    for (final rs in allRemoteRecipeSteps) {
      remoteStepsByRecipe.putIfAbsent(rs.recipeFk, () => []).add(rs);
    }

    int recipesAdded = 0;
    int recipesUpdated = 0;
    int recipesKeptLocal = 0;
    int ingredientsAdded = 0;
    int ingredientsUpdated = 0;

    await transaction(() async {
      // 1. Merge Units (non-destructive)
      final localUnits = await getAllUnits();
      final localUnitPks = {for (final u in localUnits) u.unitPk};
      for (final ru in remoteUnits) {
        if (!localUnitPks.contains(ru.unitPk)) {
          await into(units).insert(
            UnitsCompanion(
              unitPk: Value(ru.unitPk),
              name: Value(ru.name),
              symbol: Value(ru.symbol),
              category: Value(ru.category),
              factorToBase: Value(ru.factorToBase),
              isMutable: Value(ru.isMutable),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }

      // 2. Merge Ingredients (non-destructive, LWW based on updated_at)
      final localIngredients = await getAllIngredients();
      final localIngMap = {for (final i in localIngredients) i.ingredientPk: i};
      for (final ri in remoteIngredients) {
        final localIng = localIngMap[ri.ingredientPk];
        if (localIng == null) {
          await into(ingredients).insert(
            IngredientsCompanion(
              ingredientPk: Value(ri.ingredientPk),
              name: Value(ri.name),
              cost: Value(ri.cost),
              quantityForCost: Value(ri.quantityForCost),
              unitFk: Value(ri.unitFk),
              dateCreated: Value(ri.dateCreated),
              dateTimeModified: Value(ri.dateTimeModified),
            ),
          );
          ingredientsAdded++;
        } else {
          final localTime = localIng.dateTimeModified ?? localIng.dateCreated;
          final remoteTime = ri.dateTimeModified ?? ri.dateCreated;
          if (remoteTime.isAfter(localTime)) {
            await (update(ingredients)
                  ..where((t) => t.ingredientPk.equals(localIng.ingredientPk)))
                .write(
              IngredientsCompanion(
                name: Value(ri.name),
                cost: Value(ri.cost),
                quantityForCost: Value(ri.quantityForCost),
                unitFk: Value(ri.unitFk),
                dateTimeModified:
                    Value(ri.dateTimeModified ?? ri.dateCreated),
              ),
            );
            ingredientsUpdated++;
          }
        }
      }

      // 3. Merge Recipes (non-destructive, LWW based on updated_at)
      final localRecipes = await getAllRecipes();
      final localRecipeMap = {for (final r in localRecipes) r.recipePk: r};

      for (final remoteRecipe in remoteRecipes) {
        final localRecipe = localRecipeMap[remoteRecipe.recipePk];

        if (localRecipe == null) {
          // New recipe from remote: insert into local database
          await into(recipes).insert(
            RecipesCompanion(
              recipePk: Value(remoteRecipe.recipePk),
              name: Value(remoteRecipe.name),
              description: Value(remoteRecipe.description),
              defaultYield: Value(remoteRecipe.defaultYield),
              yieldName: Value(remoteRecipe.yieldName),
              targetProfitMargin: Value(remoteRecipe.targetProfitMargin),
              targetPricePerPortion: Value(remoteRecipe.targetPricePerPortion),
              fixedOverheadCost: Value(remoteRecipe.fixedOverheadCost),
              colour: Value(remoteRecipe.colour),
              dateCreated: Value(remoteRecipe.dateCreated),
              dateTimeModified: Value(remoteRecipe.dateTimeModified),
              archived: Value(remoteRecipe.archived),
            ),
          );

          final ings = remoteIngsByRecipe[remoteRecipe.recipePk] ?? [];
          for (final ri in ings) {
            await into(recipeIngredients).insert(
              RecipeIngredientsCompanion(
                recipeIngredientPk: Value(ri.recipeIngredientPk),
                recipeFk: Value(ri.recipeFk),
                ingredientFk: Value(ri.ingredientFk),
                amountNeeded: Value(ri.amountNeeded),
                dateTimeModified: Value(ri.dateTimeModified),
              ),
            );
          }

          final steps = remoteStepsByRecipe[remoteRecipe.recipePk] ?? [];
          for (final rs in steps) {
            await into(recipeSteps).insert(
              RecipeStepsCompanion(
                stepPk: Value(rs.stepPk),
                recipeFk: Value(rs.recipeFk),
                stepNumber: Value(rs.stepNumber),
                instruction: Value(rs.instruction),
                dateTimeModified: Value(rs.dateTimeModified),
              ),
            );
          }

          recipesAdded++;
        } else {
          // Conflict: recipe exists locally and remotely.
          // Resolve recipe conflicts using "last-write-wins" based on timestamps (updated_at).
          // Do not wipe local records or overwrite newer local edits.
          final localUpdatedAt =
              localRecipe.dateTimeModified ?? localRecipe.dateCreated;
          final remoteUpdatedAt =
              remoteRecipe.dateTimeModified ?? remoteRecipe.dateCreated;

          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            // Remote is newer -> overwrite local recipe with remote version
            await (update(recipes)
                  ..where((t) => t.recipePk.equals(localRecipe.recipePk)))
                .write(
              RecipesCompanion(
                name: Value(remoteRecipe.name),
                description: Value(remoteRecipe.description),
                defaultYield: Value(remoteRecipe.defaultYield),
                yieldName: Value(remoteRecipe.yieldName),
                targetProfitMargin: Value(remoteRecipe.targetProfitMargin),
                targetPricePerPortion: Value(remoteRecipe.targetPricePerPortion),
                fixedOverheadCost: Value(remoteRecipe.fixedOverheadCost),
                colour: Value(remoteRecipe.colour),
                dateTimeModified: Value(remoteRecipe.dateTimeModified),
                archived: Value(remoteRecipe.archived),
              ),
            );

            // Replace recipe ingredients with remote's
            await (delete(recipeIngredients)
                  ..where((t) => t.recipeFk.equals(localRecipe.recipePk)))
                .go();
            final ings = remoteIngsByRecipe[remoteRecipe.recipePk] ?? [];
            for (final ri in ings) {
              await into(recipeIngredients).insert(
                RecipeIngredientsCompanion(
                  recipeIngredientPk: Value(ri.recipeIngredientPk),
                  recipeFk: Value(ri.recipeFk),
                  ingredientFk: Value(ri.ingredientFk),
                  amountNeeded: Value(ri.amountNeeded),
                  dateTimeModified: Value(ri.dateTimeModified),
                ),
              );
            }

            // Replace recipe steps with remote's
            await (delete(recipeSteps)
                  ..where((t) => t.recipeFk.equals(localRecipe.recipePk)))
                .go();
            final steps = remoteStepsByRecipe[remoteRecipe.recipePk] ?? [];
            for (final rs in steps) {
              await into(recipeSteps).insert(
                RecipeStepsCompanion(
                  stepPk: Value(rs.stepPk),
                  recipeFk: Value(rs.recipeFk),
                  stepNumber: Value(rs.stepNumber),
                  instruction: Value(rs.instruction),
                  dateTimeModified: Value(rs.dateTimeModified),
                ),
              );
            }

            recipesUpdated++;
          } else {
            // Local is newer or equal -> keep local edits!
            recipesKeptLocal++;
          }
        }
      }
    });

    return SyncMergeResult(
      recipesAdded: recipesAdded,
      recipesUpdated: recipesUpdated,
      recipesKeptLocal: recipesKeptLocal,
      ingredientsAdded: ingredientsAdded,
      ingredientsUpdated: ingredientsUpdated,
    );
  }
}

class SyncMergeResult {
  final int recipesAdded;
  final int recipesUpdated;
  final int recipesKeptLocal;
  final int ingredientsAdded;
  final int ingredientsUpdated;

  const SyncMergeResult({
    this.recipesAdded = 0,
    this.recipesUpdated = 0,
    this.recipesKeptLocal = 0,
    this.ingredientsAdded = 0,
    this.ingredientsUpdated = 0,
  });

  bool get hasChanges =>
      recipesAdded > 0 ||
      recipesUpdated > 0 ||
      ingredientsAdded > 0 ||
      ingredientsUpdated > 0;
}

class RecipeWithFinancials {
  final Recipe recipe;
  final RecipeFinancialSummary financials;

  RecipeWithFinancials({required this.recipe, required this.financials});
}

class RecipeDetail {
  final Recipe recipe;
  final List<RecipeIngredientWithData> ingredients;
  final List<RecipeStep> steps;

  RecipeDetail({
    required this.recipe,
    required this.ingredients,
    required this.steps,
  });
}

class RecipeIngredientWithData {
  final RecipeIngredient entry;
  final Ingredient ingredient;

  RecipeIngredientWithData({required this.entry, required this.ingredient});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    return NativeDatabase(file);
  });
}
