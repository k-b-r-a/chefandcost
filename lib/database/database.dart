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
    DeletedRecords,
    RecipeProductions,
    InventoryMovements,
    RecipeInventoryMovements,
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
  int get schemaVersion => 3;

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
          if (!await _tableExists('deleted_records')) {
            await m.createTable(deletedRecords);
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
        if (from < 3) {
          if (!await _tableExists('recipe_productions')) {
            await m.createTable(recipeProductions);
          }
          if (!await _tableExists('inventory_movements')) {
            await m.createTable(inventoryMovements);
          }
          if (!await _tableExists('recipe_inventory_movements')) {
            await m.createTable(recipeInventoryMovements);
          }
          if (!await _columnExists('recipes', 'current_stock')) {
            await m.addColumn(recipes, recipes.currentStock);
          }
          if (!await _columnExists('recipes', 'minimum_stock')) {
            await m.addColumn(recipes, recipes.minimumStock);
          }
          if (!await _columnExists('recipes', 'last_stock_update')) {
            await m.addColumn(recipes, recipes.lastStockUpdate);
          }
        }
      },
      beforeOpen: (details) async {
        // Repair databases already stamped at v2/v3 that are missing tables.
        // Drift only calls onUpgrade when the stored schema version is older.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS deleted_records (
            record_pk TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            deleted_at INTEGER NOT NULL,
            PRIMARY KEY (record_pk, entity_type)
          )
        ''');
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
        await customStatement('''
          CREATE TABLE IF NOT EXISTS recipe_productions (
            production_pk TEXT NOT NULL PRIMARY KEY,
            recipe_fk TEXT NOT NULL,
            recipe_name_snapshot TEXT NOT NULL,
            category_snapshot TEXT,
            space_id TEXT,
            multiplier REAL NOT NULL DEFAULT 1.0,
            portions_produced REAL NOT NULL,
            yield_name_snapshot TEXT NOT NULL,
            total_cost_snapshot REAL NOT NULL,
            unit_price_snapshot REAL NOT NULL,
            total_revenue_snapshot REAL NOT NULL,
            total_profit_snapshot REAL NOT NULL,
            notes TEXT,
            produced_at INTEGER NOT NULL,
            is_reverted INTEGER NOT NULL DEFAULT 0,
            reverted_at INTEGER
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS inventory_movements (
            movement_pk TEXT NOT NULL PRIMARY KEY,
            ingredient_fk TEXT NOT NULL,
            ingredient_name_snapshot TEXT NOT NULL,
            group_id TEXT,
            movement_type TEXT NOT NULL,
            recipe_production_fk TEXT,
            recipe_fk TEXT,
            previous_stock REAL NOT NULL,
            delta_stock REAL NOT NULL,
            new_stock REAL NOT NULL,
            stock_unit_pk TEXT,
            unit_cost_in_stock_unit_snapshot REAL NOT NULL,
            total_value_delta_snapshot REAL NOT NULL,
            reason TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_recipe_productions_produced_at ON recipe_productions(produced_at);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_recipe_productions_recipe_fk ON recipe_productions(recipe_fk, produced_at);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_inventory_movements_ing_created ON inventory_movements(ingredient_fk, created_at);',
        );
        if (!await _columnExists('recipes', 'current_stock')) {
          await customStatement(
            'ALTER TABLE recipes ADD COLUMN current_stock REAL DEFAULT 0.0;',
          );
        }
        if (!await _columnExists('recipes', 'minimum_stock')) {
          await customStatement(
            'ALTER TABLE recipes ADD COLUMN minimum_stock REAL;',
          );
        }
        if (!await _columnExists('recipes', 'last_stock_update')) {
          await customStatement(
            'ALTER TABLE recipes ADD COLUMN last_stock_update INTEGER;',
          );
        }
        await customStatement('''
          CREATE TABLE IF NOT EXISTS recipe_inventory_movements (
            movement_pk TEXT NOT NULL PRIMARY KEY,
            recipe_fk TEXT NOT NULL,
            recipe_name_snapshot TEXT NOT NULL,
            space_id TEXT,
            movement_type TEXT NOT NULL,
            recipe_production_fk TEXT,
            previous_stock REAL NOT NULL,
            delta_stock REAL NOT NULL,
            new_stock REAL NOT NULL,
            unit_cost_snapshot REAL NOT NULL,
            unit_price_snapshot REAL NOT NULL,
            total_cost_delta_snapshot REAL NOT NULL,
            total_revenue_delta_snapshot REAL NOT NULL,
            reason TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_recipe_inv_movements_rec_created ON recipe_inventory_movements(recipe_fk, created_at);',
        );
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

  Future<int> insertRecipe(RecipesCompanion recipe) {
    final now = DateTime.now();
    final withTime = recipe.dateTimeModified.present
        ? recipe
        : recipe.copyWith(dateTimeModified: Value(now));
    return into(recipes).insert(withTime);
  }

  Future<bool> updateRecipe(Recipe recipe) {
    final updated = recipe.copyWith(dateTimeModified: Value(DateTime.now()));
    return update(recipes).replace(updated);
  }

  Future<int> deleteRecipe(Recipe recipe, {bool recordTombstone = true}) =>
      deleteRecipeById(recipe.recipePk, recordTombstone: recordTombstone);

  Future<int> deleteRecipeById(
    String recipePk, {
    bool recordTombstone = true,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      if (recordTombstone) {
        await into(deletedRecords).insert(
          DeletedRecordsCompanion(
            recordPk: Value(recipePk),
            entityType: const Value('recipes'),
            deletedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      final steps = await (select(recipeSteps)
            ..where((t) => t.recipeFk.equals(recipePk)))
          .get();
      for (final s in steps) {
        if (recordTombstone) {
          await into(deletedRecords).insert(
            DeletedRecordsCompanion(
              recordPk: Value(s.stepPk),
              entityType: const Value('recipe_steps'),
              deletedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      await (delete(recipeSteps)..where((t) => t.recipeFk.equals(recipePk)))
          .go();

      final ings = await (select(recipeIngredients)
            ..where((t) => t.recipeFk.equals(recipePk)))
          .get();
      for (final ri in ings) {
        if (recordTombstone) {
          await into(deletedRecords).insert(
            DeletedRecordsCompanion(
              recordPk: Value(ri.recipeIngredientPk),
              entityType: const Value('recipe_ingredients'),
              deletedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      await (delete(recipeIngredients)
            ..where((t) => t.recipeFk.equals(recipePk)))
          .go();

      return await (delete(recipes)
            ..where((t) => t.recipePk.equals(recipePk)))
          .go();
    });
  }

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
    if (groupId != null && groupId.isNotEmpty) {
      final delFilter = includeDeleted ? '' : 'AND i.is_deleted = 0';
      return customSelect(
        '''
        SELECT DISTINCT i.* FROM ingredients i
        LEFT JOIN recipe_ingredients ri ON ri.ingredient_fk = i.ingredient_pk
        LEFT JOIN recipe_spaces rs ON rs.recipe_id = ri.recipe_fk AND rs.is_deleted = 0
        WHERE (i.group_id = ?1 OR rs.space_id = ?1) $delFilter
        ORDER BY i.name ASC
        ''',
        variables: [Variable.withString(groupId)],
        readsFrom: {ingredients, recipeIngredients, recipeSpaces},
      ).watch().map((rows) => rows.map((r) => ingredients.map(r.data)).toList());
    }
    final query = select(ingredients);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<int> insertIngredient(IngredientsCompanion ingredient) {
    final now = DateTime.now();
    final withTime = ingredient.dateTimeModified.present
        ? ingredient
        : ingredient.copyWith(dateTimeModified: Value(now));
    return into(ingredients).insert(withTime);
  }

  double _computeUnitCostInStockUnit(
    Ingredient ing,
    Unit? ingUnit,
    Unit? stockUnit,
  ) {
    if (ing.quantityForCost <= 0 || !ing.cost.isFinite) return 0.0;
    final costPerIngUnit = ing.cost / ing.quantityForCost;
    if (ingUnit != null &&
        stockUnit != null &&
        ingUnit.category != null &&
        ingUnit.category == stockUnit.category &&
        ingUnit.factorToBase.isFinite &&
        ingUnit.factorToBase > 0 &&
        stockUnit.factorToBase.isFinite &&
        stockUnit.factorToBase > 0) {
      return costPerIngUnit * (stockUnit.factorToBase / ingUnit.factorToBase);
    }
    return costPerIngUnit;
  }

  Future<void> updateIngredientStock({
    required String ingredientPk,
    double? currentStock,
    double? minimumStock,
    String? stockUnit,
    double? costPerStockUnit,
    double? cost,
    double? quantityForCost,
    String movementType = 'exact_adjustment',
    String? reason,
  }) async {
    await transaction(() async {
      final existing = await getIngredientById(
        ingredientPk,
        includeDeleted: true,
      );
      final now = DateTime.now();
      final clampedStock = currentStock != null
          ? (currentStock < 0 ? 0.0 : currentStock)
          : null;
      await (update(
        ingredients,
      )..where((t) => t.ingredientPk.equals(ingredientPk))).write(
        IngredientsCompanion(
          currentStock: clampedStock != null
              ? Value(clampedStock)
              : const Value.absent(),
          minimumStock: minimumStock != null
              ? Value(minimumStock)
              : const Value.absent(),
          stockUnit: stockUnit != null
              ? Value(stockUnit)
              : const Value.absent(),
          costPerStockUnit: costPerStockUnit != null
              ? Value(costPerStockUnit)
              : const Value.absent(),
          cost: cost != null ? Value(cost) : const Value.absent(),
          quantityForCost: quantityForCost != null
              ? Value(quantityForCost)
              : const Value.absent(),
          lastStockUpdate: Value(now),
          dateTimeModified: Value(now),
        ),
      );

      if (existing != null && clampedStock != null) {
        final previous = existing.currentStock ?? 0.0;
        final delta = clampedStock - previous;
        if (delta.abs() > 1e-9) {
          final allUnits = await getAllUnits();
          final unitMap = {for (final u in allUnits) u.unitPk: u};
          final effectiveIng = existing.copyWith(
            cost: cost ?? existing.cost,
            quantityForCost: quantityForCost ?? existing.quantityForCost,
            stockUnit: Value(stockUnit ?? existing.stockUnit),
          );
          final ingUnit = unitMap[effectiveIng.unitFk];
          final effStockUnitPk = effectiveIng.stockUnit ?? effectiveIng.unitFk;
          final effStockUnit = unitMap[effStockUnitPk];
          final unitCostInStock = _computeUnitCostInStockUnit(
            effectiveIng,
            ingUnit,
            effStockUnit,
          );
          await into(inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              ingredientFk: existing.ingredientPk,
              ingredientNameSnapshot: existing.name,
              groupId: Value(existing.groupId),
              movementType: movementType,
              previousStock: previous,
              deltaStock: delta,
              newStock: clampedStock,
              stockUnitPk: Value(effStockUnitPk),
              unitCostInStockUnitSnapshot: unitCostInStock,
              totalValueDeltaSnapshot: delta * unitCostInStock,
              reason: Value(reason),
              createdAt: Value(now),
            ),
          );
        }
      }
    });
  }

  Future<void> deductRecipeFromInventory({
    required String recipePk,
    double multiplier = 1.0,
  }) async {
    await executeRecipeProduction(
      recipePk: recipePk,
      multiplier: multiplier,
    );
  }

  Future<RecipeProductionResult> executeRecipeProduction({
    required String recipePk,
    double multiplier = 1.0,
    double? customPortions,
    Map<String, double>? ingredientAmountOverrides,
    Set<String>? excludedIngredientPks,
    String? spaceId,
    String? notes,
  }) async {
    return transaction(() async {
      final detail = await getRecipeDetail(recipePk);
      final recipe = detail.recipe;
      final allUnits = await getAllUnits();
      final unitMap = {for (final u in allUnits) u.unitPk: u};
      final now = DateTime.now();
      final productionPk = const Uuid().v4();
      final portionsProduced =
          customPortions ?? (recipe.defaultYield * multiplier);

      double totalCost = 0.0;
      final deductedItems = <ProducedIngredientDeduction>[];
      final lowStockAlerts = <String>[];

      for (final item in detail.ingredients) {
        final ing = item.ingredient;
        if (ing.isDeleted) continue;
        if (excludedIngredientPks != null &&
            excludedIngredientPks.contains(ing.ingredientPk)) {
          continue;
        }

        final ingUnit = unitMap[ing.unitFk];
        final stockUnitPk = ing.stockUnit ?? ing.unitFk;
        final stockUnit =
            allUnits
                .where((u) => u.unitPk == stockUnitPk || u.symbol == stockUnitPk)
                .firstOrNull ??
            ingUnit;

        final baseAmount =
            ingredientAmountOverrides?[ing.ingredientPk] ??
            (item.entry.amountNeeded * multiplier);

        double deductAmount = baseAmount;
        if (ingUnit != null &&
            stockUnit != null &&
            ingUnit.category != null &&
            ingUnit.category == stockUnit.category &&
            ingUnit.factorToBase.isFinite &&
            ingUnit.factorToBase > 0 &&
            stockUnit.factorToBase.isFinite &&
            stockUnit.factorToBase > 0) {
          deductAmount =
              baseAmount * (ingUnit.factorToBase / stockUnit.factorToBase);
        }

        final unitCostInStock = _computeUnitCostInStockUnit(
          ing,
          ingUnit,
          stockUnit,
        );
        final itemCost = deductAmount * unitCostInStock;
        totalCost += itemCost;

        final previous = ing.currentStock ?? 0.0;
        final nextStock = (previous - deductAmount) < 0
            ? 0.0
            : (previous - deductAmount);
        final actualDelta = nextStock - previous;

        await (update(
          ingredients,
        )..where((t) => t.ingredientPk.equals(ing.ingredientPk))).write(
          IngredientsCompanion(
            currentStock: Value(nextStock),
            lastStockUpdate: Value(now),
            dateTimeModified: Value(now),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion.insert(
            ingredientFk: ing.ingredientPk,
            ingredientNameSnapshot: ing.name,
            groupId: Value(ing.groupId ?? spaceId),
            movementType: 'recipe_production',
            recipeProductionFk: Value(productionPk),
            recipeFk: Value(recipe.recipePk),
            previousStock: previous,
            deltaStock: actualDelta,
            newStock: nextStock,
            stockUnitPk: Value(stockUnit?.unitPk ?? stockUnitPk),
            unitCostInStockUnitSnapshot: unitCostInStock,
            totalValueDeltaSnapshot: actualDelta * unitCostInStock,
            reason: Value(recipe.name),
            createdAt: Value(now),
          ),
        );

        if (ing.minimumStock != null &&
            nextStock <= ing.minimumStock! &&
            previous > ing.minimumStock!) {
          lowStockAlerts.add(ing.name);
        }

        deductedItems.add(
          ProducedIngredientDeduction(
            ingredientPk: ing.ingredientPk,
            name: ing.name,
            previousStock: previous,
            deductedAmount: deductAmount,
            newStock: nextStock,
            unitSymbol: stockUnit?.symbol ?? ingUnit?.symbol ?? '',
          ),
        );
      }

      final unitPrice = recipe.targetPricePerPortion;
      final totalRevenue = unitPrice * portionsProduced;
      final totalProfit = totalRevenue - totalCost;

      await into(recipeProductions).insert(
        RecipeProductionsCompanion.insert(
          productionPk: Value(productionPk),
          recipeFk: recipe.recipePk,
          recipeNameSnapshot: recipe.name,
          categorySnapshot: Value(recipe.category),
          spaceId: Value(spaceId ?? recipe.groupId),
          multiplier: Value(multiplier),
          portionsProduced: portionsProduced,
          yieldNameSnapshot: recipe.yieldName,
          totalCostSnapshot: totalCost,
          unitPriceSnapshot: unitPrice,
          totalRevenueSnapshot: totalRevenue,
          totalProfitSnapshot: totalProfit,
          notes: Value(notes),
          producedAt: Value(now),
        ),
      );

      // Increment prepared recipe stock (+multiplier, e.g. 1x Tarta = +1)
      final prevRecipeStock = recipe.currentStock ?? 0.0;
      final nextRecipeStock = prevRecipeStock + multiplier;
      await (update(
        recipes,
      )..where((t) => t.recipePk.equals(recipe.recipePk))).write(
        RecipesCompanion(
          currentStock: Value(nextRecipeStock),
          lastStockUpdate: Value(now),
          dateTimeModified: Value(now),
        ),
      );

      await into(recipeInventoryMovements).insert(
        RecipeInventoryMovementsCompanion.insert(
          recipeFk: recipe.recipePk,
          recipeNameSnapshot: recipe.name,
          spaceId: Value(spaceId ?? recipe.groupId),
          movementType: 'recipe_production',
          recipeProductionFk: Value(productionPk),
          previousStock: prevRecipeStock,
          deltaStock: multiplier,
          newStock: nextRecipeStock,
          unitCostSnapshot: multiplier > 0 ? totalCost / multiplier : 0.0,
          unitPriceSnapshot: multiplier > 0 ? totalRevenue / multiplier : 0.0,
          totalCostDeltaSnapshot: totalCost,
          totalRevenueDeltaSnapshot: totalRevenue,
          reason: Value(recipe.name),
          createdAt: Value(now),
        ),
      );

      return RecipeProductionResult(
        productionPk: productionPk,
        recipePk: recipe.recipePk,
        recipeName: recipe.name,
        multiplier: multiplier,
        portionsProduced: portionsProduced,
        totalCost: totalCost,
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        deductedItems: deductedItems,
        lowStockAlerts: lowStockAlerts,
      );
    });
  }

  Future<void> revertRecipeProduction(String productionPk) async {
    await transaction(() async {
      final prod =
          (await (select(recipeProductions)
                    ..where((t) => t.productionPk.equals(productionPk))
                    ..limit(1))
                  .get())
              .firstOrNull;
      if (prod == null || prod.isReverted) return;

      final now = DateTime.now();
      final movements =
          await (select(inventoryMovements)..where(
                (t) =>
                    t.recipeProductionFk.equals(productionPk) &
                    t.movementType.equals('recipe_production'),
              ))
              .get();

      for (final mov in movements) {
        final ing = await getIngredientById(
          mov.ingredientFk,
          includeDeleted: true,
        );
        if (ing == null) continue;
        final previous = ing.currentStock ?? 0.0;
        final restoreDelta = -mov.deltaStock; // deltaStock was negative
        final nextStock = (previous + restoreDelta) < 0
            ? 0.0
            : (previous + restoreDelta);

        await (update(
          ingredients,
        )..where((t) => t.ingredientPk.equals(ing.ingredientPk))).write(
          IngredientsCompanion(
            currentStock: Value(nextStock),
            lastStockUpdate: Value(now),
            dateTimeModified: Value(now),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion.insert(
            ingredientFk: ing.ingredientPk,
            ingredientNameSnapshot: ing.name,
            groupId: Value(mov.groupId),
            movementType: 'revert',
            recipeProductionFk: Value(productionPk),
            recipeFk: Value(mov.recipeFk),
            previousStock: previous,
            deltaStock: nextStock - previous,
            newStock: nextStock,
            stockUnitPk: Value(mov.stockUnitPk),
            unitCostInStockUnitSnapshot: mov.unitCostInStockUnitSnapshot,
            totalValueDeltaSnapshot:
                (nextStock - previous) * mov.unitCostInStockUnitSnapshot,
            reason: Value('Revert: ${prod.recipeNameSnapshot}'),
            createdAt: Value(now),
          ),
        );
      }

      // Revert prepared recipe stock
      final recipeRow =
          (await (select(recipes)
                    ..where((t) => t.recipePk.equals(prod.recipeFk))
                    ..limit(1))
                  .get())
              .firstOrNull;
      if (recipeRow != null) {
        final prevRecStock = recipeRow.currentStock ?? 0.0;
        final nextRecStock = (prevRecStock - prod.multiplier) < 0
            ? 0.0
            : (prevRecStock - prod.multiplier);
        await (update(
          recipes,
        )..where((t) => t.recipePk.equals(recipeRow.recipePk))).write(
          RecipesCompanion(
            currentStock: Value(nextRecStock),
            lastStockUpdate: Value(now),
            dateTimeModified: Value(now),
          ),
        );
        await into(recipeInventoryMovements).insert(
          RecipeInventoryMovementsCompanion.insert(
            recipeFk: recipeRow.recipePk,
            recipeNameSnapshot: recipeRow.name,
            spaceId: Value(prod.spaceId),
            movementType: 'revert',
            recipeProductionFk: Value(productionPk),
            previousStock: prevRecStock,
            deltaStock: nextRecStock - prevRecStock,
            newStock: nextRecStock,
            unitCostSnapshot: prod.multiplier > 0
                ? prod.totalCostSnapshot / prod.multiplier
                : 0.0,
            unitPriceSnapshot: prod.multiplier > 0
                ? prod.totalRevenueSnapshot / prod.multiplier
                : 0.0,
            totalCostDeltaSnapshot: -prod.totalCostSnapshot,
            totalRevenueDeltaSnapshot: -prod.totalRevenueSnapshot,
            reason: Value('Revert: ${prod.recipeNameSnapshot}'),
            createdAt: Value(now),
          ),
        );
      }

      await (update(
        recipeProductions,
      )..where((t) => t.productionPk.equals(productionPk))).write(
        RecipeProductionsCompanion(
          isReverted: const Value(true),
          revertedAt: Value(now),
        ),
      );
    });
  }

  Stream<List<RecipeProduction>> watchRecipeProductions({
    DateTime? from,
    DateTime? to,
    String? spaceId,
    String? recipePk,
    bool includeReverted = false,
    int? limit,
  }) {
    final query = select(recipeProductions);
    if (!includeReverted) {
      query.where((t) => t.isReverted.equals(false));
    }
    if (from != null) {
      query.where((t) => t.producedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.producedAt.isSmallerOrEqualValue(to));
    }
    if (spaceId != null && spaceId.isNotEmpty) {
      query.where((t) => t.spaceId.equals(spaceId));
    }
    if (recipePk != null && recipePk.isNotEmpty) {
      query.where((t) => t.recipeFk.equals(recipePk));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.producedAt, mode: OrderingMode.desc),
    ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  Stream<List<InventoryMovement>> watchInventoryMovements({
    String? ingredientPk,
    String? movementType,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final query = select(inventoryMovements);
    if (ingredientPk != null && ingredientPk.isNotEmpty) {
      query.where((t) => t.ingredientFk.equals(ingredientPk));
    }
    if (movementType != null && movementType.isNotEmpty) {
      query.where((t) => t.movementType.equals(movementType));
    }
    if (from != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.createdAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  Future<void> updateRecipeStock({
    required String recipePk,
    double? currentStock,
    double? minimumStock,
    String movementType = 'exact_adjustment',
    String? reason,
    double unitCostSnapshot = 0.0,
    double unitPriceSnapshot = 0.0,
    String? spaceId,
  }) async {
    await transaction(() async {
      final existing =
          (await (select(recipes)
                    ..where((t) => t.recipePk.equals(recipePk))
                    ..limit(1))
                  .get())
              .firstOrNull;
      final now = DateTime.now();
      final clampedStock = currentStock != null
          ? (currentStock < 0 ? 0.0 : currentStock)
          : null;
      await (update(recipes)..where((t) => t.recipePk.equals(recipePk))).write(
        RecipesCompanion(
          currentStock: clampedStock != null
              ? Value(clampedStock)
              : const Value.absent(),
          minimumStock: minimumStock != null
              ? Value(minimumStock)
              : const Value.absent(),
          lastStockUpdate: Value(now),
          dateTimeModified: Value(now),
        ),
      );

      if (existing != null && clampedStock != null) {
        final previous = existing.currentStock ?? 0.0;
        final delta = clampedStock - previous;
        if (delta.abs() > 1e-9) {
          await into(recipeInventoryMovements).insert(
            RecipeInventoryMovementsCompanion.insert(
              recipeFk: existing.recipePk,
              recipeNameSnapshot: existing.name,
              spaceId: Value(spaceId ?? existing.groupId),
              movementType: movementType,
              previousStock: previous,
              deltaStock: delta,
              newStock: clampedStock,
              unitCostSnapshot: unitCostSnapshot,
              unitPriceSnapshot: unitPriceSnapshot,
              totalCostDeltaSnapshot: delta * unitCostSnapshot,
              totalRevenueDeltaSnapshot: delta * unitPriceSnapshot,
              reason: Value(reason ?? existing.name),
              createdAt: Value(now),
            ),
          );
        }
      }
    });
  }

  Stream<List<RecipeInventoryMovement>> watchRecipeInventoryMovements({
    String? recipePk,
    int? limit,
  }) {
    final query = select(recipeInventoryMovements);
    if (recipePk != null && recipePk.isNotEmpty) {
      query.where((t) => t.recipeFk.equals(recipePk));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  Future<ProductionStatisticsSummary> getProductionStatisticsSummary({
    required DateTime from,
    required DateTime to,
    String? spaceId,
  }) async {
    final prodQuery = select(recipeProductions)
      ..where(
        (t) =>
            t.isReverted.equals(false) &
            t.producedAt.isBiggerOrEqualValue(from) &
            t.producedAt.isSmallerOrEqualValue(to),
      );
    if (spaceId != null && spaceId.isNotEmpty) {
      prodQuery.where((t) => t.spaceId.equals(spaceId));
    }
    final prods = await prodQuery.get();

    final movQuery = select(inventoryMovements)
      ..where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(from) &
            t.createdAt.isSmallerOrEqualValue(to),
      );
    if (spaceId != null && spaceId.isNotEmpty) {
      movQuery.where((t) => t.groupId.equals(spaceId));
    }
    final movs = await movQuery.get();

    double totalCost = 0.0;
    double totalRevenue = 0.0;
    double totalProfit = 0.0;
    double totalPortions = 0.0;
    final dailyBuckets = <DateTime, DailyProductionBucket>{};
    final recipeAgg = <String, RecipeProductionStat>{};

    for (final p in prods) {
      totalCost += p.totalCostSnapshot;
      totalRevenue += p.totalRevenueSnapshot;
      totalProfit += p.totalProfitSnapshot;
      totalPortions += p.portionsProduced;

      final day = DateTime(
        p.producedAt.year,
        p.producedAt.month,
        p.producedAt.day,
      );
      final prevDay = dailyBuckets[day];
      dailyBuckets[day] = DailyProductionBucket(
        date: day,
        batches: (prevDay?.batches ?? 0) + 1,
        portions: (prevDay?.portions ?? 0.0) + p.portionsProduced,
        cost: (prevDay?.cost ?? 0.0) + p.totalCostSnapshot,
        revenue: (prevDay?.revenue ?? 0.0) + p.totalRevenueSnapshot,
        profit: (prevDay?.profit ?? 0.0) + p.totalProfitSnapshot,
      );

      final prevRec = recipeAgg[p.recipeFk];
      recipeAgg[p.recipeFk] = RecipeProductionStat(
        recipePk: p.recipeFk,
        recipeName: p.recipeNameSnapshot,
        batches: (prevRec?.batches ?? 0) + 1,
        portions: (prevRec?.portions ?? 0.0) + p.portionsProduced,
        totalCost: (prevRec?.totalCost ?? 0.0) + p.totalCostSnapshot,
        totalRevenue: (prevRec?.totalRevenue ?? 0.0) + p.totalRevenueSnapshot,
        totalProfit: (prevRec?.totalProfit ?? 0.0) + p.totalProfitSnapshot,
      );
    }

    double totalRestockSpend = 0.0;
    double totalWasteCost = 0.0;
    for (final m in movs) {
      if (m.movementType == 'restock' && m.totalValueDeltaSnapshot > 0) {
        totalRestockSpend += m.totalValueDeltaSnapshot;
      } else if (m.movementType == 'consume_waste' &&
          m.totalValueDeltaSnapshot < 0) {
        totalWasteCost += m.totalValueDeltaSnapshot.abs();
      }
    }

    final sortedDaily = dailyBuckets.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final sortedRecipes = recipeAgg.values.toList()
      ..sort((a, b) => b.batches.compareTo(a.batches));

    return ProductionStatisticsSummary(
      totalBatches: prods.length,
      totalPortions: totalPortions,
      totalProductionCost: totalCost,
      totalEstimatedRevenue: totalRevenue,
      totalEstimatedProfit: totalProfit,
      totalRestockSpend: totalRestockSpend,
      totalWasteCost: totalWasteCost,
      dailyBuckets: sortedDaily,
      topRecipes: sortedRecipes,
    );
  }

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
                  RecipeIngredientsCompanion(
                    amountNeeded: Value(converted),
                    dateTimeModified: Value(DateTime.now()),
                  ),
                );
          }
        }
      }
      final updated = ingredient.copyWith(
        dateTimeModified: Value(DateTime.now()),
      );
      return update(ingredients).replace(updated);
    });
  }

  Future<int> deleteIngredient(
    Ingredient ingredient, {
    bool recordTombstone = true,
  }) {
    final now = DateTime.now();
    return transaction(() async {
      if (recordTombstone) {
        await into(deletedRecords).insert(
          DeletedRecordsCompanion(
            recordPk: Value(ingredient.ingredientPk),
            entityType: const Value('ingredients'),
            deletedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      return (update(
        ingredients,
      )..where((t) => t.ingredientPk.equals(ingredient.ingredientPk))).write(
        IngredientsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          dateTimeModified: Value(now),
        ),
      );
    });
  }

  Future<int> deleteIngredientPhysically(
    String ingredientPk, {
    bool recordTombstone = true,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      if (recordTombstone) {
        await into(deletedRecords).insert(
          DeletedRecordsCompanion(
            recordPk: Value(ingredientPk),
            entityType: const Value('ingredients'),
            deletedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      return await (delete(ingredients)
            ..where((t) => t.ingredientPk.equals(ingredientPk)))
          .go();
    });
  }

  Future<int> restoreIngredient(String ingredientPk) {
    final now = DateTime.now();
    return transaction(() async {
      await (delete(deletedRecords)
            ..where(
              (t) =>
                  t.recordPk.equals(ingredientPk) &
                  t.entityType.equals('ingredients'),
            ))
          .go();
      return (update(
        ingredients,
      )..where((t) => t.ingredientPk.equals(ingredientPk))).write(
        IngredientsCompanion(
          isDeleted: const Value(false),
          deletedAt: const Value(null),
          dateTimeModified: Value(now),
        ),
      );
    });
  }

  // --- Recipe Ingredient & Step CRUD ---
  Future<int> insertRecipeIngredient(RecipeIngredientsCompanion entry) {
    final now = DateTime.now();
    final withTime = entry.dateTimeModified.present
        ? entry
        : entry.copyWith(dateTimeModified: Value(now));
    return into(recipeIngredients).insert(withTime);
  }

  Future<bool> updateRecipeIngredient(RecipeIngredient entry) {
    final updated = entry.copyWith(dateTimeModified: Value(DateTime.now()));
    return update(recipeIngredients).replace(updated);
  }

  Future<int> deleteRecipeIngredient(
    String recipeIngredientPk, {
    bool recordTombstone = true,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      if (recordTombstone) {
        await into(deletedRecords).insert(
          DeletedRecordsCompanion(
            recordPk: Value(recipeIngredientPk),
            entityType: const Value('recipe_ingredients'),
            deletedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      return await (delete(recipeIngredients)
            ..where((t) => t.recipeIngredientPk.equals(recipeIngredientPk)))
          .go();
    });
  }

  Future<int> insertRecipeStep(RecipeStepsCompanion step) {
    final now = DateTime.now();
    final withTime = step.dateTimeModified.present
        ? step
        : step.copyWith(dateTimeModified: Value(now));
    return into(recipeSteps).insert(withTime);
  }

  Future<bool> updateRecipeStep(RecipeStep step) {
    final updated = step.copyWith(dateTimeModified: Value(DateTime.now()));
    return update(recipeSteps).replace(updated);
  }

  Future<int> deleteRecipeStep(
    String stepPk, {
    bool recordTombstone = true,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      if (recordTombstone) {
        await into(deletedRecords).insert(
          DeletedRecordsCompanion(
            recordPk: Value(stepPk),
            entityType: const Value('recipe_steps'),
            deletedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      return await (delete(recipeSteps)..where((t) => t.stepPk.equals(stepPk)))
          .go();
    });
  }

  // --- Deletion Tracking (Tombstones) ---
  Future<void> recordTombstone(
    String recordPk,
    String entityType, {
    DateTime? deletedAt,
  }) async {
    await into(deletedRecords).insert(
      DeletedRecordsCompanion(
        recordPk: Value(recordPk),
        entityType: Value(entityType),
        deletedAt: Value(deletedAt ?? DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<DeletedRecord>> getAllDeletedRecords() =>
      select(deletedRecords).get();

  Future<List<DeletedRecord>> getDeletedRecordsSince(DateTime? since) {
    final query = select(deletedRecords);
    if (since != null) {
      query.where((t) => t.deletedAt.isBiggerOrEqualValue(since));
    }
    return query.get();
  }

  Future<int> clearDeletedRecords(Iterable<DeletedRecord> records) async {
    if (records.isEmpty) return 0;
    return transaction(() async {
      int count = 0;
      for (final r in records) {
        count += await (delete(deletedRecords)
              ..where(
                (t) =>
                    t.recordPk.equals(r.recordPk) &
                    t.entityType.equals(r.entityType),
              ))
            .go();
      }
      return count;
    });
  }

  Future<int> clearDeletedRecord(String recordPk, String entityType) {
    return (delete(deletedRecords)
          ..where(
            (t) =>
                t.recordPk.equals(recordPk) & t.entityType.equals(entityType),
          ))
        .go();
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

      // 3. preserve stock on target before deleting the old ingredient
      if (source.currentStock != null) {
        final convertedStock = source.currentStock! * conversion;
        final nextStock = (target.currentStock ?? 0.0) + convertedStock;
        await (update(
          ingredients,
        )..where((t) => t.ingredientPk.equals(target.ingredientPk))).write(
          IngredientsCompanion(
            currentStock: Value(nextStock < 0 ? 0.0 : nextStock),
            lastStockUpdate: Value(now),
            dateTimeModified: Value(now),
          ),
        );
      }

      // 4. delete the old ingredient
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
              groupId: Value(ri.groupId),
              category: Value(ri.category),
              currentStock: Value(ri.currentStock),
              minimumStock: Value(ri.minimumStock),
              stockUnit: Value(ri.stockUnit),
              costPerStockUnit: Value(ri.costPerStockUnit),
              lastStockUpdate: Value(ri.lastStockUpdate),
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
                        groupId: Value(ri.groupId),
                        category: Value(ri.category),
                        currentStock: Value(ri.currentStock),
                        minimumStock: Value(ri.minimumStock),
                        stockUnit: Value(ri.stockUnit),
                        costPerStockUnit: Value(ri.costPerStockUnit),
                        lastStockUpdate: Value(ri.lastStockUpdate),
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
                        groupId: Value(ri.groupId),
                        category: Value(ri.category),
                        currentStock: Value(ri.currentStock),
                        minimumStock: Value(ri.minimumStock),
                        stockUnit: Value(ri.stockUnit),
                        costPerStockUnit: Value(ri.costPerStockUnit),
                        lastStockUpdate: Value(ri.lastStockUpdate),
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

      // 4. Merge RecipeProductions & InventoryMovements (non-destructive append)
      final remoteProductions = await remoteDb.select(remoteDb.recipeProductions).get();
      for (final rp in remoteProductions) {
        await into(recipeProductions).insert(
          RecipeProductionsCompanion.insert(
            productionPk: Value(rp.productionPk),
            recipeFk: rp.recipeFk,
            recipeNameSnapshot: rp.recipeNameSnapshot,
            categorySnapshot: Value(rp.categorySnapshot),
            spaceId: Value(rp.spaceId),
            multiplier: Value(rp.multiplier),
            portionsProduced: rp.portionsProduced,
            yieldNameSnapshot: rp.yieldNameSnapshot,
            totalCostSnapshot: rp.totalCostSnapshot,
            unitPriceSnapshot: rp.unitPriceSnapshot,
            totalRevenueSnapshot: rp.totalRevenueSnapshot,
            totalProfitSnapshot: rp.totalProfitSnapshot,
            notes: Value(rp.notes),
            producedAt: Value(rp.producedAt),
            isReverted: Value(rp.isReverted),
            revertedAt: Value(rp.revertedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      final remoteMovements = await remoteDb.select(remoteDb.inventoryMovements).get();
      for (final im in remoteMovements) {
        await into(inventoryMovements).insert(
          InventoryMovementsCompanion.insert(
            movementPk: Value(im.movementPk),
            ingredientFk: im.ingredientFk,
            ingredientNameSnapshot: im.ingredientNameSnapshot,
            groupId: Value(im.groupId),
            movementType: im.movementType,
            recipeProductionFk: Value(im.recipeProductionFk),
            recipeFk: Value(im.recipeFk),
            previousStock: im.previousStock,
            deltaStock: im.deltaStock,
            newStock: im.newStock,
            stockUnitPk: Value(im.stockUnitPk),
            unitCostInStockUnitSnapshot: im.unitCostInStockUnitSnapshot,
            totalValueDeltaSnapshot: im.totalValueDeltaSnapshot,
            reason: Value(im.reason),
            createdAt: Value(im.createdAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
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

class ProducedIngredientDeduction {
  final String ingredientPk;
  final String name;
  final double previousStock;
  final double deductedAmount;
  final double newStock;
  final String unitSymbol;

  const ProducedIngredientDeduction({
    required this.ingredientPk,
    required this.name,
    required this.previousStock,
    required this.deductedAmount,
    required this.newStock,
    required this.unitSymbol,
  });
}

class RecipeProductionResult {
  final String productionPk;
  final String recipePk;
  final String recipeName;
  final double multiplier;
  final double portionsProduced;
  final double totalCost;
  final double totalRevenue;
  final double totalProfit;
  final List<ProducedIngredientDeduction> deductedItems;
  final List<String> lowStockAlerts;

  const RecipeProductionResult({
    required this.productionPk,
    required this.recipePk,
    required this.recipeName,
    required this.multiplier,
    required this.portionsProduced,
    required this.totalCost,
    required this.totalRevenue,
    required this.totalProfit,
    required this.deductedItems,
    required this.lowStockAlerts,
  });
}

class DailyProductionBucket {
  final DateTime date;
  final int batches;
  final double portions;
  final double cost;
  final double revenue;
  final double profit;

  const DailyProductionBucket({
    required this.date,
    required this.batches,
    required this.portions,
    required this.cost,
    required this.revenue,
    required this.profit,
  });
}

class RecipeProductionStat {
  final String recipePk;
  final String recipeName;
  final int batches;
  final double portions;
  final double totalCost;
  final double totalRevenue;
  final double totalProfit;

  const RecipeProductionStat({
    required this.recipePk,
    required this.recipeName,
    required this.batches,
    required this.portions,
    required this.totalCost,
    required this.totalRevenue,
    required this.totalProfit,
  });
}

class ProductionStatisticsSummary {
  final int totalBatches;
  final double totalPortions;
  final double totalProductionCost;
  final double totalEstimatedRevenue;
  final double totalEstimatedProfit;
  final double totalRestockSpend;
  final double totalWasteCost;
  final List<DailyProductionBucket> dailyBuckets;
  final List<RecipeProductionStat> topRecipes;

  const ProductionStatisticsSummary({
    required this.totalBatches,
    required this.totalPortions,
    required this.totalProductionCost,
    required this.totalEstimatedRevenue,
    required this.totalEstimatedProfit,
    required this.totalRestockSpend,
    required this.totalWasteCost,
    required this.dailyBuckets,
    required this.topRecipes,
  });
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
