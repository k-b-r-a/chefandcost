import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../utils/dialog_utils.dart';
import '../utils/recipe_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../provider/web_layout_provider.dart';
import '../services/app_tutorial_service.dart';
import '../database/sample_manufacturing_recipe.dart';
import 'recipe_editor_screen.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final ScrollController _scrollController = ScrollController();
  final RecipeListTutorialKeys _tutorialKeys = RecipeListTutorialKeys();
  String? _expandedRecipeId;
  bool _tutorialChecked = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleTutorialStepFocus(String stepId) async {
    if (stepId == 'step_recipe_list_hold') {
      final recipesAsync = ref.read(recipesWithFinancialsStreamProvider);
      final searchQuery = ref.read(recipeSearchQueryProvider).toLowerCase();
      final recipes = recipesAsync.asData?.value ?? [];
      final filtered = recipes.where((item) => item.recipe.name.toLowerCase().contains(searchQuery)).toList();
      if (filtered.isNotEmpty) {
        final firstPk = filtered.first.recipe.recipePk;
        if (_expandedRecipeId != firstPk) {
          if (mounted) {
            setState(() {
              _expandedRecipeId = firstPk;
            });
          }
          // Allow AnimatedSize transition to complete so spotlight encapsulates the expanded card
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
  }

  void _handleTutorialEnd() {
    if (mounted && _expandedRecipeId != null) {
      setState(() {
        _expandedRecipeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recipesAsync = ref.watch(recipesWithFinancialsStreamProvider);
    final searchQuery = ref.watch(recipeSearchQueryProvider).toLowerCase();
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          buildFloatingPillAppBar(
            context: context,
            title: l10n.recipes_title,
            controller: _scrollController,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                tooltip: l10n.tutorial_help_tooltip,
                onPressed: () {
                  AppTutorialService.showRecipeListTutorial(
                    context,
                    keys: _tutorialKeys,
                    onStepFocus: _handleTutorialStepFocus,
                    onFinish: _handleTutorialEnd,
                    onSkip: _handleTutorialEnd,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          recipesAsync.when(
            data: (recipes) {
              final hasSample = recipes.any(
                (item) => isSampleManufacturingRecipe(item.recipe.recipePk),
              );
              if (hasSample) {
                final prefs = ref.watch(sharedPreferencesProvider);
                if (prefs.getBool(AppTutorialService.kTutorialRecipeEditorCompletedKey) == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      final db = ref.read(databaseProvider);
                      dismissSampleManufacturingRecipe(db, prefs: prefs);
                    }
                  });
                }
              }

              final filteredRecipes = recipes.where((item) {
                final effectiveName = isSampleManufacturingRecipe(item.recipe.recipePk)
                    ? l10n.sample_manufacturing_recipe_title
                    : item.recipe.name;
                return effectiveName.toLowerCase().contains(searchQuery);
              }).toList();

              if (!_tutorialChecked && filteredRecipes.isNotEmpty) {
                _tutorialChecked = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    AppTutorialService.checkAndShowRecipeListTutorial(
                      context,
                      keys: _tutorialKeys,
                      onStepFocus: _handleTutorialStepFocus,
                      onFinish: _handleTutorialEnd,
                      onSkip: _handleTutorialEnd,
                    );
                  }
                });
              }

              final isWideWeb = MediaQuery.sizeOf(context).width >= 640;
              if (isWideWeb && filteredRecipes.isNotEmpty) {
                final webLayout = ref.watch(webLayoutProvider);
                if (webLayout.middleTab == WebMiddleTab.recipes &&
                    webLayout.selectedRecipeId == null &&
                    webLayout.rightPaneView == WebRightPaneView.recipe) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        ref.read(webLayoutProvider).selectedRecipeId == null &&
                        ref.read(webLayoutProvider).rightPaneView == WebRightPaneView.recipe) {
                      ref.read(webLayoutProvider.notifier).openRecipe(filteredRecipes.first.recipe.recipePk);
                    }
                  });
                }
              }

              if (filteredRecipes.isEmpty) {
                return SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.restaurant_menu,
                    message: searchQuery.isEmpty
                        ? l10n.recipes_title
                        : l10n.no_recipes_found,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= filteredRecipes.length) return null;
                    final item = filteredRecipes[index];
                    final recipe = item.recipe;
                    final financials = item.financials;
                    final isExpanded = _expandedRecipeId == recipe.recipePk;

                    final avatarBgColor = RecipeUtils.parseColor(
                      recipe.colour,
                      fallback: theme.colorScheme.primary,
                    );

                    final isWideWeb = MediaQuery.sizeOf(context).width >= 800;
                    final selectedRecipeId = isWideWeb
                        ? ref.watch(webLayoutProvider).selectedRecipeId
                        : null;
                    final isSelected = isWideWeb && selectedRecipeId == recipe.recipePk;

                    return RepaintBoundary(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: KeyedSubtree(
                            key: index == 0 ? _tutorialKeys.recipeCardKey : null,
                            child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            color: isSelected
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                                : null,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (isExpanded) {
                                  setState(() {
                                    _expandedRecipeId = null;
                                  });
                                } else {
                                  if (isWideWeb) {
                                    if (ref.read(webLayoutProvider).selectedRecipeId == recipe.recipePk) return;
                                    final guard = ref.read(recipeCanLeaveGuardProvider);
                                    if (guard != null && !await guard()) return;
                                    ref
                                        .read(webLayoutProvider.notifier)
                                        .openRecipe(recipe.recipePk);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RecipeEditorScreen(
                                              recipeId: recipe.recipePk,
                                              isTemporary: isSampleManufacturingRecipe(recipe.recipePk),
                                            ),
                                      ),
                                    );
                                  }
                                }
                              },
                        onLongPress: () {
                          setState(() {
                            _expandedRecipeId = isExpanded ? null : recipe.recipePk;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: avatarBgColor,
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isSampleManufacturingRecipe(recipe.recipePk)
                                                    ? l10n.sample_manufacturing_recipe_title
                                                    : recipe.name,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSampleManufacturingRecipe(recipe.recipePk)) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.tertiaryContainer,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.science_outlined,
                                                      size: 11,
                                                      color: theme.colorScheme.onTertiaryContainer,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      l10n.sample_manufacturing_badge,
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: theme.colorScheme.onTertiaryContainer,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if ((isSampleManufacturingRecipe(recipe.recipePk)
                                                ? l10n.sample_manufacturing_recipe_desc
                                                : recipe.description) !=
                                            null &&
                                            (isSampleManufacturingRecipe(recipe.recipePk)
                                                    ? l10n.sample_manufacturing_recipe_desc
                                                    : (recipe.description ?? ''))
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            isSampleManufacturingRecipe(recipe.recipePk)
                                                ? l10n.sample_manufacturing_recipe_desc
                                                : recipe.description!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              KeyedSubtree(
                                key: index == 0 ? _tutorialKeys.recipeFinanceGridKey : null,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStaticFinancialGridItem(
                                        context,
                                        settings,
                                        l10n.total_cost,
                                        '${settings.currencySymbol}${RecipeUtils.formatNumber(financials.totalCost)}',
                                        theme.colorScheme.errorContainer,
                                        theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildStaticFinancialGridItem(
                                        context,
                                        settings,
                                        l10n.total_profit,
                                        '${settings.currencySymbol}${RecipeUtils.formatNumber(financials.totalProfit)}',
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildStaticFinancialGridItem(
                                        context,
                                        settings,
                                        l10n.financial_price,
                                        '${settings.currencySymbol}${RecipeUtils.formatNumber(recipe.targetPricePerPortion)}',
                                        theme.colorScheme.secondaryContainer,
                                        theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedSize(
                                duration: settings.animationsEnabled
                                    ? const Duration(milliseconds: 200)
                                    : Duration.zero,
                                curve: Curves.easeInOut,
                                child: isExpanded
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          Divider(
                                            height: 1,
                                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMenuButton(
                                                  context: context,
                                                  icon: Icons.edit_outlined,
                                                  label: l10n.edit_button,
                                                  onTap: () async {
                                                    if (isWideWeb) {
                                                      if (ref.read(webLayoutProvider).selectedRecipeId != recipe.recipePk) {
                                                        final guard = ref.read(recipeCanLeaveGuardProvider);
                                                        if (guard != null && !await guard()) return;
                                                      }
                                                      ref
                                                          .read(webLayoutProvider.notifier)
                                                          .openRecipe(recipe.recipePk);
                                                      setState(() {
                                                        _expandedRecipeId = null;
                                                      });
                                                    } else {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              RecipeEditorScreen(
                                                                recipeId: recipe.recipePk,
                                                                isTemporary: isSampleManufacturingRecipe(recipe.recipePk),
                                                              ),
                                                        ),
                                                      ).then((_) {
                                                        setState(() {
                                                          _expandedRecipeId = null;
                                                        });
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildMenuButton(
                                                  context: context,
                                                  icon: Icons.scale_outlined,
                                                  label: l10n.scale_button,
                                                  onTap: () {
                                                    _showScalePickerFromList(context, recipe);
                                                  },
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildMenuButton(
                                                  context: context,
                                                  icon: Icons.copy_rounded,
                                                  label: l10n.duplicate_button,
                                                  onTap: () {
                                                    _duplicateRecipeFromList(context, recipe);
                                                  },
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildMenuButton(
                                                  context: context,
                                                  icon: Icons.delete_outline_rounded,
                                                  label: l10n.delete_button,
                                                  color: theme.colorScheme.error,
                                                  onTap: () {
                                                    _deleteRecipeFromList(context, recipe);
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
                );
                }, childCount: filteredRecipes.length),
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

  Widget _buildStaticFinancialGridItem(
    BuildContext context,
    SettingsState settings,
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    String shortLabel = label;

    if (label.toLowerCase().contains('cost')) {
      shortLabel = l10n.short_cost;
    } else if (label.toLowerCase().contains('profit') ||
        label.toLowerCase().contains('ganancia')) {
      shortLabel = l10n.short_profit;
    } else if (label.toLowerCase().contains('price') ||
        label.toLowerCase().contains('precio')) {
      shortLabel = l10n.short_price_portion;
    }

    final effectiveBgColor = settings.numberColorsEnabled
        ? bgColor
        : theme.colorScheme.surfaceContainerHighest;
    final effectiveTextColor = settings.numberColorsEnabled
        ? textColor
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: effectiveBgColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            shortLabel,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: effectiveTextColor.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              RecipeUtils.formatCurrencyTextSpan(
                context: context,
                text: value,
                currencySymbol: settings.currencySymbol,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: effectiveTextColor,
                ),
                currencyColor: settings.numberColorsEnabled
                    ? effectiveTextColor
                    : theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: buttonColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: buttonColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateRecipeFromList(BuildContext context, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final defaultNewName = l10n.recipe_duplicate_name(recipe.name, l10n.duplicate_button);

    final newName = await AppDialogs.promptText(
      context,
      title: l10n.duplicate_button,
      initialValue: defaultNewName,
      labelText: l10n.recipe_name,
      confirmText: l10n.save_button,
      cancelText: l10n.discard_button,
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await db.duplicateRecipe(recipe.recipePk, newName);
        setState(() {
          _expandedRecipeId = null;
        });
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(context, "${l10n.error_prefix}: $e");
        }
      }
    }
  }

  void _deleteRecipeFromList(BuildContext context, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    final confirm = await AppDialogs.confirmDelete(
      context,
      title: l10n.delete_recipe_title,
      message: l10n.delete_recipe_message,
      confirmText: l10n.delete_button,
      cancelText: l10n.discard_button,
    );

    if (confirm) {
      try {
        if (isSampleManufacturingRecipe(recipe.recipePk)) {
          final prefs = ref.read(sharedPreferencesProvider);
          await dismissSampleManufacturingRecipe(db, prefs: prefs);
        } else {
          await db.deleteRecipe(recipe);
        }
        setState(() {
          _expandedRecipeId = null;
        });
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(context, "${l10n.error_prefix}: $e");
        }
      }
    }
  }

  void _showScalePickerFromList(BuildContext context, Recipe recipe) {
    final l10n = AppLocalizations.of(context)!;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scale_button, softWrap: true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [0.5, 2.0, 3.0, 4.0, 5.0].map((multiplier) {
                return OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openTemporaryScaledRecipeFromList(context, recipe, multiplier);
                  },
                  child: Text(
                    l10n.scale_multiplier_button(RecipeUtils.formatNumber(multiplier)),
                    softWrap: true,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.ingredient_quantity,
                hintText: l10n.scale_custom_multiplier_hint,
                border: const OutlineInputBorder(),
                suffixText: 'x',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button, softWrap: true),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(customController.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                Navigator.of(context).pop();
                _openTemporaryScaledRecipeFromList(context, recipe, val);
              }
            },
            child: Text(l10n.save_button, softWrap: true),
          ),
        ],
      ),
    );
  }

  void _openTemporaryScaledRecipeFromList(BuildContext context, Recipe recipe, double multiplier) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await db.getRecipeDetail(recipe.recipePk);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading indicator

      final scaledYield = detail.recipe.defaultYield * multiplier;

      final initialIngs = detail.ingredients.map((ingData) {
        return InitialIngredientInput(
          ingredient: ingData.ingredient,
          amount: ingData.entry.amountNeeded * multiplier,
        );
      }).toList();

      final initialSteps = detail.steps.map((stepData) {
        return InitialStepInput(
          instruction: stepData.instruction,
        );
      }).toList();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecipeEditorScreen(
            isTemporary: true,
            multiplier: multiplier,
            initialName: l10n.scaled_recipe_name(recipe.name, RecipeUtils.formatNumber(multiplier)),
            initialDescription: recipe.description,
            initialYield: RecipeUtils.formatNumber(scaledYield),
            initialYieldName: recipe.yieldName,
            initialProfitMargin: RecipeUtils.formatNumber(recipe.targetProfitMargin * 100),
            initialPrice: RecipeUtils.formatNumber(recipe.targetPricePerPortion),
            initialIngredients: initialIngs,
            initialSteps: initialSteps,
          ),
        ),
      ).then((_) {
        setState(() {
          _expandedRecipeId = null;
        });
      });
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading indicator
        AppSnackBar.showError(context, "Error scaling recipe: $e");
      }
    }
  }
}
