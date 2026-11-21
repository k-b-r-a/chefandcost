import 'dart:math' as math;
import '../entities/fill_profile.dart';
import '../entities/mold_geometry.dart';
import '../entities/scaling_result.dart';
import '../validators/mold_validator.dart';
import 'thermal_advisor.dart';

/// Pure Dart geometry calculations for mold fill heights, volumes, wetted SA, and scaling.
class GeometryEngine {
  GeometryEngine._();

  static double effectiveFillHeight(MoldGeometry mold, double fillRatio) {
    final clampedRatio = fillRatio.clamp(0.0, 1.0);
    return mold.totalHeight * clampedRatio;
  }

  static double effectiveVolume(MoldGeometry mold, double fillRatio) {
    return mold.volumeAtHeight(effectiveFillHeight(mold, fillRatio));
  }

  static double effectiveFootprintArea(MoldGeometry mold, double fillRatio) {
    final base = mold.baseArea();
    if (base > kMoldEpsilon) return base;
    final hFill = effectiveFillHeight(mold, fillRatio);
    final atFill = mold.crossSectionAreaAt(hFill);
    if (atFill > kMoldEpsilon) return atFill;
    final top = mold.topArea();
    if (top > kMoldEpsilon) return top;
    final vol = effectiveVolume(mold, fillRatio);
    return hFill > kMoldEpsilon ? vol / hFill : 0.0;
  }

  static double wettedSurfaceArea(MoldGeometry mold, double fillRatio) {
    return mold.wettedSurfaceAreaAt(effectiveFillHeight(mold, fillRatio));
  }

  static double saToVRatio(MoldGeometry mold, double fillRatio) {
    final vol = effectiveVolume(mold, fillRatio);
    if (vol <= kMoldEpsilon) return 0.0;
    return wettedSurfaceArea(mold, fillRatio) / vol;
  }

  /// Solves the fill height [y] (in cm) inside [mold] that holds [volumeMl] ml.
  static double solveFillHeightForVolume(MoldGeometry mold, double volumeMl) {
    final hTotal = mold.totalHeight;
    if (hTotal <= 0.0 || volumeMl <= kMoldEpsilon) return 0.0;
    final vTotal = mold.totalVolume;
    if (volumeMl >= vTotal - kMoldEpsilon) return hTotal;

    var lo = 0.0;
    var hi = hTotal;
    for (var i = 0; i < 60; i++) {
      final mid = 0.5 * (lo + hi);
      final vMid = mold.volumeAtHeight(mid);
      if ((vMid - volumeMl).abs() <= 1e-5 || (hi - lo) <= 1e-6) {
        return mid;
      }
      if (vMid < volumeMl) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return 0.5 * (lo + hi);
  }

  static ScalingResult computeScaling({
    required MoldGeometry source,
    required double sourceFillRatio,
    required MoldGeometry target,
    required double targetFillRatio,
    FillProfile? targetFillProfile,
  }) {
    MoldValidator.assertValidMold(source, fillRatio: sourceFillRatio);
    MoldValidator.assertValidMold(target, fillRatio: targetFillRatio);

    final srcFillH = effectiveFillHeight(source, sourceFillRatio);
    final tgtFillH = effectiveFillHeight(target, targetFillRatio);

    final srcEffVol = source.volumeAtHeight(srcFillH);
    final tgtEffVol = target.volumeAtHeight(tgtFillH);

    final srcTotalVol = source.totalVolume;
    final tgtTotalVol = target.totalVolume;

    final srcArea = effectiveFootprintArea(source, sourceFillRatio);
    final tgtArea = effectiveFootprintArea(target, targetFillRatio);

    final srcSa = source.wettedSurfaceAreaAt(srcFillH);
    final tgtSa = target.wettedSurfaceAreaAt(tgtFillH);

    final srcSaToV = srcEffVol > kMoldEpsilon ? srcSa / srcEffVol : 0.0;
    final tgtSaToV = tgtEffVol > kMoldEpsilon ? tgtSa / tgtEffVol : 0.0;

    final kV = srcEffVol > kMoldEpsilon ? tgtEffVol / srcEffVol : 1.0;
    final kA = srcArea > kMoldEpsilon ? tgtArea / srcArea : 1.0;
    final depthRatio = srcFillH > kMoldEpsilon ? tgtFillH / srcFillH : 1.0;

    final batterDiff = srcEffVol - tgtEffVol;
    final leftoverMl = math.max(0.0, batterDiff);
    final leftoverPct =
        srcEffVol > kMoldEpsilon ? (leftoverMl / srcEffVol) * 100.0 : 0.0;
    final deficitMl = math.max(0.0, -batterDiff);
    final deficitPct =
        tgtEffVol > kMoldEpsilon ? (deficitMl / tgtEffVol) * 100.0 : 0.0;

    final overflows = srcEffVol > tgtTotalVol + 1e-6;
    final unscaledH = overflows
        ? target.totalHeight
        : solveFillHeightForVolume(target, srcEffVol);
    final unscaledPct = overflows
        ? (tgtTotalVol > kMoldEpsilon
            ? (srcEffVol / tgtTotalVol) * 100.0
            : 100.0)
        : (target.totalHeight > kMoldEpsilon
            ? (unscaledH / target.totalHeight) * 100.0
            : 0.0);

    final advisories = ThermalAdvisor.evaluate(
      depthRatio: depthRatio,
      sourceSaToV: srcSaToV,
      targetSaToV: tgtSaToV,
      targetFillRatio: targetFillRatio,
      targetFillProfile: targetFillProfile,
    );

    return ScalingResult(
      sourceEffectiveVolumeMl: srcEffVol,
      targetEffectiveVolumeMl: tgtEffVol,
      sourceTotalVolumeMl: srcTotalVol,
      targetTotalVolumeMl: tgtTotalVol,
      sourceFillHeightCm: srcFillH,
      targetFillHeightCm: tgtFillH,
      sourceEffectiveAreaCm2: srcArea,
      targetEffectiveAreaCm2: tgtArea,
      sourceWettedSaCm2: srcSa,
      targetWettedSaCm2: tgtSa,
      sourceSaToV: srcSaToV,
      targetSaToV: tgtSaToV,
      volumeScaleFactor: kV,
      areaScaleFactor: kA,
      depthRatio: depthRatio,
      batterDifferenceMl: batterDiff,
      leftoverBatterMl: leftoverMl,
      leftoverPercent: leftoverPct,
      deficitBatterMl: deficitMl,
      deficitPercent: deficitPct,
      unscaledTargetFillHeightCm: unscaledH,
      unscaledTargetFillPercent: unscaledPct,
      unscaledOverflowsTarget: overflows,
      advisories: advisories,
    );
  }
}
