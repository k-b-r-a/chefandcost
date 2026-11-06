import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Predefined system categories for recipes and kitchen operations.
enum RecipeCategory {
  cocina,
  pasteleria,
  cocteleria;

  String get id => name;

  static RecipeCategory fromString(String? value) {
    if (value == null) return RecipeCategory.cocina;
    final normalized = value.toLowerCase().trim();
    if (normalized == 'pasteleria' ||
        normalized == 'pastelería' ||
        normalized == 'pastry' ||
        normalized == 'bakery') {
      return RecipeCategory.pasteleria;
    }
    if (normalized == 'cocteleria' ||
        normalized == 'coctelería' ||
        normalized == 'bar' ||
        normalized == 'cocktail' ||
        normalized == 'cocktails') {
      return RecipeCategory.cocteleria;
    }
    return RecipeCategory.cocina;
  }

  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case RecipeCategory.cocina:
        return l10n.category_cocina;
      case RecipeCategory.pasteleria:
        return l10n.category_pasteleria;
      case RecipeCategory.cocteleria:
        return l10n.category_cocteleria;
    }
  }

  IconData get icon {
    switch (this) {
      case RecipeCategory.cocina:
        return Icons.restaurant_rounded;
      case RecipeCategory.pasteleria:
        return Icons.cake_outlined;
      case RecipeCategory.cocteleria:
        return Icons.local_bar_outlined;
    }
  }

  Color get color {
    switch (this) {
      case RecipeCategory.cocina:
        return const Color(0xFFE65100); // Warm amber / orange
      case RecipeCategory.pasteleria:
        return const Color(0xFFC2185B); // Rose / pastry pink
      case RecipeCategory.cocteleria:
        return const Color(0xFF00796B); // Deep teal
    }
  }

  Color get containerColor {
    switch (this) {
      case RecipeCategory.cocina:
        return const Color(0xFFFFE0B2);
      case RecipeCategory.pasteleria:
        return const Color(0xFFF8BBD0);
      case RecipeCategory.cocteleria:
        return const Color(0xFFB2DFDB);
    }
  }

  Color get onContainerColor {
    switch (this) {
      case RecipeCategory.cocina:
        return const Color(0xFF5D2100);
      case RecipeCategory.pasteleria:
        return const Color(0xFF5A0028);
      case RecipeCategory.cocteleria:
        return const Color(0xFF003831);
    }
  }
}
