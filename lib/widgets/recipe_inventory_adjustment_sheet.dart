import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../utils/recipe_utils.dart';
import '../utils/ui_utils.dart';
import 'inventory_adjustment_sheet.dart';
import 'make_recipe_sheet.dart';

Future<void> showRecipeInventoryAdjustmentSheet({
  required BuildContext context,
  required RecipeWithFinancials item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: RecipeInventoryAdjustmentSheet(item: item),
    ),
  );
}

class RecipeInventoryAdjustmentSheet extends ConsumerStatefulWidget {
  final RecipeWithFinancials item;

  const RecipeInventoryAdjustmentSheet({super.key, required this.item});

  @override
  ConsumerState<RecipeInventoryAdjustmentSheet> createState() =>
      _RecipeInventoryAdjustmentSheetState();
}

class _RecipeInventoryAdjustmentSheetState
    extends ConsumerState<RecipeInventoryAdjustmentSheet> {
  InventoryAdjustmentMode _mode = InventoryAdjustmentMode.consume;
  late TextEditingController _amountController;
  late TextEditingController _minStockController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _minStockController = TextEditingController(
      text: widget.item.recipe.minimumStock != null
          ? RecipeUtils.formatQuantity(widget.item.recipe.minimumStock!)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  double _computeNewStock() {
    final current = widget.item.recipe.currentStock ?? 0.0;
    final rawText = _amountController.text.trim();
    if (rawText.isEmpty) return current;
    final rawAmount = RecipeUtils.parseFormattedNumber(rawText);

    switch (_mode) {
      case InventoryAdjustmentMode.restock:
        return (current + rawAmount).clamp(0.0, double.infinity).toDouble();
      case InventoryAdjustmentMode.consume:
        return (current - rawAmount).clamp(0.0, double.infinity).toDouble();
      case InventoryAdjustmentMode.exact:
        return rawAmount.clamp(0.0, double.infinity).toDouble();
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final newStock = _computeNewStock();
      final minText = _minStockController.text.trim();
      final double? minStock = minText.isEmpty
          ? null
          : RecipeUtils.parseFormattedNumber(minText)
                .clamp(0.0, double.infinity)
                .toDouble();

      final movementType = switch (_mode) {
        InventoryAdjustmentMode.restock => 'manual_restock',
        InventoryAdjustmentMode.consume => 'sale_consume',
        InventoryAdjustmentMode.exact => 'exact_adjustment',
      };

      await db.updateRecipeStock(
        recipePk: widget.item.recipe.recipePk,
        currentStock: newStock,
        minimumStock: minStock,
        movementType: movementType,
        unitCostSnapshot: widget.item.financials.totalCost,
        unitPriceSnapshot: widget.item.financials.totalRevenue,
      );

      if (mounted) {
        ref.invalidate(recipesWithFinancialsStreamProvider);
        ref.invalidate(
          recipeInventoryMovementsStreamProvider(widget.item.recipe.recipePk),
        );
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, l10n.inventory_adjusted_toast);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, l10n.error_prefix(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recipe = widget.item.recipe;
    final currentStock = recipe.currentStock ?? 0.0;
    final newStock = _computeNewStock();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.inventory_current_stock}: ${RecipeUtils.formatQuantity(currentStock)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  showMakeRecipeSheet(
                    context: context,
                    recipePk: recipe.recipePk,
                  );
                },
                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                label: Text(l10n.make_recipe_button),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<InventoryAdjustmentMode>(
            segments: [
              ButtonSegment(
                value: InventoryAdjustmentMode.restock,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.inventory_mode_restock),
              ),
              ButtonSegment(
                value: InventoryAdjustmentMode.consume,
                icon: const Icon(Icons.remove_rounded, size: 18),
                label: Text(l10n.inventory_mode_consume),
              ),
              ButtonSegment(
                value: InventoryAdjustmentMode.exact,
                icon: const Icon(Icons.drag_handle_rounded, size: 18),
                label: Text(l10n.inventory_mode_exact),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.inventory_amount_label,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.inventory_new_stock_preview(
                RecipeUtils.formatQuantity(newStock),
                '',
              ).trim(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (_mode == InventoryAdjustmentMode.exact) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _minStockController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.inventory_min_stock_label,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildRecentActivitySection(context, l10n, theme),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.inventory_save_adjustment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final movementsAsync = ref.watch(
      recipeInventoryMovementsStreamProvider(widget.item.recipe.recipePk),
    );

    return movementsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (movements) {
        if (movements.isEmpty) {
          return Text(
            l10n.inventory_no_recent_activity,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        final recent = movements.take(5).toList();
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            l10n.inventory_recent_activity,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          children: recent.map((m) {
            final isPositive = m.deltaStock >= 0;
            final sign = isPositive ? '+' : '';
            final label = switch (m.movementType) {
              'recipe_production' => l10n.inventory_movement_production(
                m.reason ?? '',
              ),
              'manual_restock' => l10n.inventory_movement_restock,
              'sale_consume' => l10n.inventory_movement_waste,
              'revert' => l10n.inventory_movement_revert,
              _ => l10n.inventory_movement_exact,
            };
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                '$sign${RecipeUtils.formatQuantity(m.deltaStock)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : theme.colorScheme.error,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
