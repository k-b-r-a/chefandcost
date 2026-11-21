import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/recipe_utils.dart';
import '../../data/mold_presets_catalog.dart';
import '../../domain/entities/fill_profile.dart';
import '../../domain/entities/mold_geometry.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/validators/mold_validator.dart';
import '../../l10n/mold_l10n_helper.dart';
import 'mold_preview_painter.dart';

class MoldDimensionForm extends StatefulWidget {
  final String title;
  final Color accentColor;
  final MoldGeometry geometry;
  final FillProfileId fillProfileId;
  final double fillRatio;
  final List<MoldValidationError> errors;
  final List<MoldPreset> customMolds;
  final int configVersion;
  final ValueChanged<MoldGeometry> onGeometryChanged;
  final ValueChanged<MoldShapeType> onShapeChanged;
  final ValueChanged<MoldPreset> onPresetSelected;
  final ValueChanged<bool> onMultiCavityToggled;
  final ValueChanged<FillProfileId> onFillProfileChanged;
  final ValueChanged<double> onFillRatioChanged;
  final Future<void> Function(String name) onSaveCustomMold;
  final Future<void> Function(String id) onDeleteCustomMold;

  const MoldDimensionForm({
    super.key,
    required this.title,
    required this.accentColor,
    required this.geometry,
    required this.fillProfileId,
    required this.fillRatio,
    required this.errors,
    required this.customMolds,
    required this.configVersion,
    required this.onGeometryChanged,
    required this.onShapeChanged,
    required this.onPresetSelected,
    required this.onMultiCavityToggled,
    required this.onFillProfileChanged,
    required this.onFillRatioChanged,
    required this.onSaveCustomMold,
    required this.onDeleteCustomMold,
  });

  @override
  State<MoldDimensionForm> createState() => _MoldDimensionFormState();
}

class _MoldDimensionFormState extends State<MoldDimensionForm> {
  final Map<String, TextEditingController> _controllers = {};
  bool _useSlantHeight = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromGeometry();
  }

  @override
  void didUpdateWidget(covariant MoldDimensionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldInner = oldWidget.geometry is MultiCavityMold
        ? (oldWidget.geometry as MultiCavityMold).singleCavity
        : oldWidget.geometry;
    final newInner = widget.geometry is MultiCavityMold
        ? (widget.geometry as MultiCavityMold).singleCavity
        : widget.geometry;

    if (widget.configVersion != oldWidget.configVersion ||
        oldInner.shapeType != newInner.shapeType ||
        (oldWidget.geometry is MultiCavityMold) !=
            (widget.geometry is MultiCavityMold)) {
      if (newInner is CircularFrustum) {
        _useSlantHeight = newInner.slantHeight != null;
      } else {
        _useSlantHeight = false;
      }
      _syncControllersFromGeometry();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, double initialValue) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: RecipeUtils.formatQuantity(initialValue, maxDecimalDigits: 2),
      ),
    );
  }

  void _setControllerText(String key, double value) {
    final formatted = RecipeUtils.formatQuantity(value, maxDecimalDigits: 2);
    final ctrl = _controllers[key];
    if (ctrl == null) {
      _controllers[key] = TextEditingController(text: formatted);
    } else if (ctrl.text != formatted) {
      ctrl.text = formatted;
    }
  }

  void _syncControllersFromGeometry() {
    final g = widget.geometry;
    if (g is MultiCavityMold) {
      _setControllerText('cavityCount', g.cavityCount.toDouble());
    }
    final inner = g is MultiCavityMold ? g.singleCavity : g;
    switch (inner) {
      case CircularCylinder(:final diameter, :final height):
        _setControllerText('diameter', diameter);
        _setControllerText('height', height);
        break;
      case SquarePrism(:final side, :final height):
        _setControllerText('side', side);
        _setControllerText('height', height);
        break;
      case RectangularPrism(:final length, :final width, :final height):
        _setControllerText('length', length);
        _setControllerText('width', width);
        _setControllerText('height', height);
        break;
      case CircularFrustum(
          :final bottomDiameter,
          :final topDiameter,
          :final height,
          :final slantHeight,
        ):
        _setControllerText('bottomDiameter', bottomDiameter);
        _setControllerText('topDiameter', topDiameter);
        _setControllerText('height', height);
        _setControllerText('slantHeight', slantHeight ?? height);
        break;
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        _setControllerText('bottomLength', bottomLength);
        _setControllerText('bottomWidth', bottomWidth);
        _setControllerText('topLength', topLength);
        _setControllerText('topWidth', topWidth);
        _setControllerText('height', height);
        break;
      case VChannelMold(:final bottomWidth, :final topWidth, :final length, :final height):
        _setControllerText('bottomWidth', bottomWidth);
        _setControllerText('topWidth', topWidth);
        _setControllerText('length', length);
        _setControllerText('height', height);
        break;
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
        ):
        _setControllerText('outerBottomDiameter', outerBottomDiameter);
        _setControllerText('outerTopDiameter', outerTopDiameter);
        _setControllerText('tubeBottomDiameter', tubeBottomDiameter);
        _setControllerText('tubeTopDiameter', tubeTopDiameter);
        _setControllerText('height', height);
        _setControllerText('tubeHeight', tubeHeight ?? height);
        break;
      case SphericalCapMold(:final diameter, :final height):
        _setControllerText('diameter', diameter);
        _setControllerText('height', height);
        break;
      case UChannelMold(:final width, :final length, :final height):
        _setControllerText('width', width);
        _setControllerText('length', length);
        _setControllerText('height', height);
        break;
      case RegularPolygonMold(:final sides, :final sideLength, :final height):
        _setControllerText('sides', sides.toDouble());
        _setControllerText('sideLength', sideLength);
        _setControllerText('height', height);
        break;
      case HeartShapeMold(:final width, :final length, :final height, :final shapeFactor):
        _setControllerText('width', width);
        _setControllerText('length', length);
        _setControllerText('height', height);
        _setControllerText('shapeFactor', shapeFactor);
        break;
      case WaterDisplacementMold(
          :final measuredVolumeMl,
          :final height,
          :final fillCurveExponent,
        ):
        _setControllerText('measuredVolumeMl', measuredVolumeMl);
        _setControllerText('height', height);
        _setControllerText('fillCurveExponent', fillCurveExponent);
        break;
      case MultiCavityMold():
        break;
    }
  }

  double _readField(String key, double fallback) {
    final text = _controllers[key]?.text.trim() ?? '';
    if (text.isEmpty) return 0.0;
    return RecipeUtils.parseFormattedNumber(text);
  }

  void _emitGeometry(MoldGeometry updatedInner, {int? cavityCount}) {
    final g = widget.geometry;
    if (g is MultiCavityMold) {
      final count = cavityCount ?? g.cavityCount;
      widget.onGeometryChanged(
        MultiCavityMold(singleCavity: updatedInner, cavityCount: count),
      );
    } else {
      widget.onGeometryChanged(updatedInner);
    }
  }

  void _rebuildFromControllers() {
    final g = widget.geometry;
    final inner = g is MultiCavityMold ? g.singleCavity : g;
    final cavityCount = g is MultiCavityMold
        ? _readField('cavityCount', g.cavityCount.toDouble()).round()
        : null;

    final MoldGeometry nextInner;
    switch (inner) {
      case CircularCylinder(:final diameter, :final height):
        nextInner = CircularCylinder(
          diameter: _readField('diameter', diameter),
          height: _readField('height', height),
        );
        break;
      case SquarePrism(:final side, :final height):
        nextInner = SquarePrism(
          side: _readField('side', side),
          height: _readField('height', height),
        );
        break;
      case RectangularPrism(:final length, :final width, :final height):
        nextInner = RectangularPrism(
          length: _readField('length', length),
          width: _readField('width', width),
          height: _readField('height', height),
        );
        break;
      case CircularFrustum(:final bottomDiameter, :final topDiameter, :final height):
        nextInner = CircularFrustum(
          bottomDiameter: _readField('bottomDiameter', bottomDiameter),
          topDiameter: _readField('topDiameter', topDiameter),
          height: _readField('height', height),
          slantHeight: _useSlantHeight
              ? _readField('slantHeight', height)
              : null,
        );
        break;
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        nextInner = RectangularFrustum(
          bottomLength: _readField('bottomLength', bottomLength),
          bottomWidth: _readField('bottomWidth', bottomWidth),
          topLength: _readField('topLength', topLength),
          topWidth: _readField('topWidth', topWidth),
          height: _readField('height', height),
        );
        break;
      case VChannelMold(:final bottomWidth, :final topWidth, :final length, :final height):
        nextInner = VChannelMold(
          bottomWidth: _readField('bottomWidth', bottomWidth),
          topWidth: _readField('topWidth', topWidth),
          length: _readField('length', length),
          height: _readField('height', height),
        );
        break;
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
          :final flutingFactor,
        ):
        final h = _readField('height', height);
        final th = _readField('tubeHeight', tubeHeight ?? height);
        nextInner = AnnularTubeMold(
          outerBottomDiameter: _readField('outerBottomDiameter', outerBottomDiameter),
          outerTopDiameter: _readField('outerTopDiameter', outerTopDiameter),
          tubeBottomDiameter: _readField('tubeBottomDiameter', tubeBottomDiameter),
          tubeTopDiameter: _readField('tubeTopDiameter', tubeTopDiameter),
          height: h,
          tubeHeight: (th - h).abs() < 1e-6 ? null : th,
          flutingFactor: flutingFactor,
        );
        break;
      case SphericalCapMold(:final diameter, :final height):
        nextInner = SphericalCapMold(
          diameter: _readField('diameter', diameter),
          height: _readField('height', height),
        );
        break;
      case UChannelMold(:final width, :final length, :final height):
        nextInner = UChannelMold(
          width: _readField('width', width),
          length: _readField('length', length),
          height: _readField('height', height),
        );
        break;
      case RegularPolygonMold(:final sides, :final sideLength, :final height):
        nextInner = RegularPolygonMold(
          sides: _readField('sides', sides.toDouble()).round(),
          sideLength: _readField('sideLength', sideLength),
          height: _readField('height', height),
        );
        break;
      case HeartShapeMold(:final width, :final length, :final height, :final shapeFactor):
        nextInner = HeartShapeMold(
          width: _readField('width', width),
          length: _readField('length', length),
          height: _readField('height', height),
          shapeFactor: _readField('shapeFactor', shapeFactor),
        );
        break;
      case WaterDisplacementMold(
          :final measuredVolumeMl,
          :final height,
          :final fillCurveExponent,
        ):
        nextInner = WaterDisplacementMold(
          measuredVolumeMl: _readField('measuredVolumeMl', measuredVolumeMl),
          height: _readField('height', height),
          fillCurveExponent: _readField('fillCurveExponent', fillCurveExponent),
        );
        break;
      case MultiCavityMold():
        return;
    }

    _emitGeometry(nextInner, cavityCount: cavityCount);
  }

  Future<void> _showPresetsDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final allPresets = [...widget.customMolds, ...MoldPresetsCatalog.builtInMolds];

    final grouped = <MoldPresetCategory, List<MoldPreset>>{};
    for (final p in allPresets) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    l10n.mold_calc_select_preset,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        for (final cat in MoldPresetCategory.values)
                          if (grouped.containsKey(cat)) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                MoldL10nHelper.presetCategoryName(l10n, cat),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...grouped[cat]!.map((preset) {
                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(
                                  preset.isCustom
                                      ? Icons.bookmark_rounded
                                      : Icons.cake_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(
                                  preset.label,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${preset.geometry.totalVolume.toStringAsFixed(0)} ml',
                                ),
                                trailing: preset.isCustom
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        tooltip: l10n.mold_calc_delete_custom,
                                        onPressed: () async {
                                          await widget.onDeleteCustomMold(preset.id);
                                          if (sheetCtx.mounted) {
                                            Navigator.of(sheetCtx).pop();
                                          }
                                        },
                                      )
                                    : null,
                                onTap: () {
                                  widget.onPresetSelected(preset);
                                  Navigator.of(sheetCtx).pop();
                                },
                              );
                            }),
                          ],
                      ],
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

  Future<void> _showSaveCustomDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l10n.mold_calc_save_custom),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.mold_calc_custom_name_hint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: Text(l10n.mold_calc_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: Text(l10n.mold_calc_save),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await widget.onSaveCustomMold(nameCtrl.text.trim());
    }
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isMultiCavity = widget.geometry is MultiCavityMold;
    final inner = isMultiCavity
        ? (widget.geometry as MultiCavityMold).singleCavity
        : widget.geometry;
    final availableShapes = MoldShapeType.values
        .where((s) => s != MoldShapeType.multiCavity)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Role badge + Presets + Save Custom
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: widget.accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _showPresetsDialog(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                icon: const Icon(Icons.list_alt_rounded, size: 17),
                label: Text(l10n.mold_calc_presets),
              ),
              IconButton(
                onPressed: widget.errors.isEmpty
                    ? () => _showSaveCustomDialog(context)
                    : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                tooltip: l10n.mold_calc_save_custom,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Shape selector + mini contextual schematic diagram
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: CustomPaint(
                  painter: MoldShapeSchematicPainter(
                    shapeType: inner.shapeType,
                    primaryColor: widget.accentColor,
                    accentColor: widget.accentColor,
                    onSurfaceColor: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<MoldShapeType>(
                  initialValue: inner.shapeType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isMultiCavity
                        ? l10n.mold_calc_cavity_shape
                        : l10n.mold_calc_shape_cylinder.split('/').first,
                    isDense: true,
                  ),
                  items: availableShapes.map((shape) {
                    return DropdownMenuItem<MoldShapeType>(
                      value: shape,
                      child: Text(
                        MoldL10nHelper.shapeName(l10n, shape),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      widget.onShapeChanged(val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multi-cavity toggle
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              l10n.mold_calc_multi_cavity_toggle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            value: isMultiCavity,
            onChanged: widget.onMultiCavityToggled,
          ),

          if (isMultiCavity) ...[
            _buildNumberInput(
              keyName: 'cavityCount',
              label: l10n.mold_calc_dim_cavities,
              initialValue:
                  (widget.geometry as MultiCavityMold).cavityCount.toDouble(),
              isInteger: true,
            ),
            const SizedBox(height: 10),
          ],

          // Dynamic shape-specific inputs
          ..._buildShapeFields(inner, l10n, theme),
          const SizedBox(height: 12),

          // Fill profile & ratio slider
          DropdownButtonFormField<FillProfileId>(
            initialValue: widget.fillProfileId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.mold_calc_fill_profile_label,
              isDense: true,
            ),
            items: FillProfileId.values.map((id) {
              return DropdownMenuItem<FillProfileId>(
                value: id,
                child: Text(
                  MoldL10nHelper.fillProfileName(l10n, id),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) widget.onFillProfileChanged(val);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.mold_calc_fill_ratio_label(
                    (widget.fillRatio * 100).round().toString(),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: widget.fillRatio.clamp(0.10, 1.0),
            min: 0.10,
            max: 1.0,
            divisions: 90,
            activeColor: widget.accentColor,
            label: '${(widget.fillRatio * 100).round()}%',
            onChanged: widget.onFillRatioChanged,
          ),

          // Validation errors
          if (widget.errors.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.errors.map((err) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            MoldL10nHelper.validationError(l10n, err.code),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildShapeFields(
    MoldGeometry inner,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (inner) {
      case CircularCylinder(:final diameter, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'diameter',
              label: l10n.mold_calc_dim_diameter,
              initialValue: diameter,
            ),
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
          ),
        ];
      case SquarePrism(:final side, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'side',
              label: l10n.mold_calc_dim_side,
              initialValue: side,
            ),
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
          ),
        ];
      case RectangularPrism(:final length, :final width, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'length',
              label: l10n.mold_calc_dim_length,
              initialValue: length,
            ),
            _buildNumberInput(
              keyName: 'width',
              label: l10n.mold_calc_dim_width,
              initialValue: width,
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInput(
            keyName: 'height',
            label: l10n.mold_calc_dim_height,
            initialValue: height,
          ),
        ];
      case CircularFrustum(
          :final bottomDiameter,
          :final topDiameter,
          :final height,
          :final slantHeight,
        ):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'bottomDiameter',
              label: l10n.mold_calc_dim_bottom_diameter,
              initialValue: bottomDiameter,
            ),
            _buildNumberInput(
              keyName: 'topDiameter',
              label: l10n.mold_calc_dim_top_diameter,
              initialValue: topDiameter,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              l10n.mold_calc_use_slant_height,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            value: _useSlantHeight,
            onChanged: (val) {
              setState(() => _useSlantHeight = val);
              _rebuildFromControllers();
            },
          ),
          _buildNumberInput(
            keyName: _useSlantHeight ? 'slantHeight' : 'height',
            label: _useSlantHeight
                ? l10n.mold_calc_dim_slant_height
                : l10n.mold_calc_dim_height,
            initialValue: _useSlantHeight ? (slantHeight ?? height) : height,
          ),
        ];
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'bottomLength',
              label: l10n.mold_calc_dim_bottom_length,
              initialValue: bottomLength,
            ),
            _buildNumberInput(
              keyName: 'bottomWidth',
              label: l10n.mold_calc_dim_bottom_width,
              initialValue: bottomWidth,
            ),
          ),
          const SizedBox(height: 8),
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'topLength',
              label: l10n.mold_calc_dim_top_length,
              initialValue: topLength,
            ),
            _buildNumberInput(
              keyName: 'topWidth',
              label: l10n.mold_calc_dim_top_width,
              initialValue: topWidth,
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInput(
            keyName: 'height',
            label: l10n.mold_calc_dim_height,
            initialValue: height,
          ),
        ];
      case VChannelMold(:final bottomWidth, :final topWidth, :final length, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'bottomWidth',
              label: l10n.mold_calc_dim_bottom_width,
              initialValue: bottomWidth,
            ),
            _buildNumberInput(
              keyName: 'topWidth',
              label: l10n.mold_calc_dim_top_width,
              initialValue: topWidth,
            ),
          ),
          const SizedBox(height: 8),
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'length',
              label: l10n.mold_calc_dim_length,
              initialValue: length,
            ),
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
          ),
        ];
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
          :final flutingFactor,
        ):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'outerBottomDiameter',
              label: l10n.mold_calc_dim_bottom_diameter,
              initialValue: outerBottomDiameter,
            ),
            _buildNumberInput(
              keyName: 'outerTopDiameter',
              label: l10n.mold_calc_dim_top_diameter,
              initialValue: outerTopDiameter,
            ),
          ),
          const SizedBox(height: 8),
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'tubeBottomDiameter',
              label: l10n.mold_calc_dim_tube_bottom,
              initialValue: tubeBottomDiameter,
            ),
            _buildNumberInput(
              keyName: 'tubeTopDiameter',
              label: l10n.mold_calc_dim_tube_top,
              initialValue: tubeTopDiameter,
            ),
          ),
          const SizedBox(height: 8),
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
            _buildNumberInput(
              keyName: 'tubeHeight',
              label: l10n.mold_calc_dim_tube_height,
              initialValue: tubeHeight ?? height,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.mold_calc_dim_fluting}: ${flutingFactor.toStringAsFixed(2)}',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: flutingFactor.clamp(0.80, 1.0),
            min: 0.80,
            max: 1.0,
            divisions: 20,
            activeColor: widget.accentColor,
            label: flutingFactor.toStringAsFixed(2),
            onChanged: (eta) {
              _emitGeometry(
                AnnularTubeMold(
                  outerBottomDiameter: outerBottomDiameter,
                  outerTopDiameter: outerTopDiameter,
                  tubeBottomDiameter: tubeBottomDiameter,
                  tubeTopDiameter: tubeTopDiameter,
                  height: height,
                  tubeHeight: tubeHeight,
                  flutingFactor: eta,
                ),
              );
            },
          ),
        ];
      case SphericalCapMold(:final diameter, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'diameter',
              label: l10n.mold_calc_dim_diameter,
              initialValue: diameter,
            ),
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
          ),
        ];
      case UChannelMold(:final width, :final length, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'width',
              label: l10n.mold_calc_dim_width,
              initialValue: width,
            ),
            _buildNumberInput(
              keyName: 'length',
              label: l10n.mold_calc_dim_length,
              initialValue: length,
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInput(
            keyName: 'height',
            label: l10n.mold_calc_dim_height,
            initialValue: height,
          ),
        ];
      case RegularPolygonMold(:final sides, :final sideLength, :final height):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'sides',
              label: l10n.mold_calc_dim_sides_n,
              initialValue: sides.toDouble(),
              isInteger: true,
            ),
            _buildNumberInput(
              keyName: 'sideLength',
              label: l10n.mold_calc_dim_side,
              initialValue: sideLength,
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInput(
            keyName: 'height',
            label: l10n.mold_calc_dim_height,
            initialValue: height,
          ),
        ];
      case HeartShapeMold(:final width, :final length, :final height, :final shapeFactor):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'width',
              label: l10n.mold_calc_dim_width,
              initialValue: width,
            ),
            _buildNumberInput(
              keyName: 'length',
              label: l10n.mold_calc_dim_length,
              initialValue: length,
            ),
          ),
          const SizedBox(height: 8),
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
            _buildNumberInput(
              keyName: 'shapeFactor',
              label: l10n.mold_calc_dim_shape_factor,
              initialValue: shapeFactor,
            ),
          ),
        ];
      case WaterDisplacementMold(
          :final measuredVolumeMl,
          :final height,
          :final fillCurveExponent,
        ):
        return [
          _buildTwoUpRow(
            _buildNumberInput(
              keyName: 'measuredVolumeMl',
              label: l10n.mold_calc_dim_measured_ml,
              initialValue: measuredVolumeMl,
            ),
            _buildNumberInput(
              keyName: 'height',
              label: l10n.mold_calc_dim_height,
              initialValue: height,
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInput(
            keyName: 'fillCurveExponent',
            label: l10n.mold_calc_dim_fill_curve,
            initialValue: fillCurveExponent,
          ),
        ];
      case MultiCavityMold():
        return const [];
    }
  }

  Widget _buildTwoUpRow(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildNumberInput({
    required String keyName,
    required String label,
    required double initialValue,
    bool isInteger = false,
  }) {
    final ctrl = _controllerFor(keyName, initialValue);
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      onChanged: (_) => _rebuildFromControllers(),
    );
  }
}
