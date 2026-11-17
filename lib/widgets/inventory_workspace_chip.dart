import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';

/// Workspace-styled chip for toggling/filtering Inventory in both
/// IngredientsScreen and RecipeListScreen (beside ActiveGroupChip).
class InventoryWorkspaceChip extends ConsumerWidget {
  final bool isCompact;
  final bool isRecipesContext;

  const InventoryWorkspaceChip({
    super.key,
    this.isCompact = false,
    this.isRecipesContext = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    int lowCount = 0;
    int outCount = 0;
    final bool isInventoryActive;
    final InventoryStockFilter stockFilter;

    if (isRecipesContext) {
      final recipesTab = ref.watch(recipesSectionTabProvider);
      stockFilter = ref.watch(recipeInventoryStockFilterProvider);
      isInventoryActive = recipesTab == RecipesSectionTab.inventory;
      final recipes =
          ref.watch(recipesWithFinancialsStreamProvider).value ??
          const <RecipeWithFinancials>[];
      for (final item in recipes) {
        final m = RecipeInventoryMetrics.fromRecipeWithFinancials(item);
        if (m.status == InventoryStockStatus.lowStock) lowCount++;
        if (m.status == InventoryStockStatus.outOfStock) outCount++;
      }
    } else {
      final activeTab = ref.watch(ingredientsSectionTabProvider);
      stockFilter = ref.watch(inventoryStockFilterProvider);
      isInventoryActive = activeTab == IngredientsSectionTab.inventory;
      final ingredients =
          ref.watch(ingredientsStreamProvider).value ?? const <Ingredient>[];
      final units = ref.watch(unitsStreamProvider).value ?? const <Unit>[];
      final unitMap = {for (final u in units) u.unitPk: u};

      for (final ing in ingredients) {
        final m = IngredientInventoryMetrics.fromIngredient(
          ing,
          ingredientUnit: unitMap[ing.unitFk],
          stockUnit: unitMap[ing.stockUnit ?? ing.unitFk],
        );
        if (m.status == InventoryStockStatus.lowStock) lowCount++;
        if (m.status == InventoryStockStatus.outOfStock) outCount++;
      }
    }

    final alertCount = lowCount + outCount;

    final Color badgeColor;
    if (outCount > 0) {
      badgeColor = theme.colorScheme.error;
    } else if (lowCount > 0) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.green;
    }

    final String label;
    if (isInventoryActive && stockFilter != InventoryStockFilter.all) {
      label = switch (stockFilter) {
        InventoryStockFilter.all => l10n.ingredients_tab_inventory,
        InventoryStockFilter.lowStock => l10n.inventory_filter_low_stock,
        InventoryStockFilter.outOfStock => l10n.inventory_filter_out_of_stock,
        InventoryStockFilter.inStock => l10n.inventory_filter_in_stock,
      };
    } else {
      label = l10n.ingredients_tab_inventory;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          isRecipesContext
              ? 'recipes_inventory_workspace_chip'
              : 'ingredients_inventory_workspace_chip',
        ),
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isRecipesContext) {
            final current = ref.read(recipesSectionTabProvider);
            final next = current == RecipesSectionTab.inventory
                ? RecipesSectionTab.recipes
                : RecipesSectionTab.inventory;
            ref.read(recipesSectionTabProvider.notifier).setTab(next);
          } else {
            final current = ref.read(ingredientsSectionTabProvider);
            final next = current == IngredientsSectionTab.inventory
                ? IngredientsSectionTab.ingredients
                : IngredientsSectionTab.inventory;
            ref.read(ingredientsSectionTabProvider.notifier).setTab(next);
          }
        },
        onLongPress: () => InventoryFilterSheet.show(
          context,
          isRecipesContext: isRecipesContext,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: isInventoryActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isInventoryActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isCompact ? 18 : 20,
                height: isCompact ? 18 : 20,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: isCompact ? 11.5 : 13,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 115),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: isInventoryActive
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: isInventoryActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (alertCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$alertCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => InventoryFilterSheet.show(
                  context,
                  isRecipesContext: isRecipesContext,
                ),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: isCompact ? 18 : 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workspace-styled modal bottom sheet for switching Inventory views/filters
/// in either Recipes or Ingredients.
class InventoryFilterSheet extends ConsumerWidget {
  final bool isRecipesContext;

  const InventoryFilterSheet({
    super.key,
    this.isRecipesContext = false,
  });

  static Future<void> show(
    BuildContext context, {
    bool isRecipesContext = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryFilterSheet(isRecipesContext: isRecipesContext),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final bool isInventoryMode = isRecipesContext
        ? ref.watch(recipesSectionTabProvider) == RecipesSectionTab.inventory
        : ref.watch(ingredientsSectionTabProvider) ==
              IngredientsSectionTab.inventory;
    final stockFilter = isRecipesContext
        ? ref.watch(recipeInventoryStockFilterProvider)
        : ref.watch(inventoryStockFilterProvider);

    void selectCatalog() {
      if (isRecipesContext) {
        ref
            .read(recipesSectionTabProvider.notifier)
            .setTab(RecipesSectionTab.recipes);
      } else {
        ref
            .read(ingredientsSectionTabProvider.notifier)
            .setTab(IngredientsSectionTab.ingredients);
      }
      Navigator.of(context).pop();
    }

    void selectInventoryFilter(InventoryStockFilter filter) {
      if (isRecipesContext) {
        ref
            .read(recipesSectionTabProvider.notifier)
            .setTab(RecipesSectionTab.inventory);
        ref.read(recipeInventoryStockFilterProvider.notifier).setFilter(filter);
      } else {
        ref
            .read(ingredientsSectionTabProvider.notifier)
            .setTab(IngredientsSectionTab.inventory);
        ref.read(inventoryStockFilterProvider.notifier).setFilter(filter);
      }
      Navigator.of(context).pop();
    }

    final options = <({
      String title,
      IconData icon,
      Color color,
      bool isSelected,
      VoidCallback onTap,
    })>[
      (
        title: isRecipesContext
            ? l10n.recipes_title
            : l10n.ingredients_tab_ingredients,
        icon: isRecipesContext ? Icons.restaurant_menu_rounded : Icons.egg_outlined,
        color: theme.colorScheme.primary,
        isSelected: !isInventoryMode,
        onTap: selectCatalog,
      ),
      (
        title: '${l10n.ingredients_tab_inventory} • ${l10n.inventory_filter_all}',
        icon: Icons.inventory_2_outlined,
        color: theme.colorScheme.primary,
        isSelected: isInventoryMode && stockFilter == InventoryStockFilter.all,
        onTap: () => selectInventoryFilter(InventoryStockFilter.all),
      ),
      (
        title: l10n.inventory_filter_low_stock,
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        isSelected:
            isInventoryMode && stockFilter == InventoryStockFilter.lowStock,
        onTap: () => selectInventoryFilter(InventoryStockFilter.lowStock),
      ),
      (
        title: l10n.inventory_filter_out_of_stock,
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        isSelected:
            isInventoryMode && stockFilter == InventoryStockFilter.outOfStock,
        onTap: () => selectInventoryFilter(InventoryStockFilter.outOfStock),
      ),
      (
        title: l10n.inventory_filter_in_stock,
        icon: Icons.check_circle_outline_rounded,
        color: Colors.green,
        isSelected:
            isInventoryMode && stockFilter == InventoryStockFilter.inStock,
        onTap: () => selectInventoryFilter(InventoryStockFilter.inStock),
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Text(
                l10n.ingredients_tab_inventory,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final opt = options[index];
                  return Material(
                    color: opt.isSelected
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.35,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: opt.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: opt.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.25,
                                  ),
                            width: opt.isSelected ? 1.75 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: opt.color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                opt.icon,
                                color: opt.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: opt.isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (opt.isSelected)
                              Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
