import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/add_ingredient_screen.dart';
import '../utils/recipe_utils.dart';
import '../utils/ui_utils.dart';
import '../utils/unit_utils.dart';
import 'ingredient_filter_chips_row.dart';

/// Bottom sheet widget for searching, filtering, selecting, and adding ingredients to a recipe.
class GlobalIngredientPickerSheet extends ConsumerStatefulWidget {
  final List<RecipeIngredientData> currentIngredients;
  final void Function(List<(Ingredient, double)> selectedResults) onAddIngredients;
  final void Function(
    BuildContext context,
    WidgetRef ref,
    Ingredient ing,
    List<Ingredient> allIngredients,
    ThemeData theme,
    AppLocalizations l10n,
    StateSetter setModalState,
  ) showPickerIngredientOptionsModal;

  final VoidCallback? onClose;
  final VoidCallback? onOpenNewIngredient;
  final bool isPanel;

  const GlobalIngredientPickerSheet({
    super.key,
    required this.currentIngredients,
    required this.onAddIngredients,
    required this.showPickerIngredientOptionsModal,
    this.onClose,
    this.onOpenNewIngredient,
    this.isPanel = false,
  });

  @override
  ConsumerState<GlobalIngredientPickerSheet> createState() =>
      _GlobalIngredientPickerSheetState();
}

class _GlobalIngredientPickerSheetState
    extends ConsumerState<GlobalIngredientPickerSheet> {
  late final TextEditingController _searchController;
  final Map<String, (Ingredient, TextEditingController, FocusNode)>
      _selectedInModal = {};
  IngredientFilterType _modalFilter = IngredientFilterType.all;
  String? _focusedIngredientPk;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).setQuery('');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final entry in _selectedInModal.values) {
      entry.$2.dispose();
      entry.$3.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currencySymbol;

    return Container(
      height: widget.isPanel ? null : MediaQuery.sizeOf(context).height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: widget.isPanel
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          if (!widget.isPanel) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.select_ingredient_recipe_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchController,
                      onChanged: (val) => ref
                          .read(searchQueryProvider.notifier)
                          .setQuery(val),
                      decoration: InputDecoration(
                        hintText: l10n.search_hint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(searchQueryProvider.notifier)
                                      .setQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  if (widget.onOpenNewIngredient != null) {
                    widget.onOpenNewIngredient!();
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddIngredientScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                tooltip: l10n.new_ingredient_button,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IngredientFilterChipsRow(
            currentFilter: _modalFilter,
            onFilterSelected: (filter) {
              setState(() {
                _modalFilter = filter;
              });
            },
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final query = ref.watch(searchQueryProvider);
                final ingredientsAsync = query.isEmpty
                    ? ref.watch(ingredientsStreamProvider)
                    : ref.watch(relatedIngredientsProvider(query));
                final unitsAsync = ref.watch(unitsProvider);

                return ingredientsAsync.when(
                  data: (ingredients) {
                    return unitsAsync.when(
                      data: (units) {
                        final unitMap = {for (var u in units) u.unitPk: u};
                        final displayedIngredients =
                            UnitUtils.filterIngredients(
                          ingredients: ingredients,
                          unitMap: unitMap,
                          filter: _modalFilter,
                          searchQuery: query,
                        );

                        if (displayedIngredients.isEmpty) {
                          final category = _modalFilter ==
                                  IngredientFilterType.liquids
                              ? 'volume'
                              : _modalFilter == IngredientFilterType.solids
                                  ? 'mass'
                                  : _modalFilter == IngredientFilterType.pieces
                                      ? 'count'
                                      : null;
                          return AppEmptyState(
                            icon: UnitUtils.getCategoryIcon(category),
                            message: query.isEmpty &&
                                    _modalFilter == IngredientFilterType.all
                                ? l10n.no_ingredients
                                : l10n.no_ingredients_found,
                          );
                        }

                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is UserScrollNotification &&
                                notification.direction !=
                                    ScrollDirection.idle) {
                              if (_focusedIngredientPk != null) {
                                FocusScope.of(context).unfocus();
                                if (mounted) {
                                  setState(() {
                                    _focusedIngredientPk = null;
                                  });
                                }
                              }
                            }
                            return false;
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: displayedIngredients.length,
                            itemBuilder: (context, index) {
                              final ing = displayedIngredients[index];
                              final isAlreadyInRecipe = widget.currentIngredients
                                  .any(
                                (i) =>
                                    i.ingredient.ingredientPk ==
                                    ing.ingredientPk,
                              );
                              final isSelected = _selectedInModal.containsKey(
                                ing.ingredientPk,
                              );
                              final itemColor = RecipeUtils.getIngredientColor(
                                ing.name,
                                theme.colorScheme,
                              );

                              final bool hasFocus =
                                  _focusedIngredientPk != null;
                              final bool isThisFocused =
                                  _focusedIngredientPk == ing.ingredientPk;
                              final bool shouldDim =
                                  hasFocus && !isThisFocused;

                              final animDuration = settings.animationsEnabled
                                  ? const Duration(milliseconds: 150)
                                  : Duration.zero;

                              return RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: AnimatedOpacity(
                                    duration: animDuration,
                                    opacity: shouldDim ? 0.35 : 1.0,
                                    child: AnimatedContainer(
                                      duration: animDuration,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primaryContainer
                                              .withValues(
                                              alpha: isThisFocused ? 0.28 : 0.15,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                        width: isThisFocused ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isThisFocused
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ListTile(
                                      enabled: !isAlreadyInRecipe,
                                      onLongPress: () {
                                        widget.showPickerIngredientOptionsModal(
                                          context,
                                          ref,
                                          ing,
                                          ingredients,
                                          theme,
                                          l10n,
                                          setState,
                                        );
                                      },
                                      leading: CircleAvatar(
                                        backgroundColor: itemColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: isSelected
                                            ? Icon(
                                                Icons.check,
                                                color: theme.colorScheme.primary,
                                              )
                                            : Icon(
                                                Icons.egg_outlined,
                                                size: 20,
                                                color: itemColor,
                                              ),
                                      ),
                                      title: Text(
                                        ing.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: isAlreadyInRecipe
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      subtitle: unitsAsync.when(
                                        data: (units) {
                                          final unit = units
                                              .firstWhere(
                                                (u) => u.unitPk == ing.unitFk,
                                              )
                                              .symbol;
                                          return CurrencyText(
                                            l10n.ingredient_price_per_quantity(
                                              '$currency${RecipeUtils.formatNumber(ing.cost)}',
                                              RecipeUtils.formatNumber(
                                                ing.quantityForCost,
                                              ),
                                              unit,
                                            ),
                                            currencySymbol: currency,
                                          );
                                        },
                                        loading: () => const Text('...'),
                                        error: (_, _) => const Text('Error'),
                                      ),
                                      trailing: isAlreadyInRecipe
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.grey,
                                            )
                                          : isSelected
                                              ? SizedBox(
                                                  width: 80,
                                                  child: TextField(
                                                    controller:
                                                        _selectedInModal[ing
                                                                .ingredientPk]!
                                                            .$2,
                                                    focusNode:
                                                        _selectedInModal[ing
                                                                .ingredientPk]!
                                                            .$3,
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                    textInputAction:
                                                        TextInputAction.done,
                                                    onTap: () {
                                                      final ctrl =
                                                          _selectedInModal[ing
                                                                  .ingredientPk]
                                                              ?.$2;
                                                      if (ctrl != null &&
                                                          ctrl.text.isNotEmpty) {
                                                        ctrl.selection =
                                                            TextSelection(
                                                          baseOffset: 0,
                                                          extentOffset:
                                                              ctrl.text.length,
                                                        );
                                                      }
                                                    },
                                                    onEditingComplete: () {
                                                      FocusScope.of(context)
                                                          .unfocus();
                                                    },
                                                    onSubmitted: (_) {
                                                      FocusScope.of(context)
                                                          .unfocus();
                                                    },
                                                    textAlign: TextAlign.end,
                                                    autofocus: true,
                                                    scrollPadding:
                                                        const EdgeInsets.all(
                                                            120),
                                                    decoration: InputDecoration(
                                                      hintText: '0',
                                                      suffixText: unitsAsync
                                                          .maybeWhen(
                                                        data: (units) {
                                                          final settings =
                                                              ref.read(
                                                            settingsProvider,
                                                          );
                                                          final sourceUnit =
                                                              units
                                                                  .where(
                                                                    (u) =>
                                                                        u.unitPk ==
                                                                        ing.unitFk,
                                                                  )
                                                                  .firstOrNull;
                                                          final targetUnit =
                                                              sourceUnit != null
                                                                  ? UnitUtils
                                                                      .getTargetUnit(
                                                                      sourceUnit,
                                                                      units,
                                                                      settings,
                                                                    )
                                                                  : null;
                                                          return targetUnit
                                                                  ?.symbol ??
                                                              sourceUnit
                                                                  ?.symbol ??
                                                              '';
                                                        },
                                                        orElse: () => '',
                                                      ),
                                                      suffixStyle:
                                                          const TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                      isDense: true,
                                                      border:
                                                          const UnderlineInputBorder(),
                                                    ),
                                                    onChanged: (val) =>
                                                        setState(() {}),
                                                  ),
                                                )
                                              : null,
                                      onTap: () {
                                        if (isAlreadyInRecipe) return;
                                        setState(() {
                                          if (isSelected) {
                                            if (_focusedIngredientPk ==
                                                ing.ingredientPk) {
                                              final entry =
                                                  _selectedInModal.remove(
                                                ing.ingredientPk,
                                              );
                                              _focusedIngredientPk = null;
                                              entry?.$2.dispose();
                                              entry?.$3.dispose();
                                            } else {
                                              _focusedIngredientPk =
                                                  ing.ingredientPk;
                                              final entry = _selectedInModal[
                                                  ing.ingredientPk];
                                              if (entry != null) {
                                                entry.$3.requestFocus();
                                                if (entry.$2.text.isNotEmpty) {
                                                  entry.$2.selection =
                                                      TextSelection(
                                                    baseOffset: 0,
                                                    extentOffset:
                                                        entry.$2.text.length,
                                                  );
                                                }
                                              }
                                            }
                                          } else {
                                            final controller =
                                                TextEditingController();
                                            final focusNode = FocusNode();
                                            _focusedIngredientPk =
                                                ing.ingredientPk;

                                            focusNode.addListener(() {
                                              if (!mounted) return;
                                              if (focusNode.hasFocus) {
                                                setState(() {
                                                  _focusedIngredientPk =
                                                      ing.ingredientPk;
                                                });
                                                if (controller
                                                    .text.isNotEmpty) {
                                                  controller.selection =
                                                      TextSelection(
                                                    baseOffset: 0,
                                                    extentOffset: controller
                                                        .text.length,
                                                  );
                                                }
                                              } else if (_focusedIngredientPk ==
                                                  ing.ingredientPk) {
                                                setState(() {
                                                  _focusedIngredientPk = null;
                                                });
                                              }
                                            });

                                            _selectedInModal[ing
                                                .ingredientPk] = (
                                              ing,
                                              controller,
                                              focusNode,
                                            );
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              focusNode.requestFocus();
                                              if (controller
                                                  .text.isNotEmpty) {
                                                controller.selection =
                                                    TextSelection(
                                                  baseOffset: 0,
                                                  extentOffset:
                                                      controller.text.length,
                                                );
                                              }
                                            });
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                            },
                          ),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(e.toString())),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                );
              },
            ),
          ),
          if (_selectedInModal.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    SystemChannels.textInput.invokeMethod('TextInput.hide');

                    final settings = ref.read(settingsProvider);
                    final units = ref.read(unitsProvider).value ?? [];
                    final List<(Ingredient, double)> results = [];

                    _selectedInModal.forEach((_, value) {
                      final ing = value.$1;
                      final controller = value.$2;
                      final sourceUnit = units
                          .where((u) => u.unitPk == ing.unitFk)
                          .firstOrNull;
                      final targetUnit = sourceUnit != null
                          ? UnitUtils.getTargetUnit(
                              sourceUnit,
                              units,
                              settings,
                            )
                          : null;

                      double amountInSource =
                          RecipeUtils.parseFormattedNumber(
                        controller.text,
                      );
                      if (sourceUnit != null &&
                          targetUnit != null &&
                          sourceUnit.category == targetUnit.category &&
                          sourceUnit.category != null) {
                        final base =
                            amountInSource * targetUnit.factorToBase;
                        amountInSource = base / sourceUnit.factorToBase;
                      }

                      results.add((ing, amountInSource));
                    });

                    widget.onAddIngredients(results);
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.add_task),
                  label: Text(
                    "${l10n.add_button} (${_selectedInModal.length})"
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
