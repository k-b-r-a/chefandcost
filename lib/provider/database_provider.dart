import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/recipe_category.dart';
import '../database/sample_manufacturing_recipe.dart';
import 'settings_provider.dart';

const String kAllGroupsId = '__all_groups__';

class DatabaseNotifier extends Notifier<AppDatabase> {
  @override
  AppDatabase build() {
    final db = AppDatabase();
    ref.onDispose(() => db.close());
    Future.microtask(() async {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await ensureSampleManufacturingRecipe(db, prefs: prefs);
      } catch (_) {}
    });
    return db;
  }

  void refreshDatabase() {
    state.close();
    ref.invalidateSelf();
  }
}

/// Provider that exposes the AppDatabase instance to the entire app.
final databaseProvider = NotifierProvider<DatabaseNotifier, AppDatabase>(
  DatabaseNotifier.new,
);

/// Any change in the 'recipes' table will trigger an automatic UI update.
final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final db = ref.watch(databaseProvider);
  final active = ref.watch(activeGroupProvider);
  return db.watchAllRecipes(spaceId: active?.id);
});

/// Stream of recipes including their calculated financial summaries.
final recipesWithFinancialsStreamProvider =
    StreamProvider<List<RecipeWithFinancials>>((ref) {
      final db = ref.watch(databaseProvider);
      final spaceId = ref.watch(
        activeGroupProvider.select((group) => group?.id),
      );
      return db.watchAllRecipesWithFinancials(spaceId: spaceId);
    });

/// Any change in the 'ingredients' table will trigger an automatic UI update.
final ingredientsStreamProvider = StreamProvider<List<Ingredient>>((ref) {
  final db = ref.watch(databaseProvider);
  final spaceId = ref.watch(
    activeGroupProvider.select((group) => group?.id),
  );
  return db.watchAllIngredients(groupId: spaceId);
});

/// Fetches the full details of a single recipe, including its ingredients and steps.
final recipeDetailProvider = FutureProvider.family<RecipeDetail, String>((
  ref,
  recipePk,
) {
  final db = ref.watch(databaseProvider);
  ref.watch(ingredientsStreamProvider);
  return db.getRecipeDetail(recipePk);
});

/// Provides a list of all available units.
final unitsProvider = FutureProvider<List<Unit>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllUnits();
});

/// Provides a reactive stream of all available units.
final unitsStreamProvider = StreamProvider<List<Unit>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllUnits();
});

/// Filter type for ingredients (all, solids, liquids, pieces).
enum IngredientFilterType { all, solids, liquids, pieces }

/// Notifier for the ingredient filter type.
class IngredientFilterNotifier extends Notifier<IngredientFilterType> {
  @override
  IngredientFilterType build() => IngredientFilterType.all;

  void setFilter(IngredientFilterType filter) => state = filter;
}

/// State provider for filtering ingredients.
final ingredientFilterProvider =
    NotifierProvider<IngredientFilterNotifier, IngredientFilterType>(
      IngredientFilterNotifier.new,
    );

/// Active tab in the ingredients section.
enum IngredientsSectionTab { ingredients, inventory }

/// Notifier for the active ingredients section tab.
class IngredientsSectionTabNotifier extends Notifier<IngredientsSectionTab> {
  @override
  IngredientsSectionTab build() => IngredientsSectionTab.ingredients;

  void setTab(IngredientsSectionTab tab) => state = tab;
}

/// State provider for the active ingredients section tab.
final ingredientsSectionTabProvider =
    NotifierProvider<IngredientsSectionTabNotifier, IngredientsSectionTab>(
      IngredientsSectionTabNotifier.new,
    );

/// Filter type for inventory stock status.
enum InventoryStockFilter { all, lowStock, outOfStock, inStock }

/// Notifier for the inventory stock filter.
class InventoryStockFilterNotifier extends Notifier<InventoryStockFilter> {
  @override
  InventoryStockFilter build() => InventoryStockFilter.all;

  void setFilter(InventoryStockFilter filter) => state = filter;
}

/// State provider for filtering inventory by stock status.
final inventoryStockFilterProvider =
    NotifierProvider<InventoryStockFilterNotifier, InventoryStockFilter>(
      InventoryStockFilterNotifier.new,
    );

/// Computed stock status for an ingredient.
enum InventoryStockStatus { outOfStock, lowStock, inStock }

/// Helper computing inventory metrics for an [Ingredient].
class IngredientInventoryMetrics {
  const IngredientInventoryMetrics({
    required this.currentStock,
    required this.minimumStock,
    required this.status,
    required this.stockValue,
  });

  final double currentStock;
  final double? minimumStock;
  final InventoryStockStatus status;
  final double stockValue;

  factory IngredientInventoryMetrics.fromIngredient(
    Ingredient ingredient, {
    Unit? ingredientUnit,
    Unit? stockUnit,
  }) {
    final current = ingredient.currentStock ?? 0.0;
    final minimum = ingredient.minimumStock;
    final InventoryStockStatus status;
    if (current <= 0) {
      status = InventoryStockStatus.outOfStock;
    } else if (minimum != null && current <= minimum) {
      status = InventoryStockStatus.lowStock;
    } else {
      status = InventoryStockStatus.inStock;
    }

    double stockValue = 0.0;
    if (ingredient.quantityForCost > 0) {
      double normalizedStock = current;
      if (ingredientUnit != null &&
          stockUnit != null &&
          ingredientUnit.category != null &&
          ingredientUnit.category == stockUnit.category &&
          ingredientUnit.factorToBase.isFinite &&
          ingredientUnit.factorToBase > 0 &&
          stockUnit.factorToBase.isFinite &&
          stockUnit.factorToBase > 0) {
        normalizedStock =
            current * (stockUnit.factorToBase / ingredientUnit.factorToBase);
      }
      stockValue =
          (normalizedStock / ingredient.quantityForCost) * ingredient.cost;
    }

    return IngredientInventoryMetrics(
      currentStock: current,
      minimumStock: minimum,
      status: status,
      stockValue: stockValue,
    );
  }
}

/// Provides a stream of ingredients that match a search query.
final relatedIngredientsProvider =
    StreamProvider.family<List<Ingredient>, String>((ref, query) {
      final db = ref.watch(databaseProvider);
      return db.searchIngredients(query);
    });

/// Notifier for the recipe search query.
class RecipeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

/// State provider for the recipe search query using Notifier.
final recipeSearchQueryProvider =
    NotifierProvider<RecipeSearchQueryNotifier, String>(
      RecipeSearchQueryNotifier.new,
    );

/// Notifier for the ingredient search query.
class IngredientSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

/// State provider for the ingredient search query using Notifier.
final ingredientSearchQueryProvider =
    NotifierProvider<IngredientSearchQueryNotifier, String>(
      IngredientSearchQueryNotifier.new,
    );

/// Backward compatibility aliases for the legacy search query provider.
typedef SearchQueryNotifier = RecipeSearchQueryNotifier;
final searchQueryProvider = recipeSearchQueryProvider;

/// Provides a reactive stream of all operational groups / venues.
final groupsStreamProvider = StreamProvider<List<Group>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllGroups().asBroadcastStream();
});

/// Provides a reactive stream of all preset categories.
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCategories().asBroadcastStream();
});

/// Notifier to manage the currently active group / workspace ID.
class ActiveGroupIdNotifier extends Notifier<String?> {
  static const String prefActiveGroupIdKey = 'active_group_id';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // On first open, default to All Spaces (kAllGroupsId) instead of a single workspace.
    return prefs.getString(prefActiveGroupIdKey) ?? kAllGroupsId;
  }

  Future<void> setActiveGroupId(String? id) async {
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    if (id != null) {
      await prefs.setString(prefActiveGroupIdKey, id);
    } else {
      await prefs.remove(prefActiveGroupIdKey);
    }
  }
}

/// State provider for the active group ID.
final activeGroupIdProvider = NotifierProvider<ActiveGroupIdNotifier, String?>(
  ActiveGroupIdNotifier.new,
);

/// Provider that resolves the active [Group] object.
/// Returns null when All Spaces (kAllGroupsId) is active.
final activeGroupProvider = Provider<Group?>((ref) {
  final activeId = ref.watch(activeGroupIdProvider);
  final groups = ref.watch(groupsStreamProvider).asData?.value ?? [];
  if (groups.isEmpty) return null;
  if (activeId == kAllGroupsId || activeId == null) return null;
  final found = groups
      .where((g) => g.id == activeId && !g.isDeleted)
      .firstOrNull;
  return found;
});

/// Notifier for category filtering on recipes (null represents 'Todos').
class RecipeCategoryFilterNotifier extends Notifier<RecipeCategory?> {
  @override
  RecipeCategory? build() => null;

  void setCategory(RecipeCategory? category) => state = category;
}

/// State provider for filtering recipes by category.
final recipeCategoryFilterProvider =
    NotifierProvider<RecipeCategoryFilterNotifier, RecipeCategory?>(
      RecipeCategoryFilterNotifier.new,
    );

/// Reactive stream of recipe production history (for statistics & audit).
final recipeProductionHistoryStreamProvider =
    StreamProvider<List<RecipeProduction>>((ref) {
      final db = ref.watch(databaseProvider);
      final spaceId = ref.watch(
        activeGroupProvider.select((group) => group?.id),
      );
      return db.watchRecipeProductions(spaceId: spaceId, limit: 100);
    });

/// Reactive stream of recent inventory movements for a specific ingredient.
final ingredientMovementsStreamProvider =
    StreamProvider.family<List<InventoryMovement>, String>((ref, ingredientPk) {
      final db = ref.watch(databaseProvider);
      return db.watchInventoryMovements(
        ingredientPk: ingredientPk,
        limit: 10,
      );
    });

/// Aggregated production & inventory statistics summary for a date range.
final productionStatsSummaryProvider =
    FutureProvider.family<ProductionStatisticsSummary, ({DateTime from, DateTime to})>((
      ref,
      range,
    ) {
      final db = ref.watch(databaseProvider);
      final spaceId = ref.watch(
        activeGroupProvider.select((group) => group?.id),
      );
      ref.watch(recipeProductionHistoryStreamProvider);
      return db.getProductionStatisticsSummary(
        from: range.from,
        to: range.to,
        spaceId: spaceId,
      );
    });

/// Active tab in the recipes section.
enum RecipesSectionTab { recipes, inventory }

class RecipesSectionTabNotifier extends Notifier<RecipesSectionTab> {
  @override
  RecipesSectionTab build() => RecipesSectionTab.recipes;

  void setTab(RecipesSectionTab tab) => state = tab;
}

final recipesSectionTabProvider =
    NotifierProvider<RecipesSectionTabNotifier, RecipesSectionTab>(
      RecipesSectionTabNotifier.new,
    );

class RecipeInventoryStockFilterNotifier extends Notifier<InventoryStockFilter> {
  @override
  InventoryStockFilter build() => InventoryStockFilter.all;

  void setFilter(InventoryStockFilter filter) => state = filter;
}

final recipeInventoryStockFilterProvider =
    NotifierProvider<RecipeInventoryStockFilterNotifier, InventoryStockFilter>(
      RecipeInventoryStockFilterNotifier.new,
    );

/// Computed prepared-stock metrics for a [Recipe].
class RecipeInventoryMetrics {
  const RecipeInventoryMetrics({
    required this.currentStock,
    required this.minimumStock,
    required this.status,
    required this.stockCostValue,
    required this.stockSaleValue,
  });

  final double currentStock;
  final double? minimumStock;
  final InventoryStockStatus status;
  final double stockCostValue;
  final double stockSaleValue;

  factory RecipeInventoryMetrics.fromRecipeWithFinancials(
    RecipeWithFinancials item,
  ) {
    final current = item.recipe.currentStock ?? 0.0;
    final minimum = item.recipe.minimumStock;
    final InventoryStockStatus status;
    if (current <= 0) {
      status = InventoryStockStatus.outOfStock;
    } else if (minimum != null && current <= minimum) {
      status = InventoryStockStatus.lowStock;
    } else {
      status = InventoryStockStatus.inStock;
    }

    return RecipeInventoryMetrics(
      currentStock: current,
      minimumStock: minimum,
      status: status,
      stockCostValue: current * item.financials.totalCost,
      stockSaleValue: current * item.financials.totalRevenue,
    );
  }
}

/// Reactive stream of recent prepared-recipe inventory movements.
final recipeInventoryMovementsStreamProvider =
    StreamProvider.family<List<RecipeInventoryMovement>, String>((ref, recipePk) {
      final db = ref.watch(databaseProvider);
      return db.watchRecipeInventoryMovements(
        recipePk: recipePk,
        limit: 10,
      );
    });
