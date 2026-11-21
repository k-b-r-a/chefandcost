import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../provider/settings_provider.dart';
import '../../data/mold_presets_catalog.dart';
import '../../data/mold_repository.dart';
import '../../domain/entities/fill_profile.dart';
import '../../domain/entities/mold_geometry.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/entities/portion_yield.dart';
import '../../domain/entities/scaling_result.dart';
import '../../domain/services/equivalence_solver.dart';
import '../../domain/services/geometry_engine.dart';
import '../../domain/services/portion_engine.dart';
import '../../domain/validators/mold_validator.dart';

enum MoldRole { source, target }

class MoldCalculatorState {
  final MoldGeometry sourceMold;
  final MoldGeometry targetMold;
  final FillProfileId sourceFillProfile;
  final FillProfileId targetFillProfile;
  final double sourceFillRatio;
  final double targetFillRatio;
  final bool linkFillProfiles;
  final bool equivalenceMode;
  final SolveParameter solveParameter;

  // Portion & Yield state
  final MoldRole portionMoldRole;
  final CutStrategyType cutStrategy;
  final bool useFixedRadialSlices;
  final int radialFixedSlices;
  final double targetArcCm;
  final double innerRingDiameterCm;
  final double pieceLengthCm;
  final double pieceWidthCm;
  final double edgeTrimCm;
  final double sliceThicknessCm;
  final double endTrimCm;

  final List<MoldPreset> customMolds;
  final int moldConfigVersion;

  const MoldCalculatorState({
    required this.sourceMold,
    required this.targetMold,
    required this.sourceFillProfile,
    required this.targetFillProfile,
    required this.sourceFillRatio,
    required this.targetFillRatio,
    this.linkFillProfiles = true,
    this.equivalenceMode = false,
    this.solveParameter = SolveParameter.primaryDimension,
    this.portionMoldRole = MoldRole.target,
    this.cutStrategy = CutStrategyType.radial,
    this.useFixedRadialSlices = false,
    this.radialFixedSlices = 8,
    this.targetArcCm = 5.0,
    this.innerRingDiameterCm = 10.0,
    this.pieceLengthCm = 5.0,
    this.pieceWidthCm = 5.0,
    this.edgeTrimCm = 0.0,
    this.sliceThicknessCm = 2.0,
    this.endTrimCm = 0.5,
    this.customMolds = const [],
    this.moldConfigVersion = 0,
  });

  factory MoldCalculatorState.initial({
    List<MoldPreset> customMolds = const [],
  }) {
    return MoldCalculatorState(
      sourceMold: MoldPresetsCatalog.defaultSource.geometry,
      targetMold: MoldPresetsCatalog.defaultTarget.geometry,
      sourceFillProfile: FillProfileId.butterCake,
      targetFillProfile: FillProfileId.butterCake,
      sourceFillRatio: FillProfile.butterCake.defaultFillRatio,
      targetFillRatio: FillProfile.butterCake.defaultFillRatio,
      customMolds: customMolds,
    );
  }

  MoldGeometry get activePortionMold =>
      portionMoldRole == MoldRole.source ? sourceMold : targetMold;

  double get activePortionFillRatio =>
      portionMoldRole == MoldRole.source ? sourceFillRatio : targetFillRatio;

  List<MoldValidationError> get sourceErrors =>
      MoldValidator.validateMold(sourceMold, fillRatio: sourceFillRatio);

  List<MoldValidationError> get targetErrors =>
      MoldValidator.validateMold(targetMold, fillRatio: targetFillRatio);

  ScalingResult? get scalingResult {
    if (sourceErrors.isNotEmpty || targetErrors.isNotEmpty) return null;
    try {
      return GeometryEngine.computeScaling(
        source: sourceMold,
        sourceFillRatio: sourceFillRatio,
        target: targetMold,
        targetFillRatio: targetFillRatio,
        targetFillProfile: FillProfile.byId(targetFillProfile),
      );
    } on MoldValidationException {
      return null;
    }
  }

  EquivalenceResult? get equivalenceResult {
    if (!equivalenceMode || sourceErrors.isNotEmpty) return null;
    final fillErrors =
        MoldValidator.validateMold(targetMold, fillRatio: targetFillRatio);
    // Allow solving even if current dimension is valid; reject invalid fill ratio.
    if (fillErrors.any((e) => e.code == MoldValidationErrorCode.invalidFillRatio)) {
      return null;
    }
    final targetVol = GeometryEngine.effectiveVolume(sourceMold, sourceFillRatio);
    return EquivalenceSolver.solve(
      targetVolumeMl: targetVol,
      template: targetMold,
      targetFillRatio: targetFillRatio,
      parameter: solveParameter,
    );
  }

  ({PortionYieldResult? result, List<MoldValidationError> errors})
      get portionEvaluation {
    final mold = activePortionMold;
    final fillRatio = activePortionFillRatio;
    final moldErrs = MoldValidator.validateMold(mold, fillRatio: fillRatio);
    if (moldErrs.isNotEmpty) {
      return (result: null, errors: moldErrs);
    }

    try {
      final PortionYieldResult res;
      switch (cutStrategy) {
        case CutStrategyType.radial:
          res = PortionEngine.calculateRadial(
            mold: mold,
            fillRatio: fillRatio,
            fixedSlices: useFixedRadialSlices ? radialFixedSlices : null,
            targetArcCm: targetArcCm,
          );
        case CutStrategyType.concentric:
          res = PortionEngine.calculateConcentric(
            mold: mold,
            fillRatio: fillRatio,
            innerDiameterCm: innerRingDiameterCm,
            targetArcCm: targetArcCm,
          );
        case CutStrategyType.grid:
          res = PortionEngine.calculateGrid(
            mold: mold,
            fillRatio: fillRatio,
            pieceLengthCm: pieceLengthCm,
            pieceWidthCm: pieceWidthCm,
            edgeTrimCm: edgeTrimCm,
          );
        case CutStrategyType.linear:
          res = PortionEngine.calculateLinear(
            mold: mold,
            fillRatio: fillRatio,
            sliceThicknessCm: sliceThicknessCm,
            endTrimCm: endTrimCm,
          );
      }
      return (result: res, errors: const []);
    } on MoldValidationException catch (e) {
      return (result: null, errors: e.errors);
    }
  }

  MoldCalculatorState copyWith({
    MoldGeometry? sourceMold,
    MoldGeometry? targetMold,
    FillProfileId? sourceFillProfile,
    FillProfileId? targetFillProfile,
    double? sourceFillRatio,
    double? targetFillRatio,
    bool? linkFillProfiles,
    bool? equivalenceMode,
    SolveParameter? solveParameter,
    MoldRole? portionMoldRole,
    CutStrategyType? cutStrategy,
    bool? useFixedRadialSlices,
    int? radialFixedSlices,
    double? targetArcCm,
    double? innerRingDiameterCm,
    double? pieceLengthCm,
    double? pieceWidthCm,
    double? edgeTrimCm,
    double? sliceThicknessCm,
    double? endTrimCm,
    List<MoldPreset>? customMolds,
    int? moldConfigVersion,
  }) {
    return MoldCalculatorState(
      sourceMold: sourceMold ?? this.sourceMold,
      targetMold: targetMold ?? this.targetMold,
      sourceFillProfile: sourceFillProfile ?? this.sourceFillProfile,
      targetFillProfile: targetFillProfile ?? this.targetFillProfile,
      sourceFillRatio: sourceFillRatio ?? this.sourceFillRatio,
      targetFillRatio: targetFillRatio ?? this.targetFillRatio,
      linkFillProfiles: linkFillProfiles ?? this.linkFillProfiles,
      equivalenceMode: equivalenceMode ?? this.equivalenceMode,
      solveParameter: solveParameter ?? this.solveParameter,
      portionMoldRole: portionMoldRole ?? this.portionMoldRole,
      cutStrategy: cutStrategy ?? this.cutStrategy,
      useFixedRadialSlices: useFixedRadialSlices ?? this.useFixedRadialSlices,
      radialFixedSlices: radialFixedSlices ?? this.radialFixedSlices,
      targetArcCm: targetArcCm ?? this.targetArcCm,
      innerRingDiameterCm: innerRingDiameterCm ?? this.innerRingDiameterCm,
      pieceLengthCm: pieceLengthCm ?? this.pieceLengthCm,
      pieceWidthCm: pieceWidthCm ?? this.pieceWidthCm,
      edgeTrimCm: edgeTrimCm ?? this.edgeTrimCm,
      sliceThicknessCm: sliceThicknessCm ?? this.sliceThicknessCm,
      endTrimCm: endTrimCm ?? this.endTrimCm,
      customMolds: customMolds ?? this.customMolds,
      moldConfigVersion: moldConfigVersion ?? this.moldConfigVersion,
    );
  }
}

class MoldCalculatorNotifier extends Notifier<MoldCalculatorState> {
  late MoldRepository _repository;

  @override
  MoldCalculatorState build() {
    SharedPreferences? prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } catch (_) {
      prefs = null;
    }
    _repository = MoldRepository(prefs);
    final custom = _repository.loadCustomMolds();
    return MoldCalculatorState.initial(customMolds: custom);
  }

  void setMold(
    MoldRole role,
    MoldGeometry mold, {
    bool bumpVersion = false,
  }) {
    final nextVersion =
        bumpVersion ? state.moldConfigVersion + 1 : state.moldConfigVersion;
    if (role == MoldRole.source) {
      state = state.copyWith(
        sourceMold: mold,
        moldConfigVersion: nextVersion,
      );
    } else {
      state = state.copyWith(
        targetMold: mold,
        moldConfigVersion: nextVersion,
      );
    }
  }

  void selectPreset(MoldRole role, MoldPreset preset) {
    setMold(role, preset.geometry, bumpVersion: true);
  }

  void changeShapeType(MoldRole role, MoldShapeType shapeType) {
    final current = role == MoldRole.source ? state.sourceMold : state.targetMold;
    final h = current.totalHeight > 0.0 ? current.totalHeight : 5.0;
    final w = current.boundingWidth > 0.0 ? current.boundingWidth : 20.0;
    final l = current.boundingLength > 0.0 ? current.boundingLength : 25.0;

    final MoldGeometry next = switch (shapeType) {
      MoldShapeType.circularCylinder => CircularCylinder(diameter: w, height: h),
      MoldShapeType.squarePrism => SquarePrism(side: w, height: h),
      MoldShapeType.rectangularPrism => RectangularPrism(
          length: math.max(l, w),
          width: math.min(l, w),
          height: h,
        ),
      MoldShapeType.circularFrustum => CircularFrustum(
          bottomDiameter: math.max(1.0, w * 0.8),
          topDiameter: w,
          height: h,
        ),
      MoldShapeType.rectangularFrustum => RectangularFrustum(
          bottomLength: math.max(1.0, l * 0.85),
          bottomWidth: math.max(1.0, w * 0.8),
          topLength: l,
          topWidth: w,
          height: h,
        ),
      MoldShapeType.vChannel => VChannelMold(
          bottomWidth: 2.0,
          topWidth: math.min(w, 12.0),
          length: math.max(l, 20.0),
          height: h,
        ),
      MoldShapeType.annularTube => AnnularTubeMold(
          outerBottomDiameter: w,
          outerTopDiameter: w,
          tubeBottomDiameter: math.max(2.0, (w * 0.3).clamp(2.0, w - 2.0)),
          tubeTopDiameter: math.max(2.0, (w * 0.3).clamp(2.0, w - 2.0)),
          height: h,
          flutingFactor: 1.0,
        ),
      MoldShapeType.sphericalCap => SphericalCapMold(
          diameter: w,
          height: math.min(h, w / 2.0),
        ),
      MoldShapeType.uChannel => UChannelMold(
          width: math.min(w, 12.0),
          length: math.max(l, 20.0),
          height: h,
        ),
      MoldShapeType.regularPolygon => RegularPolygonMold(
          sides: 6,
          sideLength: math.max(4.0, w / 2.0),
          height: h,
        ),
      MoldShapeType.heartShape => HeartShapeMold(
          width: w,
          length: w,
          height: h,
          shapeFactor: 0.82,
        ),
      MoldShapeType.waterDisplacement => WaterDisplacementMold(
          measuredVolumeMl: math.max(100.0, current.totalVolume),
          height: h,
          fillCurveExponent: 1.0,
        ),
      MoldShapeType.multiCavity => current is MultiCavityMold
          ? current
          : MultiCavityMold(
              singleCavity: const CircularCylinder(diameter: 7.0, height: 3.5),
              cavityCount: 12,
            ),
    };

    setMold(role, next, bumpVersion: true);
  }

  void toggleMultiCavity(MoldRole role, bool enabled) {
    final current = role == MoldRole.source ? state.sourceMold : state.targetMold;
    if (enabled && current is! MultiCavityMold) {
      setMold(
        role,
        MultiCavityMold(singleCavity: current, cavityCount: 12),
        bumpVersion: true,
      );
    } else if (!enabled && current is MultiCavityMold) {
      setMold(role, current.singleCavity, bumpVersion: true);
    }
  }

  void swapMolds() {
    state = state.copyWith(
      sourceMold: state.targetMold,
      targetMold: state.sourceMold,
      sourceFillProfile: state.targetFillProfile,
      targetFillProfile: state.sourceFillProfile,
      sourceFillRatio: state.targetFillRatio,
      targetFillRatio: state.sourceFillRatio,
      moldConfigVersion: state.moldConfigVersion + 1,
    );
  }

  void reset() {
    state = MoldCalculatorState.initial(customMolds: state.customMolds).copyWith(
      moldConfigVersion: state.moldConfigVersion + 1,
    );
  }

  void setFillProfile(MoldRole role, FillProfileId id) {
    final ratio = FillProfile.byId(id).defaultFillRatio;
    if (state.linkFillProfiles) {
      state = state.copyWith(
        sourceFillProfile: id,
        targetFillProfile: id,
        sourceFillRatio: id == FillProfileId.custom ? state.sourceFillRatio : ratio,
        targetFillRatio: id == FillProfileId.custom ? state.targetFillRatio : ratio,
      );
      return;
    }
    if (role == MoldRole.source) {
      state = state.copyWith(
        sourceFillProfile: id,
        sourceFillRatio: id == FillProfileId.custom ? state.sourceFillRatio : ratio,
      );
    } else {
      state = state.copyWith(
        targetFillProfile: id,
        targetFillRatio: id == FillProfileId.custom ? state.targetFillRatio : ratio,
      );
    }
  }

  void setFillRatio(MoldRole role, double ratio) {
    final clamped = ratio.clamp(0.05, 1.0);
    if (state.linkFillProfiles) {
      state = state.copyWith(
        sourceFillProfile: FillProfileId.custom,
        targetFillProfile: FillProfileId.custom,
        sourceFillRatio: clamped,
        targetFillRatio: clamped,
      );
      return;
    }
    if (role == MoldRole.source) {
      state = state.copyWith(
        sourceFillProfile: FillProfileId.custom,
        sourceFillRatio: clamped,
      );
    } else {
      state = state.copyWith(
        targetFillProfile: FillProfileId.custom,
        targetFillRatio: clamped,
      );
    }
  }

  void setLinkFillProfiles(bool linked) {
    if (linked) {
      state = state.copyWith(
        linkFillProfiles: true,
        targetFillProfile: state.sourceFillProfile,
        targetFillRatio: state.sourceFillRatio,
      );
    } else {
      state = state.copyWith(linkFillProfiles: false);
    }
  }

  void setEquivalenceMode(bool enabled) {
    state = state.copyWith(equivalenceMode: enabled);
  }

  void setSolveParameter(SolveParameter parameter) {
    state = state.copyWith(solveParameter: parameter);
  }

  void applySolvedEquivalence() {
    final equiv = state.equivalenceResult;
    if (equiv == null || !equiv.converged) return;
    state = state.copyWith(
      targetMold: equiv.solvedMold,
      moldConfigVersion: state.moldConfigVersion + 1,
    );
  }

  void setPortionMoldRole(MoldRole role) {
    state = state.copyWith(portionMoldRole: role);
  }

  void setCutStrategy(CutStrategyType strategy) {
    state = state.copyWith(cutStrategy: strategy);
  }

  void applyPortionPreset(PortionPreset preset) {
    state = state.copyWith(
      cutStrategy: preset.strategy,
      useFixedRadialSlices: preset.sliceCount != null,
      radialFixedSlices: preset.sliceCount ?? state.radialFixedSlices,
      targetArcCm: preset.arcWidthCm ?? state.targetArcCm,
      innerRingDiameterCm: preset.innerDiameterCm ?? state.innerRingDiameterCm,
      pieceLengthCm: preset.pieceLengthCm ?? state.pieceLengthCm,
      pieceWidthCm: preset.pieceWidthCm ?? state.pieceWidthCm,
      edgeTrimCm: preset.edgeTrimCm,
      sliceThicknessCm: preset.sliceThicknessCm ?? state.sliceThicknessCm,
      endTrimCm: preset.endTrimCm,
    );
  }

  void updatePortionParams({
    bool? useFixedRadialSlices,
    int? radialFixedSlices,
    double? targetArcCm,
    double? innerRingDiameterCm,
    double? pieceLengthCm,
    double? pieceWidthCm,
    double? edgeTrimCm,
    double? sliceThicknessCm,
    double? endTrimCm,
  }) {
    state = state.copyWith(
      useFixedRadialSlices: useFixedRadialSlices,
      radialFixedSlices: radialFixedSlices,
      targetArcCm: targetArcCm,
      innerRingDiameterCm: innerRingDiameterCm,
      pieceLengthCm: pieceLengthCm,
      pieceWidthCm: pieceWidthCm,
      edgeTrimCm: edgeTrimCm,
      sliceThicknessCm: sliceThicknessCm,
      endTrimCm: endTrimCm,
    );
  }

  Future<void> saveCustomMold(String label, MoldGeometry geometry) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final preset = MoldPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: trimmed,
      category: MoldPresetCategory.custom,
      geometry: geometry,
      isCustom: true,
    );
    final updated = await _repository.saveCustomMold(preset);
    state = state.copyWith(customMolds: updated);
  }

  Future<void> deleteCustomMold(String id) async {
    final updated = await _repository.deleteCustomMold(id);
    state = state.copyWith(customMolds: updated);
  }
}

final moldCalculatorProvider =
    NotifierProvider<MoldCalculatorNotifier, MoldCalculatorState>(
  MoldCalculatorNotifier.new,
);

/// Transient handoff scale factor when launching RecipeEditorScreen in desktop 3-pane mode.
class PendingMoldScaleFactorNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void setFactor(double? factor) {
    state = factor;
  }

  double? consume() {
    final val = state;
    if (val != null) {
      state = null;
    }
    return val;
  }
}

final pendingMoldScaleFactorProvider =
    NotifierProvider<PendingMoldScaleFactorNotifier, double?>(
  PendingMoldScaleFactorNotifier.new,
);
