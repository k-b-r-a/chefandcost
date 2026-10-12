import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../services/recipe_share_service.dart';

class ShareRecipeSheet extends ConsumerStatefulWidget {
  final RecipeDetail recipeDetail;

  const ShareRecipeSheet({
    super.key,
    required this.recipeDetail,
  });

  static Future<void> show(
    BuildContext context, {
    required RecipeDetail recipeDetail,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareRecipeSheet(recipeDetail: recipeDetail),
    );
  }

  @override
  ConsumerState<ShareRecipeSheet> createState() => _ShareRecipeSheetState();
}

class _ShareRecipeSheetState extends ConsumerState<ShareRecipeSheet> {
  bool _isExporting = false;
  String? _exportingStatus;

  Future<void> _shareChefy() async {
    setState(() {
      _isExporting = true;
      _exportingStatus = null;
    });

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    try {
      final db = ref.read(databaseProvider);
      final allUnits = await db.getAllUnits();
      final bytes = RecipeShareService.exportAsChefy(widget.recipeDetail, allUnits);
      final filename =
          '${RecipeShareService.sanitizeFileName(widget.recipeDetail.recipe.name)}.chefy';

      await RecipeShareService.shareRecipeFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/json',
        subject: widget.recipeDetail.recipe.name,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.error_text}: $e',
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    setState(() {
      _isExporting = true;
      _exportingStatus = l10n.share_recipe_generating;
    });

    try {
      final db = ref.read(databaseProvider);
      final allUnits = await db.getAllUnits();
      final currency = ref.read(settingsProvider).currencySymbol;

      final bytes = await RecipeShareService.exportAsPdf(
        detail: widget.recipeDetail,
        allUnits: allUnits,
        currency: currency,
        l10n: l10n,
      );

      final filename =
          '${RecipeShareService.sanitizeFileName(widget.recipeDetail.recipe.name)}.pdf';

      await RecipeShareService.shareRecipeFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/pdf',
        subject: widget.recipeDetail.recipe.name,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.error_text}: $e',
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    setState(() {
      _isExporting = true;
      _exportingStatus = l10n.share_recipe_generating;
    });

    try {
      final db = ref.read(databaseProvider);
      final allUnits = await db.getAllUnits();
      final currency = ref.read(settingsProvider).currencySymbol;

      final bytes = RecipeShareService.exportAsCsv(
        detail: widget.recipeDetail,
        allUnits: allUnits,
        currency: currency,
        l10n: l10n,
      );

      final filename =
          '${RecipeShareService.sanitizeFileName(widget.recipeDetail.recipe.name)}.csv';

      await RecipeShareService.shareRecipeFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv',
        subject: widget.recipeDetail.recipe.name,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.error_text}: $e',
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final recipeName = widget.recipeDetail.recipe.name;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.share_recipe_bottom_sheet_title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recipeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isExporting) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _exportingStatus ?? l10n.share_recipe_generating,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Option 1: Chefy File
              _buildShareOption(
                context: context,
                icon: Icons.inventory_2_outlined,
                iconColor: theme.colorScheme.primary,
                iconBgColor: theme.colorScheme.primaryContainer,
                title: l10n.share_recipe_format_chefy_title,
                subtitle: l10n.share_recipe_format_chefy_subtitle,
                badge: 'Chef&Cost',
                badgeColor: theme.colorScheme.primary,
                onTap: _shareChefy,
              ),

              const SizedBox(height: 12),

              // Option 2: PDF
              _buildShareOption(
                context: context,
                icon: Icons.picture_as_pdf_outlined,
                iconColor: Colors.red.shade700,
                iconBgColor: Colors.red.shade50,
                title: l10n.share_recipe_format_pdf_title,
                subtitle: l10n.share_recipe_format_pdf_subtitle,
                badge: 'PDF',
                badgeColor: Colors.red.shade700,
                onTap: _sharePdf,
              ),

              const SizedBox(height: 12),

              // Option 3: CSV
              _buildShareOption(
                context: context,
                icon: Icons.table_chart_outlined,
                iconColor: Colors.green.shade700,
                iconBgColor: Colors.green.shade50,
                title: l10n.share_recipe_format_csv_title,
                subtitle: l10n.share_recipe_format_csv_subtitle,
                badge: 'CSV',
                badgeColor: Colors.green.shade700,
                onTap: _shareCsv,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
