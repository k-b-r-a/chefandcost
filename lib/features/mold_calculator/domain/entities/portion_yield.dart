import 'mold_preset.dart';

/// Pure-Dart rectangle representing a cut piece inside the top-down layout (cm).
class PortionGridRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const PortionGridRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Output of portion yield calculation including cut geometry & trim waste (merma).
class PortionYieldResult {
  final CutStrategyType strategy;
  final int fullPortions;
  final double portionVolumeMl;
  final double portionAreaCm2;
  final double totalAreaCm2;
  final double usedAreaCm2;
  final double wasteAreaCm2;
  final double wastePercent;

  // Radial / concentric metadata
  final double? outerArcCm;
  final double? innerArcCm;
  final int? innerPortions;
  final int? outerPortions;
  final double? innerDiameterCm;
  final double? outerDiameterCm;

  // Grid metadata
  final int? columns;
  final int? rows;
  final double? pieceLengthCm;
  final double? pieceWidthCm;
  final double edgeTrimCm;
  final bool rotatedOrientation;
  final List<PortionGridRect> rects;
  final double? panLengthCm;
  final double? panWidthCm;
  final bool isCircularPan;

  // Linear metadata
  final double? sliceThicknessCm;
  final double endTrimCm;
  final double? totalLengthCm;
  final double? usedLengthCm;

  const PortionYieldResult({
    required this.strategy,
    required this.fullPortions,
    required this.portionVolumeMl,
    required this.portionAreaCm2,
    required this.totalAreaCm2,
    required this.usedAreaCm2,
    required this.wasteAreaCm2,
    required this.wastePercent,
    this.outerArcCm,
    this.innerArcCm,
    this.innerPortions,
    this.outerPortions,
    this.innerDiameterCm,
    this.outerDiameterCm,
    this.columns,
    this.rows,
    this.pieceLengthCm,
    this.pieceWidthCm,
    this.edgeTrimCm = 0.0,
    this.rotatedOrientation = false,
    this.rects = const [],
    this.panLengthCm,
    this.panWidthCm,
    this.isCircularPan = false,
    this.sliceThicknessCm,
    this.endTrimCm = 0.0,
    this.totalLengthCm,
    this.usedLengthCm,
  });
}
