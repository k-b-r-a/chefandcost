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
    SettingsState settings,
  ) {
    if (source.category == null) return source;
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
      if (query.isNotEmpty &&
          !ingredient.name.toLowerCase().contains(query)) {
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
}
