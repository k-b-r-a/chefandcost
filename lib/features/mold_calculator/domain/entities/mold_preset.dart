import 'mold_geometry.dart';

enum MoldPresetCategory {
  roundCake,
  squarePan,
  gastronormSheet,
  loafBudinera,
  tubeBundt,
  tartRing,
  custom,
}

/// Industry-standard or user-saved mold preset.
class MoldPreset {
  final String id;
  final String label;
  final MoldPresetCategory category;
  final MoldGeometry geometry;
  final bool isCustom;

  const MoldPreset({
    required this.id,
    required this.label,
    required this.category,
    required this.geometry,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'category': category.name,
        'geometry': geometry.toJson(),
        'isCustom': isCustom,
      };

  static MoldPreset fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String?;
    final category = MoldPresetCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => MoldPresetCategory.custom,
    );
    final geomMap = json['geometry'];
    final geometry = geomMap is Map<String, dynamic>
        ? MoldGeometry.fromJson(geomMap)
        : const CircularCylinder(diameter: 20.0, height: 5.0);

    return MoldPreset(
      id: (json['id'] as String?) ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: (json['label'] as String?) ?? 'Custom Mold',
      category: category,
      geometry: geometry,
      isCustom: (json['isCustom'] as bool?) ?? true,
    );
  }
}

enum CutStrategyType {
  radial,
  concentric,
  grid,
  linear,
}

/// Portioning preset for radial, concentric, grid, or linear slicing.
class PortionPreset {
  final String id;
  final CutStrategyType strategy;
  final double? arcWidthCm;
  final int? sliceCount;
  final double? innerDiameterCm;
  final double? pieceLengthCm;
  final double? pieceWidthCm;
  final double edgeTrimCm;
  final double? sliceThicknessCm;
  final double endTrimCm;

  const PortionPreset({
    required this.id,
    required this.strategy,
    this.arcWidthCm,
    this.sliceCount,
    this.innerDiameterCm,
    this.pieceLengthCm,
    this.pieceWidthCm,
    this.edgeTrimCm = 0.0,
    this.sliceThicknessCm,
    this.endTrimCm = 0.0,
  });
}
