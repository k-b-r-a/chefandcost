import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
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
  AppDatabase.forPath(String path)
      : super(
          driftDatabase(
            name: 'remote_merge',
            native: DriftNativeOptions(databasePath: () async => path),
          ),
        );
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(ingredients, ingredients.isDeleted);
          await m.addColumn(ingredients, ingredients.deletedAt);
        }
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
  Future<List<Ingredient>> getAllIngredients({bool includeDeleted = false}) {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<Ingredient?> getIngredientById(String pk, {bool includeDeleted = false}) async {
    final query = select(ingredients)..where((t) => t.ingredientPk.equals(pk));
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (await (query..limit(1)).get()).firstOrNull;
  }

  Stream<List<Ingredient>> watchAllIngredients({bool includeDeleted = false}) {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<int> insertIngredient(IngredientsCompanion ingredient) =>
      into(ingredients).insert(ingredient);

  Future<bool> updateIngredient(Ingredient ingredient) async {
    return transaction(() async {
      final old = await getIngredientById(ingredient.ingredientPk, includeDeleted: true);
      if (old != null && old.unitFk != ingredient.unitFk) {
        final allUnits = await getAllUnits();
        final oldUnit = allUnits.where((u) => u.unitPk == old.unitFk).firstOrNull;
        final newUnit = allUnits.where((u) => u.unitPk == ingredient.unitFk).firstOrNull;
        if (oldUnit != null &&
            newUnit != null &&
            oldUnit.category != null &&
            oldUnit.category == newUnit.category &&
            oldUnit.factorToBase != newUnit.factorToBase) {
          final existingRecipeIngs = await (select(recipeIngredients)
                ..where((t) => t.ingredientFk.equals(ingredient.ingredientPk)))
              .get();
          for (final entry in existingRecipeIngs) {
            final base = entry.amountNeeded * oldUnit.factorToBase;
            final converted = double.parse((base / newUnit.factorToBase).toStringAsFixed(6));
            await (update(recipeIngredients)
                  ..where((t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk)))
                .write(RecipeIngredientsCompanion(
              amountNeeded: Value(converted),
            ));
          }
        }
      }
      return update(ingredients).replace(ingredient);
    });
  }

  Future<int> deleteIngredient(Ingredient ingredient) {
    final now = DateTime.now();
    return (update(ingredients)..where((t) => t.ingredientPk.equals(ingredient.ingredientPk))).write(
      IngredientsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        dateTimeModified: Value(now),
      ),
    );
  }

  Future<int> restoreIngredient(String ingredientPk) {
    final now = DateTime.now();
    return (update(ingredients)..where((t) => t.ingredientPk.equals(ingredientPk))).write(
      IngredientsCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        dateTimeModified: Value(now),
      ),
    );
  }

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
            ..where((t) => t.isDeleted.equals(false) & t.name.contains(trimmedQuery))
            ..limit(5))
          .watch();
    }

    return (select(ingredients)
          ..where((t) {
            final expressions = terms.map((term) => t.name.contains(term)).toList();
            return t.isDeleted.equals(false) & expressions.reduce((a, b) => a | b);
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
        final existingNewEntry = (await (select(recipeIngredients)
              ..where((t) => t.recipeFk.equals(entry.recipeFk))
              ..where((t) => t.ingredientFk.equals(newIngredient.ingredientPk))
              ..limit(1))
            .get()).firstOrNull;

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
    final recipe = (await (select(
      recipes,
    )..where((t) => t.recipePk.equals(recipePk))..limit(1)).get()).firstOrNull;

    if (recipe == null) {
      throw StateError('Recipe not found: $recipePk');
    }

    final ingredientList = await (select(recipeIngredients).join([
      leftOuterJoin(
        ingredients,
        ingredients.ingredientPk.equalsExp(recipeIngredients.ingredientFk),
      ),
    ])..where(recipeIngredients.recipeFk.equals(recipePk))).get();

    final stepList =
        await (select(recipeSteps)
              ..where((t) => t.recipeFk.equals(recipePk))
              ..orderBy([(t) => OrderingTerm(expression: t.stepNumber)]))
            .get();

    final validIngredients = <RecipeIngredientWithData>[];
    for (final row in ingredientList) {
      final entry = row.readTable(recipeIngredients);
      final ing = row.readTableOrNull(ingredients);
      if (ing != null && ing.isDeleted) {
        continue;
      }
      final effectiveIng = ing ??
          Ingredient(
            ingredientPk: entry.ingredientFk,
            name: 'Unknown Ingredient',
            cost: 0.0,
            quantityForCost: 1.0,
            unitFk: 'unit-g',
            dateCreated: DateTime.now(),
            isDeleted: false,
          );
      validIngredients.add(RecipeIngredientWithData(
        entry: entry,
        ingredient: effectiveIng,
      ));
    }

    return RecipeDetail(
      recipe: recipe,
      ingredients: validIngredients,
      steps: stepList,
    );
  }

  Future<List<RecipeDetail>> getAllRecipeDetails({DateTime? modifiedSince}) async {
    final query = select(recipes);
    if (modifiedSince != null) {
      query.where((t) =>
          t.dateTimeModified.isBiggerOrEqualValue(modifiedSince) |
          t.dateCreated.isBiggerOrEqualValue(modifiedSince));
    }
    final recipeList = await query.get();
    final List<RecipeDetail> details = [];
    for (final r in recipeList) {
      details.add(await getRecipeDetail(r.recipePk));
    }
    return details;
  }

  Future<List<Ingredient>> getIngredientsModifiedSince(DateTime? modifiedSince, {bool includeDeleted = false}) async {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    if (modifiedSince != null) {
      query.where((t) =>
          t.dateTimeModified.isBiggerOrEqualValue(modifiedSince) |
          t.dateCreated.isBiggerOrEqualValue(modifiedSince) |
          t.deletedAt.isBiggerOrEqualValue(modifiedSince));
    }
    return query.get();
  }

  Future<List<Unit>> getCustomUnitsModifiedSince(DateTime? modifiedSince) async {
    final query = select(units)..where((t) => t.isMutable.equals(true));
    return query.get();
  }

  /// Merges a single recipe and its embedded ingredients and steps from remote using LWW based on updated_at.
  /// Also upserts any nested ingredients provided, with Recipe Dependency Conflict Resolution.
  /// Returns: 1 if inserted, 2 if updated, 0 if kept local.
  Future<int> mergeRecipeFromRemote({
    required Recipe remoteRecipe,
    required List<RecipeIngredient> remoteIngredients,
    required List<RecipeStep> remoteSteps,
    List<Ingredient> nestedIngredients = const [],
  }) async {
    return transaction(() async {
      final recipeUpdatedAt = remoteRecipe.dateTimeModified ?? remoteRecipe.dateCreated;

      // 1. Merge nested ingredients
      for (final ing in nestedIngredients) {
        await mergeIngredientFromRemote(ing);
      }

      // 2. Recipe Dependency Conflict Resolver pass
      final resolvedIngredients = <RecipeIngredient>[];

      for (final ri in remoteIngredients) {
        final localIng = await getIngredientById(ri.ingredientFk, includeDeleted: true);

        if (localIng != null && localIng.isDeleted) {
          final ingredientDeletedAt = localIng.deletedAt ?? localIng.dateTimeModified ?? localIng.dateCreated;

          if (recipeUpdatedAt.isAfter(ingredientDeletedAt)) {
            // Case 1 (Recipe Updated AFTER Deletion: recipe.updated_at > ingredient.deleted_at):
            // Action (Resurrection / Restoration): Reactivate the ingredient (is_deleted = false, clear deleted_at)
            // and log a sync notice, preserving recipe integrity.
            await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
              IngredientsCompanion(
                isDeleted: const Value(false),
                deletedAt: const Value(null),
                dateTimeModified: Value(DateTime.now()),
              ),
            );
            debugPrint(
              'Sync Notice: Resurrected ingredient "${localIng.name}" (${localIng.ingredientPk}) '
              'because recipe "${remoteRecipe.name}" was modified after ingredient deletion '
              '($recipeUpdatedAt > $ingredientDeletedAt).',
            );
            resolvedIngredients.add(ri);
          } else {
            // Case 2 (Deletion NEWER Than Recipe: ingredient.deleted_at >= recipe.updated_at):
            // Action (Cascade / Detach): Retain the deletion of the ingredient.
            // Remove the dead ingredient reference from the local recipe instance to prevent FK errors and crashes.
            debugPrint(
              'Sync Notice: Detached deleted ingredient "${localIng.name}" (${localIng.ingredientPk}) '
              'from recipe "${remoteRecipe.name}" because ingredient was deleted after recipe modification '
              '($ingredientDeletedAt >= $recipeUpdatedAt).',
            );
          }
        } else if (localIng == null) {
          // Case 3 (Missing / Ambiguous): Prefer data safety
          final nested = nestedIngredients.where((n) => n.ingredientPk == ri.ingredientFk).firstOrNull;
          if (nested != null) {
            if (nested.isDeleted) {
              final nestedDeletedAt = nested.deletedAt ?? nested.dateTimeModified ?? nested.dateCreated;
              if (recipeUpdatedAt.isAfter(nestedDeletedAt)) {
                await mergeIngredientFromRemote(Ingredient(
                  ingredientPk: nested.ingredientPk,
                  name: nested.name,
                  cost: nested.cost,
                  quantityForCost: nested.quantityForCost,
                  unitFk: nested.unitFk,
                  dateCreated: nested.dateCreated,
                  dateTimeModified: nested.dateTimeModified,
                  isDeleted: false,
                  deletedAt: null,
                ));
                resolvedIngredients.add(ri);
              }
            } else {
              resolvedIngredients.add(ri);
            }
          } else {
            final fallbackUnit = (await (select(units)..limit(1)).get()).firstOrNull;
            if (fallbackUnit != null) {
              await into(ingredients).insert(
                IngredientsCompanion(
                  ingredientPk: Value(ri.ingredientFk),
                  name: const Value('Ingrediente'),
                  cost: const Value(0.0),
                  quantityForCost: const Value(1.0),
                  unitFk: Value(fallbackUnit.unitPk),
                  dateCreated: Value(DateTime.now()),
                  isDeleted: const Value(false),
                  deletedAt: const Value(null),
                ),
                mode: InsertMode.insertOrIgnore,
              );
              resolvedIngredients.add(ri);
            }
          }
        } else {
          resolvedIngredients.add(ri);
        }
      }

      // 3. Persist recipe using LWW
      final localRecipe = (await (select(recipes)
            ..where((t) => t.recipePk.equals(remoteRecipe.recipePk))
            ..limit(1))
          .get()).firstOrNull;

      if (localRecipe == null) {
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

        for (final ri in resolvedIngredients) {
          await into(recipeIngredients).insert(
            RecipeIngredientsCompanion(
              recipeIngredientPk: Value(ri.recipeIngredientPk),
              recipeFk: Value(ri.recipeFk),
              ingredientFk: Value(ri.ingredientFk),
              amountNeeded: Value(ri.amountNeeded),
              dateTimeModified: Value(ri.dateTimeModified),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }

        for (final rs in remoteSteps) {
          await into(recipeSteps).insert(
            RecipeStepsCompanion(
              stepPk: Value(rs.stepPk),
              recipeFk: Value(rs.recipeFk),
              stepNumber: Value(rs.stepNumber),
              instruction: Value(rs.instruction),
              dateTimeModified: Value(rs.dateTimeModified),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }

        return 1;
      } else {
        final localUpdatedAt = localRecipe.dateTimeModified ?? localRecipe.dateCreated;

        if (recipeUpdatedAt.isAfter(localUpdatedAt)) {
          await (update(recipes)..where((t) => t.recipePk.equals(localRecipe.recipePk))).write(
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

          await (delete(recipeIngredients)..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
          for (final ri in resolvedIngredients) {
            await into(recipeIngredients).insert(
              RecipeIngredientsCompanion(
                recipeIngredientPk: Value(ri.recipeIngredientPk),
                recipeFk: Value(ri.recipeFk),
                ingredientFk: Value(ri.ingredientFk),
                amountNeeded: Value(ri.amountNeeded),
                dateTimeModified: Value(ri.dateTimeModified),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }

          await (delete(recipeSteps)..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
          for (final rs in remoteSteps) {
            await into(recipeSteps).insert(
              RecipeStepsCompanion(
                stepPk: Value(rs.stepPk),
                recipeFk: Value(rs.recipeFk),
                stepNumber: Value(rs.stepNumber),
                instruction: Value(rs.instruction),
                dateTimeModified: Value(rs.dateTimeModified),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }

          return 2;
        } else {
          return 0;
        }
      }
    });
  }

  /// Merges an ingredient from remote using LWW and deletion tracking.
  /// Returns: 1 if inserted, 2 if updated, 0 if kept local.
  Future<int> mergeIngredientFromRemote(Ingredient remoteIngredient) async {
    // Ensure the unit exists before inserting ingredient to satisfy FK constraint
    var targetUnitFk = remoteIngredient.unitFk;
    final unitExists = (await (select(units)
          ..where((t) => t.unitPk.equals(targetUnitFk))
          ..limit(1))
        .get()).firstOrNull;
    if (unitExists == null) {
      final defaultUnit = (await (select(units)
            ..where((t) => t.symbol.equals('g') | t.name.equals('unit_grams'))
            ..limit(1))
          .get()).firstOrNull ??
          (await (select(units)..limit(1)).get()).firstOrNull;
      await into(units).insert(
        UnitsCompanion(
          unitPk: Value(targetUnitFk),
          name: Value(defaultUnit?.name ?? 'unit_grams'),
          symbol: Value(defaultUnit?.symbol ?? 'g'),
          category: Value(defaultUnit?.category ?? 'mass'),
          factorToBase: Value(defaultUnit?.factorToBase ?? 1.0),
          isMutable: const Value(false),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    final localIng = await getIngredientById(remoteIngredient.ingredientPk, includeDeleted: true);
    final remoteTime = remoteIngredient.dateTimeModified ?? remoteIngredient.dateCreated;

    if (localIng == null) {
      await into(ingredients).insert(
        IngredientsCompanion(
          ingredientPk: Value(remoteIngredient.ingredientPk),
          name: Value(remoteIngredient.name),
          cost: Value(remoteIngredient.cost),
          quantityForCost: Value(remoteIngredient.quantityForCost),
          unitFk: Value(targetUnitFk),
          dateCreated: Value(remoteIngredient.dateCreated),
          dateTimeModified: Value(remoteIngredient.dateTimeModified),
          isDeleted: Value(remoteIngredient.isDeleted),
          deletedAt: Value(remoteIngredient.deletedAt),
        ),
        mode: InsertMode.insertOrReplace,
      );
      return remoteIngredient.isDeleted ? 0 : 1;
    }

    final localTime = localIng.dateTimeModified ?? localIng.dateCreated;

    if (localIng.isDeleted) {
      final localDeletedAt = localIng.deletedAt ?? localTime;

      if (remoteIngredient.isDeleted) {
        final remoteDeletedAt = remoteIngredient.deletedAt ?? remoteTime;
        if (remoteDeletedAt.isAfter(localDeletedAt)) {
          await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              deletedAt: Value(remoteDeletedAt),
              dateTimeModified: Value(remoteTime),
            ),
          );
          return 2;
        }
        return 0;
      } else {
        // Local is deleted, remote is active!
        // Inbound sync filtering: Do NOT re-download or recreate any ingredient whose ID is marked as deleted locally with deleted_at >= remote_updated_at
        if (!remoteTime.isAfter(localDeletedAt)) {
          return 0;
        } else {
          await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              name: Value(remoteIngredient.name),
              cost: Value(remoteIngredient.cost),
              quantityForCost: Value(remoteIngredient.quantityForCost),
              unitFk: Value(targetUnitFk),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              dateTimeModified: Value(remoteTime),
            ),
          );
          return 2;
        }
      }
    } else {
      if (remoteIngredient.isDeleted) {
        // Firestore sends is_deleted: true, apply to Drift
        final remoteDeletedAt = remoteIngredient.deletedAt ?? remoteTime;
        if (remoteDeletedAt.isAfter(localTime) || remoteDeletedAt.isAtSameMomentAs(localTime)) {
          await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(remoteDeletedAt),
              dateTimeModified: Value(remoteTime),
            ),
          );
          return 2;
        }
        return 0;
      } else {
        if (remoteTime.isAfter(localTime)) {
          await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              name: Value(remoteIngredient.name),
              cost: Value(remoteIngredient.cost),
              quantityForCost: Value(remoteIngredient.quantityForCost),
              unitFk: Value(targetUnitFk),
              dateTimeModified: Value(remoteIngredient.dateTimeModified ?? remoteIngredient.dateCreated),
            ),
          );
          return 2;
        }
        return 0;
      }
    }
  }

  /// Merges a unit from remote (non-destructive insert if absent, deduplicated by name).
  Future<void> mergeUnitFromRemote(Unit remoteUnit) async {
    final localUnit = (await (select(units)
          ..where((t) => t.unitPk.equals(remoteUnit.unitPk))
          ..limit(1))
        .get()).firstOrNull;
    if (localUnit != null) return;

    final normName = remoteUnit.name == 'unit_spoonfuls' ? 'unit_tablespoons' : remoteUnit.name;
    final unitByName = (await (select(units)
          ..where((t) => t.name.equals(normName))
          ..limit(1))
        .get()).firstOrNull;

    if (unitByName != null) {
      await (update(ingredients)..where((t) => t.unitFk.equals(remoteUnit.unitPk)))
          .write(IngredientsCompanion(unitFk: Value(unitByName.unitPk)));
      return;
    }

    await into(units).insert(
      UnitsCompanion(
        unitPk: Value(remoteUnit.unitPk),
        name: Value(remoteUnit.name),
        symbol: Value(remoteUnit.symbol),
        category: Value(remoteUnit.category),
        factorToBase: Value(remoteUnit.factorToBase),
        isMutable: Value(remoteUnit.isMutable),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Performs a two-way, non-destructive merge of [remoteDb] into this database.
  /// Recipe conflicts are resolved using "last-write-wins" based on timestamps (updated_at).
  /// Local records and newer local edits are never wiped or overwritten.
  Future<SyncMergeResult> mergeWithDatabase(AppDatabase remoteDb) async {
    final remoteUnits = await remoteDb.getAllUnits();
    final remoteIngredients = await remoteDb.getAllIngredients(includeDeleted: true);
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
      // 1. Merge Units (non-destructive & deduplicated)
      final localUnits = await getAllUnits();
      final localUnitPks = {for (final u in localUnits) u.unitPk};
      final localUnitsByName = {for (final u in localUnits) u.name: u};
      final unitRemap = <String, String>{};

      for (final ru in remoteUnits) {
        if (localUnitPks.contains(ru.unitPk)) continue;
        final normName = ru.name == 'unit_spoonfuls' ? 'unit_tablespoons' : ru.name;
        if (localUnitsByName.containsKey(normName)) {
          unitRemap[ru.unitPk] = localUnitsByName[normName]!.unitPk;
          continue;
        }
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

      // 2. Merge Ingredients (non-destructive, LWW based on updated_at, with deletion tracking)
      final localIngredients = await getAllIngredients(includeDeleted: true);
      final localIngMap = {for (final i in localIngredients) i.ingredientPk: i};
      for (final ri in remoteIngredients) {
        final effectiveUnitFk = unitRemap[ri.unitFk] ?? ri.unitFk;
        final localIng = localIngMap[ri.ingredientPk];
        final remoteTime = ri.dateTimeModified ?? ri.dateCreated;

        if (localIng == null) {
          await into(ingredients).insert(
            IngredientsCompanion(
              ingredientPk: Value(ri.ingredientPk),
              name: Value(ri.name),
              cost: Value(ri.cost),
              quantityForCost: Value(ri.quantityForCost),
              unitFk: Value(effectiveUnitFk),
              dateCreated: Value(ri.dateCreated),
              dateTimeModified: Value(ri.dateTimeModified),
              isDeleted: Value(ri.isDeleted),
              deletedAt: Value(ri.deletedAt),
            ),
            mode: InsertMode.insertOrReplace,
          );
          if (!ri.isDeleted) {
            ingredientsAdded++;
          }
        } else {
          final localTime = localIng.dateTimeModified ?? localIng.dateCreated;

          if (localIng.isDeleted) {
            final localDeletedAt = localIng.deletedAt ?? localTime;
            if (ri.isDeleted) {
              final remoteDeletedAt = ri.deletedAt ?? remoteTime;
              if (remoteDeletedAt.isAfter(localDeletedAt)) {
                await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
                  IngredientsCompanion(
                    deletedAt: Value(remoteDeletedAt),
                    dateTimeModified: Value(remoteTime),
                  ),
                );
                ingredientsUpdated++;
              }
            } else {
              // Remote is active, local is deleted:
              // Do NOT re-download or recreate if local deletion is newer or equal
              if (remoteTime.isAfter(localDeletedAt)) {
                await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
                  IngredientsCompanion(
                    name: Value(ri.name),
                    cost: Value(ri.cost),
                    quantityForCost: Value(ri.quantityForCost),
                    unitFk: Value(effectiveUnitFk),
                    isDeleted: const Value(false),
                    deletedAt: const Value(null),
                    dateTimeModified: Value(remoteTime),
                  ),
                );
                ingredientsUpdated++;
              }
            }
          } else {
            // Local is active
            if (ri.isDeleted) {
              final remoteDeletedAt = ri.deletedAt ?? remoteTime;
              if (remoteDeletedAt.isAfter(localTime) || remoteDeletedAt.isAtSameMomentAs(localTime)) {
                await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
                  IngredientsCompanion(
                    isDeleted: const Value(true),
                    deletedAt: Value(remoteDeletedAt),
                    dateTimeModified: Value(remoteTime),
                  ),
                );
                ingredientsUpdated++;
              }
            } else {
              if (remoteTime.isAfter(localTime)) {
                await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
                  IngredientsCompanion(
                    name: Value(ri.name),
                    cost: Value(ri.cost),
                    quantityForCost: Value(ri.quantityForCost),
                    unitFk: Value(effectiveUnitFk),
                    dateTimeModified: Value(ri.dateTimeModified ?? ri.dateCreated),
                  ),
                );
                ingredientsUpdated++;
              }
            }
          }
        }
      }

      // 3. Merge Recipes (non-destructive, LWW based on updated_at, with dependency conflict resolution)
      final localRecipes = await getAllRecipes();
      final localRecipeMap = {for (final r in localRecipes) r.recipePk: r};

      for (final remoteRecipe in remoteRecipes) {
        final localRecipe = localRecipeMap[remoteRecipe.recipePk];
        final recipeUpdatedAt = remoteRecipe.dateTimeModified ?? remoteRecipe.dateCreated;

        // Resolve recipe ingredients against deleted ingredients
        final rawIngs = remoteIngsByRecipe[remoteRecipe.recipePk] ?? [];
        final resolvedIngs = <RecipeIngredient>[];

        for (final ri in rawIngs) {
          final localIng = await getIngredientById(ri.ingredientFk, includeDeleted: true);
          if (localIng != null && localIng.isDeleted) {
            final ingDeletedAt = localIng.deletedAt ?? localIng.dateTimeModified ?? localIng.dateCreated;
            if (recipeUpdatedAt.isAfter(ingDeletedAt)) {
              // Case 1: Resurrect ingredient
              await (update(ingredients)..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
                IngredientsCompanion(
                  isDeleted: const Value(false),
                  deletedAt: const Value(null),
                  dateTimeModified: Value(DateTime.now()),
                ),
              );
              resolvedIngs.add(ri);
            } else {
              // Case 2: Detach dead ingredient reference
            }
          } else if (localIng == null) {
            final fallbackUnit = (await (select(units)..limit(1)).get()).firstOrNull;
            if (fallbackUnit != null) {
              await into(ingredients).insert(
                IngredientsCompanion(
                  ingredientPk: Value(ri.ingredientFk),
                  name: const Value('Ingrediente'),
                  cost: const Value(0.0),
                  quantityForCost: const Value(1.0),
                  unitFk: Value(fallbackUnit.unitPk),
                  dateCreated: Value(DateTime.now()),
                  isDeleted: const Value(false),
                  deletedAt: const Value(null),
                ),
                mode: InsertMode.insertOrIgnore,
              );
              resolvedIngs.add(ri);
            }
          } else {
            resolvedIngs.add(ri);
          }
        }

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

          for (final ri in resolvedIngs) {
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
          final localUpdatedAt =
              localRecipe.dateTimeModified ?? localRecipe.dateCreated;

          if (recipeUpdatedAt.isAfter(localUpdatedAt)) {
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
            for (final ri in resolvedIngs) {
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

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
