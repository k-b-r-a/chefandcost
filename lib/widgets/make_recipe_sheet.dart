import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../utils/recipe_utils.dart';
import '../widgets/gooey_toast.dart';

Future<RecipeProductionResult?> showMakeRecipeSheet({
  required BuildContext context,
  required String recipePk,
  double initialMultiplier = 1.0,
}) {
  return showModalBottomSheet<RecipeProductionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: MakeRecipeSheet(
        recipePk: recipePk,
        initialMultiplier: initialMultiplier,
      ),
    ),
  );
}

class MakeRecipeSheet extends ConsumerStatefulWidget {
  final String recipePk;
  final double initialMultiplier;

  const MakeRecipeSheet({
    super.key,
    required this.recipePk,
    this.initialMultiplier = 1.0,
  });

  @override
  ConsumerState<MakeRecipeSheet> createState() => _MakeRecipeSheetState();
}

class _MakeRecipeSheetState extends ConsumerState<MakeRecipeSheet> {
  late double _multiplier;
  late TextEditingController _batchesController;
  late TextEditingController _portionsController;
  final Set<String> _excludedIngredientPks = {};
  bool _isExecuting = false;
  bool _initializedControllers = false;

  @override
  void initState() {
    super.initState();
    _multiplier = widget.initialMultiplier <= 0
        ? 1.0
        : widget.initialMultiplier;
    _batchesController = TextEditingController(
      text: RecipeUtils.formatQuantity(_multiplier),
    );
    _portionsController = TextEditingController();
  }

  @override
  void dispose() {
    _batchesController.dispose();
    _portionsController.dispose();
    super.dispose();
  }

  void _setMultiplier(double next, double defaultYield) {
    final safe = next <= 0 ? 0.25 : next;
    setState(() {
      _multiplier = safe;
      _batchesController.text = RecipeUtils.formatQuantity(safe);
      _portionsController.text = RecipeUtils.formatQuantity(
        safe * defaultYield,
      );
    });
  }

  Future<void> _executeProduction(
    RecipeDetail detail,
    RecipeProductionPreview preview,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    setState(() => _isExecuting = true);

    try {
      final db = ref.read(databaseProvider);
      final activeSpaceId = ref.read(activeGroupProvider)?.id;
      final result = await db.executeRecipeProduction(
        recipePk: detail.recipe.recipePk,
        multiplier: preview.multiplier,
        customPortions: preview.portions,
        excludedIngredientPks: _excludedIngredientPks,
        spaceId: activeSpaceId,
      );

      ref.invalidate(ingredientsStreamProvider);
      ref.invalidate(recipeProductionHistoryStreamProvider);

      if (!mounted) return;
      navigator.pop(result);

      final alertSuffix = result.lowStockAlerts.isNotEmpty
          ? ' • ${l10n.make_recipe_low_stock_alert(result.lowStockAlerts.join(', '))}'
          : '';
      final message = '${l10n.recipe_deduct_success}$alertSuffix';

      if (rootContext.mounted) {
        GooeyToast.showSuccess(
          rootContext,
          message: message,
          duration: const Duration(seconds: 5),
          actionLabel: l10n.make_recipe_undo_action,
          onAction: () async {
            await db.revertRecipeProduction(result.productionPk);
            ref.invalidate(ingredientsStreamProvider);
            ref.invalidate(recipesWithFinancialsStreamProvider);
            ref.invalidate(recipeProductionHistoryStreamProvider);
            if (rootContext.mounted) {
              GooeyToast.showSuccess(
                rootContext,
                message: l10n.make_recipe_reverted_toast,
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        GooeyToast.showError(
          context,
          message: l10n.error_prefix(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final detailAsync = ref.watch(recipeDetailProvider(widget.recipePk));
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final unitsAsync = ref.watch(unitsStreamProvider);
    final isDark = theme.brightness == Brightness.dark;
    final numberColor = isDark ? Colors.white : Colors.black;

    return detailAsync.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.error_prefix(e.toString())),
      ),
      data: (detail) {
        final allUnits = unitsAsync.value ?? const <Unit>[];
        final allIngredients = ingredientsAsync.value ?? const <Ingredient>[];
        final ingMap = {for (final i in allIngredients) i.ingredientPk: i};
        final unitMap = {for (final u in allUnits) u.unitPk: u};

        final resolvedIngredients = detail.ingredients.map((ri) {
          final fresh = ingMap[ri.ingredient.ingredientPk];
          return fresh != null
              ? RecipeIngredientWithData(entry: ri.entry, ingredient: fresh)
              : ri;
        }).toList();

        if (!_initializedControllers) {
          _initializedControllers = true;
          _portionsController.text = RecipeUtils.formatQuantity(
            _multiplier * detail.recipe.defaultYield,
          );
        }

        final preview = RecipeProductionPreview.calculate(
          recipe: detail.recipe,
          ingredients: resolvedIngredients,
          unitMap: unitMap,
          allUnits: allUnits,
          multiplier: _multiplier,
          excludedIngredientPks: _excludedIngredientPks,
        );

        final maxBatches = preview.maxMakeableBatches;
        final yieldName = detail.recipe.yieldName.isNotEmpty
            ? detail.recipe.yieldName
            : l10n.unit_portions.toLowerCase();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.make_recipe_title.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail.recipe.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (maxBatches != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: maxBatches >= _multiplier
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.45,
                                )
                              : theme.colorScheme.errorContainer.withValues(
                                  alpha: 0.45,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: maxBatches >= _multiplier
                                    ? Colors.green
                                    : theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Max ${RecipeUtils.formatQuantity(maxBatches, maxDecimalDigits: 1)}x',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: maxBatches >= _multiplier
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildFinanceMicroCard(
                          theme: theme,
                          label: l10n.make_recipe_batches_label,
                          child: TextField(
                            key: const ValueKey('make_recipe_batches_input'),
                            controller: _batchesController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: numberColor,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              suffixText: 'x',
                            ),
                            onChanged: (val) {
                              final parsed = RecipeUtils.parseFormattedNumber(
                                val,
                              );
                              if (parsed > 0) {
                                setState(() {
                                  _multiplier = parsed;
                                  _portionsController.text =
                                      RecipeUtils.formatQuantity(
                                    parsed * detail.recipe.defaultYield,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFinanceMicroCard(
                          theme: theme,
                          label: l10n.make_recipe_portions_label,
                          child: TextField(
                            key: const ValueKey('make_recipe_portions_input'),
                            controller: _portionsController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: numberColor,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              suffixText: yieldName,
                              suffixStyle: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = RecipeUtils.parseFormattedNumber(
                                val,
                              );
                              if (parsed > 0 &&
                                  detail.recipe.defaultYield > 0) {
                                setState(() {
                                  _multiplier =
                                      parsed / detail.recipe.defaultYield;
                                  _batchesController.text =
                                      RecipeUtils.formatQuantity(_multiplier);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFinanceMicroCard(
                          theme: theme,
                          label: l10n.total_cost,
                          isHighlighted: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: CurrencyText(
                              '${settings.currencySymbol}${RecipeUtils.formatNumber(preview.totalCost)}',
                              currencySymbol: settings.currencySymbol,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: numberColor,
                              ),
                              currencyColor: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [0.5, 1.0, 2.0, 3.0, 5.0].map((mult) {
                      final selected = (_multiplier - mult).abs() < 0.001;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () =>
                              _setMultiplier(mult, detail.recipe.defaultYield),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              RecipeUtils.formatMultiplier(mult),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (preview.hasInsufficient) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.recipe_deduct_insufficient_warning,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...preview.checks.map((check) {
                  final ingPk = check.ingredient.ingredientPk;
                  final isIncluded = !_excludedIngredientPks.contains(ingPk);
                  final statusColor = switch (check.status) {
                    IngredientProductionStatus.ok => Colors.green,
                    IngredientProductionStatus.lowStock => Colors.orange,
                    IngredientProductionStatus.insufficient =>
                      theme.colorScheme.error,
                  };

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          if (isIncluded) {
                            _excludedIngredientPks.add(ingPk);
                          } else {
                            _excludedIngredientPks.remove(ingPk);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: isIncluded ? 0.16 : 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isIncluded
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isIncluded
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                check.ingredient.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: isIncluded
                                      ? null
                                      : TextDecoration.lineThrough,
                                  color: isIncluded
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${RecipeUtils.formatQuantity(check.availableInStockUnit)} → ${RecipeUtils.formatQuantity(check.remainingAfterStockUnit)} ${check.stockUnitSymbol}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isIncluded
                                    ? statusColor
                                    : theme.colorScheme.outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '-${RecipeUtils.formatQuantity(check.requiredInStockUnit)} ${check.stockUnitSymbol}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isIncluded
                                    ? statusColor
                                    : theme.colorScheme.outline,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    key: const ValueKey('confirm_make_recipe_button'),
                    onPressed: _isExecuting || preview.checks.isEmpty
                        ? null
                        : () => _executeProduction(detail, preview),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restaurant_menu_rounded, size: 18),
                    label: Text(
                      '${l10n.recipe_deduct_confirm} • ${RecipeUtils.formatQuantity(preview.portions)} $yieldName',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinanceMicroCard({
    required ThemeData theme,
    required String label,
    required Widget child,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
