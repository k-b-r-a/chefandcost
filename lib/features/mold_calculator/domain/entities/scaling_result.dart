enum ThermalWarningType {
  shallowFastBake,
  deepSlowBake,
  highFillOverflowRisk,
  optimalMatch,
}

enum ThermalSeverity {
  info,
  warning,
  caution,
}

/// Thermal baking advisory derived from depth ratio, SA:V ratio, and fill ratio.
class ThermalAdvisory {
  final ThermalWarningType type;
  final ThermalSeverity severity;
  final double depthRatio;
  final double saToVRatio;
  final double fillRatio;

  const ThermalAdvisory({
    required this.type,
    required this.severity,
    required this.depthRatio,
    required this.saToVRatio,
    required this.fillRatio,
  });
}

/// Full comparative scaling result between a source mold and a target mold.
class ScalingResult {
  final double sourceEffectiveVolumeMl;
  final double targetEffectiveVolumeMl;
  final double sourceTotalVolumeMl;
  final double targetTotalVolumeMl;
  final double sourceFillHeightCm;
  final double targetFillHeightCm;
  final double sourceEffectiveAreaCm2;
  final double targetEffectiveAreaCm2;
  final double sourceWettedSaCm2;
  final double targetWettedSaCm2;
  final double sourceSaToV;
  final double targetSaToV;

  /// Volumetric scaling factor: k_V = V_eff_target / V_eff_source.
  final double volumeScaleFactor;

  /// Footprint area scaling factor: k_A = A_eff_target / A_eff_source.
  final double areaScaleFactor;

  /// Depth ratio: h_fill_target / h_fill_source.
  final double depthRatio;

  /// Signed batter difference if pouring 1x source recipe into target mold:
  /// positive => leftover batter, negative => deficit.
  final double batterDifferenceMl;

  final double leftoverBatterMl;
  final double leftoverPercent;
  final double deficitBatterMl;
  final double deficitPercent;

  /// Height reached inside the target mold when pouring unscaled (1x) source batter.
  final double unscaledTargetFillHeightCm;
  final double unscaledTargetFillPercent;
  final bool unscaledOverflowsTarget;

  final List<ThermalAdvisory> advisories;

  const ScalingResult({
    required this.sourceEffectiveVolumeMl,
    required this.targetEffectiveVolumeMl,
    required this.sourceTotalVolumeMl,
    required this.targetTotalVolumeMl,
    required this.sourceFillHeightCm,
    required this.targetFillHeightCm,
    required this.sourceEffectiveAreaCm2,
    required this.targetEffectiveAreaCm2,
    required this.sourceWettedSaCm2,
    required this.targetWettedSaCm2,
    required this.sourceSaToV,
    required this.targetSaToV,
    required this.volumeScaleFactor,
    required this.areaScaleFactor,
    required this.depthRatio,
    required this.batterDifferenceMl,
    required this.leftoverBatterMl,
    required this.leftoverPercent,
    required this.deficitBatterMl,
    required this.deficitPercent,
    required this.unscaledTargetFillHeightCm,
    required this.unscaledTargetFillPercent,
    required this.unscaledOverflowsTarget,
    required this.advisories,
  });
}
