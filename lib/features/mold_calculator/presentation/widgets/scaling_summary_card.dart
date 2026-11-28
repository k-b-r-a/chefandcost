import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/recipe_utils.dart';
import '../../domain/entities/scaling_result.dart';
import '../../domain/services/equivalence_solver.dart';
import '../../l10n/mold_l10n_helper.dart';

class ScalingSummaryCard extends StatelessWidget {
  final ScalingResult? scalingResult;
  final EquivalenceResult? equivalenceResult;
  final VoidCallback? onApplyEquivalence;
  final ValueChanged<double> onApplyScaleFactor;

  const ScalingSummaryCard({
    super.key,
    required this.scalingResult,
    required this.equivalenceResult,
    required this.onApplyEquivalence,
    required this.onApplyScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final res = scalingResult;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.mold_calc_summary_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (res != null)
                FilledButton.icon(
                  key: const ValueKey('mold_apply_to_recipe_button'),
                  onPressed: () => onApplyScaleFactor(res.volumeScaleFactor),
                  icon: const Icon(Icons.scale_rounded, size: 18),
                  label: Text(l10n.mold_calc_apply_to_recipe),
                ),
            ],
          ),

          // Equivalence Solver banner
          if (equivalenceResult != null) ...[
            const SizedBox(height: 12),
            _buildEquivalenceBanner(context, theme, l10n, equivalenceResult!),
          ],

          if (res != null) ...[
            const SizedBox(height: 16),
            // KPI Row: Depth Ratio
            _KpiBadge(
              label: l10n.mold_calc_depth_ratio,
              value:
                  '${RecipeUtils.formatNumber(res.depthRatio, decimalDigits: 2, trimTrailingZeros: true)}×',
              highlight: true,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 14),

            // Source vs Target Volume & Fill Height comparison
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _MetricComparisonRow(
                    label: l10n.mold_calc_effective_volume,
                    sourceValue:
                        '${RecipeUtils.formatNumber(res.sourceEffectiveVolumeMl, decimalDigits: 0)} ml',
                    targetValue:
                        '${RecipeUtils.formatNumber(res.targetEffectiveVolumeMl, decimalDigits: 0)} ml',
                    sourceShort: l10n.mold_calc_preview_source_short,
                    targetShort: l10n.mold_calc_preview_target_short,
                  ),
                  const Divider(height: 14),
                  _MetricComparisonRow(
                    label: l10n.mold_calc_fill_height,
                    sourceValue:
                        '${RecipeUtils.formatNumber(res.sourceFillHeightCm, decimalDigits: 1, trimTrailingZeros: true)} cm',
                    targetValue:
                        '${RecipeUtils.formatNumber(res.targetFillHeightCm, decimalDigits: 1, trimTrailingZeros: true)} cm',
                    sourceShort: l10n.mold_calc_preview_source_short,
                    targetShort: l10n.mold_calc_preview_target_short,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Leftover / Deficit & Unscaled Fill indicator
            _buildBatterBalanceCard(theme, l10n, res),
            const SizedBox(height: 14),

            // Thermal Advisories
            Text(
              l10n.mold_calc_thermal_title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...res.advisories.map((adv) {
              final Color tone;
              final IconData icon;
              switch (adv.severity) {
                case ThermalSeverity.warning:
                  tone = Colors.orange.shade700;
                  icon = Icons.thermostat_rounded;
                  break;
                case ThermalSeverity.caution:
                  tone = theme.colorScheme.error;
                  icon = Icons.warning_amber_rounded;
                  break;
                case ThermalSeverity.info:
                  tone = Colors.green.shade700;
                  icon = Icons.check_circle_outline_rounded;
                  break;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tone.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: tone, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MoldL10nHelper.thermalTitle(l10n, adv.type),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: tone,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            MoldL10nHelper.thermalDescription(l10n, adv.type),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEquivalenceBanner(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    EquivalenceResult eq,
  ) {
    final ok = eq.converged;
    final color = ok ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.auto_fix_high_rounded : Icons.error_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? l10n.mold_calc_equiv_result_title
                      : l10n.mold_calc_equiv_no_solution,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (ok)
                  Text(
                    l10n.mold_calc_equiv_result_desc(
                      RecipeUtils.formatNumber(
                        eq.solvedValueCm,
                        decimalDigits: 2,
                        trimTrailingZeros: true,
                      ),
                      RecipeUtils.formatNumber(eq.achievedVolumeMl, decimalDigits: 0),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (ok && onApplyEquivalence != null)
            FilledButton.tonal(
              key: const ValueKey('mold_apply_equivalence_button'),
              onPressed: onApplyEquivalence,
              child: Text(l10n.mold_calc_equiv_apply_btn),
            ),
        ],
      ),
    );
  }

  Widget _buildBatterBalanceCard(
    ThemeData theme,
    AppLocalizations l10n,
    ScalingResult res,
  ) {
    final isExact = res.batterDifferenceMl.abs() < 1.0;
    final isLeftover = res.leftoverBatterMl >= 1.0;

    final String title;
    final String valueText;
    final Color tone;

    if (isExact) {
      title = l10n.mold_calc_exact_match;
      valueText = '0 ml (0%)';
      tone = Colors.green.shade700;
    } else if (isLeftover) {
      title = l10n.mold_calc_leftover_batter;
      valueText =
          '${RecipeUtils.formatNumber(res.leftoverBatterMl, decimalDigits: 0)} ml (${RecipeUtils.formatNumber(res.leftoverPercent, decimalDigits: 0)}%)';
      tone = Colors.orange.shade800;
    } else {
      title = l10n.mold_calc_extra_batter_needed;
      valueText =
          '${RecipeUtils.formatNumber(res.deficitBatterMl, decimalDigits: 0)} ml (${RecipeUtils.formatNumber(res.deficitPercent, decimalDigits: 0)}%)';
      tone = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                valueText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            res.unscaledOverflowsTarget
                ? l10n.mold_calc_overflows_target
                : l10n.mold_calc_unscaled_fill(
                    RecipeUtils.formatNumber(
                      res.unscaledTargetFillHeightCm,
                      decimalDigits: 1,
                      trimTrailingZeros: true,
                    ),
                    RecipeUtils.formatNumber(
                      res.unscaledTargetFillPercent,
                      decimalDigits: 0,
                    ),
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: res.unscaledOverflowsTarget
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  res.unscaledOverflowsTarget ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (res.unscaledTargetFillPercent / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: res.unscaledOverflowsTarget
                  ? theme.colorScheme.error
                  : tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color color;

  const _KpiBadge({
    required this.label,
    required this.value,
    this.highlight = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricComparisonRow extends StatelessWidget {
  final String label;
  final String sourceValue;
  final String targetValue;
  final String sourceShort;
  final String targetShort;

  const _MetricComparisonRow({
    required this.label,
    required this.sourceValue,
    required this.targetValue,
    required this.sourceShort,
    required this.targetShort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            '$sourceShort: $sourceValue  →  $targetShort: $targetValue',
            textAlign: TextAlign.end,
            softWrap: true,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
