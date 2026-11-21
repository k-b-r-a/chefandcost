import '../entities/fill_profile.dart';
import '../entities/mold_geometry.dart';
import '../entities/scaling_result.dart';

/// Evaluates thermal baking characteristics when converting between molds.
class ThermalAdvisor {
  ThermalAdvisor._();

  static List<ThermalAdvisory> evaluate({
    required double depthRatio,
    required double sourceSaToV,
    required double targetSaToV,
    required double targetFillRatio,
    FillProfile? targetFillProfile,
  }) {
    final saToVRatio =
        sourceSaToV > kMoldEpsilon ? targetSaToV / sourceSaToV : 1.0;

    final advisories = <ThermalAdvisory>[];

    if (depthRatio < 0.75 || saToVRatio > 1.25) {
      advisories.add(
        ThermalAdvisory(
          type: ThermalWarningType.shallowFastBake,
          severity: ThermalSeverity.warning,
          depthRatio: depthRatio,
          saToVRatio: saToVRatio,
          fillRatio: targetFillRatio,
        ),
      );
    }

    if (depthRatio > 1.30 || saToVRatio < 0.80) {
      advisories.add(
        ThermalAdvisory(
          type: ThermalWarningType.deepSlowBake,
          severity: ThermalSeverity.warning,
          depthRatio: depthRatio,
          saToVRatio: saToVRatio,
          fillRatio: targetFillRatio,
        ),
      );
    }

    if (targetFillProfile != null &&
        targetFillRatio > targetFillProfile.maxRecommendedFillRatio + 1e-6) {
      advisories.add(
        ThermalAdvisory(
          type: ThermalWarningType.highFillOverflowRisk,
          severity: ThermalSeverity.caution,
          depthRatio: depthRatio,
          saToVRatio: saToVRatio,
          fillRatio: targetFillRatio,
        ),
      );
    }

    if (advisories.isEmpty) {
      advisories.add(
        ThermalAdvisory(
          type: ThermalWarningType.optimalMatch,
          severity: ThermalSeverity.info,
          depthRatio: depthRatio,
          saToVRatio: saToVRatio,
          fillRatio: targetFillRatio,
        ),
      );
    }

    return advisories;
  }
}
