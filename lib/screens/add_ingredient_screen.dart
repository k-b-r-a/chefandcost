import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../provider/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/recipe_utils.dart';
import '../utils/ui_utils.dart';
import 'compare_ingredients_screen.dart';
import '../provider/settings_provider.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  final Ingredient? ingredient;
  final String? initialName;
  final VoidCallback? onClose;
  const AddIngredientScreen({
    super.key,
    this.ingredient,
    this.initialName,
    this.onClose,
  });

  @override
  ConsumerState<AddIngredientScreen> createState() =>
      _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _quantityController;
  String? _selectedUnitPk;
  String? _initialUnitPk;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.ingredient?.name ?? widget.initialName ?? '',
    );
    // automatic load: trigger search if opening existing ingredient
    _searchQuery = _nameController.text.trim();

    _nameController.addListener(() {
      setState(() {
        _searchQuery = _nameController.text.trim();
      });
    });
    _costController = TextEditingController(
      text: widget.ingredient != null ? RecipeUtils.formatNumber(widget.ingredient!.cost) : '',
    );
    _quantityController = TextEditingController(
      text: widget.ingredient != null ? RecipeUtils.formatNumber(widget.ingredient!.quantityForCost) : '',
    );
    _selectedUnitPk = widget.ingredient?.unitFk;
    _initialUnitPk = widget.ingredient?.unitFk;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// saves the ingredient to the database
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate() && _selectedUnitPk != null) {
      setState(() => _isLoading = true);
      try {
        final db = ref.read(databaseProvider);
        final name = _nameController.text.trim();
        final cost = RecipeUtils.parseFormattedNumber(_costController.text);
        final quantity = RecipeUtils.parseFormattedNumber(_quantityController.text);

        if (widget.ingredient == null) {
          await db.insertIngredient(
            IngredientsCompanion.insert(
              name: name,
              cost: cost,
              quantityForCost: quantity,
              unitFk: _selectedUnitPk!,
            ),
          );
        } else {
          await db.updateIngredient(
            widget.ingredient!.copyWith(
              name: name,
              cost: cost,
              quantityForCost: quantity,
              unitFk: _selectedUnitPk!,
              dateTimeModified: drift.Value(DateTime.now()),
            ),
          );
        }

        if (mounted) {
          _isDismissing = true;
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, l10n.error_prefix(e.toString()));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (_selectedUnitPk == null) {
      if (mounted) {
        AppSnackBar.showError(context, l10n.error_select_unit);
      }
    }
  }

  bool _hasChanges() {
    if (widget.ingredient == null) {
      final initialName = widget.initialName?.trim() ?? '';
      return _nameController.text.trim() != initialName ||
          _costController.text.trim().isNotEmpty ||
          _quantityController.text.trim().isNotEmpty ||
          (_initialUnitPk != null && _selectedUnitPk != _initialUnitPk);
    } else {
      final ing = widget.ingredient!;
      return _nameController.text.trim() != ing.name ||
          RecipeUtils.parseFormattedNumber(_costController.text) != ing.cost ||
          RecipeUtils.parseFormattedNumber(_quantityController.text) !=
              ing.quantityForCost ||
          _selectedUnitPk != ing.unitFk;
    }
  }

  void _dismiss() {
    _isDismissing = true;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleCloseOrBack() async {
    if (!_hasChanges()) {
      _dismiss();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const ValueKey('unsaved_ingredient_dialog'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.help_outline_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.unsaved_changes_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.localeName == 'es'
              ? '¿Deseas guardar los cambios del ingrediente o descartarlos?'
              : 'Do you want to save or discard changes to this ingredient?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('unsaved_ingredient_cancel'),
            onPressed: () => Navigator.of(dialogCtx).pop('cancel'),
            child: Text(l10n.cancel_button),
          ),
          TextButton(
            key: const ValueKey('unsaved_ingredient_discard'),
            onPressed: () => Navigator.of(dialogCtx).pop('discard'),
            child: Text(
              l10n.discard_button,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton(
            key: const ValueKey('unsaved_ingredient_save'),
            onPressed: () => Navigator.of(dialogCtx).pop('save'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.save_button),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == 'discard') {
      _dismiss();
    } else if (result == 'save') {
      await _save();
    }
  }

  /// navigates to comparison screen for merging
  void _compareAndMerge(Ingredient other) {
    final l10n = AppLocalizations.of(context)!;
    final ing1 = widget.ingredient ??
        Ingredient(
          ingredientPk: const Uuid().v4(),
          name: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : l10n.new_ingredient_button,
          cost: double.tryParse(_costController.text) ?? 0.0,
          quantityForCost: double.tryParse(_quantityController.text) ?? 1.0,
          unitFk: _selectedUnitPk ?? '',
          dateCreated: DateTime.now(),
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompareIngredientsScreen(
          ingredient1: ing1,
          ingredient2: other,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitsAsync = ref.watch(unitsProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return PopScope(
      canPop: _isDismissing || !_hasChanges(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleCloseOrBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: widget.onClose != null || Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.localeName == 'es' ? 'Volver' : 'Back',
                  onPressed: _handleCloseOrBack,
                )
              : null,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.ingredient == null
                ? l10n.add_ingredient_title
                : l10n.edit_ingredient_title,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.ingredient_name,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.validation_required
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            decoration: InputDecoration(
                              labelText: l10n.ingredient_cost,
                              prefixText: '${settings.currencySymbol} ',
                              prefixStyle: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) => value == null || value.isEmpty
                                ? l10n.validation_required
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: l10n.ingredient_quantity,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) => value == null || value.isEmpty
                                ? l10n.validation_required
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    unitsAsync.when(
                      data: (units) {
                        if (_selectedUnitPk == null && units.isNotEmpty) {
                          _selectedUnitPk = units.first.unitPk;
                          _initialUnitPk ??= _selectedUnitPk;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedUnitPk,
                          decoration: InputDecoration(
                            labelText: l10n.units_title,
                            border: const OutlineInputBorder(),
                          ),
                          items: units.map((unit) {
                            return DropdownMenuItem(
                              value: unit.unitPk,
                              child: Text(
                                '${RecipeUtils.translateUnitName(context, unit.name)} (${unit.symbol})',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnitPk = value;
                            });
                          },
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text(l10n.error_prefix(e.toString())),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        child: Text(l10n.save_button.toUpperCase()),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_searchQuery.isNotEmpty) ...[
                      Text(
                        l10n.related_ingredients,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ref
                          .watch(relatedIngredientsProvider(_searchQuery))
                          .when(
                            data: (ingredients) {
                              final filtered = ingredients
                                  .where(
                                    (i) =>
                                        i.ingredientPk !=
                                        widget.ingredient?.ingredientPk,
                                  )
                                  .toList();
                              if (filtered.isEmpty) {
                                return Text(l10n.no_similar_ingredients);
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return ListTile(
                                    title: Text(item.name),
                                    subtitle: Text(
                                      l10n.ingredient_price_per_quantity(
                                        RecipeUtils.formatNumber(item.cost),
                                        RecipeUtils.formatNumber(
                                          item.quantityForCost,
                                        ),
                                        '', // symbol empty for related list now
                                      ),
                                    ),
                                    trailing: OutlinedButton.icon(
                                      onPressed: () => _compareAndMerge(item),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: theme
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(0, 36),
                                      ),
                                      icon: const Icon(
                                        Icons.compare_arrows,
                                        size: 18,
                                      ),
                                      label: Text(
                                        l10n.compare_button,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      // detail view could be here
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, s) =>
                                Text(l10n.error_prefix(e.toString())),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
