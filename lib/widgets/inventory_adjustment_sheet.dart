import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../utils/recipe_utils.dart';
import '../utils/ui_utils.dart';

enum InventoryAdjustmentMode { restock, consume, exact }

Future<void> showInventoryAdjustmentSheet({
  required BuildContext context,
  required Ingredient ingredient,
  required List<Unit> units,
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
      child: InventoryAdjustmentSheet(ingredient: ingredient, units: units),
    ),
  );
}

class InventoryAdjustmentSheet extends ConsumerStatefulWidget {
  final Ingredient ingredient;
  final List<Unit> units;

  const InventoryAdjustmentSheet({
    super.key,
    required this.ingredient,
    required this.units,
  });

  @override
  ConsumerState<InventoryAdjustmentSheet> createState() =>
      _InventoryAdjustmentSheetState();
}

class _InventoryAdjustmentSheetState
    extends ConsumerState<InventoryAdjustmentSheet> {
  InventoryAdjustmentMode _mode = InventoryAdjustmentMode.restock;
  late TextEditingController _amountController;
  late TextEditingController _minStockController;
  late TextEditingController _costController;
  late TextEditingController _qtyForCostController;
  late String _selectedInputUnitPk;
  bool _updatePurchasePrice = false;
  bool _isSaving = false;

  late Map<String, Unit> _unitMap;
  late String _stockUnitPk;

  @override
  void initState() {
    super.initState();
    _unitMap = {for (final u in widget.units) u.unitPk: u};
    _stockUnitPk = widget.ingredient.stockUnit ?? widget.ingredient.unitFk;
    _selectedInputUnitPk = _stockUnitPk;
    _amountController = TextEditingController();
    _minStockController = TextEditingController(
      text: widget.ingredient.minimumStock != null
          ? RecipeUtils.formatNumber(widget.ingredient.minimumStock!)
          : '',
    );
    _costController = TextEditingController(
      text: RecipeUtils.formatNumber(widget.ingredient.cost),
    );
    _qtyForCostController = TextEditingController(
      text: RecipeUtils.formatNumber(widget.ingredient.quantityForCost),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _minStockController.dispose();
    _costController.dispose();
    _qtyForCostController.dispose();
    super.dispose();
  }

  List<Unit> _compatibleUnits() {
    final stockUnit = _unitMap[_stockUnitPk];
    if (stockUnit == null) return widget.units;
    final compatible = widget.units
        .where((u) => u.category == stockUnit.category)
        .toList();
    return compatible.isNotEmpty ? compatible : widget.units;
  }

  double _convertToStockUnit(double amount) {
    if (_selectedInputUnitPk == _stockUnitPk) return amount;
    final inputUnit = _unitMap[_selectedInputUnitPk];
    final stockUnit = _unitMap[_stockUnitPk];
    if (inputUnit == null || stockUnit == null || stockUnit.factorToBase == 0) {
      return amount;
    }
    return amount * (inputUnit.factorToBase / stockUnit.factorToBase);
  }

  double _computeNewStock() {
    final current = widget.ingredient.currentStock ?? 0.0;
    final rawText = _amountController.text.trim();
    if (rawText.isEmpty) return current;
    final rawAmount = RecipeUtils.parseFormattedNumber(rawText);
    final converted = _convertToStockUnit(rawAmount);

    switch (_mode) {
      case InventoryAdjustmentMode.restock:
        return (current + converted).clamp(0.0, double.infinity).toDouble();
      case InventoryAdjustmentMode.consume:
        return (current - converted).clamp(0.0, double.infinity).toDouble();
      case InventoryAdjustmentMode.exact:
        return converted.clamp(0.0, double.infinity).toDouble();
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

      double? newCost;
      double? newQty;
      if (_mode == InventoryAdjustmentMode.restock && _updatePurchasePrice) {
        newCost = RecipeUtils.parseFormattedNumber(_costController.text);
        newQty = RecipeUtils.parseFormattedNumber(_qtyForCostController.text);
        if (newQty <= 0) newQty = 1.0;
      }

      await db.updateIngredientStock(
        ingredientPk: widget.ingredient.ingredientPk,
        currentStock: newStock,
        minimumStock: minStock,
        stockUnit: _stockUnitPk,
        cost: newCost,
        quantityForCost: newQty,
      );

      if (mounted) {
        ref.invalidate(ingredientsStreamProvider);
        if (newCost != null) {
          ref.invalidate(recipesWithFinancialsStreamProvider);
        }
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
    final stockUnit = _unitMap[_stockUnitPk];
    final stockSymbol = stockUnit?.symbol ?? '';
    final currentStock = widget.ingredient.currentStock ?? 0.0;
    final newStock = _computeNewStock();
    final compatibleUnits = _compatibleUnits();

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
          Text(
            widget.ingredient.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.inventory_current_stock}: ${RecipeUtils.formatNumber(currentStock)} $stockSymbol',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
              setState(() {
                _mode = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.inventory_amount_label,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: compatibleUnits.any(
                          (u) => u.unitPk == _selectedInputUnitPk)
                      ? _selectedInputUnitPk
                      : compatibleUnits.firstOrNull?.unitPk,
                  decoration: InputDecoration(
                    labelText: l10n.inventory_unit_label,
                    border: const OutlineInputBorder(),
                  ),
                  items: compatibleUnits
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.unitPk,
                          child: Text(u.symbol),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedInputUnitPk = val);
                    }
                  },
                ),
              ),
            ],
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
                RecipeUtils.formatNumber(newStock),
                stockSymbol,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (_mode == InventoryAdjustmentMode.restock) ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inventory_update_price_toggle),
              value: _updatePurchasePrice,
              onChanged: (val) => setState(() => _updatePurchasePrice = val),
            ),
            if (_updatePurchasePrice) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.inventory_new_cost_label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyForCostController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.inventory_new_qty_label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_mode == InventoryAdjustmentMode.exact) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _minStockController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.inventory_min_stock_label,
                suffixText: stockSymbol,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
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
}
