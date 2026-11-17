import 'package:flutter/material.dart';
import '../database/database.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';

/// Utilities for working with Units and Ingredient categorization.
class UnitUtils {
  UnitUtils._();

  static bool isMass(String? category) => category == 'mass';
  static bool isVolume(String? category) => category == 'volume';
  static bool isCount(String? category) => category == 'count';

  /// Returns the corresponding icon for a unit category.
  static IconData getCategoryIcon(String? category) {
    if (isVolume(category)) return Icons.water_drop_outlined;
    if (isMass(category)) return Icons.grain_rounded;
    if (isCount(category)) return Icons.widgets_outlined;
    return Icons.inventory_2_outlined;
  }

  /// Returns the category container background color according to the theme.
  static Color getCategoryContainerColor(String? category, ThemeData theme) {
    if (isVolume(category)) return theme.colorScheme.primaryContainer;
    if (isMass(category)) return theme.colorScheme.secondaryContainer;
    if (isCount(category)) return theme.colorScheme.tertiaryContainer;
    return theme.colorScheme.surfaceContainerHighest;
  }

  /// Returns the category foreground/text color according to the theme.
  static Color getCategoryOnContainerColor(String? category, ThemeData theme) {
    if (isVolume(category)) return theme.colorScheme.onPrimaryContainer;
    if (isMass(category)) return theme.colorScheme.onSecondaryContainer;
    if (isCount(category)) return theme.colorScheme.onTertiaryContainer;
    return theme.colorScheme.onSurfaceVariant;
  }

  /// Finds the target unit matching user's default unit preferences.
  static Unit? getTargetUnit(
    Unit source,
    List<Unit> units,
    SettingsState settings, {
    bool cocktail = false,
  }) {
    if (source.category == null) return source;
    if (cocktail && isVolume(source.category)) {
      return units
              .where(
                (unit) =>
                    unit.name == 'unit_fluid_ounces' &&
                    unit.category == 'volume',
              )
              .firstOrNull ??
          source;
    }
    final targetSymbol = isMass(source.category)
        ? settings.defaultMassUnit
        : isVolume(source.category)
        ? settings.defaultVolumeUnit
        : null;
    if (targetSymbol == null) return source;
    return units
            .where(
              (u) => u.symbol == targetSymbol && u.category == source.category,
            )
            .firstOrNull ??
        source;
  }

  /// Filters a list of ingredients according to a search query and ingredient category filter.
  static List<Ingredient> filterIngredients({
    required List<Ingredient> ingredients,
    required Map<String, Unit> unitMap,
    required IngredientFilterType filter,
    String searchQuery = '',
  }) {
    final query = searchQuery.trim().toLowerCase();
    return ingredients.where((ingredient) {
      if (query.isNotEmpty && !ingredient.name.toLowerCase().contains(query)) {
        return false;
      }

      if (filter == IngredientFilterType.all) return true;

      final unit = unitMap[ingredient.unitFk];
      if (unit == null) return false;

      if (filter == IngredientFilterType.solids) {
        return isMass(unit.category);
      } else if (filter == IngredientFilterType.liquids) {
        return isVolume(unit.category);
      } else if (filter == IngredientFilterType.pieces) {
        return isCount(unit.category);
      }
      return true;
    }).toList();
  }

  /// Returns unit-category-aware quick-stock adjustment presets.
  static List<QuickStockPreset> quickStockPresetsForUnit(Unit? stockUnit) {
    final category = stockUnit?.category;
    if (isVolume(category)) {
      return const [
        QuickStockPreset(label: '100ml', amount: 100.0, unitSymbol: 'ml'),
        QuickStockPreset(label: '250ml', amount: 250.0, unitSymbol: 'ml'),
        QuickStockPreset(label: '500ml', amount: 500.0, unitSymbol: 'ml'),
        QuickStockPreset(label: '1L', amount: 1.0, unitSymbol: 'l'),
      ];
    }
    if (isMass(category)) {
      return const [
        QuickStockPreset(label: '100g', amount: 100.0, unitSymbol: 'g'),
        QuickStockPreset(label: '250g', amount: 250.0, unitSymbol: 'g'),
        QuickStockPreset(label: '500g', amount: 500.0, unitSymbol: 'g'),
        QuickStockPreset(label: '1kg', amount: 1.0, unitSymbol: 'kg'),
      ];
    }
    final symbol = stockUnit?.symbol.trim() ?? '';
    final suffix = symbol.isNotEmpty ? ' $symbol' : '';
    return [
      QuickStockPreset(label: '1$suffix', amount: 1.0, unitSymbol: symbol),
      QuickStockPreset(label: '5$suffix', amount: 5.0, unitSymbol: symbol),
      QuickStockPreset(label: '10$suffix', amount: 10.0, unitSymbol: symbol),
      QuickStockPreset(label: '25$suffix', amount: 25.0, unitSymbol: symbol),
    ];
  }

  /// Converts a [preset] amount into [stockUnit]'s scale using [units].
  static double convertPresetToStockDelta({
    required QuickStockPreset preset,
    required Unit? stockUnit,
    required List<Unit> units,
  }) {
    if (stockUnit == null) return preset.amount;
    final targetSymbol = stockUnit.symbol.toLowerCase();
    final presetSymbol = preset.unitSymbol.toLowerCase();
    if (presetSymbol == targetSymbol) return preset.amount;

    Unit? presetUnit;
    for (final u in units) {
      if (u.symbol.toLowerCase() == presetSymbol) {
        presetUnit = u;
        break;
      }
    }
    if (presetUnit != null && stockUnit.factorToBase > 0) {
      return preset.amount * (presetUnit.factorToBase / stockUnit.factorToBase);
    }

    // Fallback for common metric pairs when units list is minimal.
    if ((presetSymbol == 'l' && targetSymbol == 'ml') ||
        (presetSymbol == 'kg' && targetSymbol == 'g')) {
      return preset.amount * 1000.0;
    }
    if ((presetSymbol == 'ml' && (targetSymbol == 'l' || targetSymbol == 'lt')) ||
        (presetSymbol == 'g' && targetSymbol == 'kg')) {
      return preset.amount / 1000.0;
    }
    return preset.amount;
  }
}

class QuickStockPreset {
  final String label;
  final double amount;
  final String unitSymbol;

  const QuickStockPreset({
    required this.label,
    required this.amount,
    required this.unitSymbol,
  });
}
