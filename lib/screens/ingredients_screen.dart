import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../database/database.dart';
import '../utils/recipe_utils.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../utils/unit_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/ingredient_filter_chips_row.dart';
import 'add_ingredient_screen.dart';
import '../provider/settings_provider.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final unitsAsync = ref.watch(unitsStreamProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final currentFilter = ref.watch(ingredientFilterProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          buildFloatingPillAppBar(
            context: context,
            title: l10n.ingredients_title,
            controller: _scrollController,
            underTitle: IngredientFilterChipsRow(
              currentFilter: currentFilter,
              onFilterSelected: (filter) {
                ref.read(ingredientFilterProvider.notifier).setFilter(filter);
              },
              isCompact: true,
            ),
          ),
          ingredientsAsync.when(
            data: (ingredients) {
              return unitsAsync.when(
                data: (units) {
                  final unitMap = {for (var u in units) u.unitPk: u};
                  final filteredIngredients = UnitUtils.filterIngredients(
                    ingredients: ingredients,
                    unitMap: unitMap,
                    filter: currentFilter,
                    searchQuery: searchQuery,
                  );

                  if (filteredIngredients.isEmpty) {
                    final emptyMsg = searchQuery.isEmpty &&
                            currentFilter == IngredientFilterType.all
                        ? l10n.no_ingredients
                        : l10n.no_ingredients_found;
                    final category = currentFilter == IngredientFilterType.liquids
                        ? 'volume'
                        : currentFilter == IngredientFilterType.solids
                            ? 'mass'
                            : currentFilter == IngredientFilterType.pieces
                                ? 'count'
                                : null;
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: UnitUtils.getCategoryIcon(category),
                        message: emptyMsg,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100, top: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final ingredient = filteredIngredients[index];
                        final unit = unitMap[ingredient.unitFk];
                        final unitSymbol = unit?.symbol ?? '';
                        final category = unit?.category;

                        return RepaintBoundary(
                          child: ListTile(
                            title: Text(
                              ingredient.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: CurrencyText(
                              l10n.ingredient_price_per_quantity(
                                '${settings.currencySymbol}${RecipeUtils.formatNumber(ingredient.cost)}',
                                RecipeUtils.formatNumber(
                                  ingredient.quantityForCost,
                                ),
                                unitSymbol,
                              ),
                              currencySymbol: settings.currencySymbol,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: UnitUtils.getCategoryContainerColor(category, theme),
                              child: Icon(
                                UnitUtils.getCategoryIcon(category),
                                color: UnitUtils.getCategoryOnContainerColor(category, theme),
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddIngredientScreen(ingredient: ingredient),
                                ),
                              );
                            },
                            onLongPress: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddIngredientScreen(ingredient: ingredient),
                                ),
                              );
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmDelete(context, ingredient),
                            ),
                          ),
                        );
                      }, childCount: filteredIngredients.length),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: Center(child: Text(l10n.error_prefix(error.toString()))),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: Center(child: Text(l10n.error_prefix(error.toString()))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Ingredient ingredient,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirmDelete(
      context,
      title: l10n.delete_button,
      message: '${l10n.delete_button} ${ingredient.name}?',
      confirmText: l10n.delete_button,
      cancelText: l10n.done_button,
    );

    if (confirmed) {
      await ref.read(databaseProvider).deleteIngredient(ingredient);
    }
  }
}
