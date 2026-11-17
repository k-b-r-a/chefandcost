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
import '../provider/web_layout_provider.dart';
import '../widgets/ad_free_pass_button.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import '../utils/ad_interleaving_helper.dart';
import '../widgets/inline_ad_card.dart';
import '../services/app_tutorial_service.dart';
import '../widgets/inventory_adjustment_sheet.dart';
import '../widgets/inventory_workspace_chip.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  final bool isWebWorkspace;

  const IngredientsScreen({super.key, this.isWebWorkspace = false});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final ScrollController _scrollController = ScrollController();
  final IngredientsTutorialKeys _tutorialKeys = IngredientsTutorialKeys();
  bool _tutorialChecked = false;
  bool _isCheckingTutorial = false;
  VoidCallback? _tutorialCompletedListener;

  @override
  void initState() {
    super.initState();
    _tutorialCompletedListener = () {
      if (!mounted) return;
      _maybeTriggerTutorial();
    };
    AppTutorialService.tutorialStepCompletedNotifier.addListener(
      _tutorialCompletedListener!,
    );
  }

  List<Unit>? _lastUnits;
  Map<String, Unit> _cachedUnitMap = const {};

  List<Ingredient>? _lastIngredients;
  IngredientFilterType? _lastFilter;
  String? _lastSearchQuery;
  List<Ingredient> _cachedFilteredIngredients = const [];

  Map<String, Unit> _getUnitMap(List<Unit> units) {
    if (identical(_lastUnits, units)) return _cachedUnitMap;
    _lastUnits = units;
    _cachedUnitMap = {for (final u in units) u.unitPk: u};
    return _cachedUnitMap;
  }

  List<Ingredient> _getFilteredIngredients(
    List<Ingredient> ingredients,
    Map<String, Unit> unitMap,
    IngredientFilterType filter,
    String searchQuery,
  ) {
    if (identical(_lastIngredients, ingredients) &&
        identical(_lastUnitMapForFilter, unitMap) &&
        _lastFilter == filter &&
        _lastSearchQuery == searchQuery) {
      return _cachedFilteredIngredients;
    }
    _lastIngredients = ingredients;
    _lastUnitMapForFilter = unitMap;
    _lastFilter = filter;
    _lastSearchQuery = searchQuery;
    _cachedFilteredIngredients = UnitUtils.filterIngredients(
      ingredients: ingredients,
      unitMap: unitMap,
      filter: filter,
      searchQuery: searchQuery,
    );
    return _cachedFilteredIngredients;
  }

  Map<String, Unit>? _lastUnitMapForFilter;

  @override
  void dispose() {
    if (_tutorialCompletedListener != null) {
      AppTutorialService.tutorialStepCompletedNotifier.removeListener(
        _tutorialCompletedListener!,
      );
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeTriggerTutorial() {
    if (_tutorialChecked || _isCheckingTutorial || !mounted) return;
    _isCheckingTutorial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isCheckingTutorial = false;
        return;
      }
      final shown = await AppTutorialService.checkAndShowIngredientsTutorial(
        context,
        keys: _tutorialKeys,
      );
      if (shown) {
        _tutorialChecked = true;
      }
      _isCheckingTutorial = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final unitsAsync = ref.watch(unitsStreamProvider);
    final searchQuery = ref.watch(ingredientSearchQueryProvider);
    final currentFilter = ref.watch(ingredientFilterProvider);
    final activeTab = ref.watch(ingredientsSectionTabProvider);
    final stockFilter = ref.watch(inventoryStockFilterProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final selectedIngredientPk = isWide
        ? ref.watch(
            webLayoutProvider.select(
              (s) => s.rightPaneView == WebRightPaneView.ingredient
                  ? s.selectedIngredient?.ingredientPk
                  : null,
            ),
          )
        : null;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            cacheExtent: 600,
            slivers: [
              buildFloatingPillAppBar(
                context: context,
                title: l10n.ingredients_title,
                controller: _scrollController,
                showCollapsedTitlePill: false,
                leading: const AdFreePassButton(),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded),
                    tooltip: l10n.tutorial_help_tooltip,
                    onPressed: () {
                      AppTutorialService.showIngredientsTutorial(
                        context,
                        keys: _tutorialKeys,
                      );
                    },
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(widget.isWebWorkspace ? 52 : 96),
                  child: RepaintBoundary(
                    child: SizedBox(
                      height: widget.isWebWorkspace ? 52 : 96,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!widget.isWebWorkspace)
                            const SizedBox(
                              height: 44,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: InventoryWorkspaceChip(isCompact: true),
                                ),
                              ),
                            ),
                          SizedBox(
                            height: 52,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: KeyedSubtree(
                                key: _tutorialKeys.ingredientFilterBarKey,
                                child: IngredientFilterChipsRow(
                                  currentFilter: currentFilter,
                                  onFilterSelected: (filter) {
                                    ref
                                        .read(ingredientFilterProvider.notifier)
                                        .setFilter(filter);
                                  },
                                  isCompact: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ingredientsAsync.when(
            data: (ingredients) {
              return unitsAsync.when(
                data: (units) {
                  final unitMap = _getUnitMap(units);
                  final filteredIngredients = _getFilteredIngredients(
                    ingredients,
                    unitMap,
                    currentFilter,
                    searchQuery,
                  );

                  if (activeTab == IngredientsSectionTab.inventory) {
                    return TweenAnimationBuilder<double>(
                      key: const ValueKey('ingredients_inventory_tab_anim'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: settings.animationsEnabled
                          ? const Duration(milliseconds: 220)
                          : Duration.zero,
                      curve: Curves.easeOutCubic,
                      builder: (context, opacity, child) => SliverOpacity(
                        opacity: opacity,
                        sliver: child!,
                      ),
                      child: _buildInventorySliver(
                        context: context,
                        allIngredients: ingredients,
                        filteredIngredients: filteredIngredients,
                        units: units,
                        unitMap: unitMap,
                        stockFilter: stockFilter,
                        currencySymbol: settings.currencySymbol,
                      ),
                    );
                  }

                  if (!_tutorialChecked && filteredIngredients.isNotEmpty) {
                    _maybeTriggerTutorial();
                  }

                  if (isWide && filteredIngredients.isNotEmpty) {
                    final shouldAutoOpenFirst = ref.watch(
                      webLayoutProvider.select(
                        (s) =>
                            s.middleTab == WebMiddleTab.ingredients &&
                            s.selectedIngredient == null &&
                            s.rightPaneView == WebRightPaneView.ingredient,
                      ),
                    );
                    if (shouldAutoOpenFirst) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted &&
                            ref.read(webLayoutProvider).selectedIngredient ==
                                null &&
                            ref.read(webLayoutProvider).rightPaneView ==
                                WebRightPaneView.ingredient) {
                          ref
                              .read(webLayoutProvider.notifier)
                              .openIngredient(filteredIngredients.first);
                        }
                      });
                    }
                  }

                  final trimmedQuery = searchQuery.trim();
                  final bool hasExactMatch =
                      trimmedQuery.isNotEmpty &&
                      filteredIngredients.any(
                        (ing) =>
                            ing.name.trim().toLowerCase() ==
                            trimmedQuery.toLowerCase(),
                      );
                  final bool showCreateNewCard =
                      trimmedQuery.isNotEmpty && !hasExactMatch;

                  if (filteredIngredients.isEmpty) {
                    if (showCreateNewCard) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 860,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCreateNewCard(
                                      context,
                                      theme,
                                      l10n,
                                      trimmedQuery,
                                      isWide: isWide,
                                    ),
                                    const SizedBox(height: 12),
                                    AppEmptyState(
                                      icon: Icons.search_off_rounded,
                                      message: l10n.no_ingredients_found,
                                      iconSize: 48,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }

                    final emptyMsg =
                        searchQuery.isEmpty &&
                            currentFilter == IngredientFilterType.all
                        ? l10n.no_ingredients
                        : l10n.no_ingredients_found;
                    final category =
                        currentFilter == IngredientFilterType.liquids
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

                  final isAdFree =
                      ref.watch(adProvider.select((s) => s.isAdFree));
                  final isMonetizationAdFree =
                      ref.watch(monetizationProvider.select((s) => s.isAdFree));
                  final bool showAds = !isAdFree &&
                      !isMonetizationAdFree &&
                      AdService.isSupportedPlatform;
                  final int ingredientsVisualCount =
                      AdInterleavingHelper.getVisualCount(
                        filteredIngredients.length,
                        showAds,
                        interval: 10,
                      );
                  final int totalItemCount =
                      ingredientsVisualCount + (showCreateNewCard ? 1 : 0);

                  return SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100, top: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, visualIndex) {
                        if (visualIndex >= totalItemCount) return null;

                        if (visualIndex == ingredientsVisualCount) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: _buildCreateNewCard(
                                  context,
                                  theme,
                                  l10n,
                                  trimmedQuery,
                                  isWide: isWide,
                                ),
                              ),
                            ),
                          );
                        }

                        if (showAds &&
                            AdInterleavingHelper.isAdIndex(
                              visualIndex,
                              interval: 10,
                            )) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: InlineAdCard(
                                key: ValueKey('ad_ingredient_slot_$visualIndex'),
                                style: InlineAdCardStyle.ingredient,
                              ),
                            ),
                          );
                        }

                        final dataIndex = showAds
                            ? AdInterleavingHelper.getDataIndex(
                                visualIndex,
                                interval: 10,
                              )
                            : visualIndex;
                        if (dataIndex >= filteredIngredients.length) return null;

                        final ingredient = filteredIngredients[dataIndex];
                        final unit = unitMap[ingredient.unitFk];
                        final unitSymbol = unit?.symbol ?? '';
                        final category = unit?.category;

                        final isSelected =
                            isWide &&
                            selectedIngredientPk == ingredient.ingredientPk;

                        return RepaintBoundary(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: KeyedSubtree(
                                key: dataIndex == 0
                                    ? _tutorialKeys.firstIngredientItemKey
                                    : null,
                                child: ListTile(
                                selected: isSelected,
                                selectedTileColor: theme
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.25),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: isSelected
                                      ? BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 1.5,
                                        )
                                      : BorderSide.none,
                                ),
                                title: Text(
                                  ingredient.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                  backgroundColor:
                                      UnitUtils.getCategoryContainerColor(
                                        category,
                                        theme,
                                      ),
                                  child: Icon(
                                    UnitUtils.getCategoryIcon(category),
                                    color:
                                        UnitUtils.getCategoryOnContainerColor(
                                          category,
                                          theme,
                                        ),
                                    size: 20,
                                  ),
                                ),
                                onTap: () {
                                  if (isWide) {
                                    ref
                                        .read(webLayoutProvider.notifier)
                                        .openIngredient(ingredient);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddIngredientScreen(
                                              ingredient: ingredient,
                                            ),
                                      ),
                                    );
                                  }
                                },
                                onLongPress: () {
                                  if (isWide) {
                                    ref
                                        .read(webLayoutProvider.notifier)
                                        .openIngredient(ingredient);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddIngredientScreen(
                                              ingredient: ingredient,
                                            ),
                                      ),
                                    );
                                  }
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _confirmDelete(context, ingredient),
                                ),
                              ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: totalItemCount),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: Center(
                    child: Text(l10n.error_prefix(error.toString())),
                  ),
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
        ],
      ),
    );
  }

  Widget _buildCreateNewCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    String query, {
    required bool isWide,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('create_new_ingredient_card'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCreateNewIngredient(context, query, isWide),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.add_custom_ingredient(query),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.new_ingredient_button,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateNewIngredient(
    BuildContext context,
    String initialName,
    bool isWide,
  ) {
    if (isWide) {
      ref
          .read(webLayoutProvider.notifier)
          .openNewIngredient(initialName: initialName);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddIngredientScreen(initialName: initialName),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Ingredient ingredient,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final confirmed = await AppDialogs.confirmDelete(
      context,
      title: l10n.delete_ingredient_title,
      message: l10n.delete_ingredient_confirm(ingredient.name),
      confirmText: l10n.delete_button,
      cancelText: l10n.cancel_button,
    );

    if (confirmed) {
      await ref.read(databaseProvider).deleteIngredient(ingredient);
      if (isWide &&
          ref.read(webLayoutProvider).selectedIngredient?.ingredientPk ==
              ingredient.ingredientPk) {
        ref.read(webLayoutProvider.notifier).closeDetail();
      }
    }
  }

  IconData _categoryIconForUnit(Unit? unit) {
    switch (unit?.category) {
      case 'liquid':
        return Icons.water_drop_outlined;
      case 'solid':
        return Icons.grain_outlined;
      case 'piece':
        return Icons.egg_alt_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildInventorySliver({
    required BuildContext context,
    required List<Ingredient> allIngredients,
    required List<Ingredient> filteredIngredients,
    required List<Unit> units,
    required Map<String, Unit> unitMap,
    required InventoryStockFilter stockFilter,
    required String currencySymbol,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    double totalValue = 0.0;
    int inStockCount = 0;
    int lowStockCount = 0;
    int outOfStockCount = 0;

    for (final ing in allIngredients) {
      final m = IngredientInventoryMetrics.fromIngredient(
        ing,
        ingredientUnit: unitMap[ing.unitFk],
        stockUnit: unitMap[ing.stockUnit ?? ing.unitFk],
      );
      totalValue += m.stockValue;
      switch (m.status) {
        case InventoryStockStatus.inStock:
          inStockCount++;
        case InventoryStockStatus.lowStock:
          lowStockCount++;
        case InventoryStockStatus.outOfStock:
          outOfStockCount++;
      }
    }

    final displayItems = <({Ingredient ingredient, IngredientInventoryMetrics metrics})>[];
    for (final ing in filteredIngredients) {
      final m = IngredientInventoryMetrics.fromIngredient(
        ing,
        ingredientUnit: unitMap[ing.unitFk],
        stockUnit: unitMap[ing.stockUnit ?? ing.unitFk],
      );
      final matches = switch (stockFilter) {
        InventoryStockFilter.all => true,
        InventoryStockFilter.inStock => m.status == InventoryStockStatus.inStock,
        InventoryStockFilter.lowStock => m.status == InventoryStockStatus.lowStock,
        InventoryStockFilter.outOfStock =>
          m.status == InventoryStockStatus.outOfStock,
      };
      if (matches) {
        displayItems.add((ingredient: ing, metrics: m));
      }
    }

    final isAdFree = ref.watch(adProvider.select((s) => s.isAdFree));
    final isMonetizationAdFree =
        ref.watch(monetizationProvider.select((s) => s.isAdFree));
    final bool showAds =
        !isAdFree && !isMonetizationAdFree && AdService.isSupportedPlatform;
    final int inventoryVisualCount = AdInterleavingHelper.getVisualCount(
      displayItems.length,
      showAds,
      interval: 10,
    );

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return _buildInventoryKpiBanner(
                context: context,
                totalValue: totalValue,
                inStockCount: inStockCount,
                lowStockCount: lowStockCount,
                outOfStockCount: outOfStockCount,
                currencySymbol: currencySymbol,
              );
            }
            if (displayItems.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.inventory_empty_title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final visualIndex = index - 1;
            if (showAds &&
                AdInterleavingHelper.isAdIndex(
                  visualIndex,
                  interval: 10,
                )) {
              return InlineAdCard(
                key: ValueKey('ad_inventory_slot_$visualIndex'),
                style: InlineAdCardStyle.ingredient,
              );
            }
            final dataIndex = showAds
                ? AdInterleavingHelper.getDataIndex(
                    visualIndex,
                    interval: 10,
                  )
                : visualIndex;
            if (dataIndex >= displayItems.length) return null;
            final item = displayItems[dataIndex];
            return _buildInventoryCard(
              context: context,
              ingredient: item.ingredient,
              metrics: item.metrics,
              units: units,
              unitMap: unitMap,
              currencySymbol: currencySymbol,
            );
          },
          childCount: displayItems.isEmpty ? 2 : inventoryVisualCount + 1,
        ),
      ),
    );
  }

  Widget _buildInventoryKpiBanner({
    required BuildContext context,
    required double totalValue,
    required int inStockCount,
    required int lowStockCount,
    required int outOfStockCount,
    required String currencySymbol,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.inventory_kpi_total_value,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currencySymbol${RecipeUtils.formatNumber(totalValue)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            _kpiCountPill(
              context,
              label: l10n.inventory_kpi_in_stock,
              count: inStockCount,
              color: Colors.green,
            ),
            const SizedBox(width: 6),
            _kpiCountPill(
              context,
              label: l10n.inventory_kpi_low_stock,
              count: lowStockCount,
              color: Colors.orange,
            ),
            const SizedBox(width: 6),
            _kpiCountPill(
              context,
              label: l10n.inventory_kpi_out_of_stock,
              count: outOfStockCount,
              color: theme.colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCountPill(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard({
    required BuildContext context,
    required Ingredient ingredient,
    required IngredientInventoryMetrics metrics,
    required List<Unit> units,
    required Map<String, Unit> unitMap,
    required String currencySymbol,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stockUnit = unitMap[ingredient.stockUnit ?? ingredient.unitFk];
    final stockSymbol = stockUnit?.symbol ?? '';

    final (statusLabel, statusColor) = switch (metrics.status) {
      InventoryStockStatus.inStock => (l10n.inventory_status_in_stock, Colors.green),
      InventoryStockStatus.lowStock => (l10n.inventory_status_low_stock, Colors.orange),
      InventoryStockStatus.outOfStock => (
        l10n.inventory_status_out_of_stock,
        theme.colorScheme.error,
      ),
    };

    final double? minStock = metrics.minimumStock;
    final double progress = (minStock != null && minStock > 0)
        ? (metrics.currentStock / minStock).clamp(0.0, 1.0)
        : (metrics.currentStock > 0 ? 1.0 : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showInventoryAdjustmentSheet(
          context: context,
          ingredient: ingredient,
          units: units,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      _categoryIconForUnit(stockUnit),
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$currencySymbol${RecipeUtils.formatNumber(metrics.stockValue)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${RecipeUtils.formatQuantity(metrics.currentStock)} $stockSymbol'.trim(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (minStock != null)
                          Text(
                            l10n.inventory_par_level(
                              RecipeUtils.formatQuantity(minStock),
                              stockSymbol,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _QuickStockPresetBar(
                stockUnit: stockUnit,
                units: units,
                onAdjust: (delta) async {
                  final next = (metrics.currentStock + delta)
                      .clamp(0.0, double.infinity)
                      .toDouble();
                  await ref.read(databaseProvider).updateIngredientStock(
                    ingredientPk: ingredient.ingredientPk,
                    currentStock: next,
                    movementType: delta >= 0 ? 'restock' : 'consume_waste',
                  );
                  ref.invalidate(ingredientsStreamProvider);
                },
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStockPresetBar extends StatefulWidget {
  final Unit? stockUnit;
  final List<Unit> units;
  final Future<void> Function(double delta) onAdjust;

  const _QuickStockPresetBar({
    required this.stockUnit,
    required this.units,
    required this.onAdjust,
  });

  @override
  State<_QuickStockPresetBar> createState() => _QuickStockPresetBarState();
}

class _QuickStockPresetBarState extends State<_QuickStockPresetBar> {
  bool _isSubtract = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = UnitUtils.quickStockPresetsForUnit(widget.stockUnit);
    final sign = _isSubtract ? '-' : '+';

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: Icon(
            _isSubtract ? Icons.remove_rounded : Icons.add_rounded,
            size: 16,
            color: _isSubtract
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          label: Text(sign),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _isSubtract = !_isSubtract),
        ),
        for (final preset in presets)
          ActionChip(
            label: Text('$sign${preset.label}'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () {
              final rawDelta = UnitUtils.convertPresetToStockDelta(
                preset: preset,
                stockUnit: widget.stockUnit,
                units: widget.units,
              );
              widget.onAdjust(_isSubtract ? -rawDelta : rawDelta);
            },
          ),
      ],
    );
  }
}
