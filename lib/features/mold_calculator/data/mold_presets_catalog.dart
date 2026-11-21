import '../domain/entities/mold_geometry.dart';
import '../domain/entities/mold_preset.dart';

/// Built-in catalog of industry-standard baking molds, GN pans, and portion presets.
class MoldPresetsCatalog {
  MoldPresetsCatalog._();

  static final List<MoldPreset> builtInMolds = [
    // Round Cake Pans (5 cm & 7.5 cm tall)
    for (final d in [10.0, 12.0, 15.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0]) ...[
      MoldPreset(
        id: 'round_${d.toInt()}x5',
        label: '${d.toInt()} cm × 5 cm',
        category: MoldPresetCategory.roundCake,
        geometry: CircularCylinder(diameter: d, height: 5.0),
      ),
      MoldPreset(
        id: 'round_${d.toInt()}x7_5',
        label: '${d.toInt()} cm × 7.5 cm',
        category: MoldPresetCategory.roundCake,
        geometry: CircularCylinder(diameter: d, height: 7.5),
      ),
    ],

    // Square Pans
    for (final s in [15.0, 20.0, 23.0, 25.0])
      MoldPreset(
        id: 'square_${s.toInt()}',
        label: '${s.toInt()} × ${s.toInt()} × 5 cm',
        category: MoldPresetCategory.squarePan,
        geometry: SquarePrism(side: s, height: 5.0),
      ),

    // Gastronorm & Sheet Pans
    const MoldPreset(
      id: 'gn_1_1',
      label: 'GN 1/1 (53 × 32.5 × 4 cm)',
      category: MoldPresetCategory.gastronormSheet,
      geometry: RectangularPrism(length: 53.0, width: 32.5, height: 4.0),
    ),
    const MoldPreset(
      id: 'gn_1_2',
      label: 'GN 1/2 (32.5 × 26.5 × 4 cm)',
      category: MoldPresetCategory.gastronormSheet,
      geometry: RectangularPrism(length: 32.5, width: 26.5, height: 4.0),
    ),
    const MoldPreset(
      id: 'half_sheet',
      label: 'Half-Sheet (45 × 33 × 2.5 cm)',
      category: MoldPresetCategory.gastronormSheet,
      geometry: RectangularPrism(length: 45.0, width: 33.0, height: 2.5),
    ),

    // Loaf / Budineras
    const MoldPreset(
      id: 'loaf_tapered_std',
      label: 'Budinera 22 × 10 × 7 cm',
      category: MoldPresetCategory.loafBudinera,
      geometry: RectangularFrustum(
        bottomLength: 19.0,
        bottomWidth: 8.0,
        topLength: 22.0,
        topWidth: 10.0,
        height: 7.0,
      ),
    ),
    const MoldPreset(
      id: 'loaf_pullman_30',
      label: 'Pullman 30 × 10 × 10 cm',
      category: MoldPresetCategory.loafBudinera,
      geometry: RectangularPrism(length: 30.0, width: 10.0, height: 10.0),
    ),

    // Tube / Savarin / Bundt
    const MoldPreset(
      id: 'savarin_24',
      label: 'Savarin Ø 24 cm (Ø tube 7 cm)',
      category: MoldPresetCategory.tubeBundt,
      geometry: AnnularTubeMold(
        outerBottomDiameter: 24.0,
        outerTopDiameter: 24.0,
        tubeBottomDiameter: 7.0,
        tubeTopDiameter: 7.0,
        height: 6.0,
        flutingFactor: 1.0,
      ),
    ),
    const MoldPreset(
      id: 'bundt_25',
      label: 'Bundt Ø 25 cm (η = 0.88)',
      category: MoldPresetCategory.tubeBundt,
      geometry: AnnularTubeMold(
        outerBottomDiameter: 20.0,
        outerTopDiameter: 25.0,
        tubeBottomDiameter: 9.0,
        tubeTopDiameter: 7.0,
        height: 9.0,
        flutingFactor: 0.88,
      ),
    ),

    // Tart Rings
    for (final d in [18.0, 20.0, 22.0, 24.0])
      MoldPreset(
        id: 'tart_${d.toInt()}',
        label: 'Tart Ring ${d.toInt()} × 2 cm',
        category: MoldPresetCategory.tartRing,
        geometry: CircularCylinder(diameter: d, height: 2.0),
      ),
  ];

  static const List<PortionPreset> portionPresets = [
    // Radial
    PortionPreset(
      id: 'radial_event_5',
      strategy: CutStrategyType.radial,
      arcWidthCm: 5.0,
    ),
    PortionPreset(
      id: 'radial_generous_7',
      strategy: CutStrategyType.radial,
      arcWidthCm: 7.0,
    ),
    PortionPreset(
      id: 'radial_fixed_8',
      strategy: CutStrategyType.radial,
      sliceCount: 8,
    ),
    PortionPreset(
      id: 'radial_fixed_12',
      strategy: CutStrategyType.radial,
      sliceCount: 12,
    ),
    PortionPreset(
      id: 'radial_fixed_16',
      strategy: CutStrategyType.radial,
      sliceCount: 16,
    ),

    // Concentric
    PortionPreset(
      id: 'concentric_event',
      strategy: CutStrategyType.concentric,
      innerDiameterCm: 10.0,
      arcWidthCm: 5.0,
    ),

    // Grid
    PortionPreset(
      id: 'grid_petit_3x3',
      strategy: CutStrategyType.grid,
      pieceLengthCm: 3.0,
      pieceWidthCm: 3.0,
      edgeTrimCm: 0.5,
    ),
    PortionPreset(
      id: 'grid_event_5x5',
      strategy: CutStrategyType.grid,
      pieceLengthCm: 5.0,
      pieceWidthCm: 5.0,
      edgeTrimCm: 0.5,
    ),
    PortionPreset(
      id: 'grid_brownie_6x6',
      strategy: CutStrategyType.grid,
      pieceLengthCm: 6.0,
      pieceWidthCm: 6.0,
      edgeTrimCm: 0.0,
    ),
    PortionPreset(
      id: 'grid_brownie_7x7',
      strategy: CutStrategyType.grid,
      pieceLengthCm: 7.0,
      pieceWidthCm: 7.0,
      edgeTrimCm: 0.0,
    ),
    PortionPreset(
      id: 'grid_bar_8x4',
      strategy: CutStrategyType.grid,
      pieceLengthCm: 8.0,
      pieceWidthCm: 4.0,
      edgeTrimCm: 0.0,
    ),

    // Linear
    PortionPreset(
      id: 'linear_loaf_1_5',
      strategy: CutStrategyType.linear,
      sliceThicknessCm: 1.5,
      endTrimCm: 0.5,
    ),
    PortionPreset(
      id: 'linear_loaf_2_0',
      strategy: CutStrategyType.linear,
      sliceThicknessCm: 2.0,
      endTrimCm: 0.5,
    ),
  ];

  static MoldPreset get defaultSource =>
      builtInMolds.firstWhere((p) => p.id == 'round_20x5');

  static MoldPreset get defaultTarget =>
      builtInMolds.firstWhere((p) => p.id == 'round_24x5');
}
