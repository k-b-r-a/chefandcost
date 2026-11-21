import '../../../l10n/app_localizations.dart';
import '../domain/entities/fill_profile.dart';
import '../domain/entities/mold_geometry.dart';
import '../domain/entities/mold_preset.dart';
import '../domain/entities/scaling_result.dart';
import '../domain/validators/mold_validator.dart';

/// Maps mold calculator domain enums, categories, and error codes to localized strings.
class MoldL10nHelper {
  MoldL10nHelper._();

  static String shapeName(AppLocalizations l10n, MoldShapeType type) {
    return switch (type) {
      MoldShapeType.circularCylinder => l10n.mold_calc_shape_cylinder,
      MoldShapeType.squarePrism => l10n.mold_calc_shape_square,
      MoldShapeType.rectangularPrism => l10n.mold_calc_shape_rectangular,
      MoldShapeType.circularFrustum => l10n.mold_calc_shape_frustum,
      MoldShapeType.rectangularFrustum => l10n.mold_calc_shape_rect_frustum,
      MoldShapeType.vChannel => l10n.mold_calc_shape_v_channel,
      MoldShapeType.annularTube => l10n.mold_calc_shape_annular,
      MoldShapeType.sphericalCap => l10n.mold_calc_shape_spherical_cap,
      MoldShapeType.uChannel => l10n.mold_calc_shape_u_channel,
      MoldShapeType.regularPolygon => l10n.mold_calc_shape_polygon,
      MoldShapeType.heartShape => l10n.mold_calc_shape_heart,
      MoldShapeType.waterDisplacement => l10n.mold_calc_shape_water_displacement,
      MoldShapeType.multiCavity => l10n.mold_calc_shape_multi_cavity,
    };
  }

  static String presetCategoryName(
    AppLocalizations l10n,
    MoldPresetCategory category,
  ) {
    return switch (category) {
      MoldPresetCategory.roundCake => l10n.mold_calc_cat_round,
      MoldPresetCategory.squarePan => l10n.mold_calc_cat_square,
      MoldPresetCategory.gastronormSheet => l10n.mold_calc_cat_gn_sheet,
      MoldPresetCategory.loafBudinera => l10n.mold_calc_cat_loaf,
      MoldPresetCategory.tubeBundt => l10n.mold_calc_cat_tube_bundt,
      MoldPresetCategory.tartRing => l10n.mold_calc_cat_tart,
      MoldPresetCategory.custom => l10n.mold_calc_cat_custom,
    };
  }

  static String fillProfileName(AppLocalizations l10n, FillProfileId id) {
    return switch (id) {
      FillProfileId.chiffonSponge => l10n.mold_calc_fill_chiffon,
      FillProfileId.butterCake => l10n.mold_calc_fill_butter,
      FillProfileId.brownieCheesecake => l10n.mold_calc_fill_brownie,
      FillProfileId.mousseEntremet => l10n.mold_calc_fill_mousse,
      FillProfileId.custom => l10n.mold_calc_fill_custom,
    };
  }

  static String cutStrategyName(AppLocalizations l10n, CutStrategyType type) {
    return switch (type) {
      CutStrategyType.radial => l10n.mold_calc_cut_radial,
      CutStrategyType.concentric => l10n.mold_calc_cut_concentric,
      CutStrategyType.grid => l10n.mold_calc_cut_grid,
      CutStrategyType.linear => l10n.mold_calc_cut_linear,
    };
  }

  static String portionPresetLabel(AppLocalizations l10n, PortionPreset preset) {
    return switch (preset.id) {
      'radial_event_5' => '${l10n.mold_calc_cut_radial} (5 cm)',
      'radial_generous_7' => '${l10n.mold_calc_cut_radial} (7 cm)',
      'radial_fixed_8' => '${l10n.mold_calc_cut_radial} (8)',
      'radial_fixed_12' => '${l10n.mold_calc_cut_radial} (12)',
      'radial_fixed_16' => '${l10n.mold_calc_cut_radial} (16)',
      'concentric_event' => '${l10n.mold_calc_cut_concentric} (Ø10 + 5 cm)',
      'grid_petit_3x3' => '3 × 3 cm',
      'grid_event_5x5' => '5 × 5 cm',
      'grid_brownie_6x6' => '6 × 6 cm',
      'grid_brownie_7x7' => '7 × 7 cm',
      'grid_bar_8x4' => '8 × 4 cm',
      'linear_loaf_1_5' => '1.5 cm',
      'linear_loaf_2_0' => '2.0 cm',
      _ => preset.id,
    };
  }

  static String thermalTitle(AppLocalizations l10n, ThermalWarningType type) {
    return switch (type) {
      ThermalWarningType.shallowFastBake => l10n.mold_calc_thermal_shallow_title,
      ThermalWarningType.deepSlowBake => l10n.mold_calc_thermal_deep_title,
      ThermalWarningType.highFillOverflowRisk => l10n.mold_calc_thermal_overflow_title,
      ThermalWarningType.optimalMatch => l10n.mold_calc_thermal_optimal_title,
    };
  }

  static String thermalDescription(
    AppLocalizations l10n,
    ThermalWarningType type,
  ) {
    return switch (type) {
      ThermalWarningType.shallowFastBake => l10n.mold_calc_thermal_shallow_desc,
      ThermalWarningType.deepSlowBake => l10n.mold_calc_thermal_deep_desc,
      ThermalWarningType.highFillOverflowRisk => l10n.mold_calc_thermal_overflow_desc,
      ThermalWarningType.optimalMatch => l10n.mold_calc_thermal_optimal_desc,
    };
  }

  static String validationError(
    AppLocalizations l10n,
    MoldValidationErrorCode code,
  ) {
    return switch (code) {
      MoldValidationErrorCode.nonPositiveDimension => l10n.mold_calc_err_non_positive,
      MoldValidationErrorCode.negativeBottomDimension => l10n.mold_calc_err_negative_bottom,
      MoldValidationErrorCode.bothTopAndBottomZero => l10n.mold_calc_err_both_zero,
      MoldValidationErrorCode.invalidFillRatio => l10n.mold_calc_err_fill_ratio,
      MoldValidationErrorCode.invalidFillHeight => l10n.mold_calc_err_fill_height,
      MoldValidationErrorCode.invalidSlantHeight => l10n.mold_calc_err_slant_height,
      MoldValidationErrorCode.tubeExceedsOuter => l10n.mold_calc_err_tube_exceeds_outer,
      MoldValidationErrorCode.invalidTubeHeight => l10n.mold_calc_err_tube_height,
      MoldValidationErrorCode.invalidFlutingFactor => l10n.mold_calc_err_fluting,
      MoldValidationErrorCode.sphericalCapHeightExceedsRadius => l10n.mold_calc_err_spherical_cap,
      MoldValidationErrorCode.invalidPolygonSides => l10n.mold_calc_err_polygon_sides,
      MoldValidationErrorCode.invalidShapeFactor => l10n.mold_calc_err_shape_factor,
      MoldValidationErrorCode.invalidCavityCount => l10n.mold_calc_err_cavity_count,
      MoldValidationErrorCode.nestedMultiCavity => l10n.mold_calc_err_nested_cavity,
      MoldValidationErrorCode.invalidPortionDimension => l10n.mold_calc_err_portion_dim,
      MoldValidationErrorCode.edgeTrimExceedsMold => l10n.mold_calc_err_edge_trim,
    };
  }
}
