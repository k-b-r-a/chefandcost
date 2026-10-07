import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../provider/timers_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/recipe_utils.dart';
import '../utils/ingredient_text_editing_controller.dart';
import '../utils/unit_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/global_ingredient_picker_sheet.dart';
import '../provider/web_layout_provider.dart';
import '../provider/cloud_sync_provider.dart';
import 'add_ingredient_screen.dart';
import 'kitchen_timers_screen.dart';
import 'compare_ingredients_screen.dart';

enum WebRecipeRightPanelMode {
  financials,
  ingredientPicker,
  newIngredient,
  editIngredient,
}

class InitialIngredientInput {
  final Ingredient ingredient;
  final double amount;
  const InitialIngredientInput({
    required this.ingredient,
    required this.amount,
  });
}

class InitialStepInput {
  final String instruction;
  const InitialStepInput({
    required this.instruction,
  });
}

class RecipeTimerData {
  final String id;
  final TextEditingController nameController;
  int durationSeconds;

  RecipeTimerData({
    required this.id,
    required String name,
    required this.durationSeconds,
  }) : nameController = TextEditingController(text: name);

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }
}

class RecipeEditorScreen extends ConsumerStatefulWidget {
  final String? recipeId;
  final double multiplier;
  final bool isTemporary;
  final String? initialName;
  final String? initialDescription;
  final String? initialYield;
  final String? initialYieldName;
  final String? initialProfitMargin;
  final String? initialPrice;
  final List<InitialIngredientInput>? initialIngredients;
  final List<InitialStepInput>? initialSteps;

  const RecipeEditorScreen({
    super.key,
    this.recipeId,
    this.multiplier = 1.0,
    this.isTemporary = false,
    this.initialName,
    this.initialDescription,
    this.initialYield,
    this.initialYieldName,
    this.initialProfitMargin,
    this.initialPrice,
    this.initialIngredients,
    this.initialSteps,
    this.onClose,
  });

  final VoidCallback? onClose;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeSnapshot {
  final String name;
  final String description;
  final String yieldVal;
  final String yieldName;
  final String margin;
  final String price;
  final List<({String pk, double amount, String? targetUnitPk})> ingredients;
  final List<String> steps;
  final List<({String name, int seconds})> timers;

  _RecipeSnapshot({
    required this.name,
    required this.description,
    required this.yieldVal,
    required this.yieldName,
    required this.margin,
    required this.price,
    required this.ingredients,
    required this.steps,
    required this.timers,
  });

  bool hasChanged({
    required String currentName,
    required String currentDescription,
    required String currentYield,
    required String currentYieldName,
    required String currentMargin,
    required String currentPrice,
    required List<RecipeIngredientData> currentIngredients,
    required List<RecipeStepData> currentSteps,
    required List<RecipeTimerData> currentTimers,
  }) {
    if (name.trim() != currentName.trim()) return true;
    if (description.trim() != currentDescription.trim()) return true;
    if (RecipeUtils.parseFormattedNumber(yieldVal) !=
        RecipeUtils.parseFormattedNumber(currentYield)) {
      return true;
    }
    if (yieldName.trim() != currentYieldName.trim()) return true;
    if (RecipeUtils.parseFormattedNumber(margin) !=
        RecipeUtils.parseFormattedNumber(currentMargin)) {
      return true;
    }
    if (RecipeUtils.parseFormattedNumber(price) !=
        RecipeUtils.parseFormattedNumber(currentPrice)) {
      return true;
    }

    // Ingredients comparison
    if (ingredients.length != currentIngredients.length) return true;
    for (int i = 0; i < ingredients.length; i++) {
      final initial = ingredients[i];
      final current = currentIngredients[i];
      if (initial.pk != current.ingredient.ingredientPk) return true;
      if ((initial.amount - current.amount).abs() > 0.0001) return true;
      if (initial.targetUnitPk != current.targetUnit?.unitPk) return true;
    }

    // Steps comparison
    final nonBlankCurrentSteps = currentSteps
        .where((s) => s.instructionController.text.trim().isNotEmpty)
        .toList();
    final nonBlankInitialSteps =
        steps.where((s) => s.trim().isNotEmpty).toList();
    if (nonBlankInitialSteps.length != nonBlankCurrentSteps.length) return true;
    for (int i = 0; i < nonBlankInitialSteps.length; i++) {
      if (nonBlankInitialSteps[i].trim() !=
          nonBlankCurrentSteps[i].instructionController.text.trim()) {
        return true;
      }
    }

    // Timers comparison
    if (timers.length != currentTimers.length) return true;
    for (int i = 0; i < timers.length; i++) {
      if (timers[i].name != currentTimers[i].nameController.text.trim()) {
        return true;
      }
      if (timers[i].seconds != currentTimers[i].durationSeconds) return true;
    }

    return false;
  }
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  String get currency => ref.watch(settingsProvider).currencySymbol;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCalculating = false;
  bool _needsRecalculate = false;
  bool _isDescriptionExpanded = true;
  bool _showBottomFinancials = false;
  bool _isEditingName = false;
  WebRecipeRightPanelMode _webRightPanelMode = WebRecipeRightPanelMode.financials;
  WebRecipeRightPanelMode _previousRightPanelMode = WebRecipeRightPanelMode.financials;
  Ingredient? _selectedIngredientForEdit;
  String? _newIngredientInitialName;
  late final Future<bool> Function() _guardFunction;
  RecipeCanLeaveGuardNotifier? _guardNotifier;
  _RecipeSnapshot? _initialSnapshot;

  // controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _yieldController = TextEditingController(text: '1');
  final _yieldNameController = TextEditingController();
  final _profitMarginController = TextEditingController(text: '30');
  final _priceController = TextEditingController(text: '0');
  final _totalSaleController = TextEditingController(text: '0');

  final _nameFocusNode = FocusNode();
  final _webNameFocusNode = FocusNode();
  final _profitMarginFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _totalSaleFocusNode = FocusNode();
  final _yieldFocusNode = FocusNode();
  final _webYieldFocusNode = FocusNode();
  final _rightPanelYieldFocusNode = FocusNode();

  // ingredients, steps and timers state
  final List<RecipeIngredientData> _ingredients = [];
  final List<RecipeStepData> _steps = [];
  final List<RecipeTimerData> _recipeTimers = [];
  RecipeIngredientSort _ingredientSort = RecipeIngredientSort.defaultOrder;

  // ui state for calculations
  double _currentRevenue = 0.0;
  double _currentTotalRevenue = 0.0;
  double _currentTotalCost = 0.0;
  double _currentCostPerPortion = 0.0;
  double _currentProfitPerPortion = 0.0;
  double _currentTotalWeightGrams = 0.0;
  double _currentTotalVolumeMl = 0.0;

  // Temporary scaling tracking
  bool _isScaledTemporarily = false;
  double? _activeScaleMultiplier;
  Map<String, String>? _unscaledIngredientAmounts;
  String? _unscaledYieldText;

  _RecipeSnapshot _createSnapshot() {
    return _RecipeSnapshot(
      name: _nameController.text,
      description: _descriptionController.text,
      yieldVal: _yieldController.text,
      yieldName: _yieldNameController.text,
      margin: _profitMarginController.text,
      price: _priceController.text,
      ingredients: _ingredients
          .map(
            (e) => (
              pk: e.ingredient.ingredientPk,
              amount: e.amount,
              targetUnitPk: e.targetUnit?.unitPk,
            ),
          )
          .toList(),
      steps: _steps.map((e) => e.instructionController.text).toList(),
      timers: _recipeTimers
          .map(
            (e) => (
              name: e.nameController.text.trim(),
              seconds: e.durationSeconds,
            ),
          )
          .toList(),
    );
  }

  bool _hasUnsavedChanges() {
    if (widget.recipeId == null && !widget.isTemporary) {
      return _nameController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _ingredients.isNotEmpty ||
          _steps.any((s) => s.instructionController.text.trim().isNotEmpty) ||
          _recipeTimers.isNotEmpty;
    }
    if (_initialSnapshot == null) return false;
    return _initialSnapshot!.hasChanged(
      currentName: _nameController.text,
      currentDescription: _descriptionController.text,
      currentYield: _yieldController.text,
      currentYieldName: _yieldNameController.text,
      currentMargin: _profitMarginController.text,
      currentPrice: _priceController.text,
      currentIngredients: _ingredients,
      currentSteps: _steps,
      currentTimers: _recipeTimers,
    );
  }

  void _onNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isTemporary && widget.multiplier != 1.0) {
      _isScaledTemporarily = true;
      _activeScaleMultiplier = widget.multiplier;
    }
    _guardFunction = () => _onPopRequested();
    _guardNotifier = ref.read(recipeCanLeaveGuardProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _guardNotifier?.setGuard(_guardFunction);
      }
    });
    final initialLayout = ref.read(webLayoutProvider);
    if (initialLayout.selectedIngredient != null) {
      _selectedIngredientForEdit = initialLayout.selectedIngredient;
      _webRightPanelMode = WebRecipeRightPanelMode.editIngredient;
    } else if (initialLayout.isCreatingIngredient) {
      _webRightPanelMode = WebRecipeRightPanelMode.newIngredient;
    }
    _isEditingName = widget.recipeId == null && !widget.isTemporary;
    _nameController.addListener(_onNameChanged);
    _isDescriptionExpanded = widget.recipeId == null && !widget.isTemporary;
    _yieldController.addListener(_calculateSummary);
    _priceController.addListener(_calculateSummary);
    _profitMarginController.addListener(_calculateSummary);
    _totalSaleController.addListener(_calculateSummary);

    _yieldFocusNode.addListener(() {
      if (_yieldFocusNode.hasFocus) {
        if (_yieldController.text.isNotEmpty) {
          _yieldController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _yieldController.text.length,
          );
        }
      } else {
        if (_yieldController.text.isNotEmpty) {
          final yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);
          _yieldController.text = RecipeUtils.formatNumber(
            yieldVal <= 0 ? 1 : yieldVal,
            decimalDigits: 0,
          );
        }
      }
    });
    _webYieldFocusNode.addListener(() {
      if (_webYieldFocusNode.hasFocus) {
        if (_yieldController.text.isNotEmpty) {
          _yieldController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _yieldController.text.length,
          );
        }
      } else {
        if (_yieldController.text.isNotEmpty) {
          final yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);
          _yieldController.text = RecipeUtils.formatNumber(
            yieldVal <= 0 ? 1 : yieldVal,
            decimalDigits: 0,
          );
        }
      }
    });
    _rightPanelYieldFocusNode.addListener(() {
      if (_rightPanelYieldFocusNode.hasFocus) {
        if (_yieldController.text.isNotEmpty) {
          _yieldController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _yieldController.text.length,
          );
        }
      } else {
        if (_yieldController.text.isNotEmpty) {
          final yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);
          _yieldController.text = RecipeUtils.formatNumber(
            yieldVal <= 0 ? 1 : yieldVal,
            decimalDigits: 0,
          );
        }
      }
    });
    _profitMarginFocusNode.addListener(() {
      if (_profitMarginFocusNode.hasFocus) {
        if (_profitMarginController.text.isNotEmpty) {
          _profitMarginController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _profitMarginController.text.length,
          );
        }
      } else {
        if (_profitMarginController.text.isNotEmpty) {
          final marginVal = RecipeUtils.parseFormattedNumber(_profitMarginController.text);
          _profitMarginController.text = RecipeUtils.formatNumber(
            marginVal,
            decimalDigits: 0,
          );
        }
      }
    });
    _priceFocusNode.addListener(() {
      if (_priceFocusNode.hasFocus && _priceController.text.isNotEmpty) {
        _priceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _priceController.text.length,
        );
      }
    });
    _totalSaleFocusNode.addListener(() {
      if (_totalSaleFocusNode.hasFocus && _totalSaleController.text.isNotEmpty) {
        _totalSaleController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _totalSaleController.text.length,
        );
      }
    });

    if (widget.isTemporary) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadTemporaryRecipeData();
          setState(() {
            _isLoading = false;
          });
          _calculateSummary();
        }
      });
    } else if (widget.recipeId != null) {
      _loadRecipeData();
    } else {
      // Initial empty step for new recipes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addStep(shouldFocus: false);
      });
    }
  }

  void _loadTemporaryRecipeData() {
    final theme = Theme.of(context);
    _nameController.text = widget.initialName ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _yieldController.text = widget.initialYield ?? '1';
    _yieldNameController.text = widget.initialYieldName ?? '';
    _profitMarginController.text = widget.initialProfitMargin ?? '30';
    _priceController.text = widget.initialPrice ?? '0';

    if (widget.initialIngredients != null) {
      for (var initIng in widget.initialIngredients!) {
        final data = RecipeIngredientData(
          ingredient: initIng.ingredient,
          initialAmount: RecipeUtils.formatNumber(
            initIng.amount,
            decimalDigits: 2,
          ),
        );
        data.amountController.addListener(_calculateSummary);
        _ingredients.add(data);
      }
    }

    if (widget.initialSteps != null) {
      for (var initStep in widget.initialSteps!) {
        _steps.add(
          RecipeStepData(
            initialInstruction: initStep.instruction,
            customController: IngredientTextEditingController(
              text: initStep.instruction,
              ingredients: _ingredients.map((e) => e.ingredient).toList(),
              colorScheme: theme.colorScheme,
            ),
          ),
        );
      }
    }

    if (_steps.isEmpty) _addStep(shouldFocus: false);
    _initialSnapshot = _createSnapshot();
  }

  void _showScaleByIngredientDialog({RecipeIngredientData? targetData, List<Unit>? units}) {
    final l10n = AppLocalizations.of(context)!;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.recipe_editor_add_ingredients_to_scale,
            softWrap: true,
          ),
        ),
      );
      return;
    }

    final allUnits = units ?? ref.read(unitsProvider).value ?? [];
    final theme = Theme.of(context);

    int selectedIdx = targetData != null ? _ingredients.indexOf(targetData) : 0;
    if (selectedIdx < 0) selectedIdx = 0;

    final initialIngData = _ingredients[selectedIdx];
    final initialAmt = RecipeUtils.parseFormattedNumber(initialIngData.amountController.text);
    final targetController = TextEditingController(
      text: RecipeUtils.formatNumber(initialAmt > 0 ? initialAmt : 1.0),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeIng = _ingredients[selectedIdx];
            final baseAmt = RecipeUtils.parseFormattedNumber(activeIng.amountController.text);
            final unitSymbol = activeIng.targetUnit?.symbol ??
                activeIng.sourceUnit?.symbol ??
                allUnits.where((u) => u.unitPk == activeIng.ingredient.unitFk).firstOrNull?.symbol ??
                '';

            final targetAmt = RecipeUtils.parseFormattedNumber(targetController.text);
            final multiplier = baseAmt > 0 ? targetAmt / baseAmt : 1.0;
            final isValid = targetAmt > 0 && baseAmt > 0;

            final currentYield = RecipeUtils.parseFormattedNumber(_yieldController.text);
            final baseYield = currentYield <= 0 ? 1.0 : currentYield;
            final scaledYield = baseYield * (isValid ? multiplier : 1.0);

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.scale_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scale_by_ingredient,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.scale_by_ingredient_desc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    if (_ingredients.length > 1) ...[
                      Text(
                        l10n.select_ingredient,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedIdx,
                            isExpanded: true,
                            items: List.generate(_ingredients.length, (i) {
                              final ing = _ingredients[i];
                              return DropdownMenuItem<int>(
                                value: i,
                                child: Text(
                                  ing.ingredient.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            onChanged: (newIdx) {
                              if (newIdx != null && newIdx != selectedIdx) {
                                setDialogState(() {
                                  selectedIdx = newIdx;
                                  final newAmt = RecipeUtils.parseFormattedNumber(_ingredients[newIdx].amountController.text);
                                  targetController.text = RecipeUtils.formatNumber(newAmt > 0 ? newAmt : 1.0);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Text(
                        activeIng.ingredient.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.current_quantity,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${RecipeUtils.formatNumber(baseAmt)} $unitSymbol',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.target_quantity,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        suffixText: unitSymbol,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isValid
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                            : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isValid
                              ? theme.colorScheme.primary.withValues(alpha: 0.4)
                              : theme.colorScheme.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.scale_factor_label(RecipeUtils.formatNumber(isValid ? multiplier : 0.0, decimalDigits: 2)),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isValid ? theme.colorScheme.primary : theme.colorScheme.error,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              if (isValid) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${multiplier >= 1 ? "+" : ""}${RecipeUtils.formatNumber(((multiplier - 1) * 100), decimalDigits: 0)}%',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${l10n.unit_portions}: ${RecipeUtils.formatNumber(baseYield)} → ${RecipeUtils.formatNumber(scaledYield, decimalDigits: scaledYield % 1 == 0 ? 0 : 2)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.discard_button, softWrap: true),
                ),
                TextButton(
                  onPressed: isValid && multiplier > 0
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showScaledRecipeDialog(multiplier);
                        }
                      : null,
                  child: Text(l10n.scale_preview_button, softWrap: true),
                ),
                FilledButton(
                  key: const ValueKey('apply_scale_by_ingredient_button'),
                  onPressed: isValid && multiplier > 0
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _applyScaledAmounts(multiplier, scaledYield);
                        }
                      : null,
                  child: Text(
                    l10n.apply_button,
                    softWrap: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openTemporaryScaledRecipe(double multiplier) {
    if (multiplier == -1.0) {
      _showScaleByIngredientDialog();
    } else {
      _showScaledRecipeDialog(multiplier);
    }
  }

  void _showScaledRecipeDialog(double multiplier) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentYield = RecipeUtils.parseFormattedNumber(_yieldController.text);
    final baseYield = currentYield <= 0 ? 1.0 : currentYield;
    final scaledYield = baseYield * multiplier;
    final scaledYieldText = RecipeUtils.formatNumber(
      scaledYield,
      decimalDigits: scaledYield % 1 == 0 ? 0 : 2,
    );
    final unitName = _yieldNameController.text.trim().isNotEmpty
        ? _yieldNameController.text.trim()
        : l10n.unit_portions.toLowerCase();

    final originalName = _nameController.text.isEmpty
        ? l10n.recipe_title
        : _nameController.text;

    final scaledTotalCost = _currentTotalCost * multiplier;
    final scaledTotalRevenue = _currentTotalRevenue * multiplier;
    final scaledProfit = _currentRevenue * multiplier;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          key: const ValueKey('scaled_recipe_dialog'),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 580,
              maxHeight: 720,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.scale,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$originalName (x${RecipeUtils.formatNumber(multiplier)})",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$scaledYieldText $unitName",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'x${RecipeUtils.formatNumber(multiplier)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: l10n.close_button,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temporary Banner Info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.temporary_view_banner(
                                    RecipeUtils.formatNumber(multiplier),
                                  ),
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Financial Summary Grid
                        Text(
                          l10n.financial_summary_title,
                          softWrap: true,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogMetricCard(
                                theme: theme,
                                label: l10n.total_cost,
                                value: '$currency${RecipeUtils.formatNumber(scaledTotalCost)}',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDialogMetricCard(
                                theme: theme,
                                label: l10n.cost_per_portion,
                                value: '$currency${RecipeUtils.formatNumber(_currentCostPerPortion)}',
                                icon: Icons.pie_chart_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogMetricCard(
                                theme: theme,
                                label: l10n.total_profit,
                                value: '+$currency${RecipeUtils.formatNumber(scaledProfit)}',
                                icon: Icons.savings_outlined,
                                isPrimary: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDialogMetricCard(
                                theme: theme,
                                label: l10n.total_sale,
                                value: '$currency${RecipeUtils.formatNumber(scaledTotalRevenue)}',
                                icon: Icons.point_of_sale_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Scaled Ingredients
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.ingredients_title,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${_ingredients.length} ${l10n.ingredients_title.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_ingredients.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.no_ingredients,
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _ingredients.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                              itemBuilder: (context, index) {
                                final ingData = _ingredients[index];
                                final originalAmt = RecipeUtils.parseFormattedNumber(ingData.amountController.text);
                                final scaledAmt = originalAmt * multiplier;
                                final unitDisplay = ingData.targetUnit?.name ?? ingData.sourceUnit?.name ?? ingData.ingredient.unitFk;
                                final scaledIngCost = ingData.totalCost * multiplier;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ingData.ingredient.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '$currency${RecipeUtils.formatNumber(scaledIngCost)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Text(
                                          '${RecipeUtils.formatNumber(scaledAmt)} $unitDisplay',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.close_button, softWrap: true),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        key: const ValueKey('apply_scaled_recipe_button'),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          l10n.apply_to_recipe_button,
                          softWrap: true,
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _applyScaledAmounts(multiplier, scaledYield);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogMetricCard({
    required ThemeData theme,
    required String label,
    required String value,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _applyScaledAmounts(double multiplier, double scaledYield) {
    setState(() {
      if (_unscaledIngredientAmounts == null) {
        _unscaledIngredientAmounts = {
          for (var ing in _ingredients)
            ing.ingredient.ingredientPk: ing.amountController.text,
        };
        _unscaledYieldText = _yieldController.text;
      }
      _isScaledTemporarily = true;
      _activeScaleMultiplier = (_activeScaleMultiplier ?? 1.0) * multiplier;

      for (var ingData in _ingredients) {
        final currentAmt = RecipeUtils.parseFormattedNumber(ingData.amountController.text);
        final newAmt = currentAmt * multiplier;
        ingData.amountController.text = RecipeUtils.formatNumber(
          newAmt,
          decimalDigits: newAmt % 1 == 0 ? 0 : 2,
        );
      }
      _yieldController.text = RecipeUtils.formatNumber(
        scaledYield,
        decimalDigits: scaledYield % 1 == 0 ? 0 : 2,
      );
    });
    _calculateSummary();
  }

  void _revertScaledRecipe() {
    if (_unscaledIngredientAmounts == null) return;
    setState(() {
      if (_unscaledYieldText != null) {
        _yieldController.text = _unscaledYieldText!;
      }
      for (var ing in _ingredients) {
        final original = _unscaledIngredientAmounts![ing.ingredient.ingredientPk];
        if (original != null) {
          ing.amountController.text = original;
        }
      }
      _unscaledIngredientAmounts = null;
      _unscaledYieldText = null;
      _isScaledTemporarily = false;
      _activeScaleMultiplier = null;
    });
    _calculateSummary();
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.scale_reverted_toast),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveScaledRecipePermanently() async {
    final success = await _saveRecipe(popOnSuccess: false);
    if (success && mounted) {
      setState(() {
        _isScaledTemporarily = false;
        _activeScaleMultiplier = null;
        _unscaledIngredientAmounts = null;
        _unscaledYieldText = null;
        _initialSnapshot = _createSnapshot();
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.scale_saved_toast),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildScaledBanner(ThemeData theme, AppLocalizations l10n) {
    final mult = _activeScaleMultiplier ?? widget.multiplier;
    final multStr = RecipeUtils.formatNumber(mult, decimalDigits: mult % 1 == 0 ? 0 : 2);

    return Container(
      key: const ValueKey('temporary_scale_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.scale_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.scale_temporary_title(multStr),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.scale_temporary_notice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_unscaledIngredientAmounts != null)
                OutlinedButton.icon(
                  key: const ValueKey('revert_scaled_recipe_button'),
                  onPressed: _revertScaledRecipe,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: Text(l10n.scale_revert_button),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              FilledButton.icon(
                key: const ValueKey('save_scaled_recipe_permanently_button'),
                onPressed: _saveScaledRecipePermanently,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(l10n.scale_save_as_real_button),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateCurrentRecipe() async {
    if (widget.recipeId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final currentName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : l10n.recipe_name;

    final newName = await AppDialogs.promptText(
      context,
      title: l10n.duplicate_button,
      initialValue: "$currentName (${l10n.duplicate_button})",
      labelText: l10n.recipe_name,
      confirmText: l10n.save_button,
      cancelText: l10n.discard_button,
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await db.duplicateRecipe(widget.recipeId!, newName);
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            l10n.recipe_duplicated_success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, l10n.error_prefix(e.toString()));
        }
      }
    }
  }

  PopupMenuItem<double> _buildPopupMenuItem(
    BuildContext context,
    double value,
    String label,
  ) {
    final theme = Theme.of(context);
    return PopupMenuItem<double>(
      value: value,
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _loadRecipeData() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final units = await db.getAllUnits();
      final detail = await db.getRecipeDetail(widget.recipeId!);
      if (!mounted) return;
      final theme = Theme.of(context);
      final settings = ref.read(settingsProvider);

      _nameController.text = detail.recipe.name;
      _descriptionController.text = detail.recipe.description ?? '';
      _yieldController.text = RecipeUtils.formatNumber(
        detail.recipe.defaultYield,
        decimalDigits: 0,
      );
      _yieldNameController.text = detail.recipe.yieldName;
      _profitMarginController.text = RecipeUtils.formatNumber(
        detail.recipe.targetProfitMargin * 100,
        decimalDigits: 0,
      );
      _priceController.text = RecipeUtils.formatNumber(
        detail.recipe.targetPricePerPortion,
        decimalDigits: 2,
      );

      for (var ingWithData in detail.ingredients) {
        final sourceUnit = units
            .where((u) => u.unitPk == ingWithData.ingredient.unitFk)
            .firstOrNull;
        final targetUnit = sourceUnit != null
            ? UnitUtils.getTargetUnit(sourceUnit, units, settings)
            : null;
        final data = RecipeIngredientData(
          ingredient: ingWithData.ingredient,
          initialAmount: RecipeUtils.formatNumber(
            ingWithData.entry.amountNeeded,
            decimalDigits: 2,
          ),
          sourceUnit: sourceUnit,
          targetUnit: targetUnit,
        );
        data.amountController.addListener(_calculateSummary);
        _ingredients.add(data);
      }

      final timerRegExp = RegExp(r'\[timer:(.*?)\|(\d+)\]');
      for (var step in detail.steps) {
        String cleanInstruction = step.instruction;
        final matches = timerRegExp.allMatches(step.instruction);
        for (final match in matches) {
          final timerName = match.group(1) ?? 'Timer';
          final durationSecs = int.tryParse(match.group(2) ?? '0') ?? 0;
          if (durationSecs > 0) {
            _recipeTimers.add(
              RecipeTimerData(
                id: const Uuid().v4(),
                name: timerName,
                durationSeconds: durationSecs,
              ),
            );
          }
        }
        cleanInstruction = cleanInstruction.replaceAll(timerRegExp, '').trim();

        _steps.add(
          RecipeStepData(
            initialInstruction: cleanInstruction,
            customController: IngredientTextEditingController(
              text: cleanInstruction,
              ingredients: _ingredients.map((e) => e.ingredient).toList(),
              colorScheme: theme.colorScheme,
            ),
          ),
        );
      }

      if (_steps.isEmpty) _addStep(shouldFocus: false);
    } catch (e) {
      // error handling
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _calculateSummary();
        _initialSnapshot = _createSnapshot();
      }
    }
  }

  void _addStep({int? atIndex, bool shouldFocus = true}) {
    setState(() {
      final theme = Theme.of(context);
      final newStep = RecipeStepData(
        customController: IngredientTextEditingController(
          ingredients: _ingredients.map((e) => e.ingredient).toList(),
          colorScheme: theme.colorScheme,
        ),
      );
      if (atIndex != null && atIndex < _steps.length) {
        _steps.insert(atIndex + 1, newStep);
      } else {
        _steps.add(newStep);
      }

      if (shouldFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          newStep.focusNode.requestFocus();
        });
      }
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].dispose();
      _steps.removeAt(index);
      if (_steps.isEmpty) {
        _addStep();
      }
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].amountController.removeListener(_calculateSummary);
      _ingredients[index].amountController.dispose();
      _ingredients.removeAt(index);

      final allIngs = _ingredients.map((e) => e.ingredient).toList();
      for (var step in _steps) {
        if (step.instructionController is IngredientTextEditingController) {
          final controller =
              step.instructionController as IngredientTextEditingController;
          controller.updateIngredients(allIngs);
        }
      }
      _calculateSummary();
    });
  }

  void _confirmDeleteIngredient(int index) async {
    final ingName = _ingredients[index].ingredient.name;
    final l10n = AppLocalizations.of(context)!;

    final confirm = await AppDialogs.confirmDelete(
      context,
      title: l10n.delete_ingredient_title,
      message: l10n.delete_ingredient_confirm(ingName),
      cancelText: l10n.discard_button,
      confirmText: l10n.delete_button,
    );

    if (confirm) {
      _removeIngredient(index);
    }
  }

  void _showMergeIngredientDialog(int sourceIndex, List<Unit> units) async {
    final sourceData = _ingredients[sourceIndex];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final otherIngredients = <int, RecipeIngredientData>{};
    for (int i = 0; i < _ingredients.length; i++) {
      if (i != sourceIndex) {
        otherIngredients[i] = _ingredients[i];
      }
    }

    if (otherIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.merge_no_other_ingredients,
            softWrap: true,
          ),
        ),
      );
      return;
    }

    int? selectedTargetIndex;

    final targetIndex = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.merge_ingredient_title,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merge_ingredient_into_prompt(sourceData.ingredient.name),
                    softWrap: true,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: otherIngredients.entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final isSelected = selectedTargetIndex == index;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            title: Text(
                              data.ingredient.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${data.amountController.text} ${data.targetUnit?.symbol ?? ""}',
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              setDialogState(() {
                                selectedTargetIndex = index;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(l10n.discard_button, softWrap: true),
                ),
                FilledButton(
                  onPressed: selectedTargetIndex != null
                      ? () => Navigator.of(ctx).pop(selectedTargetIndex)
                      : null,
                  child: Text(l10n.merge_button, softWrap: true),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (targetIndex != null && targetIndex < _ingredients.length) {
      final targetData = _ingredients[targetIndex];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompareIngredientsScreen(
            ingredient1: sourceData.ingredient,
            ingredient2: targetData.ingredient,
          ),
        ),
      );
    }
  }

  void _showIngredientOptionsModal(int index, List<Unit> units) {
    final data = _ingredients[index];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.ingredient.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.edit_outlined, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: Text(
                      l10n.edit_ingredient_action,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.edit_ingredient_action_desc,
                      softWrap: true,
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (MediaQuery.sizeOf(context).width >= 640) {
                        _openIngredientInRightPanel(data.ingredient);
                      } else {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddIngredientScreen(ingredient: data.ingredient),
                          ),
                        );
                        final db = ref.read(databaseProvider);
                        final updatedIng = await db.getIngredientById(data.ingredient.ingredientPk);
                        if (updatedIng != null && mounted) {
                          _updateIngredientInRecipe(updatedIng);
                        }
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.scale_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      l10n.scale_by_ingredient,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.scale_by_ingredient_desc,
                      softWrap: true,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showScaleByIngredientDialog(targetData: data, units: units);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      l10n.merge_ingredient_action,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.merge_ingredient_action_desc,
                      softWrap: true,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showMergeIngredientDialog(index, units);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    ),
                    title: Text(
                      l10n.delete_ingredient_action,
                      softWrap: true,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      l10n.delete_ingredient_action_desc,
                      softWrap: true,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteIngredient(index);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _guardNotifier?.clearIf(_guardFunction);
    _nameController.removeListener(_onNameChanged);
    _yieldController.removeListener(_calculateSummary);
    _priceController.removeListener(_calculateSummary);
    _profitMarginController.removeListener(_calculateSummary);
    _totalSaleController.removeListener(_calculateSummary);
    _nameController.dispose();
    _descriptionController.dispose();
    _yieldController.dispose();
    _yieldNameController.dispose();
    _profitMarginController.dispose();
    _priceController.dispose();
    _totalSaleController.dispose();
    _nameFocusNode.dispose();
    _webNameFocusNode.dispose();
    _profitMarginFocusNode.dispose();
    _priceFocusNode.dispose();
    _totalSaleFocusNode.dispose();
    _yieldFocusNode.dispose();
    _webYieldFocusNode.dispose();
    _rightPanelYieldFocusNode.dispose();
    for (var ingredient in _ingredients) {
      ingredient.amountController.dispose();
    }
    for (var step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _calculateSummary() {
    if (_isLoading || _isSaving) return;
    if (_isCalculating) {
      _needsRecalculate = true;
      return;
    }
    _isCalculating = true;
    _needsRecalculate = false;

    try {
      double yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);
      if (yieldVal <= 0) yieldVal = 1.0;

      double totalCost = 0.0;
      for (var ing in _ingredients) {
        totalCost += ing.totalCost;
      }

      // 1. Determine which value to update based on user focus
      if (_totalSaleFocusNode.hasFocus) {
        double totalSaleVal = RecipeUtils.parseFormattedNumber(
          _totalSaleController.text,
        );
        double pricePerPortion = totalSaleVal / yieldVal;
        _priceController.text = RecipeUtils.formatNumber(
          pricePerPortion,
          decimalDigits: 2,
        );
      } else if (_profitMarginFocusNode.hasFocus) {
        double targetMarkup = RecipeUtils.parseFormattedNumber(
          _profitMarginController.text,
        );
        double recommendedPrice = RecipeUtils.calculatePriceFromMarkup(
          totalIngredientsCost: totalCost,
          yieldVal: yieldVal,
          targetMarkupPercent: targetMarkup,
        );
        _priceController.text = RecipeUtils.formatNumber(
          recommendedPrice,
          decimalDigits: 2,
        );
      } else if (_priceFocusNode.hasFocus) {
        // manual price edit, margin will follow
      } else if (_yieldFocusNode.hasFocus || _webYieldFocusNode.hasFocus || _rightPanelYieldFocusNode.hasFocus) {
        // If yield changes, we maintain the configured profit margin and update the portion price
        double targetMarkup = RecipeUtils.parseFormattedNumber(
          _profitMarginController.text,
        );
        if (targetMarkup <= 0 && totalCost > 0) targetMarkup = 30.0;
        double recommendedPrice = RecipeUtils.calculatePriceFromMarkup(
          totalIngredientsCost: totalCost,
          yieldVal: yieldVal,
          targetMarkupPercent: targetMarkup,
        );
        _priceController.text = RecipeUtils.formatNumber(
          recommendedPrice,
          decimalDigits: 2,
        );
      } else {
        // Default fallback (e.g., initial load or ingredient change)
        // If margin is configured, keep price in sync without overwriting user inputs
        double targetMarkup = RecipeUtils.parseFormattedNumber(
          _profitMarginController.text,
        );
        if (targetMarkup > 0 && totalCost > 0 && RecipeUtils.parseFormattedNumber(_priceController.text) == 0) {
          double recommendedPrice = RecipeUtils.calculatePriceFromMarkup(
            totalIngredientsCost: totalCost,
            yieldVal: yieldVal,
            targetMarkupPercent: targetMarkup,
          );
          _priceController.text = RecipeUtils.formatNumber(
            recommendedPrice,
            decimalDigits: 2,
          );
        }
      }

      // 2. Perform general calculation
      final summary = RecipeUtils.calculateSummaryFromIngredients(
        ingredients: _ingredients,
        yieldText: _yieldController.text,
        priceText: _priceController.text,
      );

      final units = ref.read(unitsProvider).value ?? [];
      final totals = RecipeUtils.calculateTotalWeightAndVolume(
        ingredients: _ingredients,
        units: units,
      );

      // 3. Update state
      setState(() {
        _currentTotalCost = summary.totalCost;
        _currentTotalRevenue = summary.totalRevenue;
        _currentRevenue = summary.totalProfit;
        _currentCostPerPortion = summary.costPerPortion;
        _currentProfitPerPortion = summary.profitPerPortion;
        _currentTotalWeightGrams = totals.totalWeightGrams;
        _currentTotalVolumeMl = totals.totalVolumeMl;

        if (!_totalSaleFocusNode.hasFocus && !_isSaving) {
          _totalSaleController.text = RecipeUtils.formatNumber(
            summary.totalRevenue,
            decimalDigits: 2,
          );
        }

        // Only derive profit margin when user is explicitly editing Price or Total Sale
        if ((_priceFocusNode.hasFocus || _totalSaleFocusNode.hasFocus) && !_isSaving) {
          _profitMarginController.text = RecipeUtils.formatNumber(
            summary.profitMargin,
            decimalDigits: 0,
          );
        }
      });
    } finally {
      _isCalculating = false;
      if (_needsRecalculate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _calculateSummary();
        });
      }
    }
  }

  Future<bool> _saveRecipe({bool popOnSuccess = true}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.recipe_editor_please_enter_name,
            softWrap: true,
          ),
        ),
      );
      setState(() {
        _isEditingName = true;
      });
      _nameFocusNode.requestFocus();
      return false;
    }
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return false;
    }
    _isSaving = true;
    // Capture values IMMEDIATELY
    final name = _nameController.text;
    final description = _descriptionController.text;
    final yieldVal = _yieldController.text;
    final yieldName = _yieldNameController.text.isEmpty
        ? 'portions'
        : _yieldNameController.text;
    final margin = _profitMarginController.text;
    final price = _priceController.text;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);

      final List<RecipeStepData> stepsToSave = List.from(_steps);
      if (_recipeTimers.isNotEmpty) {
        final timerTags = _recipeTimers
            .map((t) => '[timer:${t.nameController.text.trim().isEmpty ? 'Timer' : t.nameController.text.trim()}|${t.durationSeconds}]')
            .join(' ');
        
        if (stepsToSave.isNotEmpty) {
          final lastStep = stepsToSave.last;
          final updatedInstruction = '${lastStep.instructionController.text.trim()} $timerTags'.trim();
          stepsToSave[stepsToSave.length - 1] = RecipeStepData(
            initialInstruction: updatedInstruction,
            customController: IngredientTextEditingController(
              text: updatedInstruction,
              ingredients: _ingredients.map((e) => e.ingredient).toList(),
              colorScheme: Theme.of(context).colorScheme,
            ),
          );
        } else {
          stepsToSave.add(
            RecipeStepData(
              initialInstruction: timerTags,
              customController: IngredientTextEditingController(
                text: timerTags,
                ingredients: _ingredients.map((e) => e.ingredient).toList(),
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          );
        }
      }

      final savedDetail = await RecipeUtils.saveRecipe(
        db: db,
        recipePk: widget.recipeId,
        name: name,
        description: description,
        yieldText: yieldVal,
        yieldName: yieldName,
        profitMarginText: margin,
        priceText: price,
        ingredients: _ingredients,
        steps: stepsToSave,
      );

      // Persist to cloud database if cloud sync is active
      await ref.read(cloudSyncProvider.notifier).saveRecipe(savedDetail);

      _initialSnapshot = _createSnapshot();
      if (mounted && popOnSuccess) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
      return true;
    } catch (e) {
      // error handling
      if (mounted) setState(() => _isSaving = false);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onPopRequested() async {
    if (!_hasUnsavedChanges()) return true;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          l10n.unsaved_changes_body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text(
              l10n.discard_button,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
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

    if (result == 'save') {
      final success = await _saveRecipe(popOnSuccess: false);
      return success;
    }
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final unitsAsync = ref.watch(unitsProvider);
    final settings = ref.watch(settingsProvider);

    ref.listen<AsyncValue<List<Ingredient>>>(
      ingredientsStreamProvider,
      (previous, next) {
        next.whenData((allIngredients) {
          final map = {for (var i in allIngredients) i.ingredientPk: i};
          bool changed = false;
          for (int idx = 0; idx < _ingredients.length; idx++) {
            final current = _ingredients[idx];
            final updated = map[current.ingredient.ingredientPk];
            if (updated != null &&
                (updated.cost != current.ingredient.cost ||
                 updated.name != current.ingredient.name ||
                 updated.unitFk != current.ingredient.unitFk ||
                 updated.quantityForCost != current.ingredient.quantityForCost)) {
              final updatedData = RecipeIngredientData(
                ingredient: updated,
                initialAmount: current.amountController.text,
                sourceUnit: current.sourceUnit,
                targetUnit: current.targetUnit,
              );
              updatedData.amountController.addListener(_calculateSummary);
              current.amountController.removeListener(_calculateSummary);
              current.amountController.dispose();
              _ingredients[idx] = updatedData;
              changed = true;
            }
          }
          if (changed && mounted) {
            setState(() {
              _calculateSummary();
            });
          }
        });
      },
    );

    if (_yieldNameController.text.isEmpty) {
      _yieldNameController.text = l10n.unit_portions.toLowerCase();
    }

    final appBarTitle = widget.isTemporary
        ? (_nameController.text.isEmpty
              ? l10n.recipe_title
              : _nameController.text)
        : (_nameController.text.isEmpty
              ? (widget.recipeId == null
                    ? l10n.new_recipe_title
                    : l10n.recipe_title)
              : _nameController.text);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onPopRequested();
        if (shouldPop && context.mounted) {
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: widget.onClose != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.back_to_home_tooltip,
                  onPressed: () async {
                    final shouldPop = await _onPopRequested();
                    if (shouldPop && context.mounted) {
                      widget.onClose!();
                    }
                  },
                )
              : const BackButton(),
          centerTitle: true,
          title: _isEditingName && !widget.isTemporary
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.recipe_name,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, size: 18),
                        tooltip: l10n.save_button,
                        onPressed: () {
                          setState(() {
                            _isEditingName = false;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (_) {
                      setState(() {
                        _isEditingName = false;
                      });
                    },
                  ),
                )
              : InkWell(
                  onTap: () {
                    if (!widget.isTemporary) {
                      setState(() {
                        _isEditingName = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _nameFocusNode.requestFocus();
                          if (_nameController.text.isNotEmpty) {
                            _nameController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _nameController.text.length,
                            );
                          }
                        }
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appBarTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              if (!widget.isTemporary) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          if (widget.isTemporary)
                            Text(
                              l10n.temporary_view_title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          actions: [
            if (!widget.isTemporary) ...[
              if (widget.recipeId != null) ...[
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: l10n.duplicate_button,
                  onPressed: _duplicateCurrentRecipe,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _isLoading ? null : _saveRecipe,
                tooltip: l10n.save_button,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktopWeb = constraints.maxWidth >= 640;
                  if (isDesktopWeb) {
                    return _buildDesktopWebLayout(
                      context,
                      theme,
                      l10n,
                      unitsAsync,
                      constraints,
                      _onPopRequested,
                    );
                  }
                  return _buildMobileLayout(
                    context,
                    theme,
                    l10n,
                    unitsAsync,
                    settings,
                  );
                },
              ),
      ), // close Scaffold (child of PopScope)
    ); // close PopScope
  }

  void _applyMarginPreset(double preset) {
    _profitMarginController.text = RecipeUtils.formatNumber(preset, decimalDigits: 0);
    double yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);
    if (yieldVal <= 0) yieldVal = 1.0;
    double totalCost = 0.0;
    for (var ing in _ingredients) {
      totalCost += ing.totalCost;
    }
    double recommendedPrice = RecipeUtils.calculatePriceFromMarkup(
      totalIngredientsCost: totalCost,
      yieldVal: yieldVal,
      targetMarkupPercent: preset,
    );
    _priceController.text = RecipeUtils.formatNumber(
      recommendedPrice,
      decimalDigits: 2,
    );
    _calculateSummary();
  }

  void _changeYieldBy(double delta) {
    final current = RecipeUtils.parseFormattedNumber(_yieldController.text);
    final baseVal = current <= 0 ? 1.0 : current;
    final newVal = (baseVal + delta).clamp(1.0, 99999.0);
    _applyYieldChange(newVal);
  }

  void _applyYieldChange(double newVal) {
    double totalCost = 0.0;
    for (var ing in _ingredients) {
      totalCost += ing.totalCost;
    }
    double targetMarkup = RecipeUtils.parseFormattedNumber(_profitMarginController.text);
    if (targetMarkup <= 0 && totalCost > 0) targetMarkup = 30.0;
    double recommendedPrice = RecipeUtils.calculatePriceFromMarkup(
      totalIngredientsCost: totalCost,
      yieldVal: newVal,
      targetMarkupPercent: targetMarkup,
    );
    _priceController.text = RecipeUtils.formatNumber(
      recommendedPrice,
      decimalDigits: 2,
    );
    _yieldController.text = RecipeUtils.formatNumber(
      newVal,
      decimalDigits: newVal % 1 == 0 ? 0 : 2,
    );
    _calculateSummary();
  }

  Widget _buildWebScaleButton(ThemeData theme, AppLocalizations l10n) {
    return PopupMenuButton<double>(
      tooltip: l10n.scale_recipe_tooltip,
      onSelected: _openTemporaryScaledRecipe,
      itemBuilder: (context) => [
        _buildPopupMenuItem(context, 2.0, 'x2'),
        _buildPopupMenuItem(context, 3.0, 'x3'),
        _buildPopupMenuItem(context, 4.0, 'x4'),
        _buildPopupMenuItem(context, 5.0, 'x5'),
        const PopupMenuDivider(),
        PopupMenuItem<double>(
          value: -1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.scale_by_ingredient,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scale, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              l10n.scale_button,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDuplicateButton(ThemeData theme, AppLocalizations l10n) {
    return InkWell(
      onTap: _duplicateCurrentRecipe,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.secondary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Text(
              l10n.duplicate_button,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSectionHeader({
    required ThemeData theme,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildFinancialDataRow({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
    bool isBold = false,
    bool isHighlighted = false,
    String? subtitle,
    Widget? trailingWidget,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isHighlighted ? 12 : 6,
        vertical: isHighlighted ? 10 : 7,
      ),
      margin: EdgeInsets.symmetric(vertical: isHighlighted ? 3 : 1),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor ?? theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                    color: isHighlighted
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontSize: isHighlighted ? 13 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailingWidget != null)
            trailingWidget
          else
            Text.rich(
              RecipeUtils.formatCurrencyTextSpan(
                context: context,
                text: value,
                currencySymbol: currency,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isHighlighted ? 14.5 : 12.5,
                  color: valueColor ??
                      (isHighlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface),
                ),
                currencyColor: isHighlighted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialEditableDataRow({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    String? prefix,
    String? suffix,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor ?? theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 95,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      if (controller.text.isNotEmpty) {
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: controller.text.length,
                        );
                      }
                    },
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    suffix,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPortionsRow({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    final yieldVal = RecipeUtils.parseFormattedNumber(_yieldController.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.unit_portions,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(
                      height: 16,
                      child: TextField(
                        controller: _yieldNameController,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: l10n.unit_portions.toLowerCase(),
                          hintStyle: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Stepper: [-] [ Field ] [+]
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decrement Button [-]
                    InkWell(
                      key: const ValueKey('decrement_portions_button'),
                      onTap: yieldVal > 1.0 ? () => _changeYieldBy(-1.0) : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: Container(
                        width: 28,
                        height: 30,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.remove_rounded,
                          size: 15,
                          color: yieldVal > 1.0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    // Value Input
                    SizedBox(
                      width: 44,
                      child: TextField(
                        key: const ValueKey('right_panel_yield_field'),
                        controller: _yieldController,
                        focusNode: _rightPanelYieldFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          if (_yieldController.text.isNotEmpty) {
                            _yieldController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _yieldController.text.length,
                            );
                          }
                        },
                        onEditingComplete: () => FocusScope.of(context).unfocus(),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    // Increment Button [+]
                    InkWell(
                      key: const ValueKey('increment_portions_button'),
                      onTap: () => _changeYieldBy(1.0),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      child: Container(
                        width: 28,
                        height: 30,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Scale buttons row
          Row(
            children: [
              _buildWebScaleButton(theme, l10n),
              const SizedBox(width: 6),
              ...[2.0, 3.0, 4.0, 5.0].map((mult) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      key: ValueKey('scale_preset_x${mult.toInt()}'),
                      onTap: () => _openTemporaryScaledRecipe(mult),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'x${mult.toInt()}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebPersistentFinancialPanel(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Future<bool> Function() onPopRequested,
  ) {
    final currentMargin = RecipeUtils.parseFormattedNumber(_profitMarginController.text);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.financial_summary_title,
                    softWrap: true,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n.recipe_editor_live,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable List of Data
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // SECTION 1: COSTOS
                _buildFinancialSectionHeader(
                  theme: theme,
                  title: l10n.financial_costs_section,
                ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.inventory_2_outlined,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  label: l10n.total_cost,
                  value: '$currency${RecipeUtils.formatNumber(_currentTotalCost)}',
                ),
                _buildFinancialPortionsRow(
                  context: context,
                  theme: theme,
                  l10n: l10n,
                ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  label: l10n.cost_per_portion,
                  value: '$currency${RecipeUtils.formatNumber(_currentCostPerPortion)}',
                ),

                const SizedBox(height: 6),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

                // SECTION 2: MARGEN Y PRECIOS
                _buildFinancialSectionHeader(
                  theme: theme,
                  title: l10n.financial_margin_pricing_section,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [15.0, 30.0, 50.0, 70.0].map((preset) {
                          final isSelected = (currentMargin - preset).abs() < 0.5;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                onTap: () => _applyMarginPreset(preset),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${preset.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                _buildFinancialEditableDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.percent_rounded,
                  iconColor: theme.colorScheme.primary,
                  label: l10n.financial_margin,
                  controller: _profitMarginController,
                  focusNode: _profitMarginFocusNode,
                  suffix: '%',
                ),
                _buildFinancialEditableDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.sell_outlined,
                  iconColor: theme.colorScheme.secondary,
                  label: l10n.financial_price,
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  prefix: currency,
                ),
                _buildFinancialEditableDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.point_of_sale_outlined,
                  iconColor: theme.colorScheme.secondary,
                  label: l10n.total_sale,
                  controller: _totalSaleController,
                  focusNode: _totalSaleFocusNode,
                  prefix: currency,
                ),

                const SizedBox(height: 6),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

                // SECTION 3: RESULTADOS
                _buildFinancialSectionHeader(
                  theme: theme,
                  title: l10n.financial_results_section,
                ),
                // Highlighted Gross Profit row
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.savings_outlined,
                  iconColor: theme.colorScheme.primary,
                  label: l10n.total_profit,
                  value: '+$currency${RecipeUtils.formatNumber(_currentRevenue)}',
                  valueColor: theme.colorScheme.primary,
                  isBold: true,
                  isHighlighted: true,
                  subtitle: '${_profitMarginController.text}% ${l10n.financial_margin.toLowerCase()}',
                ),
                const SizedBox(height: 3),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.trending_up_rounded,
                  iconColor: theme.colorScheme.primary,
                  label: l10n.profit_per_portion,
                  value: '+$currency${RecipeUtils.formatNumber(_currentProfitPerPortion)}',
                  valueColor: theme.colorScheme.primary,
                  isBold: true,
                ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: theme.colorScheme.secondary,
                  label: l10n.financial_total_revenue,
                  value: '$currency${RecipeUtils.formatNumber(_currentTotalRevenue)}',
                ),

                const SizedBox(height: 6),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

                // SECTION 4: DATOS DE RECETA
                _buildFinancialSectionHeader(
                  theme: theme,
                  title: l10n.recipe_stats_section,
                ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.egg_outlined,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  label: l10n.ingredients_title,
                  value: '${_ingredients.length}',
                ),
                if (_currentTotalWeightGrams > 0)
                  _buildFinancialDataRow(
                    context: context,
                    theme: theme,
                    icon: Icons.scale_outlined,
                    iconColor: theme.colorScheme.onSurfaceVariant,
                    label: l10n.total_weight,
                    value: RecipeUtils.formatWeight(_currentTotalWeightGrams),
                  ),
                if (_currentTotalVolumeMl > 0)
                  _buildFinancialDataRow(
                    context: context,
                    theme: theme,
                    icon: Icons.water_drop_outlined,
                    iconColor: theme.colorScheme.onSurfaceVariant,
                    label: l10n.total_volume,
                    value: RecipeUtils.formatVolume(_currentTotalVolumeMl),
                  ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.format_list_numbered,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  label: l10n.recipe_steps,
                  value: '${_steps.length}',
                ),
                _buildFinancialDataRow(
                  context: context,
                  theme: theme,
                  icon: Icons.timer_outlined,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  label: l10n.recipe_timers_title,
                  value: '${_recipeTimers.length}',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isTemporary)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.save_button),
                      onPressed: (_isLoading || _isSaving) ? null : _saveRecipe,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (widget.onClose != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(l10n.back_button, softWrap: true),
                      onPressed: () async {
                        final ok = await onPopRequested();
                        if (ok && context.mounted) {
                          widget.onClose!();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebRecipeForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    AsyncValue<List<Unit>> unitsAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
      children: [
        if (_isScaledTemporarily)
          _buildScaledBanner(theme, l10n),

        // Description Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.recipe_description,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (widget.recipeId != null && !widget.isTemporary)
                    _buildWebDuplicateButton(theme, l10n),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: l10n.recipe_description_hint,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Ingredients Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: _buildSectionHeader(l10n.ingredients_title),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_ingredients.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _showGlobalIngredientPicker,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.add_button),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Ingredient Sorting Controls
        _buildIngredientSortControls(theme, l10n),

        // Ingredients List
        unitsAsync.when(
          data: (units) => _buildIngredientsListView(
            context: context,
            theme: theme,
            l10n: l10n,
            units: units,
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
        const SizedBox(height: 32),

        // Steps Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: _buildSectionHeader(l10n.recipe_steps),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_steps.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _addStep(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.add_button),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // Steps List
        if (_steps.isEmpty)
          _buildEmptyPlaceholder(
            l10n.no_steps,
            Icons.format_list_numbered,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildStepItem(index, theme.colorScheme),
          ),
        const SizedBox(height: 32),

        // Timers Section
        _buildRecipeTimersSection(theme, l10n),
        const SizedBox(height: 48),
      ],
    );
  }

  void _openIngredientInRightPanel(Ingredient ingredient) {
    setState(() {
      _previousRightPanelMode = _webRightPanelMode == WebRecipeRightPanelMode.ingredientPicker
          ? WebRecipeRightPanelMode.ingredientPicker
          : WebRecipeRightPanelMode.financials;
      _selectedIngredientForEdit = ingredient;
      _webRightPanelMode = WebRecipeRightPanelMode.editIngredient;
    });
  }

  void _updateIngredientInRecipe(Ingredient updated) {
    bool changed = false;
    for (int i = 0; i < _ingredients.length; i++) {
      if (_ingredients[i].ingredient.ingredientPk == updated.ingredientPk) {
        final old = _ingredients[i];
        final updatedData = RecipeIngredientData(
          ingredient: updated,
          initialAmount: old.amountController.text,
          sourceUnit: old.sourceUnit,
          targetUnit: old.targetUnit,
        );
        updatedData.amountController.addListener(_calculateSummary);
        old.amountController.removeListener(_calculateSummary);
        old.amountController.dispose();
        _ingredients[i] = updatedData;
        changed = true;
      }
    }
    if (changed) {
      _calculateSummary();
    }
  }

  Widget _buildDesktopWebRightPanel(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Future<bool> Function() onPopRequested,
  ) {
    switch (_webRightPanelMode) {
      case WebRecipeRightPanelMode.financials:
        return _buildWebPersistentFinancialPanel(
          context,
          theme,
          l10n,
          onPopRequested,
        );
      case WebRecipeRightPanelMode.ingredientPicker:
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
          ),
          child: GlobalIngredientPickerSheet(
            isPanel: true,
            currentIngredients: _ingredients,
            showPickerIngredientOptionsModal: _showPickerIngredientOptionsModal,
            onClose: () {
              setState(() {
                _webRightPanelMode = WebRecipeRightPanelMode.financials;
              });
            },
            onOpenNewIngredient: ([initialName]) {
              setState(() {
                _newIngredientInitialName = initialName;
                _previousRightPanelMode = WebRecipeRightPanelMode.ingredientPicker;
                _webRightPanelMode = WebRecipeRightPanelMode.newIngredient;
              });
            },
            onAddIngredients: (selectedResults) {
              _addSelectedIngredients(selectedResults);
              setState(() {
                _webRightPanelMode = WebRecipeRightPanelMode.financials;
              });
            },
          ),
        );
      case WebRecipeRightPanelMode.newIngredient:
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
          ),
          child: AddIngredientScreen(
            initialName: _newIngredientInitialName,
            onClose: () {
              ref.read(webLayoutProvider.notifier).closeIngredientDetail();
              if (mounted) {
                setState(() {
                  _newIngredientInitialName = null;
                  _webRightPanelMode = _previousRightPanelMode == WebRecipeRightPanelMode.ingredientPicker
                      ? WebRecipeRightPanelMode.ingredientPicker
                      : WebRecipeRightPanelMode.financials;
                });
              }
            },
          ),
        );
      case WebRecipeRightPanelMode.editIngredient:
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
          ),
          child: AddIngredientScreen(
            key: ValueKey('edit_ing_${_selectedIngredientForEdit?.ingredientPk}'),
            ingredient: _selectedIngredientForEdit,
            onClose: () async {
              if (_selectedIngredientForEdit != null) {
                final db = ref.read(databaseProvider);
                final updated = await db.getIngredientById(_selectedIngredientForEdit!.ingredientPk);
                if (updated != null && mounted) {
                  _updateIngredientInRecipe(updated);
                }
              }
              ref.read(webLayoutProvider.notifier).closeIngredientDetail();
              if (mounted) {
                setState(() {
                  _selectedIngredientForEdit = null;
                  _webRightPanelMode = _previousRightPanelMode == WebRecipeRightPanelMode.ingredientPicker
                      ? WebRecipeRightPanelMode.ingredientPicker
                      : WebRecipeRightPanelMode.financials;
                });
              }
            },
          ),
        );
    }
  }

  Widget _buildDesktopWebLayout(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    AsyncValue<List<Unit>> unitsAsync,
    BoxConstraints constraints,
    Future<bool> Function() onPopRequested,
  ) {
    final double rightPanelWidth = constraints.maxWidth < 820
        ? 340.0
        : (constraints.maxWidth < 1100 ? 380.0 : 420.0);

    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildWebRecipeForm(context, theme, l10n, unitsAsync),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          SizedBox(
            width: rightPanelWidth,
            child: _buildDesktopWebRightPanel(
              context,
              theme,
              l10n,
              onPopRequested,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    AsyncValue<List<Unit>> unitsAsync,
    SettingsState settings,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0),
                  children: [
                    if (_isScaledTemporarily) ...[
                      const SizedBox(height: 12),
                      _buildScaledBanner(theme, l10n),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(l10n.recipe_description),
                        IconButton(
                          icon: Icon(
                            _isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => setState(() {
                            _isDescriptionExpanded =
                                !_isDescriptionExpanded;
                          }),
                        ),
                      ],
                    ),
                    if (_isDescriptionExpanded) ...[
                      _buildCustomTextField(
                        controller: _descriptionController,
                        label: '',
                        hint: l10n.recipe_description_hint,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (widget.recipeId != null &&
                        !widget.isTemporary) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_recipeTimers.isEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showAddRecipeTimerDialog(theme, l10n),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.secondary
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 18,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.recipe_timer_add_badge,
                                        softWrap: true,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              PopupMenuButton<RecipeTimerData>(
                                tooltip: l10n.start_timer_tooltip,
                                onSelected: (timerData) {
                                  final timerName = timerData.nameController.text.trim().isEmpty
                                      ? (_nameController.text.isEmpty ? 'Recipe Timer' : _nameController.text)
                                      : timerData.nameController.text.trim();

                                  ref.read(kitchenTimersProvider.notifier).addTimer(
                                    timerName,
                                    timerData.durationSeconds,
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.timer_started_snackbar(timerName, timerData.formattedDuration),
                                        softWrap: true,
                                      ),
                                      action: SnackBarAction(
                                        label: l10n.view_button,
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => const KitchenTimersScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                itemBuilder: (context) => _recipeTimers.map((timerData) {
                                  return PopupMenuItem<RecipeTimerData>(
                                    value: timerData,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${timerData.nameController.text} (${timerData.formattedDuration})',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${l10n.recipe_timer_single} (${_recipeTimers.length})',
                                        softWrap: true,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            PopupMenuButton<double>(
                              tooltip: l10n.scale_recipe_tooltip,
                              onSelected: _openTemporaryScaledRecipe,
                              itemBuilder: (context) => [
                                _buildPopupMenuItem(context, 2.0, 'x2'),
                                _buildPopupMenuItem(context, 3.0, 'x3'),
                                _buildPopupMenuItem(context, 4.0, 'x4'),
                                _buildPopupMenuItem(context, 5.0, 'x5'),
                                const PopupMenuDivider(),
                                PopupMenuItem<double>(
                                  value: -1.0,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.tune_rounded, size: 16, color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.scale_by_ingredient,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.scale,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.scale_button,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _duplicateCurrentRecipe,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.duplicate_button,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildSectionHeader(l10n.ingredients_title),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _showGlobalIngredientPicker,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 15,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.add_button,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Ingredient Sorting Controls
                    _buildIngredientSortControls(theme, l10n),

                    unitsAsync.when(
                      data: (units) => _buildIngredientsListView(
                        context: context,
                        theme: theme,
                        l10n: l10n,
                        units: units,
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) =>
                          Center(child: Text(e.toString())),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildSectionHeader(l10n.recipe_steps),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _addStep(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 15,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.add_button,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    if (_steps.isEmpty)
                      _buildEmptyPlaceholder(
                        l10n.no_steps,
                        Icons.format_list_numbered,
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _steps.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) =>
                            _buildStepItem(index, theme.colorScheme),
                      ),
                    _buildRecipeTimersSection(theme, l10n),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
              AnimatedSize(
                duration: settings.animationsEnabled
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: settings.animationsEnabled
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  reverseDuration: settings.animationsEnabled
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final isIncoming = (child.key == const ValueKey('expanded_financials') && _showBottomFinancials) ||
                                       (child.key == const ValueKey('collapsed_financials') && !_showBottomFinancials);
                    
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: isIncoming ? Curves.easeOutCubic : Curves.easeInCubic,
                    );

                    return FadeTransition(
                      opacity: curvedAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.3),
                          end: Offset.zero,
                        ).animate(curvedAnimation),
                        child: child,
                      ),
                    );
                  },
                  child: _showBottomFinancials
                      ? _buildBottomFinancials(context)
                      : _buildCollapsedBottomFinancials(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFinancials(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('expanded_financials'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _showBottomFinancials = false),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.hide_financial_summary,
                    softWrap: true,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // --- ROW 1 (3 COLUMNS): Margin, Portions, Price per Portion ---
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildFinancialInputCard(
                    theme: theme,
                    label: l10n.financial_margin,
                    controller: _profitMarginController,
                    suffix: '%',
                    focusNode: _profitMarginFocusNode,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialInputCard(
                    theme: theme,
                    label: l10n.unit_portions,
                    controller: _yieldController,
                    focusNode: _yieldFocusNode,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialInputCard(
                    theme: theme,
                    label: l10n.financial_price,
                    controller: _priceController,
                    prefix: currency,
                    focusNode: _priceFocusNode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // --- ROW 2: Fixed Total Profit on Left, Scrollable Metrics on Right ---
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FIXED ON LEFT: Total Profit
                _buildMetricCard(
                  theme: theme,
                  label: l10n.total_profit,
                  value: '$currency${RecipeUtils.formatNumber(_currentRevenue)}',
                  color: theme.colorScheme.primary,
                  isHighlighted: true,
                  minWidth: 110,
                ),
                const SizedBox(width: 6),
                VerticalDivider(
                  width: 10,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 2),
                // SCROLLABLE ON RIGHT: Other metric figures
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildMetricCard(
                          theme: theme,
                          label: l10n.total_cost,
                          value: '$currency${RecipeUtils.formatNumber(_currentTotalCost)}',
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          theme: theme,
                          label: l10n.total_sale,
                          value: '$currency${RecipeUtils.formatNumber(_currentTotalRevenue)}',
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          theme: theme,
                          label: l10n.cost_per_portion,
                          value: '$currency${RecipeUtils.formatNumber(_currentCostPerPortion)}',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          theme: theme,
                          label: l10n.profit_per_portion,
                          value: '$currency${RecipeUtils.formatNumber(_currentProfitPerPortion)}',
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          theme: theme,
                          label: l10n.sale_per_portion,
                          value: '$currency${RecipeUtils.formatNumber(RecipeUtils.parseFormattedNumber(_priceController.text))}',
                          color: theme.colorScheme.secondary,
                        ),
                        if (_currentTotalWeightGrams > 0) ...[
                          const SizedBox(width: 6),
                          _buildMetricCard(
                            theme: theme,
                            label: l10n.total_weight,
                            value: RecipeUtils.formatWeight(_currentTotalWeightGrams),
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                        if (_currentTotalVolumeMl > 0) ...[
                          const SizedBox(width: 6),
                          _buildMetricCard(
                            theme: theme,
                            label: l10n.total_volume,
                            value: RecipeUtils.formatVolume(_currentTotalVolumeMl),
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInputCard({
    required ThemeData theme,
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    required FocusNode focusNode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                  height: 1.1,
                ),
                softWrap: true,
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (prefix != null)
                Text(
                  '$prefix ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onTap: () {
                    if (controller.text.isNotEmpty) {
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      );
                    }
                  },
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required String label,
    required String value,
    required Color color,
    bool isHighlighted = false,
    double? minWidth,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 115),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? color.withValues(alpha: 0.4) : Colors.transparent,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              RecipeUtils.formatCurrencyTextSpan(
                context: context,
                text: value,
                currencySymbol: currency,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 13.5,
                ),
                currencyColor: isHighlighted ? color : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedBottomFinancials(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final totalCostStr = '$currency${RecipeUtils.formatNumber(_currentTotalCost)}';
    final pricePerPortionStr = '$currency${RecipeUtils.formatNumber(RecipeUtils.parseFormattedNumber(_priceController.text))}';
    final profitPerPortionStr = '$currency${RecipeUtils.formatNumber(_currentProfitPerPortion)}';

    return InkWell(
      key: const ValueKey('collapsed_financials'),
      onTap: () => setState(() => _showBottomFinancials = true),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.show_financial_summary,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  softWrap: true,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_up,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCollapsedMetric(
                  context,
                  l10n.total_cost,
                  totalCostStr,
                ),
                _buildCollapsedMetric(
                  context,
                  l10n.price_per_portion,
                  pricePerPortionStr,
                ),
                _buildCollapsedMetric(
                  context,
                  l10n.gain_per_portion,
                  profitPerPortionStr,
                  valueColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedMetric(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: valueColor ?? theme.colorScheme.onSurface,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          validator: validator,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            filled: !readOnly,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.2,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: readOnly ? 4 : 16,
              vertical: readOnly ? 4 : 12,
            ),
            border: readOnly
                ? InputBorder.none
                : const OutlineInputBorder(borderSide: BorderSide.none),
            enabledBorder: readOnly
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
            focusedBorder: readOnly
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
          ),
          style: readOnly
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
      ],
    );
  }



  Widget _buildEmptyPlaceholder(String message, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(40.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientSortControls(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Padding(
      key: const ValueKey('recipe_ingredient_sort_controls'),
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sort_by,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildSortOptionChip(
              theme: theme,
              label: l10n.sort_default,
              icon: Icons.format_list_numbered_rounded,
              isSelected: _ingredientSort == RecipeIngredientSort.defaultOrder,
              onTap: () {
                if (_ingredientSort != RecipeIngredientSort.defaultOrder) {
                  setState(() => _ingredientSort = RecipeIngredientSort.defaultOrder);
                }
              },
              key: const ValueKey('sort_ingredient_default'),
              tooltip: l10n.sort_default,
            ),
            const SizedBox(width: 6),
            _buildSortOptionChip(
              theme: theme,
              label: l10n.sort_type,
              icon: Icons.category_outlined,
              isSelected: _ingredientSort == RecipeIngredientSort.type,
              onTap: () {
                if (_ingredientSort != RecipeIngredientSort.type) {
                  setState(() => _ingredientSort = RecipeIngredientSort.type);
                }
              },
              key: const ValueKey('sort_ingredient_type'),
              tooltip: l10n.sort_type,
            ),
            const SizedBox(width: 6),
            _buildSortOptionChip(
              theme: theme,
              label: l10n.sort_alphabetical,
              icon: Icons.sort_by_alpha_rounded,
              isSelected: _ingredientSort == RecipeIngredientSort.alphabetical,
              onTap: () {
                if (_ingredientSort != RecipeIngredientSort.alphabetical) {
                  setState(() => _ingredientSort = RecipeIngredientSort.alphabetical);
                }
              },
              key: const ValueKey('sort_ingredient_alphabetical'),
              tooltip: l10n.sort_alphabetical,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptionChip({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Key key,
    String? tooltip,
  }) {
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.7)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildTypeGroupHeader(
    int rank,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final (String title, IconData icon, Color color) = switch (rank) {
      0 => (
        l10n.sort_solids,
        Icons.grain_rounded,
        theme.colorScheme.secondary,
      ),
      1 => (
        l10n.sort_liquids,
        Icons.water_drop_outlined,
        theme.colorScheme.primary,
      ),
      2 => (
        l10n.sort_pieces,
        Icons.widgets_outlined,
        theme.colorScheme.tertiary,
      ),
      _ => (
        l10n.recipe_editor_other_category,
        Icons.inventory_2_outlined,
        theme.colorScheme.outline,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.2),
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsListView({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required List<Unit> units,
  }) {
    final sortedIndices = RecipeUtils.getSortedIngredientIndices(
      ingredients: _ingredients,
      sort: _ingredientSort,
      units: units,
    );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ingredients.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _ingredients.length) {
          return _buildAddIngredientSquare(theme, l10n);
        }

        final originalIndex = sortedIndices[index];
        final itemWidget = _buildIngredientItem(
          originalIndex,
          theme.colorScheme,
          units,
        );

        if (_ingredientSort == RecipeIngredientSort.type) {
          final currentRank = RecipeUtils.getIngredientTypeRank(
            _ingredients[originalIndex],
            units,
          );
          final bool showHeader = (index == 0) ||
              (RecipeUtils.getIngredientTypeRank(
                    _ingredients[sortedIndices[index - 1]],
                    units,
                  ) !=
                  currentRank);

          if (showHeader) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeGroupHeader(currentRank, theme, l10n),
                const SizedBox(height: 6),
                itemWidget,
              ],
            );
          }
        }

        return itemWidget;
      },
    );
  }

  Widget _buildAddIngredientSquare(ThemeData theme, AppLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showGlobalIngredientPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.ingredients_title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n.add_button,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildIngredientItem(
    int index,
    ColorScheme colorScheme,
    List<Unit> units,
  ) {
    final data = _ingredients[index];
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final itemColor = RecipeUtils.getIngredientColor(
      data.ingredient.name,
      colorScheme,
    );

    final unitSymbol =
        data.targetUnit?.symbol ??
        units
            .firstWhere(
              (u) => u.unitPk == data.ingredient.unitFk,
              orElse: () => const Unit(
                unitPk: '',
                symbol: '',
                name: '',
                category: null,
                factorToBase: 1,
                isMutable: false,
              ),
            )
            .symbol;

    return GestureDetector(
      key: ObjectKey(data),
      onLongPress: () => _showIngredientOptionsModal(index, units),
      onTap: () {
        if (MediaQuery.sizeOf(context).width >= 640) {
          _openIngredientInRightPanel(data.ingredient);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: itemColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.ingredient.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: data.amountController,
                          onChanged: (_) => _calculateSummary(),
                          onTap: () {
                            data.amountController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: data.amountController.text.length,
                            );
                          },
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          textAlign: TextAlign.start,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        unitSymbol,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) {
                      final originalUnitSymbol = units
                          .firstWhere(
                            (u) => u.unitPk == data.ingredient.unitFk,
                            orElse: () => const Unit(
                              unitPk: '',
                              symbol: '',
                              name: '',
                              category: null,
                              factorToBase: 1,
                              isMutable: false,
                            ),
                          )
                          .symbol;
                      return CurrencyText(
                        l10n.ingredient_price_per_quantity(
                          '$currency${RecipeUtils.formatNumber(data.ingredient.cost)}',
                          RecipeUtils.formatNumber(data.ingredient.quantityForCost),
                          originalUnitSymbol,
                        ),
                        currencySymbol: currency,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.end,
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  CurrencyText(
                    '$currency ${RecipeUtils.formatNumber(data.totalCost)}',
                    currencySymbol: currency,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              color: theme.colorScheme.error.withValues(alpha: 0.6),
              onPressed: () => _confirmDeleteIngredient(index),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int index, ColorScheme colorScheme) {
    final step = _steps[index];
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _removeStep(index),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 16, thickness: 0.5),
            TextField(
              controller: step.instructionController,
              focusNode: step.focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              style: theme.textTheme.bodyLarge,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addStep(atIndex: index),
              decoration: InputDecoration(
                hintText: l10n.step_instruction_hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(
                  bottom: 24,
                  top: 4,
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSelectedIngredients(List<(Ingredient, double)> selectedResults) {
    setState(() {
      final settings = ref.read(settingsProvider);
      final units = ref.read(unitsProvider).value ?? [];
      for (var item in selectedResults) {
        final ing = item.$1;
        final amountInSource = item.$2;
        if (!_ingredients.any(
          (i) => i.ingredient.ingredientPk == ing.ingredientPk,
        )) {
          final sourceUnit = units
              .where((u) => u.unitPk == ing.unitFk)
              .firstOrNull;
          final targetUnit = sourceUnit != null
              ? UnitUtils.getTargetUnit(sourceUnit, units, settings)
              : null;

          final data = RecipeIngredientData(
            ingredient: ing,
            initialAmount: RecipeUtils.formatNumber(amountInSource),
            sourceUnit: sourceUnit,
            targetUnit: targetUnit,
          );
          data.amountController.addListener(_calculateSummary);
          _ingredients.add(data);
        }
      }

      final allIngs = _ingredients.map((e) => e.ingredient).toList();
      for (var step in _steps) {
        if (step.instructionController
            is IngredientTextEditingController) {
          (step.instructionController
                  as IngredientTextEditingController)
              .updateIngredients(allIngs);
        }
      }

      _calculateSummary();
    });
  }

  void _showGlobalIngredientPicker() {
    ref.read(ingredientSearchQueryProvider.notifier).setQuery('');
    final isDesktopWeb = MediaQuery.sizeOf(context).width >= 640;
    if (isDesktopWeb) {
      setState(() {
        _webRightPanelMode = WebRecipeRightPanelMode.ingredientPicker;
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => GlobalIngredientPickerSheet(
        currentIngredients: _ingredients,
        showPickerIngredientOptionsModal: _showPickerIngredientOptionsModal,
        onAddIngredients: _addSelectedIngredients,
      ),
    ).whenComplete(() {
      ref.read(ingredientSearchQueryProvider.notifier).setQuery('');
    });
  }



  Widget _buildRecipeTimersSection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                l10n.recipe_timers_section,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showAddRecipeTimerDialog(theme, l10n),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.add_button,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 16),
        if (_recipeTimers.isEmpty)
          _buildEmptyPlaceholder(
            l10n.no_timers_in_recipe,
            Icons.timer_off_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _recipeTimers.map((timerData) {
                  return Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth > 500 ? (constraints.maxWidth / 2 - 12) : constraints.maxWidth,
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final timerName = timerData.nameController.text.trim().isEmpty
                                      ? (_nameController.text.isEmpty ? 'Recipe Timer' : _nameController.text)
                                      : timerData.nameController.text.trim();

                                  ref.read(kitchenTimersProvider.notifier).addTimer(
                                    timerName,
                                    timerData.durationSeconds,
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.timer_started_snackbar(
                                          timerName,
                                          timerData.formattedDuration,
                                        ),
                                        softWrap: true,
                                      ),
                                      action: SnackBarAction(
                                        label: l10n.view_button,
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => const KitchenTimersScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: Text(
                                  '${timerData.nameController.text} (${timerData.formattedDuration})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                              onPressed: () => _showAddRecipeTimerDialog(theme, l10n, existingTimer: timerData),
                              tooltip: l10n.edit_button,
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant),
                              onPressed: () {
                                setState(() {
                                  _recipeTimers.remove(timerData);
                                });
                              },
                              tooltip: l10n.delete_button,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  void _showAddRecipeTimerDialog(
    ThemeData theme,
    AppLocalizations l10n, {
    RecipeTimerData? existingTimer,
  }) {
    final timerNameController = TextEditingController(
      text: existingTimer != null ? existingTimer.nameController.text : '',
    );
    int selectedMins = existingTimer != null ? (existingTimer.durationSeconds ~/ 60) : 5;
    int selectedSecs = existingTimer != null ? (existingTimer.durationSeconds % 60) : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existingTimer != null
                          ? l10n.recipe_timer_edit_title
                          : l10n.recipe_timer_add_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: timerNameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.recipe_timer_name_label,
                        hintText: l10n.recipe_timer_name_hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.timer_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              onPressed: () => setModalState(() => selectedMins++),
                            ),
                            Container(
                              width: 60,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                selectedMins.toString().padLeft(2, '0'),
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              onPressed: () => setModalState(() {
                                if (selectedMins > 0) selectedMins--;
                              }),
                            ),
                            Text(l10n.recipe_timer_min, style: theme.textTheme.bodySmall, softWrap: true),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              onPressed: () => setModalState(() {
                                if (selectedSecs < 55) selectedSecs += 5;
                              }),
                            ),
                            Container(
                              width: 60,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                selectedSecs.toString().padLeft(2, '0'),
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              onPressed: () => setModalState(() {
                                if (selectedSecs >= 5) selectedSecs -= 5;
                              }),
                            ),
                            Text(l10n.recipe_timer_sec, style: theme.textTheme.bodySmall, softWrap: true),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [1, 3, 5, 8, 10, 15, 20, 30, 45, 60].map((m) {
                        return ChoiceChip(
                          label: Text('+$m m'),
                          selected: selectedMins == m && selectedSecs == 0,
                          onSelected: (_) {
                            setModalState(() {
                              selectedMins = m;
                              selectedSecs = 0;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final totalSecs = (selectedMins * 60) + selectedSecs;
                        if (totalSecs > 0) {
                          final timerName = timerNameController.text.trim().isEmpty
                              ? 'Timer ${selectedMins}m'
                              : timerNameController.text.trim();
                          setState(() {
                            if (existingTimer != null) {
                              existingTimer.nameController.text = timerName;
                              existingTimer.durationSeconds = totalSecs;
                            } else {
                              _recipeTimers.add(
                                RecipeTimerData(
                                  id: const Uuid().v4(),
                                  name: timerName,
                                  durationSeconds: totalSecs,
                                ),
                              );
                            }
                          });
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        existingTimer != null
                            ? l10n.save_changes_button
                            : l10n.add_timer_preset_button,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPickerIngredientOptionsModal(
    BuildContext context,
    WidgetRef ref,
    Ingredient ing,
    List<Ingredient> allIngredients,
    ThemeData theme,
    AppLocalizations l10n,
    StateSetter setModalState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ing.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(Icons.edit_outlined, color: theme.colorScheme.onSecondaryContainer),
                  ),
                  title: Text(
                    l10n.edit_ingredient_action,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    softWrap: true,
                  ),
                  subtitle: Text(
                    l10n.edit_ingredient_action_desc,
                    softWrap: true,
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (MediaQuery.sizeOf(context).width >= 640) {
                      _openIngredientInRightPanel(ing);
                    } else {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddIngredientScreen(ingredient: ing),
                        ),
                      );
                      setModalState(() {});
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
                  ),
                  title: Text(
                    l10n.merge_ingredient_action,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    softWrap: true,
                  ),
                  subtitle: Text(
                    l10n.merge_ingredient_action_db_desc,
                    softWrap: true,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showGlobalMergeDialog(context, ref, ing, allIngredients, theme, l10n);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.errorContainer,
                    child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  ),
                  title: Text(
                    l10n.delete_ingredient_action,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                    softWrap: true,
                  ),
                  subtitle: Text(
                    l10n.delete_ingredient_permanent_desc,
                    softWrap: true,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmGlobalDeleteIngredient(context, ref, ing, theme, l10n);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmGlobalDeleteIngredient(
    BuildContext context,
    WidgetRef ref,
    Ingredient ing,
    ThemeData theme,
    AppLocalizations l10n,
  ) async {
    final confirm = await AppDialogs.confirmDelete(
      context,
      title: l10n.delete_ingredient_title,
      message: l10n.delete_ingredient_confirm(ing.name),
      cancelText: l10n.cancel_button,
      confirmText: l10n.delete_button,
    );

    if (confirm) {
      final db = ref.read(databaseProvider);
      await db.deleteIngredient(ing);
      ref.invalidate(ingredientsStreamProvider);

      if (context.mounted) {
        AppSnackBar.show(
          context,
          l10n.ingredient_deleted_snackbar(ing.name),
        );
      }
    }
  }

  void _showGlobalMergeDialog(
    BuildContext context,
    WidgetRef ref,
    Ingredient sourceIng,
    List<Ingredient> allIngredients,
    ThemeData theme,
    AppLocalizations l10n,
  ) async {
    final otherIngredients = allIngredients
        .where((i) => i.ingredientPk != sourceIng.ingredientPk)
        .toList();

    if (otherIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.merge_no_other_database_ingredients,
            softWrap: true,
          ),
        ),
      );
      return;
    }

    Ingredient? selectedTarget;

    final target = await showDialog<Ingredient>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.merge_ingredient_title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.merge_ingredient_into_prompt(sourceIng.name),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      softWrap: true,
                    ),
                    const SizedBox(height: 12),
                    ...otherIngredients.map((targetIng) {
                      final isSelected = selectedTarget?.ingredientPk == targetIng.ingredientPk;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(
                            targetIng.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            setDialogState(() {
                              selectedTarget = targetIng;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(l10n.cancel_button),
                ),
                FilledButton(
                  onPressed: selectedTarget != null
                      ? () => Navigator.of(ctx).pop(selectedTarget)
                      : null,
                  child: Text(l10n.merge_button),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted) return;

    if (target != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompareIngredientsScreen(
            ingredient1: sourceIng,
            ingredient2: target,
          ),
        ),
      );
    }
  }
}
