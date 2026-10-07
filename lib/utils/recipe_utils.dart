import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../l10n/app_localizations.dart';
import 'unit_utils.dart';

const uuid = Uuid();

class RecipeIngredientData {
  final Ingredient ingredient;
  final TextEditingController amountController;
  final Unit? sourceUnit;
  final Unit? targetUnit;

  RecipeIngredientData({
    required this.ingredient,
    String initialAmount = '0',
    this.sourceUnit,
    this.targetUnit,
  }) : amountController = TextEditingController(
          text: _getInitialAmountText(initialAmount, sourceUnit, targetUnit),
        );

  static String _getInitialAmountText(String initialAmount, Unit? source, Unit? target) {
    final parsed = RecipeUtils.parseFormattedNumber(initialAmount);
    if (parsed == 0.0) return initialAmount;
    if (source != null && target != null && source.category == target.category && source.category != null) {
      final valueInBase = parsed * source.factorToBase;
      final valueInTarget = valueInBase / target.factorToBase;
      return RecipeUtils.formatNumber(valueInTarget);
    }
    return initialAmount;
  }

  double get amount {
    final parsed = RecipeUtils.parseFormattedNumber(amountController.text);
    if (sourceUnit != null && targetUnit != null && sourceUnit!.category == targetUnit!.category && sourceUnit!.category != null) {
      // convert back to source unit
      final valueInBase = parsed * targetUnit!.factorToBase;
      return valueInBase / sourceUnit!.factorToBase;
    }
    return parsed;
  }

  double get unitCost => ingredient.cost / ingredient.quantityForCost;
  double get totalCost => unitCost * amount;
}

class RecipeStepData {
  final TextEditingController instructionController;
  final FocusNode focusNode;

  RecipeStepData({
    String initialInstruction = '',
    TextEditingController? customController,
  })  : instructionController = customController ?? TextEditingController(text: initialInstruction),
        focusNode = FocusNode();

  void dispose() {
    instructionController.dispose();
    focusNode.dispose();
  }
}

class RecipeFinancialSummary {
  final double totalCost;
  final double totalRevenue; // Gross: Price * Yield
  final double totalProfit; // Net: Revenue - Cost
  final double costPerPortion;
  final double profitPerPortion;
  final double profitMargin; // Markup %: (Profit / Cost) * 100

  RecipeFinancialSummary({
    required this.totalCost,
    required this.totalRevenue,
    required this.totalProfit,
    required this.costPerPortion,
    required this.profitPerPortion,
    required this.profitMargin,
  });
}

/// Sorting criteria for recipe ingredients in the recipe screen.
enum RecipeIngredientSort {
  defaultOrder,
  type,
  alphabetical,
}

class RecipeUtils {
  static int defaultDecimalDigits = 2;

  /// Returns the type rank for an ingredient:
  /// 0 for Solid (mass)
  /// 1 for Liquid (volume)
  /// 2 for Pieces (count)
  /// 3 for Other (unspecified/unknown)
  static int getIngredientTypeRank(RecipeIngredientData data, List<Unit> units) {
    final category = data.targetUnit?.category ??
        data.sourceUnit?.category ??
        units.where((u) => u.unitPk == data.ingredient.unitFk).firstOrNull?.category;
    if (UnitUtils.isMass(category)) return 0;
    if (UnitUtils.isVolume(category)) return 1;
    if (UnitUtils.isCount(category)) return 2;
    return 3;
  }

  /// Returns a sorted list of original indices into [ingredients] based on [sort],
  /// WITHOUT mutating the original [ingredients] list.
  static List<int> getSortedIngredientIndices({
    required List<RecipeIngredientData> ingredients,
    required RecipeIngredientSort sort,
    required List<Unit> units,
  }) {
    final indices = List<int>.generate(ingredients.length, (i) => i);
    switch (sort) {
      case RecipeIngredientSort.defaultOrder:
        return indices;
      case RecipeIngredientSort.type:
        indices.sort((i, j) {
          final a = ingredients[i];
          final b = ingredients[j];
          final rankA = getIngredientTypeRank(a, units);
          final rankB = getIngredientTypeRank(b, units);
          final cmp = rankA.compareTo(rankB);
          if (cmp != 0) return cmp;
          final nameCmp = a.ingredient.name.toLowerCase().compareTo(b.ingredient.name.toLowerCase());
          if (nameCmp != 0) return nameCmp;
          return i.compareTo(j);
        });
        return indices;
      case RecipeIngredientSort.alphabetical:
        indices.sort((i, j) {
          final a = ingredients[i];
          final b = ingredients[j];
          final nameCmp = a.ingredient.name.toLowerCase().compareTo(b.ingredient.name.toLowerCase());
          if (nameCmp != 0) return nameCmp;
          return i.compareTo(j);
        });
        return indices;
    }
  }

  /// Calculates total weight (grams) and total volume (milliliters) from recipe ingredients.
  static ({double totalWeightGrams, double totalVolumeMl}) calculateTotalWeightAndVolume({
    required List<RecipeIngredientData> ingredients,
    required List<Unit> units,
  }) {
    double weightGrams = 0.0;
    double volumeMl = 0.0;

    for (var data in ingredients) {
      final unit = data.targetUnit ??
          data.sourceUnit ??
          units.where((u) => u.unitPk == data.ingredient.unitFk).firstOrNull;
      if (unit == null || unit.category == null) continue;

      final parsed = parseFormattedNumber(data.amountController.text);
      if (parsed <= 0) continue;

      final baseAmount = parsed * unit.factorToBase;
      if (UnitUtils.isMass(unit.category)) {
        weightGrams += baseAmount;
      } else if (UnitUtils.isVolume(unit.category)) {
        volumeMl += baseAmount;
      }
    }

    return (totalWeightGrams: weightGrams, totalVolumeMl: volumeMl);
  }

  /// Formats weight in grams or kilograms appropriately
  static String formatWeight(double grams) {
    if (grams <= 0) return '0 g';
    if (grams >= 1000) {
      final kg = grams / 1000;
      final digits = kg % 1 == 0 ? 0 : (kg * 10 % 1 == 0 ? 1 : 2);
      return '${formatNumber(kg, decimalDigits: digits)} kg';
    }
    return '${formatNumber(grams, decimalDigits: grams % 1 == 0 ? 0 : 1)} g';
  }

  /// Formats volume in milliliters or liters appropriately
  static String formatVolume(double ml) {
    if (ml <= 0) return '0 ml';
    if (ml >= 1000) {
      final l = ml / 1000;
      final digits = l % 1 == 0 ? 0 : (l * 10 % 1 == 0 ? 1 : 2);
      return '${formatNumber(l, decimalDigits: digits)} l';
    }
    return '${formatNumber(ml, decimalDigits: ml % 1 == 0 ? 0 : 1)} ml';
  }

  /// Calculates scale factor when setting a target quantity for an ingredient.
  /// Returns 1.0 if current or target amount is invalid or <= 0.
  static double calculateScaleMultiplier({
    required double currentAmount,
    required double targetAmount,
  }) {
    if (currentAmount <= 0 || targetAmount <= 0) return 1.0;
    return targetAmount / currentAmount;
  }

  /// formats numbers with dots as thousands separator (e.g. 1.000)
  static String formatNumber(
    num value, {
    int? decimalDigits,
    int? minDecimalDigits,
    bool trimTrailingZeros = false,
  }) {
    final maxDigits = decimalDigits ?? defaultDecimalDigits;
    final minDigits = trimTrailingZeros
        ? 0
        : (minDecimalDigits ?? decimalDigits ?? defaultDecimalDigits);
    final formatter = NumberFormat.decimalPattern('es_ES'); // uses dot for thousands
    formatter.minimumFractionDigits = minDigits;
    formatter.maximumFractionDigits = maxDigits;
    return formatter.format(maxDigits == 0 ? value.round() : value);
  }

  /// Parses a number string that might contain thousands separators (dots) and decimal commas or units
  static double parseFormattedNumber(String text) {
    if (text.isEmpty) return 0.0;
    final trimmed = text.trim();
    final match = RegExp(r'[-+]?(?:[0-9]+(?:[.,][0-9]+)*|[.,][0-9]+)').firstMatch(trimmed);
    if (match == null) return 0.0;
    final numStr = match.group(0)!;
    final hasDot = numStr.contains('.');
    final hasComma = numStr.contains(',');

    String clean;
    if (hasDot && hasComma) {
      final lastDot = numStr.lastIndexOf('.');
      final lastComma = numStr.lastIndexOf(',');
      if (lastComma > lastDot) {
        // e.g. 1.000,50
        clean = numStr.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // e.g. 1,000.50
        clean = numStr.replaceAll(',', '');
      }
    } else if (hasComma) {
      if (numStr.split(',').length - 1 > 1) {
        // multiple commas: 1,000,000
        clean = numStr.replaceAll(',', '');
      } else {
        // single comma decimal: 1,5 or ,5
        clean = numStr.replaceAll(',', '.');
      }
    } else if (hasDot) {
      if (numStr.split('.').length - 1 > 1) {
        // multiple dots: 1.000.000
        clean = numStr.replaceAll('.', '');
      } else {
        // single dot decimal: 1.5 or .5
        clean = numStr;
      }
    } else {
      clean = numStr;
    }

    return double.tryParse(clean) ?? 0.0;
  }

  /// Safely parses a hex color string (e.g. "#FF5722" or "FF5722") with fallback.
  static Color parseColor(String? hexString, {Color fallback = const Color(0xFF6750A4)}) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final formatted = hexString.replaceFirst('#', '').padLeft(8, 'f');
      return Color(int.parse(formatted, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Formats any string containing a currency symbol with the currency symbol highlighted in the theme's accent/primary color.
  static TextSpan formatCurrencyTextSpan({
    required BuildContext context,
    required String text,
    required String currencySymbol,
    TextStyle? style,
    Color? currencyColor,
  }) {
    final theme = Theme.of(context);
    final accent = currencyColor ?? theme.colorScheme.primary;
    if (currencySymbol.isEmpty || !text.contains(currencySymbol)) {
      return TextSpan(text: text, style: style);
    }

    final parts = text.split(currencySymbol);
    final spans = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i], style: style));
      }
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: currencySymbol,
            style: (style ?? const TextStyle()).copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      }
    }
    return TextSpan(children: spans);
  }

  /// generates a theme-compliant color based on a string (ingredient name)
  /// ensures dark colors in light mode and pastel colors in dark mode for contrast
  static Color getIngredientColor(String name, ColorScheme colorScheme) {
    final int hash = name.hashCode;
    final isDark = colorScheme.brightness == Brightness.dark;
    
    final List<Color> palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    
    Color baseColor = palette[hash.abs() % palette.length];
    
    if (isDark) {
      // make it lighter/pastel for dark mode
      return HSLColor.fromColor(baseColor)
          .withLightness(0.7)
          .withSaturation(0.6)
          .toColor();
    } else {
      // make it darker for light mode
      return HSLColor.fromColor(baseColor)
          .withLightness(0.3)
          .withSaturation(0.8)
          .toColor();
    }
  }

  /// base logic for financial calculations
  static RecipeFinancialSummary calculateFinancials({
    required double totalIngredientsCost,
    required double yieldVal,
    required double pricePerPortion,
  }) {
    final totalRevenue = pricePerPortion * yieldVal;
    final totalProfit = totalRevenue - totalIngredientsCost;
    
    final costPortion = yieldVal > 0 ? totalIngredientsCost / yieldVal : 0.0;
    final profitPortion = yieldVal > 0 ? totalProfit / yieldVal : 0.0;
    
    // Markup logic: (Profit / Cost) * 100
    final markup = (totalIngredientsCost > 0 && pricePerPortion > 0) 
        ? (totalProfit / totalIngredientsCost) * 100 
        : 0.0;

    return RecipeFinancialSummary(
      totalCost: totalIngredientsCost,
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      costPerPortion: costPortion,
      profitPerPortion: profitPortion,
      profitMargin: markup,
    );
  }

  /// Calculates the required price per portion to achieve a specific markup margin
  static double calculatePriceFromMarkup({
    required double totalIngredientsCost,
    required double yieldVal,
    required double targetMarkupPercent,
  }) {
    if (yieldVal <= 0) return 0.0;
    final targetRevenue = totalIngredientsCost * (1 + (targetMarkupPercent / 100));
    return targetRevenue / yieldVal;
  }

  /// converts a value from one unit to another within the same category.
  static double convert({
    required double value,
    required Unit from,
    required Unit to,
  }) {
    if (from.category != to.category || from.category == null) {
      return value;
    }
    final valueInBase = value * from.factorToBase;
    return valueInBase / to.factorToBase;
  }

  /// translates unit names from their database keys (e.g., 'unit_grams' -> 'grams')
  static String translateUnitName(BuildContext context, String unitKey) {
    final l10n = AppLocalizations.of(context)!;
    switch (unitKey) {
      case 'unit_grams':
        return l10n.unit_grams;
      case 'unit_kilograms':
        return l10n.unit_kilograms;
      case 'unit_milliliters':
        return l10n.unit_milliliters;
      case 'unit_liters':
        return l10n.unit_liters;
      case 'unit_pieces':
        return l10n.unit_pieces;
      case 'unit_spoonfuls':
        return l10n.unit_spoonfuls;
      case 'unit_tablespoons':
        return l10n.unit_tablespoons;
      case 'unit_teaspoons':
        return l10n.unit_teaspoons;
      case 'unit_cups':
        return l10n.unit_cups;
      case 'unit_ounces':
        return l10n.unit_ounces;
      default:
        return unitKey;
    }
  }

  /// calculates financials from ui models (form)
  static RecipeFinancialSummary calculateSummaryFromIngredients({
    required List<RecipeIngredientData> ingredients,
    required String yieldText,
    required String priceText,
  }) {
    double totalCost = 0.0;
    for (var ing in ingredients) {
      totalCost += ing.totalCost;
    }
    return calculateFinancials(
      totalIngredientsCost: totalCost,
      yieldVal: parseFormattedNumber(yieldText),
      pricePerPortion: parseFormattedNumber(priceText),
    );
  }

  /// calculates financials from database objects (view)
  static RecipeFinancialSummary calculateSummaryFromDetail(RecipeDetail detail) {
    double totalCost = 0.0;
    for (var ingWithData in detail.ingredients) {
      final unitCost = ingWithData.ingredient.cost / ingWithData.ingredient.quantityForCost;
      totalCost += unitCost * ingWithData.entry.amountNeeded;
    }
    return calculateFinancials(
      totalIngredientsCost: totalCost,
      yieldVal: detail.recipe.defaultYield,
      pricePerPortion: detail.recipe.targetPricePerPortion,
    );
  }

  static Future<RecipeDetail> saveRecipe({
    required AppDatabase db,
    String? recipePk,
    required String name,
    required String description,
    required String yieldText,
    required String yieldName,
    required String profitMarginText,
    required String priceText,
    required List<RecipeIngredientData> ingredients,
    required List<RecipeStepData> steps,
  }) async {
    final parsedYield = parseFormattedNumber(yieldText);
    final parsedPrice = parseFormattedNumber(priceText);
    final rawMargin = parseFormattedNumber(profitMarginText);
    final decimalMargin = rawMargin / 100.0;

    final actualRecipePk = recipePk ?? uuid.v4();
    final now = DateTime.now();

    final recipeCompanion = RecipesCompanion(
      recipePk: drift.Value(actualRecipePk),
      name: drift.Value(name.trim()),
      description: drift.Value(description.trim()),
      defaultYield: drift.Value(parsedYield <= 0 ? 1.0 : parsedYield),
      yieldName: drift.Value(yieldName.trim().isEmpty ? 'portions' : yieldName.trim()),
      targetProfitMargin: drift.Value(decimalMargin),
      targetPricePerPortion: drift.Value(parsedPrice),
      dateTimeModified: drift.Value(now),
    );

    await db.transaction(() async {
      if (recipePk != null) {
        await (db.update(db.recipes)..where((t) => t.recipePk.equals(actualRecipePk))).write(recipeCompanion);
      } else {
        await db.insertRecipe(recipeCompanion);
      }

      await (db.delete(db.recipeIngredients)..where((t) => t.recipeFk.equals(actualRecipePk))).go();

      for (var ingData in ingredients) {
        // Ensure ingredient entity exists and mark modified so differential sync picks it up
        await db.into(db.ingredients).insertOnConflictUpdate(
          IngredientsCompanion(
            ingredientPk: drift.Value(ingData.ingredient.ingredientPk),
            name: drift.Value(ingData.ingredient.name),
            cost: drift.Value(ingData.ingredient.cost),
            quantityForCost: drift.Value(ingData.ingredient.quantityForCost),
            unitFk: drift.Value(ingData.ingredient.unitFk),
            dateCreated: drift.Value(ingData.ingredient.dateCreated),
            dateTimeModified: drift.Value(now),
          ),
        );

        await db.into(db.recipeIngredients).insert(
              RecipeIngredientsCompanion.insert(
                recipeFk: actualRecipePk,
                ingredientFk: ingData.ingredient.ingredientPk,
                amountNeeded: ingData.amount,
                dateTimeModified: drift.Value(now),
              ),
            );
      }

      await (db.delete(db.recipeSteps)..where((t) => t.recipeFk.equals(actualRecipePk))).go();

      for (int i = 0; i < steps.length; i++) {
        final step = _mapToCompanion(actualRecipePk, i, steps[i]);
        await db.into(db.recipeSteps).insert(step);
      }
    });

    return await db.getRecipeDetail(actualRecipePk);
  }

  static RecipeStepsCompanion _mapToCompanion(String recipePk, int index, RecipeStepData step) {
    return RecipeStepsCompanion.insert(
      recipeFk: recipePk,
      stepNumber: index + 1,
      instruction: step.instructionController.text.trim(),
    );
  }
}

/// A widget that automatically renders any text with the currency symbol highlighted in accent color.
class CurrencyText extends StatelessWidget {
  final String text;
  final String currencySymbol;
  final TextStyle? style;
  final Color? currencyColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const CurrencyText(
    this.text, {
    super.key,
    required this.currencySymbol,
    this.style,
    this.currencyColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      RecipeUtils.formatCurrencyTextSpan(
        context: context,
        text: text,
        currencySymbol: currencySymbol,
        style: style,
        currencyColor: currencyColor,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
    );
  }
}
