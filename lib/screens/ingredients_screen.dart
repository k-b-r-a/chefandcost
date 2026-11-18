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

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

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
              preferredSize: const Size.fromHeight(52),
              child: RepaintBoundary(
                child: SizedBox(
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
                        interval: 6,
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
                              interval: 6,
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
                                interval: 6,
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
}
