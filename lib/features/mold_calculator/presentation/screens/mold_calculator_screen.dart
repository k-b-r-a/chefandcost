import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../provider/database_provider.dart';
import '../../../../provider/web_layout_provider.dart';
import '../../../../screens/recipe_editor_screen.dart';
import '../../../../utils/recipe_utils.dart';
import '../../../../widgets/ad_free_pass_button.dart';
import '../../../../widgets/gooey_toast.dart';
import '../../data/mold_presets_catalog.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/services/equivalence_solver.dart';
import '../../l10n/mold_l10n_helper.dart';
import '../providers/mold_calculator_provider.dart';
import '../widgets/mold_dimension_form.dart';
import '../widgets/mold_preview_painter.dart';
import '../widgets/portion_yield_card.dart';
import '../widgets/scaling_summary_card.dart';

/// Recipient & Mold Dimension, Scaling, and Portion Yield Calculator.
class MoldCalculatorScreen extends ConsumerStatefulWidget {
  final ValueChanged<double>? onApplyScaleFactor;

  const MoldCalculatorScreen({
    super.key,
    this.onApplyScaleFactor,
  });

  @override
  ConsumerState<MoldCalculatorScreen> createState() =>
      _MoldCalculatorScreenState();
}

class _MoldCalculatorScreenState extends ConsumerState<MoldCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Portion input controllers
  late TextEditingController _arcWidthCtrl;
  late TextEditingController _fixedSlicesCtrl;
  late TextEditingController _innerRingCtrl;
  late TextEditingController _pieceLenCtrl;
  late TextEditingController _pieceWidCtrl;
  late TextEditingController _edgeTrimCtrl;
  late TextEditingController _sliceThickCtrl;
  late TextEditingController _endTrimCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final s = ref.read(moldCalculatorProvider);
    _arcWidthCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.targetArcCm, maxDecimalDigits: 1),
    );
    _fixedSlicesCtrl = TextEditingController(text: '${s.radialFixedSlices}');
    _innerRingCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.innerRingDiameterCm, maxDecimalDigits: 1),
    );
    _pieceLenCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.pieceLengthCm, maxDecimalDigits: 1),
    );
    _pieceWidCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.pieceWidthCm, maxDecimalDigits: 1),
    );
    _edgeTrimCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.edgeTrimCm, maxDecimalDigits: 1),
    );
    _sliceThickCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.sliceThicknessCm, maxDecimalDigits: 1),
    );
    _endTrimCtrl = TextEditingController(
      text: RecipeUtils.formatQuantity(s.endTrimCm, maxDecimalDigits: 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _arcWidthCtrl.dispose();
    _fixedSlicesCtrl.dispose();
    _innerRingCtrl.dispose();
    _pieceLenCtrl.dispose();
    _pieceWidCtrl.dispose();
    _edgeTrimCtrl.dispose();
    _sliceThickCtrl.dispose();
    _endTrimCtrl.dispose();
    super.dispose();
  }

  void _syncPortionControllers(MoldCalculatorState s) {
    _arcWidthCtrl.text =
        RecipeUtils.formatQuantity(s.targetArcCm, maxDecimalDigits: 1);
    _fixedSlicesCtrl.text = '${s.radialFixedSlices}';
    _innerRingCtrl.text =
        RecipeUtils.formatQuantity(s.innerRingDiameterCm, maxDecimalDigits: 1);
    _pieceLenCtrl.text =
        RecipeUtils.formatQuantity(s.pieceLengthCm, maxDecimalDigits: 1);
    _pieceWidCtrl.text =
        RecipeUtils.formatQuantity(s.pieceWidthCm, maxDecimalDigits: 1);
    _edgeTrimCtrl.text =
        RecipeUtils.formatQuantity(s.edgeTrimCm, maxDecimalDigits: 1);
    _sliceThickCtrl.text =
        RecipeUtils.formatQuantity(s.sliceThicknessCm, maxDecimalDigits: 1);
    _endTrimCtrl.text =
        RecipeUtils.formatQuantity(s.endTrimCm, maxDecimalDigits: 1);
  }

  Future<void> _handleApplyScaleFactor(double factor) async {
    if (widget.onApplyScaleFactor != null) {
      widget.onApplyScaleFactor!(factor);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final recipesAsync = ref.read(recipesWithFinancialsStreamProvider);
    final recipes = recipesAsync.asData?.value ?? [];

    if (recipes.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: Text(l10n.mold_calc_apply_to_recipe),
          content: Text(l10n.mold_calc_no_recipes_copy_msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: Text(l10n.mold_calc_cancel),
            ),
            FilledButton.icon(
              onPressed: () async {
                final text = RecipeUtils.formatNumber(factor, decimalDigits: 2);
                await Clipboard.setData(ClipboardData(text: text));
                if (dlgCtx.mounted) Navigator.of(dlgCtx).pop();
                if (mounted) {
                  GooeyToast.showSuccess(
                    context,
                    message: l10n.mold_calc_copied_factor_toast(text),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.mold_calc_copy_factor),
            ),
          ],
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.88,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.mold_calc_select_recipe_title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final text =
                              RecipeUtils.formatNumber(factor, decimalDigits: 2);
                          await Clipboard.setData(ClipboardData(text: text));
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          if (mounted) {
                            GooeyToast.showSuccess(
                              context,
                              message: l10n.mold_calc_copied_factor_toast(text),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(l10n.mold_calc_copy_factor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: recipes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final r = recipes[idx].recipe;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: RecipeUtils.parseColor(
                              r.colour,
                              fallback: theme.colorScheme.primary,
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            r.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${RecipeUtils.formatNumber(r.defaultYield, decimalDigits: 0)} ${r.yieldName.isEmpty ? l10n.unit_portions : r.yieldName}',
                          ),
                          trailing: Text(
                            '${RecipeUtils.formatNumber(factor, decimalDigits: 2)}×',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            final isWide = MediaQuery.sizeOf(context).width >= 640;
                            if (isWide) {
                              ref
                                  .read(pendingMoldScaleFactorProvider.notifier)
                                  .setFactor(factor);
                              ref
                                  .read(webLayoutProvider.notifier)
                                  .openRecipe(r.recipePk);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecipeEditorScreen(
                                    recipeId: r.recipePk,
                                    multiplier: factor,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(moldCalculatorProvider);
    final notifier = ref.read(moldCalculatorProvider.notifier);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.mold_calc_title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          const AdFreePassButton(),
          IconButton(
            key: const ValueKey('mold_reset_button'),
            tooltip: l10n.mold_calc_reset,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () {
              notifier.reset();
              _syncPortionControllers(ref.read(moldCalculatorProvider));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              key: const ValueKey('mold_tab_scale'),
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              text: l10n.mold_calc_tab_scale,
            ),
            Tab(
              key: const ValueKey('mold_tab_portion'),
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              text: l10n.mold_calc_tab_portion,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScaleTab(context, theme, l10n, state, notifier),
          _buildPortionTab(context, theme, l10n, state, notifier),
        ],
      ),
    );
  }

  Widget _buildScaleTab(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    MoldCalculatorState state,
    MoldCalculatorNotifier notifier,
  ) {
    final sourceForm = MoldDimensionForm(
      key: const ValueKey('mold_source_form'),
      title: l10n.mold_calc_source_mold,
      accentColor: theme.colorScheme.primary,
      geometry: state.sourceMold,
      fillProfileId: state.sourceFillProfile,
      fillRatio: state.sourceFillRatio,
      errors: state.sourceErrors,
      customMolds: state.customMolds,
      configVersion: state.moldConfigVersion,
      onGeometryChanged: (g) => notifier.setMold(MoldRole.source, g),
      onShapeChanged: (s) => notifier.changeShapeType(MoldRole.source, s),
      onPresetSelected: (p) => notifier.selectPreset(MoldRole.source, p),
      onMultiCavityToggled: (e) => notifier.toggleMultiCavity(MoldRole.source, e),
      onFillProfileChanged: (id) => notifier.setFillProfile(MoldRole.source, id),
      onFillRatioChanged: (r) => notifier.setFillRatio(MoldRole.source, r),
      onSaveCustomMold: (name) async {
        await notifier.saveCustomMold(name, state.sourceMold);
        if (mounted) {
          GooeyToast.showSuccess(
            this.context,
            message: l10n.mold_calc_custom_saved_toast,
          );
        }
      },
      onDeleteCustomMold: notifier.deleteCustomMold,
    );

    final targetForm = MoldDimensionForm(
      key: const ValueKey('mold_target_form'),
      title: l10n.mold_calc_target_mold,
      accentColor: theme.colorScheme.tertiary,
      geometry: state.targetMold,
      fillProfileId: state.targetFillProfile,
      fillRatio: state.targetFillRatio,
      errors: state.targetErrors,
      customMolds: state.customMolds,
      configVersion: state.moldConfigVersion,
      onGeometryChanged: (g) => notifier.setMold(MoldRole.target, g),
      onShapeChanged: (s) => notifier.changeShapeType(MoldRole.target, s),
      onPresetSelected: (p) => notifier.selectPreset(MoldRole.target, p),
      onMultiCavityToggled: (e) => notifier.toggleMultiCavity(MoldRole.target, e),
      onFillProfileChanged: (id) => notifier.setFillProfile(MoldRole.target, id),
      onFillRatioChanged: (r) => notifier.setFillRatio(MoldRole.target, r),
      onSaveCustomMold: (name) async {
        await notifier.saveCustomMold(name, state.targetMold);
        if (mounted) {
          GooeyToast.showSuccess(
            this.context,
            message: l10n.mold_calc_custom_saved_toast,
          );
        }
      },
      onDeleteCustomMold: notifier.deleteCustomMold,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick control bar: Swap, Link fill profiles, Equivalence toggle
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('mold_swap_button'),
                    onPressed: notifier.swapMolds,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(l10n.mold_calc_swap_molds),
                  ),
                  FilterChip(
                    selected: state.linkFillProfiles,
                    label: Text(l10n.mold_calc_link_fill_profiles),
                    avatar: Icon(
                      state.linkFillProfiles
                          ? Icons.link_rounded
                          : Icons.link_off_rounded,
                      size: 16,
                    ),
                    onSelected: notifier.setLinkFillProfiles,
                  ),
                  FilterChip(
                    key: const ValueKey('mold_equivalence_toggle'),
                    selected: state.equivalenceMode,
                    label: Text(l10n.mold_calc_equiv_toggle),
                    avatar: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    onSelected: notifier.setEquivalenceMode,
                  ),
                  if (state.equivalenceMode) ...[
                    ChoiceChip(
                      label: Text(l10n.mold_calc_equiv_solve_primary),
                      selected:
                          state.solveParameter == SolveParameter.primaryDimension,
                      onSelected: (_) => notifier
                          .setSolveParameter(SolveParameter.primaryDimension),
                    ),
                    ChoiceChip(
                      label: Text(l10n.mold_calc_equiv_solve_height),
                      selected: state.solveParameter == SolveParameter.height,
                      onSelected: (_) =>
                          notifier.setSolveParameter(SolveParameter.height),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // 2D Side Cross-Section comparison
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mold_calc_preview_cross_section,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 168,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: MoldSideCrossSectionPainter(
                          sourceMold: state.sourceMold,
                          sourceFillRatio: state.sourceFillRatio,
                          targetMold: state.targetMold,
                          targetFillRatio: state.targetFillRatio,
                          sourceLabel: l10n.mold_calc_preview_source_short,
                          targetLabel: l10n.mold_calc_preview_target_short,
                          sourceColor: theme.colorScheme.primary,
                          targetColor: theme.colorScheme.tertiary,
                          surfaceColor: theme.colorScheme.surface,
                          textColor: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Responsive Source / Target forms
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sourceForm),
                        const SizedBox(width: 14),
                        Expanded(child: targetForm),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      sourceForm,
                      const SizedBox(height: 14),
                      targetForm,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              ScalingSummaryCard(
                scalingResult: state.scalingResult,
                equivalenceResult: state.equivalenceResult,
                onApplyEquivalence: notifier.applySolvedEquivalence,
                onApplyScaleFactor: _handleApplyScaleFactor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortionTab(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    MoldCalculatorState state,
    MoldCalculatorNotifier notifier,
  ) {
    final eval = state.portionEvaluation;
    final strategyPresets = MoldPresetsCatalog.portionPresets
        .where((p) => p.strategy == state.cutStrategy)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mold role selector + Cut strategy selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.mold_calc_portion_mold_select,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SegmentedButton<MoldRole>(
                          segments: [
                            ButtonSegment(
                              value: MoldRole.source,
                              label: Text(l10n.mold_calc_preview_source_short),
                            ),
                            ButtonSegment(
                              value: MoldRole.target,
                              label: Text(l10n.mold_calc_preview_target_short),
                            ),
                          ],
                          selected: {state.portionMoldRole},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              notifier.setPortionMoldRole(set.first);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.mold_calc_portion_strategy,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CutStrategyType.values.map((strategy) {
                        return ChoiceChip(
                          key: ValueKey('mold_cut_${strategy.name}'),
                          label: Text(
                            MoldL10nHelper.cutStrategyName(l10n, strategy),
                          ),
                          selected: state.cutStrategy == strategy,
                          onSelected: (_) => notifier.setCutStrategy(strategy),
                        );
                      }).toList(),
                    ),
                    if (strategyPresets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.mold_calc_portion_presets,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: strategyPresets.map((preset) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(
                                  MoldL10nHelper.portionPresetLabel(l10n, preset),
                                ),
                                onPressed: () {
                                  notifier.applyPortionPreset(preset);
                                  _syncPortionControllers(
                                    ref.read(moldCalculatorProvider),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ..._buildPortionControls(l10n, theme, state, notifier),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PortionYieldCard(
                mold: state.activePortionMold,
                yieldResult: eval.result,
                errors: eval.errors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPortionControls(
    AppLocalizations l10n,
    ThemeData theme,
    MoldCalculatorState state,
    MoldCalculatorNotifier notifier,
  ) {
    switch (state.cutStrategy) {
      case CutStrategyType.radial:
        return [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.mold_calc_portion_use_fixed_slices),
            value: state.useFixedRadialSlices,
            onChanged: (v) => notifier.updatePortionParams(useFixedRadialSlices: v),
          ),
          if (state.useFixedRadialSlices)
            TextField(
              controller: _fixedSlicesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.mold_calc_portion_fixed_slices,
                isDense: true,
              ),
              onChanged: (txt) {
                final val = RecipeUtils.parseFormattedNumber(txt).round();
                if (val >= 1) {
                  notifier.updatePortionParams(radialFixedSlices: val);
                }
              },
            )
          else
            TextField(
              controller: _arcWidthCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.mold_calc_portion_arc_width,
                isDense: true,
              ),
              onChanged: (txt) {
                final val = RecipeUtils.parseFormattedNumber(txt);
                if (val > 0) {
                  notifier.updatePortionParams(targetArcCm: val);
                }
              },
            ),
        ];
      case CutStrategyType.concentric:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _innerRingCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_inner_diameter,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    final val = RecipeUtils.parseFormattedNumber(txt);
                    if (val > 0) {
                      notifier.updatePortionParams(innerRingDiameterCm: val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _arcWidthCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_arc_width,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    final val = RecipeUtils.parseFormattedNumber(txt);
                    if (val > 0) {
                      notifier.updatePortionParams(targetArcCm: val);
                    }
                  },
                ),
              ),
            ],
          ),
        ];
      case CutStrategyType.grid:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('mold_grid_piece_length'),
                  controller: _pieceLenCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_piece_length,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    notifier.updatePortionParams(
                      pieceLengthCm: RecipeUtils.parseFormattedNumber(txt),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('mold_grid_piece_width'),
                  controller: _pieceWidCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_piece_width,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    notifier.updatePortionParams(
                      pieceWidthCm: RecipeUtils.parseFormattedNumber(txt),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('mold_grid_edge_trim'),
                  controller: _edgeTrimCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_edge_trim,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    notifier.updatePortionParams(
                      edgeTrimCm: RecipeUtils.parseFormattedNumber(txt),
                    );
                  },
                ),
              ),
            ],
          ),
        ];
      case CutStrategyType.linear:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sliceThickCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_slice_thickness,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    notifier.updatePortionParams(
                      sliceThicknessCm: RecipeUtils.parseFormattedNumber(txt),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _endTrimCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.mold_calc_portion_end_trim,
                    isDense: true,
                  ),
                  onChanged: (txt) {
                    notifier.updatePortionParams(
                      endTrimCm: RecipeUtils.parseFormattedNumber(txt),
                    );
                  },
                ),
              ),
            ],
          ),
        ];
    }
  }
}
