import 'package:flutter/material.dart';
import '../database/recipe_category.dart';
import '../l10n/app_localizations.dart';

/// Compact, color-coded badge indicating the recipe category on recipe cards.
class RecipeCategoryBadge extends StatelessWidget {
  final String? categoryString;
  final bool isCompact;

  const RecipeCategoryBadge({
    super.key,
    required this.categoryString,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final category = RecipeCategory.fromString(categoryString);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? category.color.withValues(alpha: 0.22)
        : category.containerColor.withValues(alpha: 0.85);

    final fgColor = isDark
        ? category.containerColor
        : category.onContainerColor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: category.color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.icon,
            size: isCompact ? 11 : 13,
            color: fgColor,
          ),
          const SizedBox(width: 4),
          Text(
            category.localizedName(l10n),
            style: TextStyle(
              fontSize: isCompact ? 10 : 11.5,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
