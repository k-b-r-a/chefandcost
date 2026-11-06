import 'package:flutter/material.dart';
import '../database/recipe_category.dart';
import '../l10n/app_localizations.dart';

/// Horizontal scrollable filter strip for recipe categories:
/// [Todos, Cocina, Pastelería, Coctelería].
class RecipeCategoryFilterChipsRow extends StatelessWidget {
  final RecipeCategory? selectedCategory;
  final ValueChanged<RecipeCategory?> onCategorySelected;
  final bool isCompact;

  const RecipeCategoryFilterChipsRow({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items =
        <
          ({
            RecipeCategory? category,
            String label,
            IconData icon,
            Color? color,
          })
        >[
          (
            category: null,
            label: l10n.category_all,
            icon: Icons.all_inclusive_rounded,
            color: null,
          ),
          (
            category: RecipeCategory.cocina,
            label: l10n.category_cocina,
            icon: RecipeCategory.cocina.icon,
            color: RecipeCategory.cocina.color,
          ),
          (
            category: RecipeCategory.pasteleria,
            label: l10n.category_pasteleria,
            icon: RecipeCategory.pasteleria.icon,
            color: RecipeCategory.pasteleria.color,
          ),
          (
            category: RecipeCategory.cocteleria,
            label: l10n.category_cocteleria,
            icon: RecipeCategory.cocteleria.icon,
            color: RecipeCategory.cocteleria.color,
          ),
        ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 0 : 16,
        vertical: isCompact ? 0 : 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((entry) {
          final isSelected = selectedCategory == entry.category;
          final cat = entry.category;

          Color chipBg;
          Color chipBorder;
          Color chipFg;

          if (isSelected) {
            if (cat == null) {
              chipBg = theme.colorScheme.primaryContainer;
              chipBorder = theme.colorScheme.primary;
              chipFg = theme.colorScheme.onPrimaryContainer;
            } else {
              chipBg = isDark
                  ? cat.color.withValues(alpha: 0.28)
                  : cat.containerColor;
              chipBorder = cat.color;
              chipFg = isDark ? Colors.white : cat.onContainerColor;
            }
          } else {
            chipBg = theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            );
            chipBorder = theme.colorScheme.outlineVariant.withValues(
              alpha: 0.25,
            );
            chipFg = theme.colorScheme.onSurfaceVariant;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onCategorySelected(entry.category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: chipBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (entry.color ?? theme.colorScheme.primary)
                                  .withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.icon, size: 18, color: chipFg),
                      const SizedBox(width: 6),
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: chipFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
