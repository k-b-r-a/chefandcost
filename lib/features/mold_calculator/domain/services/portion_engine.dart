import 'dart:math' as math;
import '../entities/mold_geometry.dart';
import '../entities/mold_preset.dart';
import '../entities/portion_yield.dart';
import '../validators/mold_validator.dart';
import 'geometry_engine.dart';

/// Pure Dart portion layout & waste (merma) engine for radial, concentric, grid, and linear slicing.
class PortionEngine {
  PortionEngine._();

  static double _topSurfaceArea(MoldGeometry mold, double fillRatio) {
    final top = mold.topArea();
    if (top > kMoldEpsilon) return top;
    final hFill = GeometryEngine.effectiveFillHeight(mold, fillRatio);
    final atFill = mold.crossSectionAreaAt(hFill);
    if (atFill > kMoldEpsilon) return atFill;
    return GeometryEngine.effectiveFootprintArea(mold, fillRatio);
  }

  static bool _isCircularLayout(MoldGeometry mold) {
    return switch (mold) {
      CircularCylinder() ||
      CircularFrustum() ||
      AnnularTubeMold() ||
      SphericalCapMold() ||
      RegularPolygonMold() ||
      HeartShapeMold() ||
      WaterDisplacementMold() =>
        true,
      SquarePrism() ||
      RectangularPrism() ||
      RectangularFrustum() ||
      VChannelMold() ||
      UChannelMold() =>
        false,
      MultiCavityMold(:final singleCavity) => _isCircularLayout(singleCavity),
    };
  }

  /// Radial wedge cuts (e.g. round cake, tart, or Savarin/Bundt).
  static PortionYieldResult calculateRadial({
    required MoldGeometry mold,
    required double fillRatio,
    int? fixedSlices,
    double targetArcCm = 5.0,
  }) {
    MoldValidator.assertValidMold(mold, fillRatio: fillRatio);

    if (mold is MultiCavityMold) {
      final single = calculateRadial(
        mold: mold.singleCavity,
        fillRatio: fillRatio,
        fixedSlices: fixedSlices,
        targetArcCm: targetArcCm,
      );
      final n = math.max(1, mold.cavityCount);
      return PortionYieldResult(
        strategy: CutStrategyType.radial,
        fullPortions: single.fullPortions * n,
        portionVolumeMl: single.portionVolumeMl,
        portionAreaCm2: single.portionAreaCm2,
        totalAreaCm2: single.totalAreaCm2 * n,
        usedAreaCm2: single.usedAreaCm2 * n,
        wasteAreaCm2: single.wasteAreaCm2 * n,
        wastePercent: single.wastePercent,
        outerArcCm: single.outerArcCm,
        innerArcCm: single.innerArcCm,
        outerDiameterCm: single.outerDiameterCm,
        innerDiameterCm: single.innerDiameterCm,
        isCircularPan: true,
      );
    }

    final effVol = GeometryEngine.effectiveVolume(mold, fillRatio);
    final totalArea = _topSurfaceArea(mold, fillRatio);

    final outerD = switch (mold) {
      CircularFrustum(:final topDiameter) => topDiameter,
      AnnularTubeMold(:final outerTopDiameter) => outerTopDiameter,
      _ => mold.boundingWidth,
    };
    final innerD = switch (mold) {
      AnnularTubeMold(:final tubeTopDiameter) => tubeTopDiameter,
      _ => 0.0,
    };

    final outerR = outerD / 2.0;
    final circumference = 2.0 * math.pi * outerR;
    final safeArc = targetArcCm > 0.5 ? targetArcCm : 5.0;
    final slices = (fixedSlices != null && fixedSlices >= 1)
        ? fixedSlices
        : math.max(1, (circumference / safeArc).floor());

    final outerArc = slices > 0 ? circumference / slices : 0.0;
    final innerArc =
        (innerD > 0.0 && slices > 0) ? (math.pi * innerD) / slices : 0.0;

    return PortionYieldResult(
      strategy: CutStrategyType.radial,
      fullPortions: slices,
      portionVolumeMl: slices > 0 ? effVol / slices : 0.0,
      portionAreaCm2: slices > 0 ? totalArea / slices : 0.0,
      totalAreaCm2: totalArea,
      usedAreaCm2: totalArea,
      wasteAreaCm2: 0.0,
      wastePercent: 0.0,
      outerArcCm: outerArc,
      innerArcCm: innerArc,
      outerDiameterCm: outerD,
      innerDiameterCm: innerD,
      isCircularPan: true,
    );
  }

  /// Concentric ring slicing (inner cylinder + outer radial ring for >= 22 cm round cakes).
  static PortionYieldResult calculateConcentric({
    required MoldGeometry mold,
    required double fillRatio,
    double innerDiameterCm = 10.0,
    double targetArcCm = 5.0,
    int? innerSlices,
    int? outerSlices,
  }) {
    MoldValidator.assertValidMold(mold, fillRatio: fillRatio);

    if (mold is MultiCavityMold) {
      final single = calculateConcentric(
        mold: mold.singleCavity,
        fillRatio: fillRatio,
        innerDiameterCm: innerDiameterCm,
        targetArcCm: targetArcCm,
        innerSlices: innerSlices,
        outerSlices: outerSlices,
      );
      final n = math.max(1, mold.cavityCount);
      return PortionYieldResult(
        strategy: CutStrategyType.concentric,
        fullPortions: single.fullPortions * n,
        portionVolumeMl: single.portionVolumeMl,
        portionAreaCm2: single.portionAreaCm2,
        totalAreaCm2: single.totalAreaCm2 * n,
        usedAreaCm2: single.usedAreaCm2 * n,
        wasteAreaCm2: single.wasteAreaCm2 * n,
        wastePercent: single.wastePercent,
        innerPortions: (single.innerPortions ?? 0) * n,
        outerPortions: (single.outerPortions ?? 0) * n,
        innerDiameterCm: single.innerDiameterCm,
        outerDiameterCm: single.outerDiameterCm,
        outerArcCm: single.outerArcCm,
        innerArcCm: single.innerArcCm,
        isCircularPan: true,
      );
    }

    final effVol = GeometryEngine.effectiveVolume(mold, fillRatio);
    final totalArea = _topSurfaceArea(mold, fillRatio);
    final outerD = switch (mold) {
      CircularFrustum(:final topDiameter) => topDiameter,
      AnnularTubeMold(:final outerTopDiameter) => outerTopDiameter,
      _ => mold.boundingWidth,
    };

    final safeInnerD = innerDiameterCm.clamp(2.0, math.max(2.0, outerD * 0.75));
    final safeArc = targetArcCm > 0.5 ? targetArcCm : 5.0;

    final innerCirc = math.pi * safeInnerD;
    final outerCirc = math.pi * outerD;

    final innerCount = (innerSlices != null && innerSlices >= 1)
        ? innerSlices
        : math.max(1, (innerCirc / safeArc).floor());
    final outerCount = (outerSlices != null && outerSlices >= 1)
        ? outerSlices
        : math.max(1, (outerCirc / safeArc).floor());

    final totalCount = innerCount + outerCount;

    return PortionYieldResult(
      strategy: CutStrategyType.concentric,
      fullPortions: totalCount,
      portionVolumeMl: totalCount > 0 ? effVol / totalCount : 0.0,
      portionAreaCm2: totalCount > 0 ? totalArea / totalCount : 0.0,
      totalAreaCm2: totalArea,
      usedAreaCm2: totalArea,
      wasteAreaCm2: 0.0,
      wastePercent: 0.0,
      innerPortions: innerCount,
      outerPortions: outerCount,
      innerDiameterCm: safeInnerD.toDouble(),
      outerDiameterCm: outerD,
      innerArcCm: innerCirc / innerCount,
      outerArcCm: outerCirc / outerCount,
      isCircularPan: true,
    );
  }

  /// Cartesian grid slicing with automatic 0° vs 90° orientation optimization and trim waste.
  static PortionYieldResult calculateGrid({
    required MoldGeometry mold,
    required double fillRatio,
    required double pieceLengthCm,
    required double pieceWidthCm,
    double edgeTrimCm = 0.0,
  }) {
    MoldValidator.assertValidMold(mold, fillRatio: fillRatio);

    if (pieceLengthCm <= 0.0 ||
        !pieceLengthCm.isFinite ||
        pieceWidthCm <= 0.0 ||
        !pieceWidthCm.isFinite ||
        edgeTrimCm < 0.0 ||
        !edgeTrimCm.isFinite) {
      throw const MoldValidationException([
        MoldValidationError(
          code: MoldValidationErrorCode.invalidPortionDimension,
          field: 'pieceSize',
        ),
      ]);
    }

    if (mold is MultiCavityMold) {
      final single = calculateGrid(
        mold: mold.singleCavity,
        fillRatio: fillRatio,
        pieceLengthCm: pieceLengthCm,
        pieceWidthCm: pieceWidthCm,
        edgeTrimCm: edgeTrimCm,
      );
      final n = math.max(1, mold.cavityCount);
      return PortionYieldResult(
        strategy: CutStrategyType.grid,
        fullPortions: single.fullPortions * n,
        portionVolumeMl: single.portionVolumeMl,
        portionAreaCm2: single.portionAreaCm2,
        totalAreaCm2: single.totalAreaCm2 * n,
        usedAreaCm2: single.usedAreaCm2 * n,
        wasteAreaCm2: single.wasteAreaCm2 * n,
        wastePercent: single.wastePercent,
        columns: single.columns,
        rows: single.rows,
        pieceLengthCm: single.pieceLengthCm,
        pieceWidthCm: single.pieceWidthCm,
        edgeTrimCm: single.edgeTrimCm,
        rotatedOrientation: single.rotatedOrientation,
        rects: single.rects,
        panLengthCm: single.panLengthCm,
        panWidthCm: single.panWidthCm,
        isCircularPan: single.isCircularPan,
      );
    }

    final effVol = GeometryEngine.effectiveVolume(mold, fillRatio);
    final totalArea = _topSurfaceArea(mold, fillRatio);
    final isCircular = _isCircularLayout(mold);
    final pieceArea = pieceLengthCm * pieceWidthCm;

    if (isCircular) {
      final d = mold.boundingWidth;
      final r = d / 2.0;
      final usableR = math.max(0.0, r - edgeTrimCm);

      final optA = _packCircleGrid(
        radius: usableR,
        centerX: r,
        centerY: r,
        cellW: pieceLengthCm,
        cellH: pieceWidthCm,
      );
      final optB = _packCircleGrid(
        radius: usableR,
        centerX: r,
        centerY: r,
        cellW: pieceWidthCm,
        cellH: pieceLengthCm,
      );

      final useRotated = optB.rects.length > optA.rects.length;
      final chosen = useRotated ? optB : optA;
      final count = chosen.rects.length;
      final usedArea = math.min(totalArea, count * pieceArea);
      final wasteArea = math.max(0.0, totalArea - usedArea);
      final wastePct = totalArea > kMoldEpsilon ? (wasteArea / totalArea) * 100.0 : 0.0;
      final portionVol = totalArea > kMoldEpsilon
          ? effVol * (pieceArea / totalArea)
          : 0.0;

      return PortionYieldResult(
        strategy: CutStrategyType.grid,
        fullPortions: count,
        portionVolumeMl: count > 0 ? portionVol : 0.0,
        portionAreaCm2: count > 0 ? pieceArea : 0.0,
        totalAreaCm2: totalArea,
        usedAreaCm2: usedArea,
        wasteAreaCm2: wasteArea,
        wastePercent: wastePct,
        columns: chosen.cols,
        rows: chosen.rows,
        pieceLengthCm: useRotated ? pieceWidthCm : pieceLengthCm,
        pieceWidthCm: useRotated ? pieceLengthCm : pieceWidthCm,
        edgeTrimCm: edgeTrimCm,
        rotatedOrientation: useRotated,
        rects: chosen.rects,
        panLengthCm: d,
        panWidthCm: d,
        isCircularPan: true,
      );
    }

    final panL = mold.boundingLength;
    final panW = mold.boundingWidth;
    final usableL = math.max(0.0, panL - 2.0 * edgeTrimCm);
    final usableW = math.max(0.0, panW - 2.0 * edgeTrimCm);

    final colsA = ((usableL + kMoldEpsilon) / pieceLengthCm).floor();
    final rowsA = ((usableW + kMoldEpsilon) / pieceWidthCm).floor();
    final countA = colsA * rowsA;

    final colsB = ((usableL + kMoldEpsilon) / pieceWidthCm).floor();
    final rowsB = ((usableW + kMoldEpsilon) / pieceLengthCm).floor();
    final countB = colsB * rowsB;

    final useRotated = countB > countA;
    final cols = useRotated ? colsB : colsA;
    final rows = useRotated ? rowsB : rowsA;
    final cellL = useRotated ? pieceWidthCm : pieceLengthCm;
    final cellW = useRotated ? pieceLengthCm : pieceWidthCm;
    final count = cols * rows;

    final rects = <PortionGridRect>[];
    final usedSpanL = cols * cellL;
    final usedSpanW = rows * cellW;
    final startX = edgeTrimCm + (usableL - usedSpanL) / 2.0;
    final startY = edgeTrimCm + (usableW - usedSpanW) / 2.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        rects.add(
          PortionGridRect(
            x: startX + c * cellL,
            y: startY + r * cellW,
            width: cellL,
            height: cellW,
          ),
        );
      }
    }

    final boxArea = panL * panW;
    final refArea = totalArea > kMoldEpsilon ? totalArea : boxArea;
    final usedArea = math.min(refArea, count * pieceArea);
    final wasteArea = math.max(0.0, refArea - usedArea);
    final wastePct = refArea > kMoldEpsilon ? (wasteArea / refArea) * 100.0 : 0.0;
    final portionVol = refArea > kMoldEpsilon ? effVol * (pieceArea / refArea) : 0.0;

    return PortionYieldResult(
      strategy: CutStrategyType.grid,
      fullPortions: count,
      portionVolumeMl: count > 0 ? portionVol : 0.0,
      portionAreaCm2: count > 0 ? pieceArea : 0.0,
      totalAreaCm2: refArea,
      usedAreaCm2: usedArea,
      wasteAreaCm2: wasteArea,
      wastePercent: wastePct,
      columns: cols,
      rows: rows,
      pieceLengthCm: cellL,
      pieceWidthCm: cellW,
      edgeTrimCm: edgeTrimCm,
      rotatedOrientation: useRotated,
      rects: rects,
      panLengthCm: panL,
      panWidthCm: panW,
      isCircularPan: false,
    );
  }

  static ({int cols, int rows, List<PortionGridRect> rects}) _packCircleGrid({
    required double radius,
    required double centerX,
    required double centerY,
    required double cellW,
    required double cellH,
  }) {
    if (radius <= 0.0 || cellW <= 0.0 || cellH <= 0.0) {
      return (cols: 0, rows: 0, rects: const []);
    }

    final maxCols = ((2.0 * radius) / cellW).floor() + 2;
    final maxRows = ((2.0 * radius) / cellH).floor() + 2;

    List<PortionGridRect> best = const [];
    var bestCols = 0;
    var bestRows = 0;

    // Test both centered-on-cell and centered-on-edge alignments
    for (final xShift in [0.0, 0.5]) {
      for (final yShift in [0.0, 0.5]) {
        final found = <PortionGridRect>[];
        final colIndices = <int>{};
        final rowIndices = <int>{};
        for (var r = -maxRows; r <= maxRows; r++) {
          for (var c = -maxCols; c <= maxCols; c++) {
            final localLeft = (c - xShift) * cellW;
            final localTop = (r - yShift) * cellH;
            final localRight = localLeft + cellW;
            final localBottom = localTop + cellH;
            if (_allCornersInside(
              localLeft,
              localTop,
              localRight,
              localBottom,
              radius,
            )) {
              colIndices.add(c);
              rowIndices.add(r);
              found.add(
                PortionGridRect(
                  x: centerX + localLeft,
                  y: centerY + localTop,
                  width: cellW,
                  height: cellH,
                ),
              );
            }
          }
        }
        if (found.length > best.length) {
          best = found;
          bestCols = colIndices.length;
          bestRows = rowIndices.length;
        }
      }
    }

    return (cols: bestCols, rows: bestRows, rects: best);
  }

  static bool _allCornersInside(
    double left,
    double top,
    double right,
    double bottom,
    double radius,
  ) {
    final r2 = radius * radius + 1e-6;
    return (left * left + top * top <= r2) &&
        (right * right + top * top <= r2) &&
        (left * left + bottom * bottom <= r2) &&
        (right * right + bottom * bottom <= r2);
  }

  /// Linear loaf / budinera / channel slicing along [boundingLength].
  static PortionYieldResult calculateLinear({
    required MoldGeometry mold,
    required double fillRatio,
    required double sliceThicknessCm,
    double endTrimCm = 0.0,
  }) {
    MoldValidator.assertValidMold(mold, fillRatio: fillRatio);

    if (sliceThicknessCm <= 0.0 ||
        !sliceThicknessCm.isFinite ||
        endTrimCm < 0.0 ||
        !endTrimCm.isFinite) {
      throw const MoldValidationException([
        MoldValidationError(
          code: MoldValidationErrorCode.invalidPortionDimension,
          field: 'sliceThickness',
        ),
      ]);
    }

    if (mold is MultiCavityMold) {
      final single = calculateLinear(
        mold: mold.singleCavity,
        fillRatio: fillRatio,
        sliceThicknessCm: sliceThicknessCm,
        endTrimCm: endTrimCm,
      );
      final n = math.max(1, mold.cavityCount);
      return PortionYieldResult(
        strategy: CutStrategyType.linear,
        fullPortions: single.fullPortions * n,
        portionVolumeMl: single.portionVolumeMl,
        portionAreaCm2: single.portionAreaCm2,
        totalAreaCm2: single.totalAreaCm2 * n,
        usedAreaCm2: single.usedAreaCm2 * n,
        wasteAreaCm2: single.wasteAreaCm2 * n,
        wastePercent: single.wastePercent,
        sliceThicknessCm: single.sliceThicknessCm,
        endTrimCm: single.endTrimCm,
        totalLengthCm: single.totalLengthCm,
        usedLengthCm: single.usedLengthCm,
        panLengthCm: single.panLengthCm,
        panWidthCm: single.panWidthCm,
      );
    }

    final effVol = GeometryEngine.effectiveVolume(mold, fillRatio);
    final totalArea = _topSurfaceArea(mold, fillRatio);
    final totalLen = mold.boundingLength;
    final usableLen = math.max(0.0, totalLen - 2.0 * endTrimCm);
    final slices = ((usableLen + kMoldEpsilon) / sliceThicknessCm).floor();
    final usedLen = slices * sliceThicknessCm;
    final usedFraction =
        totalLen > kMoldEpsilon ? (usedLen / totalLen).clamp(0.0, 1.0) : 0.0;

    final usedArea = totalArea * usedFraction;
    final wasteArea = math.max(0.0, totalArea - usedArea);
    final wastePct = (1.0 - usedFraction) * 100.0;
    final usedVol = effVol * usedFraction;

    return PortionYieldResult(
      strategy: CutStrategyType.linear,
      fullPortions: slices,
      portionVolumeMl: slices > 0 ? usedVol / slices : 0.0,
      portionAreaCm2: slices > 0 ? usedArea / slices : 0.0,
      totalAreaCm2: totalArea,
      usedAreaCm2: usedArea,
      wasteAreaCm2: wasteArea,
      wastePercent: wastePct,
      sliceThicknessCm: sliceThicknessCm,
      endTrimCm: endTrimCm,
      totalLengthCm: totalLen,
      usedLengthCm: usedLen,
      panLengthCm: totalLen,
      panWidthCm: mold.boundingWidth,
    );
  }
}
