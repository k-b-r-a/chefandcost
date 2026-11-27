import 'dart:math' as math;
import '../entities/mold_geometry.dart';
import '../validators/mold_validator.dart';
import 'geometry_engine.dart';

enum SolveParameter {
  primaryDimension,
  height,
}

class EquivalenceResult {
  final MoldGeometry solvedMold;
  final double solvedValueCm;
  final double achievedVolumeMl;
  final double targetVolumeMl;
  final bool usedClosedForm;
  final int iterations;
  final bool converged;
  final MoldValidationErrorCode? errorCode;

  const EquivalenceResult({
    required this.solvedMold,
    required this.solvedValueCm,
    required this.achievedVolumeMl,
    required this.targetVolumeMl,
    required this.usedClosedForm,
    required this.iterations,
    required this.converged,
    this.errorCode,
  });
}

/// Solves for the target mold dimension that matches [targetVolumeMl] at [targetFillRatio].
///
/// Uses closed-form algebra for straight-walled prisms/cylinders and safeguarded
/// Newton-Raphson + Bisection (tolerance 1e-4 cm, max 50 iterations) for non-linear shapes.
class EquivalenceSolver {
  EquivalenceSolver._();

  static EquivalenceResult solve({
    required double targetVolumeMl,
    required MoldGeometry template,
    required double targetFillRatio,
    SolveParameter parameter = SolveParameter.primaryDimension,
    double toleranceCm = 1e-4,
    int maxIterations = 50,
  }) {
    if (!targetVolumeMl.isFinite || targetVolumeMl <= 0.0) {
      return EquivalenceResult(
        solvedMold: template,
        solvedValueCm: template.boundingWidth,
        achievedVolumeMl: GeometryEngine.effectiveVolume(template, targetFillRatio),
        targetVolumeMl: targetVolumeMl,
        usedClosedForm: false,
        iterations: 0,
        converged: false,
        errorCode: MoldValidationErrorCode.nonPositiveDimension,
      );
    }

    if (!targetFillRatio.isFinite ||
        targetFillRatio <= 0.0 ||
        targetFillRatio > 1.0 + kMoldEpsilon) {
      return EquivalenceResult(
        solvedMold: template,
        solvedValueCm: template.boundingWidth,
        achievedVolumeMl: GeometryEngine.effectiveVolume(template, targetFillRatio),
        targetVolumeMl: targetVolumeMl,
        usedClosedForm: false,
        iterations: 0,
        converged: false,
        errorCode: MoldValidationErrorCode.invalidFillRatio,
      );
    }

    if (template is MultiCavityMold) {
      final count = math.max(1, template.cavityCount);
      final singleResult = solve(
        targetVolumeMl: targetVolumeMl / count,
        template: template.singleCavity,
        targetFillRatio: targetFillRatio,
        parameter: parameter,
        toleranceCm: toleranceCm,
        maxIterations: maxIterations,
      );
      final wrapped = MultiCavityMold(
        singleCavity: singleResult.solvedMold,
        cavityCount: count,
      );
      return EquivalenceResult(
        solvedMold: wrapped,
        solvedValueCm: singleResult.solvedValueCm,
        achievedVolumeMl: GeometryEngine.effectiveVolume(wrapped, targetFillRatio),
        targetVolumeMl: targetVolumeMl,
        usedClosedForm: singleResult.usedClosedForm,
        iterations: singleResult.iterations,
        converged: singleResult.converged,
        errorCode: singleResult.errorCode,
      );
    }

    if (parameter == SolveParameter.height) {
      return _solveForHeight(
        targetVolumeMl: targetVolumeMl,
        template: template,
        targetFillRatio: targetFillRatio,
        toleranceCm: toleranceCm,
        maxIterations: maxIterations,
      );
    }

    return _solveForPrimaryDimension(
      targetVolumeMl: targetVolumeMl,
      template: template,
      targetFillRatio: targetFillRatio,
      toleranceCm: toleranceCm,
      maxIterations: maxIterations,
    );
  }

  static EquivalenceResult _solveForPrimaryDimension({
    required double targetVolumeMl,
    required MoldGeometry template,
    required double targetFillRatio,
    required double toleranceCm,
    required int maxIterations,
  }) {
    final p = targetFillRatio;

    switch (template) {
      case CircularCylinder(:final height):
        final d = 2.0 * math.sqrt(targetVolumeMl / (math.pi * p * height));
        final solved = CircularCylinder(diameter: d, height: height);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: d,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case SquarePrism(:final height):
        final s = math.sqrt(targetVolumeMl / (p * height));
        final solved = SquarePrism(side: s, height: height);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: s,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case RectangularPrism(:final width, :final height):
        final l = targetVolumeMl / (width * p * height);
        final solved = RectangularPrism(length: l, width: width, height: height);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: l,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case RegularPolygonMold(:final sides, :final height):
        final s = math.sqrt(
          (4.0 * math.tan(math.pi / sides) * targetVolumeMl) / (sides * p * height),
        );
        final solved = RegularPolygonMold(
          sides: sides,
          sideLength: s,
          height: height,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: s,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case HeartShapeMold(:final length, :final height, :final shapeFactor):
        final w = targetVolumeMl / (shapeFactor * length * p * height);
        final solved = HeartShapeMold(
          width: w,
          length: length,
          height: height,
          shapeFactor: shapeFactor,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: w,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case WaterDisplacementMold(:final height, :final fillCurveExponent):
        final vTotal = targetVolumeMl / math.pow(p, fillCurveExponent);
        final solved = WaterDisplacementMold(
          measuredVolumeMl: vTotal,
          height: height,
          fillCurveExponent: fillCurveExponent,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: vTotal,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case CircularFrustum(:final bottomDiameter, :final topDiameter, :final height):
        final h = template.totalHeight;
        final ratio = topDiameter > 0.0 ? bottomDiameter / topDiameter : 1.0;
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, topDiameter),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (dTop) => CircularFrustum(
            bottomDiameter: ratio <= 0.0 ? 0.0 : dTop * ratio,
            topDiameter: dTop,
            height: h > 0.0 ? h : height,
          ),
        );
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        final ratio = topLength > 0.0 ? bottomLength / topLength : 1.0;
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, topLength),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (lTop) => RectangularFrustum(
            bottomLength: lTop * ratio,
            bottomWidth: bottomWidth,
            topLength: lTop,
            topWidth: topWidth,
            height: height,
          ),
        );
      case VChannelMold(:final bottomWidth, :final topWidth, :final length, :final height):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, length),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (len) => VChannelMold(
            bottomWidth: bottomWidth,
            topWidth: topWidth,
            length: len,
            height: height,
          ),
        );
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
          :final flutingFactor,
        ):
        final ratio =
            outerTopDiameter > 0.0 ? outerBottomDiameter / outerTopDiameter : 1.0;
        final minFromBottom =
            ratio > 0.0 ? (tubeBottomDiameter + 0.2) / ratio : tubeTopDiameter + 0.2;
        final minOuterTop = math.max(tubeTopDiameter + 0.2, minFromBottom);
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(minOuterTop + 1.0, outerTopDiameter),
          minBound: minOuterTop,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (dOuterTop) => AnnularTubeMold(
            outerBottomDiameter: dOuterTop * ratio,
            outerTopDiameter: dOuterTop,
            tubeBottomDiameter: tubeBottomDiameter,
            tubeTopDiameter: tubeTopDiameter,
            height: height,
            tubeHeight: tubeHeight,
            flutingFactor: flutingFactor,
          ),
        );
      case SphericalCapMold(:final diameter, :final height):
        final minDiameter = 2.0 * height;
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(minDiameter, diameter),
          minBound: minDiameter,
          maxBoundLimit: 10000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (d) => SphericalCapMold(diameter: d, height: height),
        );
      case UChannelMold(:final width, :final length, :final height):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, length),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (len) => UChannelMold(
            width: width,
            length: len,
            height: height,
          ),
        );
      case MultiCavityMold():
        throw StateError('MultiCavityMold handled above');
    }
  }

  static EquivalenceResult _solveForHeight({
    required double targetVolumeMl,
    required MoldGeometry template,
    required double targetFillRatio,
    required double toleranceCm,
    required int maxIterations,
  }) {
    final p = targetFillRatio;

    switch (template) {
      case CircularCylinder(:final diameter):
        final a = template.baseArea();
        final h = targetVolumeMl / (a * p);
        final solved = CircularCylinder(diameter: diameter, height: h);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case SquarePrism(:final side):
        final a = template.baseArea();
        final h = targetVolumeMl / (a * p);
        final solved = SquarePrism(side: side, height: h);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case RectangularPrism(:final length, :final width):
        final a = template.baseArea();
        final h = targetVolumeMl / (a * p);
        final solved = RectangularPrism(length: length, width: width, height: h);
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case RegularPolygonMold(:final sides, :final sideLength):
        final a = template.baseArea();
        final h = targetVolumeMl / (a * p);
        final solved = RegularPolygonMold(
          sides: sides,
          sideLength: sideLength,
          height: h,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case HeartShapeMold(:final width, :final length, :final shapeFactor):
        final a = template.baseArea();
        final h = targetVolumeMl / (a * p);
        final solved = HeartShapeMold(
          width: width,
          length: length,
          height: h,
          shapeFactor: shapeFactor,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case WaterDisplacementMold(:final measuredVolumeMl, :final height, :final fillCurveExponent):
        final currentEff = GeometryEngine.effectiveVolume(template, p);
        final h = currentEff > kMoldEpsilon ? height * (targetVolumeMl / currentEff) : height;
        final solved = WaterDisplacementMold(
          measuredVolumeMl: measuredVolumeMl,
          height: h,
          fillCurveExponent: fillCurveExponent,
        );
        return EquivalenceResult(
          solvedMold: solved,
          solvedValueCm: h,
          achievedVolumeMl: GeometryEngine.effectiveVolume(solved, p),
          targetVolumeMl: targetVolumeMl,
          usedClosedForm: true,
          iterations: 1,
          converged: true,
        );
      case CircularFrustum(:final bottomDiameter, :final topDiameter, :final height):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, height),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => CircularFrustum(
            bottomDiameter: bottomDiameter,
            topDiameter: topDiameter,
            height: h,
          ),
        );
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, height),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => RectangularFrustum(
            bottomLength: bottomLength,
            bottomWidth: bottomWidth,
            topLength: topLength,
            topWidth: topWidth,
            height: h,
          ),
        );
      case VChannelMold(:final bottomWidth, :final topWidth, :final length, :final height):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, height),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => VChannelMold(
            bottomWidth: bottomWidth,
            topWidth: topWidth,
            length: length,
            height: h,
          ),
        );
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
          :final flutingFactor,
        ):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, height),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => AnnularTubeMold(
            outerBottomDiameter: outerBottomDiameter,
            outerTopDiameter: outerTopDiameter,
            tubeBottomDiameter: tubeBottomDiameter,
            tubeTopDiameter: tubeTopDiameter,
            height: h,
            tubeHeight: tubeHeight != null ? math.min(tubeHeight, h) : null,
            flutingFactor: flutingFactor,
          ),
        );
      case SphericalCapMold(:final diameter, :final height):
        final maxH = diameter / 2.0;
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.min(height, maxH * 0.5),
          minBound: 0.05,
          maxBoundLimit: maxH,
          fixedMaxBound: maxH,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => SphericalCapMold(diameter: diameter, height: h),
        );
      case UChannelMold(:final width, :final length, :final height):
        return _safeguardedNewtonBisection(
          targetVolumeMl: targetVolumeMl,
          targetFillRatio: p,
          initialGuess: math.max(1.0, height),
          minBound: 0.1,
          maxBoundLimit: 5000.0,
          toleranceCm: toleranceCm,
          maxIterations: maxIterations,
          buildMold: (h) => UChannelMold(
            width: width,
            length: length,
            height: h,
          ),
        );
      case MultiCavityMold():
        throw StateError('MultiCavityMold handled above');
    }
  }

  static EquivalenceResult _safeguardedNewtonBisection({
    required double targetVolumeMl,
    required double targetFillRatio,
    required double initialGuess,
    required double minBound,
    required double maxBoundLimit,
    double? fixedMaxBound,
    required double toleranceCm,
    required int maxIterations,
    required MoldGeometry Function(double x) buildMold,
  }) {
    double evalVol(double x) =>
        GeometryEngine.effectiveVolume(buildMold(x), targetFillRatio);

    var lo = minBound;
    final fLo = evalVol(lo) - targetVolumeMl;
    if (fLo >= 0.0) {
      final solved = buildMold(lo);
      return EquivalenceResult(
        solvedMold: solved,
        solvedValueCm: lo,
        achievedVolumeMl: evalVol(lo),
        targetVolumeMl: targetVolumeMl,
        usedClosedForm: false,
        iterations: 0,
        converged: fLo.abs() <= 1e-4,
        errorCode:
            fLo.abs() <= 1e-4 ? null : MoldValidationErrorCode.nonPositiveDimension,
      );
    }

    var hi = fixedMaxBound ?? math.max(initialGuess * 2.0, lo + 5.0);
    if (fixedMaxBound == null) {
      while (evalVol(hi) < targetVolumeMl && hi < maxBoundLimit) {
        lo = hi;
        hi = math.min(maxBoundLimit, hi * 2.0);
      }
    }

    final fHi = evalVol(hi) - targetVolumeMl;
    if (fHi < 0.0) {
      final solved = buildMold(hi);
      return EquivalenceResult(
        solvedMold: solved,
        solvedValueCm: hi,
        achievedVolumeMl: evalVol(hi),
        targetVolumeMl: targetVolumeMl,
        usedClosedForm: false,
        iterations: 0,
        converged: false,
        errorCode: MoldValidationErrorCode.sphericalCapHeightExceedsRadius,
      );
    }

    var x = initialGuess.clamp(lo, hi);
    if (x <= lo || x >= hi) {
      x = 0.5 * (lo + hi);
    }

    var iterations = 0;
    var converged = false;

    for (var i = 1; i <= maxIterations; i++) {
      iterations = i;
      final fx = evalVol(x) - targetVolumeMl;

      if (fx.abs() <= 1e-6 || (hi - lo) <= toleranceCm) {
        converged = true;
        break;
      }

      if (fx < 0.0) {
        lo = x;
      } else {
        hi = x;
      }

      final eps = math.max(1e-6, x * 1e-6);
      final xPlus = math.min(hi, x + eps);
      final xMinus = math.max(lo, x - eps);
      final df = (xPlus - xMinus) > 1e-9
          ? (evalVol(xPlus) - evalVol(xMinus)) / (xPlus - xMinus)
          : 0.0;

      double xNext;
      if (df.abs() > 1e-12) {
        final newton = x - fx / df;
        if (newton > lo && newton < hi) {
          xNext = newton;
        } else {
          xNext = 0.5 * (lo + hi);
        }
      } else {
        xNext = 0.5 * (lo + hi);
      }

      final step = (xNext - x).abs();
      x = xNext;
      if (step <= toleranceCm && (evalVol(x) - targetVolumeMl).abs() <= 1e-3) {
        converged = true;
        break;
      }
    }

    final solved = buildMold(x);
    return EquivalenceResult(
      solvedMold: solved,
      solvedValueCm: x,
      achievedVolumeMl: evalVol(x),
      targetVolumeMl: targetVolumeMl,
      usedClosedForm: false,
      iterations: iterations,
      converged: converged,
    );
  }
}
