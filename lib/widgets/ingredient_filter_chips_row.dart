import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';

/// Reusable filter chips row for ingredient categories (All, Solids, Liquids, Pieces).
class IngredientFilterChipsRow extends StatelessWidget {
  final IngredientFilterType currentFilter;
  final ValueChanged<IngredientFilterType> onFilterSelected;
  final bool isCompact;

  const IngredientFilterChipsRow({
    super.key,
    required this.currentFilter,
    required this.onFilterSelected,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filters = [
      (
        IngredientFilterType.all,
        l10n.filter_all,
        Icons.all_inclusive_rounded,
      ),
      (
        IngredientFilterType.solids,
        l10n.filter_solids,
        Icons.grain_rounded,
      ),
      (
        IngredientFilterType.liquids,
        l10n.filter_liquids,
        Icons.water_drop_outlined,
      ),
      (
        IngredientFilterType.pieces,
        l10n.filter_pieces,
        Icons.widgets_outlined,
      ),
    ];

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: filters.map((entry) {
          final isSelected = currentFilter == entry.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onFilterSelected(entry.$1),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.6)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.$3,
                        size: 13,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((entry) {
          final isSelected = currentFilter == entry.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(
                entry.$3,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(
                entry.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                softWrap: true,
              ),
              selected: isSelected,
              onSelected: (_) => onFilterSelected(entry.$1),
              showCheckmark: false,
              selectedColor: theme.colorScheme.primaryContainer,
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
