import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';
import 'tables.dart';
import 'initialize_default_database.dart';
import '../utils/recipe_utils.dart' hide uuid;

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Recipes,
    Ingredients,
    RecipeIngredients,
    RecipeSteps,
    Units,
    Groups,
    Categories,
    RecipeSpaces,
  ],
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

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
      variables: [Variable.withString(tableName)],
    ).get();
    return result.isNotEmpty;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final result = await customSelect("PRAGMA table_info('$tableName');").get();
    return result.any((row) => row.data['name'] == columnName);
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          if (!await _columnExists('ingredients', 'is_deleted')) {
            await m.addColumn(ingredients, ingredients.isDeleted);
          }
          if (!await _columnExists('ingredients', 'deleted_at')) {
            await m.addColumn(ingredients, ingredients.deletedAt);
          }
          if (!await _tableExists('groups')) {
            await m.createTable(groups);
          }
          if (!await _tableExists('categories')) {
            await m.createTable(categories);
          }
          if (!await _columnExists('recipes', 'group_id')) {
            await m.addColumn(recipes, recipes.groupId);
          }
          if (!await _columnExists('recipes', 'category')) {
            await m.addColumn(recipes, recipes.category);
          }
          if (!await _columnExists('ingredients', 'group_id')) {
            await m.addColumn(ingredients, ingredients.groupId);
          }
          if (!await _columnExists('ingredients', 'category')) {
            await m.addColumn(ingredients, ingredients.category);
          }
          if (!await _columnExists('ingredients', 'current_stock')) {
            await m.addColumn(ingredients, ingredients.currentStock);
          }
          if (!await _columnExists('ingredients', 'minimum_stock')) {
            await m.addColumn(ingredients, ingredients.minimumStock);
          }
          if (!await _columnExists('ingredients', 'stock_unit')) {
            await m.addColumn(ingredients, ingredients.stockUnit);
          }
          if (!await _columnExists('ingredients', 'cost_per_stock_unit')) {
            await m.addColumn(ingredients, ingredients.costPerStockUnit);
          }
          if (!await _columnExists('ingredients', 'last_stock_update')) {
            await m.addColumn(ingredients, ingredients.lastStockUpdate);
          }
        }
      },
      beforeOpen: (details) async {
        // Repair databases already stamped at v2 that are missing this table.
        // Drift only calls onUpgrade when the stored schema version is older.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            icon_name TEXT
          )
        ''');
        final hadRecipeSpaces = await _tableExists('recipe_spaces');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS recipe_spaces (
            recipe_id TEXT NOT NULL REFERENCES recipes(recipe_pk) ON DELETE CASCADE,
            space_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            is_deleted INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (recipe_id, space_id)
          )
        ''');
        if (!hadRecipeSpaces) {
          await customStatement('''
            INSERT OR IGNORE INTO recipe_spaces (recipe_id, space_id, created_at, is_deleted)
            SELECT r.recipe_pk, r.group_id, CAST(strftime('%s', 'now') AS INTEGER), 0
            FROM recipes r JOIN groups g ON g.id = r.group_id
            WHERE r.group_id IS NOT NULL AND g.is_deleted = 0
          ''');
        }
        await repairRecipeSpaceTimestamps();
        await initializeDefaultDatabase(this);
      },
    );
  }

  /// Repairs early v2 junction tables whose raw SQL stored SQLite's formatted
  /// timestamp text instead of Drift's numeric Unix timestamp representation.
  Future<void> repairRecipeSpaceTimestamps() async {
    await customStatement('''
      UPDATE recipe_spaces
      SET created_at = CAST(strftime('%s', created_at) AS INTEGER)
      WHERE typeof(created_at) = 'text'
        AND strftime('%s', created_at) IS NOT NULL
    ''');
  }

  // --- Group Queries ---
  Future<List<Group>> getAllGroups({bool includeDeleted = false}) {
    final query = select(groups);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Stream<List<Group>> watchAllGroups({bool includeDeleted = false}) {
    final query = select(groups);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<Group?> getGroupById(String id) =>
      (select(groups)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(GroupsCompanion group) => into(groups).insert(group);

  Future<bool> updateGroup(Group group) => update(groups).replace(group);

  Future<void> mergeGroupFromRemote(Group remote) async {
    final local = await getGroupById(remote.id);
    if (local == null) {
      await into(groups).insertOnConflictUpdate(
        GroupsCompanion.insert(
          id: Value(remote.id),
          name: remote.name,
          iconName: Value(remote.iconName),
          colorHex: Value(remote.colorHex),
          isActive: Value(remote.isActive),
          createdAt: Value(remote.createdAt),
          updatedAt: Value(remote.updatedAt),
          isDeleted: Value(remote.isDeleted),
        ),
      );
    } else if (remote.updatedAt.isAfter(local.updatedAt)) {
      await transaction(() async {
        await update(groups).replace(remote);
        if (remote.isDeleted) {
          await (update(recipeSpaces)
                ..where((t) => t.spaceId.equals(remote.id)))
              .write(const RecipeSpacesCompanion(isDeleted: Value(true)));
        }
      });
    }
  }

  Future<int> softDeleteGroup(String id) async {
    return transaction(() async {
      await (update(recipeSpaces)..where((t) => t.spaceId.equals(id))).write(
        const RecipeSpacesCompanion(isDeleted: Value(true)),
      );
      return (update(groups)..where((t) => t.id.equals(id))).write(
        GroupsCompanion(
          isDeleted: const Value(true),
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // --- Category Queries ---
  Future<List<Category>> getAllCategories() => (select(
    categories,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Stream<List<Category>> watchAllCategories() => (select(
    categories,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  // --- Unit Queries ---
  Future<List<Unit>> getAllUnits() => select(units).get();
  Stream<List<Unit>> watchAllUnits() => select(units).watch();
  Future<int> insertUnit(UnitsCompanion unit) => into(units).insert(unit);
  Future<bool> updateUnit(Unit unit) => update(units).replace(unit);

  // --- Recipe Queries ---
  Future<List<Recipe>> getAllRecipes({
    String? groupId,
    String? spaceId,
    String? category,
  }) => getRecipes(spaceId: spaceId ?? groupId, category: category);

  Stream<List<Recipe>> watchAllRecipes({
    String? groupId,
    String? spaceId,
    String? category,
  }) => watchRecipes(spaceId: spaceId ?? groupId, category: category);

  Future<List<Recipe>> getRecipes({
    String? spaceId,
    String? category,
    String? searchQuery,
  }) async {
    final List<Recipe> rows;
    if (spaceId != null && spaceId.isNotEmpty) {
      rows =
          await (select(recipes).join([
                  innerJoin(
                    recipeSpaces,
                    recipeSpaces.recipeId.equalsExp(recipes.recipePk),
                  ),
                ])
                ..where(
                  recipeSpaces.spaceId.equals(spaceId) &
                      recipeSpaces.isDeleted.equals(false),
                )
                ..orderBy([OrderingTerm(expression: recipes.name)]))
              .map((row) => row.readTable(recipes))
              .get();
    } else {
      rows = await (select(
        recipes,
      )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
    }
    var filtered = rows;
    if (category != null && category.isNotEmpty) {
      filtered = filtered.where((r) => r.category == category).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      filtered = filtered
          .where(
            (r) =>
                r.name.toLowerCase().contains(searchQuery.trim().toLowerCase()),
          )
          .toList();
    }
    return filtered;
  }

  Stream<List<Recipe>> watchRecipes({
    String? groupId,
    String? spaceId,
    String? category,
    String? searchQuery,
  }) {
    final targetSpaceId = spaceId ?? groupId;
    if (targetSpaceId != null && targetSpaceId.isNotEmpty) {
      final query =
          select(recipes).join([
            innerJoin(
              recipeSpaces,
              recipeSpaces.recipeId.equalsExp(recipes.recipePk),
            ),
          ])..where(
            recipeSpaces.spaceId.equals(targetSpaceId) &
                recipeSpaces.isDeleted.equals(false),
          );
      return query.watch().map((rows) {
        var result = rows.map((row) => row.readTable(recipes)).toList();
        if (category != null && category.isNotEmpty) {
          result = result.where((r) => r.category == category).toList();
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          result = result
              .where(
                (r) => r.name.toLowerCase().contains(
                  searchQuery.trim().toLowerCase(),
                ),
              )
              .toList();
        }
        result.sort((a, b) => a.name.compareTo(b.name));
        return result;
      });
    }
    final query = select(recipes).join([
      leftOuterJoin(
        recipeSpaces,
        recipeSpaces.recipeId.equalsExp(recipes.recipePk),
      ),
    ]);
    return query.watch().map((rows) {
      final unique = <String, Recipe>{};
      for (final row in rows) {
        final recipe = row.readTable(recipes);
        if (category != null &&
            category.isNotEmpty &&
            recipe.category != category) {
          continue;
        }
        if (searchQuery != null &&
            searchQuery.trim().isNotEmpty &&
            !recipe.name.toLowerCase().contains(
              searchQuery.trim().toLowerCase(),
            )) {
          continue;
        }
        unique[recipe.recipePk] = recipe;
      }
      final result = unique.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return result;
    });
  }

  Future<void> setRecipeSpaces(
    String recipeId,
    List<String> spaceIds, {
    bool markModified = true,
  }) async {
    await transaction(() async {
      final available = (await getAllGroups()).map((g) => g.id).toSet();
      final selected = spaceIds.where(available.contains).toSet();
      final current = await (select(
        recipeSpaces,
      )..where((t) => t.recipeId.equals(recipeId))).get();
      for (final link in current) {
        await (update(recipeSpaces)..where(
              (t) =>
                  t.recipeId.equals(recipeId) & t.spaceId.equals(link.spaceId),
            ))
            .write(
              RecipeSpacesCompanion(
                isDeleted: Value(!selected.contains(link.spaceId)),
              ),
            );
      }
      final known = current.map((link) => link.spaceId).toSet();
      for (final id in selected.difference(known)) {
        await into(recipeSpaces).insert(
          RecipeSpacesCompanion.insert(
            recipeId: recipeId,
            spaceId: id,
            createdAt: Value(DateTime.now()),
          ),
        );
      }
      if (markModified) {
        await (update(recipes)..where((t) => t.recipePk.equals(recipeId)))
            .write(RecipesCompanion(dateTimeModified: Value(DateTime.now())));
      }
    });
  }

  Stream<List<Group>> watchSpacesForRecipe(String recipeId) {
    final query =
        select(groups).join([
          innerJoin(recipeSpaces, recipeSpaces.spaceId.equalsExp(groups.id)),
        ])..where(
          recipeSpaces.recipeId.equals(recipeId) &
              recipeSpaces.isDeleted.equals(false) &
              groups.isDeleted.equals(false),
        );
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(groups)).toList(),
    );
  }

  Stream<List<RecipeWithFinancials>> watchAllRecipesWithFinancials({
    String? groupId,
    String? spaceId,
    String? category,
  }) => watchRecipesWithFinancials(
    groupId: groupId,
    spaceId: spaceId,
    category: category,
  );

  Stream<List<RecipeWithFinancials>> watchRecipesWithFinancials({
    String? groupId,
    String? spaceId,
    String? category,
  }) {
    // Observe all inputs without restarting the subscription when ingredients
    // change. Read each complete feed from one consistent database snapshot.
    final changes = customSelect(
      'SELECT recipe_pk FROM recipes',
      readsFrom: {
        recipes,
        ingredients,
        recipeIngredients,
        recipeSteps,
        recipeSpaces,
        groups,
        units,
      },
    ).watch();
    return changes.asyncMap(
      (_) => transaction(() async {
        final recipeList = await getRecipes(
          spaceId: spaceId ?? groupId,
          category: category,
        );
        final List<RecipeWithFinancials> results = [];

        for (var recipe in recipeList) {
          final detail = await getRecipeDetail(recipe.recipePk);
          final financials = RecipeUtils.calculateSummaryFromDetail(detail);

          results.add(
            RecipeWithFinancials(
              recipe: detail.recipe,
              financials: financials,
              spaces: detail.spaces,
            ),
          );
        }

        return results;
      }),
    );
  }

  Future<int> insertRecipe(RecipesCompanion recipe) =>
      into(recipes).insert(recipe);
  Future<bool> updateRecipe(Recipe recipe) => update(recipes).replace(recipe);
  Future<int> deleteRecipe(Recipe recipe) => delete(recipes).delete(recipe);

  Future<void> duplicateRecipe(String sourcePk, String newName) async {
    final detail = await getRecipeDetail(sourcePk);
    final newPk = const Uuid().v4();
    await transaction(() async {
      await insertRecipe(
        RecipesCompanion(
          recipePk: Value(newPk),
          name: Value(newName),
          description: Value(detail.recipe.description ?? ''),
          defaultYield: Value(detail.recipe.defaultYield),
          yieldName: Value(detail.recipe.yieldName),
          targetProfitMargin: Value(detail.recipe.targetProfitMargin),
          targetPricePerPortion: Value(detail.recipe.targetPricePerPortion),
          colour: Value(detail.recipe.colour),
          groupId: Value(detail.recipe.groupId),
          category: Value(detail.recipe.category),
          dateTimeModified: Value(DateTime.now()),
        ),
      );
      for (final ing in detail.ingredients) {
        await into(recipeIngredients).insert(
          RecipeIngredientsCompanion.insert(
            recipeFk: newPk,
            ingredientFk: ing.ingredient.ingredientPk,
            amountNeeded: ing.entry.amountNeeded,
          ),
        );
      }
      for (int i = 0; i < detail.steps.length; i++) {
        await into(recipeSteps).insert(
          RecipeStepsCompanion.insert(
            recipeFk: newPk,
            stepNumber: detail.steps[i].stepNumber,
            instruction: detail.steps[i].instruction,
          ),
        );
      }
      await setRecipeSpaces(newPk, detail.spaceIds);
    });
  }

  // --- Ingredient Queries ---
  Future<List<Ingredient>> getAllIngredients({
    bool includeDeleted = false,
    String? groupId,
  }) {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    if (groupId != null && groupId.isNotEmpty) {
      query.where((t) => t.groupId.equals(groupId));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<Ingredient?> getIngredientById(
    String pk, {
    bool includeDeleted = false,
  }) async {
    final query = select(ingredients)..where((t) => t.ingredientPk.equals(pk));
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (await (query..limit(1)).get()).firstOrNull;
  }

  Stream<List<Ingredient>> watchAllIngredients({
    bool includeDeleted = false,
    String? groupId,
  }) {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    if (groupId != null && groupId.isNotEmpty) {
      query.where((t) => t.groupId.equals(groupId));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<int> insertIngredient(IngredientsCompanion ingredient) =>
      into(ingredients).insert(ingredient);

  Future<bool> updateIngredient(Ingredient ingredient) async {
    return transaction(() async {
      final old = await getIngredientById(
        ingredient.ingredientPk,
        includeDeleted: true,
      );
      if (old != null && old.unitFk != ingredient.unitFk) {
        final allUnits = await getAllUnits();
        final oldUnit = allUnits
            .where((u) => u.unitPk == old.unitFk)
            .firstOrNull;
        final newUnit = allUnits
            .where((u) => u.unitPk == ingredient.unitFk)
            .firstOrNull;
        if (oldUnit != null &&
            newUnit != null &&
            oldUnit.category != null &&
            oldUnit.category == newUnit.category &&
            oldUnit.factorToBase != newUnit.factorToBase) {
          final existingRecipeIngs =
              await (select(recipeIngredients)..where(
                    (t) => t.ingredientFk.equals(ingredient.ingredientPk),
                  ))
                  .get();
          for (final entry in existingRecipeIngs) {
            final base = entry.amountNeeded * oldUnit.factorToBase;
            final converted = double.parse(
              (base / newUnit.factorToBase).toStringAsFixed(6),
            );
            await (update(recipeIngredients)..where(
                  (t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk),
                ))
                .write(
                  RecipeIngredientsCompanion(amountNeeded: Value(converted)),
                );
          }
        }
      }
      return update(ingredients).replace(ingredient);
    });
  }

  Future<int> deleteIngredient(Ingredient ingredient) {
    final now = DateTime.now();
    return (update(
      ingredients,
    )..where((t) => t.ingredientPk.equals(ingredient.ingredientPk))).write(
      IngredientsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        dateTimeModified: Value(now),
      ),
    );
  }

  Future<int> restoreIngredient(String ingredientPk) {
    final now = DateTime.now();
    return (update(
      ingredients,
    )..where((t) => t.ingredientPk.equals(ingredientPk))).write(
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
    final terms = trimmedQuery
        .split(' ')
        .where((term) => term.length > 2)
        .toList();

    if (terms.isEmpty) {
      // fallback to simple contains
      return (select(ingredients)
            ..where(
              (t) => t.isDeleted.equals(false) & t.name.contains(trimmedQuery),
            )
            ..limit(5))
          .watch();
    }

    return (select(ingredients)..where((t) {
          final expressions = terms
              .map((term) => t.name.contains(term))
              .toList();
          return t.isDeleted.equals(false) &
              expressions.reduce((a, b) => a | b);
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
            if (nameA.startsWith(trimmedQuery) &&
                !nameB.startsWith(trimmedQuery)) {
              return -1;
            }
            if (nameB.startsWith(trimmedQuery) &&
                !nameA.startsWith(trimmedQuery)) {
              return 1;
            }

            // 3. Count matching terms
            int matchesA = terms.where((t) => nameA.contains(t)).length;
            int matchesB = terms.where((t) => nameB.contains(t)).length;
            if (matchesA != matchesB) return matchesB.compareTo(matchesA);

            // 4. Alphabetical fallback
            return nameA.compareTo(nameB);
          });
          return list
              .take(15)
              .toList(); // Return more results now that they are sorted
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
      if (oldIngredient.ingredientPk == newIngredient.ingredientPk) {
        throw ArgumentError('Cannot merge an ingredient into itself');
      }
      final source = await getIngredientById(oldIngredient.ingredientPk);
      final target = await getIngredientById(newIngredient.ingredientPk);
      if (source == null || target == null) {
        throw StateError('Both ingredients must still be active');
      }
      final sourceUnit = await (select(
        units,
      )..where((u) => u.unitPk.equals(source.unitFk))).getSingle();
      final targetUnit = await (select(
        units,
      )..where((u) => u.unitPk.equals(target.unitFk))).getSingle();
      final sameUnit = sourceUnit.unitPk == targetUnit.unitPk;
      if (!sameUnit &&
          (sourceUnit.category == null ||
              sourceUnit.category != targetUnit.category)) {
        throw ArgumentError(
          'Cannot merge incompatible units: ${sourceUnit.symbol} / ${targetUnit.symbol}',
        );
      }
      if (!sourceUnit.factorToBase.isFinite ||
          sourceUnit.factorToBase <= 0 ||
          !targetUnit.factorToBase.isFinite ||
          targetUnit.factorToBase <= 0) {
        throw ArgumentError('Invalid unit conversion factor');
      }
      final conversion = sameUnit
          ? 1.0
          : sourceUnit.factorToBase / targetUnit.factorToBase;
      final now = DateTime.now();
      final affected = <String>{};
      final recipeIngredientsToUpdate = await (select(
        recipeIngredients,
      )..where((t) => t.ingredientFk.equals(oldIngredient.ingredientPk))).get();

      for (final entry in recipeIngredientsToUpdate) {
        affected.add(entry.recipeFk);
        final convertedAmount = entry.amountNeeded * conversion;
        if (!convertedAmount.isFinite) {
          throw ArgumentError('Invalid ingredient quantity');
        }
        final existingNewEntry =
            (await (select(recipeIngredients)
                      ..where((t) => t.recipeFk.equals(entry.recipeFk))
                      ..where(
                        (t) =>
                            t.ingredientFk.equals(newIngredient.ingredientPk),
                      )
                      ..limit(1))
                    .get())
                .firstOrNull;

        if (existingNewEntry != null) {
          await (update(recipeIngredients)..where(
                (t) => t.recipeIngredientPk.equals(
                  existingNewEntry.recipeIngredientPk,
                ),
              ))
              .write(
                RecipeIngredientsCompanion(
                  amountNeeded: Value(
                    existingNewEntry.amountNeeded + convertedAmount,
                  ),
                  dateTimeModified: Value(now),
                ),
              );
          await (delete(recipeIngredients)..where(
                (t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk),
              ))
              .go();
        } else {
          await (update(recipeIngredients)..where(
                (t) => t.recipeIngredientPk.equals(entry.recipeIngredientPk),
              ))
              .write(
                RecipeIngredientsCompanion(
                  ingredientFk: Value(newIngredient.ingredientPk),
                  amountNeeded: Value(convertedAmount),
                  dateTimeModified: Value(now),
                ),
              );
        }
      }

      // 2. update recipesteps instructions
      final oldTag = '[${source.name}]';
      final newTag = '[${target.name}]';
      for (final step in await select(recipeSteps).get()) {
        if (!step.instruction.contains(oldTag)) continue;
        affected.add(step.recipeFk);
        await (update(
          recipeSteps,
        )..where((s) => s.stepPk.equals(step.stepPk))).write(
          RecipeStepsCompanion(
            instruction: Value(step.instruction.replaceAll(oldTag, newTag)),
            dateTimeModified: Value(now),
          ),
        );
      }
      for (final recipeId in affected) {
        await (update(recipes)..where((r) => r.recipePk.equals(recipeId)))
            .write(RecipesCompanion(dateTimeModified: Value(now)));
      }

      // 3. delete the old ingredient
      await deleteIngredient(source);
    });
  }

  Future<RecipeDetail> getRecipeDetail(String recipePk) async {
    final recipe =
        (await (select(recipes)
                  ..where((t) => t.recipePk.equals(recipePk))
                  ..limit(1))
                .get())
            .firstOrNull;

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
      final effectiveIng =
          ing ??
          Ingredient(
            ingredientPk: entry.ingredientFk,
            name: 'Unknown Ingredient',
            cost: 0.0,
            quantityForCost: 1.0,
            unitFk: 'unit-g',
            dateCreated: DateTime.now(),
            isDeleted: false,
          );
      validIngredients.add(
        RecipeIngredientWithData(entry: entry, ingredient: effectiveIng),
      );
    }

    return RecipeDetail(
      recipe: recipe,
      ingredients: validIngredients,
      steps: stepList,
      spaceIds: await getSpaceIdsForRecipe(recipePk),
      spaces: await getSpacesForRecipe(recipePk),
    );
  }

  Future<List<String>> getSpaceIdsForRecipe(String recipeId) async =>
      (await (select(recipeSpaces)..where(
                (t) => t.recipeId.equals(recipeId) & t.isDeleted.equals(false),
              ))
              .get())
          .map((link) => link.spaceId)
          .toList();

  Future<List<Group>> getSpacesForRecipe(String recipeId) async =>
      (await (select(groups).join([
                innerJoin(
                  recipeSpaces,
                  recipeSpaces.spaceId.equalsExp(groups.id),
                ),
              ])..where(
                recipeSpaces.recipeId.equals(recipeId) &
                    recipeSpaces.isDeleted.equals(false) &
                    groups.isDeleted.equals(false),
              ))
              .get())
          .map((row) => row.readTable(groups))
          .toList();

  Future<List<RecipeDetail>> getAllRecipeDetails({
    DateTime? modifiedSince,
  }) async {
    final query = select(recipes);
    if (modifiedSince != null) {
      query.where(
        (t) =>
            t.dateTimeModified.isBiggerOrEqualValue(modifiedSince) |
            t.dateCreated.isBiggerOrEqualValue(modifiedSince),
      );
    }
    final recipeList = await query.get();
    final List<RecipeDetail> details = [];
    for (final r in recipeList) {
      details.add(await getRecipeDetail(r.recipePk));
    }
    return details;
  }

  Future<List<Ingredient>> getIngredientsModifiedSince(
    DateTime? modifiedSince, {
    bool includeDeleted = false,
  }) async {
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    if (modifiedSince != null) {
      query.where(
        (t) =>
            t.dateTimeModified.isBiggerOrEqualValue(modifiedSince) |
            t.dateCreated.isBiggerOrEqualValue(modifiedSince) |
            t.deletedAt.isBiggerOrEqualValue(modifiedSince),
      );
    }
    return query.get();
  }

  Future<List<Unit>> getCustomUnitsModifiedSince(
    DateTime? modifiedSince,
  ) async {
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
    List<String> remoteSpaceIds = const [],
  }) async {
    return transaction(() async {
      final recipeUpdatedAt =
          remoteRecipe.dateTimeModified ?? remoteRecipe.dateCreated;

      // 1. Merge nested ingredients
      for (final ing in nestedIngredients) {
        await mergeIngredientFromRemote(ing);
      }

      // 2. Recipe Dependency Conflict Resolver pass
      final resolvedIngredients = <RecipeIngredient>[];

      for (final ri in remoteIngredients) {
        final localIng = await getIngredientById(
          ri.ingredientFk,
          includeDeleted: true,
        );

        if (localIng != null && localIng.isDeleted) {
          // Keep the missing dependency visible; editing a recipe is not restoration.
          resolvedIngredients.add(ri);
        } else if (localIng == null) {
          // Case 3 (Missing / Ambiguous): Prefer data safety
          final nested = nestedIngredients
              .where((n) => n.ingredientPk == ri.ingredientFk)
              .firstOrNull;
          if (nested != null) {
            await mergeIngredientFromRemote(nested);
            resolvedIngredients.add(ri);
          } else {
            final fallbackUnit = (await (select(
              units,
            )..limit(1)).get()).firstOrNull;
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
                  currentStock: const Value(0.0),
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
      final localRecipe =
          (await (select(recipes)
                    ..where((t) => t.recipePk.equals(remoteRecipe.recipePk))
                    ..limit(1))
                  .get())
              .firstOrNull;

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
            groupId: Value(remoteRecipe.groupId),
            category: Value(remoteRecipe.category),
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

        await setRecipeSpaces(
          remoteRecipe.recipePk,
          remoteSpaceIds,
          markModified: false,
        );

        return 1;
      } else {
        final localUpdatedAt =
            localRecipe.dateTimeModified ?? localRecipe.dateCreated;

        if (recipeUpdatedAt.isAfter(localUpdatedAt)) {
          await (update(
            recipes,
          )..where((t) => t.recipePk.equals(localRecipe.recipePk))).write(
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
              groupId: Value(remoteRecipe.groupId),
              category: Value(remoteRecipe.category),
            ),
          );

          await (delete(
            recipeIngredients,
          )..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
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

          await (delete(
            recipeSteps,
          )..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
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

          await setRecipeSpaces(
            localRecipe.recipePk,
            remoteSpaceIds,
            markModified: false,
          );

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
    final unitExists =
        (await (select(units)
                  ..where((t) => t.unitPk.equals(targetUnitFk))
                  ..limit(1))
                .get())
            .firstOrNull;
    if (unitExists == null) {
      final defaultUnit =
          (await (select(units)
                    ..where(
                      (t) => t.symbol.equals('g') | t.name.equals('unit_grams'),
                    )
                    ..limit(1))
                  .get())
              .firstOrNull ??
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

    final localIng = await getIngredientById(
      remoteIngredient.ingredientPk,
      includeDeleted: true,
    );
    final remoteTime =
        remoteIngredient.dateTimeModified ?? remoteIngredient.dateCreated;

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
          groupId: Value(remoteIngredient.groupId),
          category: Value(remoteIngredient.category),
          currentStock: Value(remoteIngredient.currentStock),
          minimumStock: Value(remoteIngredient.minimumStock),
          stockUnit: Value(remoteIngredient.stockUnit),
          costPerStockUnit: Value(remoteIngredient.costPerStockUnit),
          lastStockUpdate: Value(remoteIngredient.lastStockUpdate),
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
          await (update(
            ingredients,
          )..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
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
          await (update(
            ingredients,
          )..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              name: Value(remoteIngredient.name),
              cost: Value(remoteIngredient.cost),
              quantityForCost: Value(remoteIngredient.quantityForCost),
              unitFk: Value(targetUnitFk),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              dateTimeModified: Value(remoteTime),
              groupId: Value(remoteIngredient.groupId),
              category: Value(remoteIngredient.category),
              currentStock: Value(remoteIngredient.currentStock),
              minimumStock: Value(remoteIngredient.minimumStock),
              stockUnit: Value(remoteIngredient.stockUnit),
              costPerStockUnit: Value(remoteIngredient.costPerStockUnit),
              lastStockUpdate: Value(remoteIngredient.lastStockUpdate),
            ),
          );
          return 2;
        }
      }
    } else {
      if (remoteIngredient.isDeleted) {
        // Firestore sends is_deleted: true, apply to Drift
        final remoteDeletedAt = remoteIngredient.deletedAt ?? remoteTime;
        if (remoteDeletedAt.isAfter(localTime) ||
            remoteDeletedAt.isAtSameMomentAs(localTime)) {
          await (update(
            ingredients,
          )..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
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
          await (update(
            ingredients,
          )..where((t) => t.ingredientPk.equals(localIng.ingredientPk))).write(
            IngredientsCompanion(
              name: Value(remoteIngredient.name),
              cost: Value(remoteIngredient.cost),
              quantityForCost: Value(remoteIngredient.quantityForCost),
              unitFk: Value(targetUnitFk),
              dateTimeModified: Value(
                remoteIngredient.dateTimeModified ??
                    remoteIngredient.dateCreated,
              ),
              groupId: Value(remoteIngredient.groupId),
              category: Value(remoteIngredient.category),
              currentStock: Value(remoteIngredient.currentStock),
              minimumStock: Value(remoteIngredient.minimumStock),
              stockUnit: Value(remoteIngredient.stockUnit),
              costPerStockUnit: Value(remoteIngredient.costPerStockUnit),
              lastStockUpdate: Value(remoteIngredient.lastStockUpdate),
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
    final localUnit =
        (await (select(units)
                  ..where((t) => t.unitPk.equals(remoteUnit.unitPk))
                  ..limit(1))
                .get())
            .firstOrNull;
    if (localUnit != null) return;

    final normName = remoteUnit.name == 'unit_spoonfuls'
        ? 'unit_tablespoons'
        : remoteUnit.name;
    final unitByName =
        (await (select(units)
                  ..where((t) => t.name.equals(normName))
                  ..limit(1))
                .get())
            .firstOrNull;

    if (unitByName != null) {
      await (update(ingredients)
            ..where((t) => t.unitFk.equals(remoteUnit.unitPk)))
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
    final remoteIngredients = await remoteDb.getAllIngredients(
      includeDeleted: true,
    );
    final remoteRecipes = await remoteDb.getAllRecipes();
    final allRemoteRecipeIngredients = await (remoteDb.select(
      remoteDb.recipeIngredients,
    )).get();
    final allRemoteRecipeSteps = await (remoteDb.select(
      remoteDb.recipeSteps,
    )).get();

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
        final normName = ru.name == 'unit_spoonfuls'
            ? 'unit_tablespoons'
            : ru.name;
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
                await (update(ingredients)..where(
                      (t) => t.ingredientPk.equals(localIng.ingredientPk),
                    ))
                    .write(
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
                await (update(ingredients)..where(
                      (t) => t.ingredientPk.equals(localIng.ingredientPk),
                    ))
                    .write(
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
              if (remoteDeletedAt.isAfter(localTime) ||
                  remoteDeletedAt.isAtSameMomentAs(localTime)) {
                await (update(ingredients)..where(
                      (t) => t.ingredientPk.equals(localIng.ingredientPk),
                    ))
                    .write(
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
                await (update(ingredients)..where(
                      (t) => t.ingredientPk.equals(localIng.ingredientPk),
                    ))
                    .write(
                      IngredientsCompanion(
                        name: Value(ri.name),
                        cost: Value(ri.cost),
                        quantityForCost: Value(ri.quantityForCost),
                        unitFk: Value(effectiveUnitFk),
                        dateTimeModified: Value(
                          ri.dateTimeModified ?? ri.dateCreated,
                        ),
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
        final recipeUpdatedAt =
            remoteRecipe.dateTimeModified ?? remoteRecipe.dateCreated;

        // Resolve recipe ingredients against deleted ingredients
        final rawIngs = remoteIngsByRecipe[remoteRecipe.recipePk] ?? [];
        final resolvedIngs = <RecipeIngredient>[];

        for (final ri in rawIngs) {
          final localIng = await getIngredientById(
            ri.ingredientFk,
            includeDeleted: true,
          );
          if (localIng != null && localIng.isDeleted) {
            resolvedIngs.add(ri);
          } else if (localIng == null) {
            final fallbackUnit = (await (select(
              units,
            )..limit(1)).get()).firstOrNull;
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
            await (update(
              recipes,
            )..where((t) => t.recipePk.equals(localRecipe.recipePk))).write(
              RecipesCompanion(
                name: Value(remoteRecipe.name),
                description: Value(remoteRecipe.description),
                defaultYield: Value(remoteRecipe.defaultYield),
                yieldName: Value(remoteRecipe.yieldName),
                targetProfitMargin: Value(remoteRecipe.targetProfitMargin),
                targetPricePerPortion: Value(
                  remoteRecipe.targetPricePerPortion,
                ),
                fixedOverheadCost: Value(remoteRecipe.fixedOverheadCost),
                colour: Value(remoteRecipe.colour),
                dateTimeModified: Value(remoteRecipe.dateTimeModified),
                archived: Value(remoteRecipe.archived),
              ),
            );

            // Replace recipe ingredients with remote's
            await (delete(
              recipeIngredients,
            )..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
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
            await (delete(
              recipeSteps,
            )..where((t) => t.recipeFk.equals(localRecipe.recipePk))).go();
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
  final List<Group> spaces;

  RecipeWithFinancials({
    required this.recipe,
    required this.financials,
    this.spaces = const [],
  });
}

class RecipeDetail {
  final Recipe recipe;
  final List<RecipeIngredientWithData> ingredients;
  final List<RecipeStep> steps;
  final List<String> spaceIds;
  final List<Group> spaces;

  RecipeDetail({
    required this.recipe,
    required this.ingredients,
    required this.steps,
    this.spaceIds = const [],
    this.spaces = const [],
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
