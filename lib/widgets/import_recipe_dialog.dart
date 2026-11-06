import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/recipe_share_service.dart';
import '../utils/recipe_utils.dart';

class ImportRecipeDialog extends StatelessWidget {
  final RecipeImportPreview preview;

  const ImportRecipeDialog({
    super.key,
    required this.preview,
  });

  static Future<bool?> show(
    BuildContext context, {
    required RecipeImportPreview preview,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportRecipeDialog(preview: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.file_download_rounded,
          color: theme.colorScheme.onPrimaryContainer,
          size: 32,
        ),
      ),
      title: Text(
        l10n.import_recipe_dialog_title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        softWrap: true,
        overflow: TextOverflow.clip,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.import_recipe_dialog_desc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
            const SizedBox(height: 16),

            // Recipe preview card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.clip,
                  ),
                  if (preview.description != null &&
                      preview.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview.description!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Metadata Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildChip(
                        theme,
                        icon: Icons.pie_chart_outline_rounded,
                        label: l10n.import_recipe_portions(
                          RecipeUtils.formatQuantity(preview.defaultYield),
                          preview.yieldName,
                        ),
                      ),
                      _buildChip(
                        theme,
                        icon: Icons.kitchen_rounded,
                        label: l10n.import_recipe_ingredients_count(
                          preview.ingredientsCount,
                        ),
                      ),
                      _buildChip(
                        theme,
                        icon: Icons.format_list_numbered_rounded,
                        label: l10n.import_recipe_steps_count(
                          preview.stepsCount,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (preview.hasExistingRecipeWithSameName) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.import_recipe_name_conflict_warning(
                          preview.suggestedName,
                        ),
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            l10n.discard_button,
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            l10n.import_recipe_confirm_btn,
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}
