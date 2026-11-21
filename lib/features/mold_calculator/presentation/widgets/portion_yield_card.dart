import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/recipe_utils.dart';
import '../../domain/entities/mold_geometry.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/entities/portion_yield.dart';
import '../../domain/validators/mold_validator.dart';
import '../../l10n/mold_l10n_helper.dart';
import 'mold_preview_painter.dart';

class PortionYieldCard extends StatelessWidget {
  final MoldGeometry mold;
  final PortionYieldResult? yieldResult;
  final List<MoldValidationError> errors;

  const PortionYieldCard({
    super.key,
    required this.mold,
    required this.yieldResult,
    required this.errors,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final res = yieldResult;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mold_calc_preview_top_down,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (res != null && res.rotatedOrientation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.mold_calc_portion_rotated_badge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: CustomPaint(
              painter: MoldTopDownCutPainter(
                mold: mold,
                yieldResult: res,
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.tertiary,
                wasteColor: theme.colorScheme.error,
                surfaceColor: theme.colorScheme.surface,
              ),
            ),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              MoldL10nHelper.validationError(l10n, errors.first.code),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else if (res != null) ...[
            if (res.strategy == CutStrategyType.concentric &&
                res.innerPortions != null &&
                res.outerPortions != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  l10n.mold_calc_portion_ring_breakdown(
                    res.innerPortions!,
                    res.outerPortions!,
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                _PortionKpiTile(
                  label: l10n.mold_calc_portion_full_count,
                  value: '${res.fullPortions}',
                  highlight: true,
                ),
                _PortionKpiTile(
                  label: l10n.mold_calc_portion_vol_each,
                  value: RecipeUtils.formatVolume(res.portionVolumeMl),
                ),
                _PortionKpiTile(
                  label: l10n.mold_calc_portion_area_each,
                  value:
                      '${RecipeUtils.formatNumber(res.portionAreaCm2, decimalDigits: 1)} cm²',
                ),
                _PortionKpiTile(
                  label: l10n.mold_calc_portion_waste_merma,
                  value:
                      '${RecipeUtils.formatNumber(res.wasteAreaCm2, decimalDigits: 1)} cm² (${RecipeUtils.formatNumber(res.wastePercent, decimalDigits: 1)}%)',
                  isWarning: res.wastePercent > 15.0,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PortionKpiTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool isWarning;

  const _PortionKpiTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isWarning
        ? theme.colorScheme.error
        : (highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
