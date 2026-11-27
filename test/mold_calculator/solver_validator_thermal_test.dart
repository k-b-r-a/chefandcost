import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/fill_profile.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/mold_geometry.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/scaling_result.dart';
import 'package:recipetools/features/mold_calculator/domain/services/equivalence_solver.dart';
import 'package:recipetools/features/mold_calculator/domain/services/geometry_engine.dart';
import 'package:recipetools/features/mold_calculator/domain/services/thermal_advisor.dart';
import 'package:recipetools/features/mold_calculator/domain/validators/mold_validator.dart';

void main() {
  group('EquivalenceSolver Tests', () {
    test('Round 20cm (h=5) -> Square (h=5) solves L ≈ 17.72 cm (k_V = 1.00)', () {
      const source = CircularCylinder(diameter: 20.0, height: 5.0);
      const template = SquarePrism(side: 20.0, height: 5.0);
      final targetVol = GeometryEngine.effectiveVolume(source, 0.72);

      final result = EquivalenceSolver.solve(
        targetVolumeMl: targetVol,
        template: template,
        targetFillRatio: 0.72,
      );

      expect(result.converged, isTrue);
      expect(result.usedClosedForm, isTrue);
      expect(result.solvedValueCm, closeTo(10.0 * math.sqrt(math.pi), 1e-4)); // ~17.7245
      expect(result.achievedVolumeMl, closeTo(targetVol, 1e-3));
    });

    test('Numerical solver converges for CircularFrustum, RectangularFrustum, AnnularTube, SphericalCap, VChannel, UChannel', () {
      const targetVol = 1400.0;
      const fillRatio = 0.72;

      final templates = <MoldGeometry>[
        const CircularFrustum(bottomDiameter: 16.0, topDiameter: 22.0, height: 8.0),
        const RectangularFrustum(
          bottomLength: 19.0,
          bottomWidth: 8.0,
          topLength: 22.0,
          topWidth: 10.0,
          height: 7.0,
        ),
        const AnnularTubeMold(
          outerBottomDiameter: 22.0,
          outerTopDiameter: 24.0,
          tubeBottomDiameter: 7.0,
          tubeTopDiameter: 7.0,
          height: 7.0,
          flutingFactor: 0.9,
        ),
        const SphericalCapMold(diameter: 24.0, height: 8.0),
        const VChannelMold(bottomWidth: 2.0, topWidth: 10.0, length: 25.0, height: 7.0),
        const UChannelMold(width: 8.0, length: 25.0, height: 7.0),
        const MultiCavityMold(
          singleCavity: CircularFrustum(bottomDiameter: 5.0, topDiameter: 7.0, height: 4.0),
          cavityCount: 12,
        ),
      ];

      for (final tpl in templates) {
        final res = EquivalenceSolver.solve(
          targetVolumeMl: targetVol,
          template: tpl,
          targetFillRatio: fillRatio,
        );
        expect(res.converged, isTrue, reason: 'Failed for ${tpl.shapeType}');
        expect(res.iterations, lessThanOrEqualTo(50));
        expect(
          res.achievedVolumeMl,
          closeTo(targetVol, 0.5),
          reason: 'Volume mismatch for ${tpl.shapeType}',
        );
      }
    });

    test('EquivalenceSolver solves height parameter for straight and tapered shapes', () {
      const targetVol = 1500.0;
      const fillRatio = 0.75;

      final cylRes = EquivalenceSolver.solve(
        targetVolumeMl: targetVol,
        template: const CircularCylinder(diameter: 20.0, height: 5.0),
        targetFillRatio: fillRatio,
        parameter: SolveParameter.height,
      );
      expect(cylRes.converged, isTrue);
      expect(cylRes.usedClosedForm, isTrue);
      expect(cylRes.achievedVolumeMl, closeTo(targetVol, 1e-3));

      final frustumRes = EquivalenceSolver.solve(
        targetVolumeMl: targetVol,
        template: const CircularFrustum(bottomDiameter: 16.0, topDiameter: 22.0, height: 6.0),
        targetFillRatio: fillRatio,
        parameter: SolveParameter.height,
      );
      expect(frustumRes.converged, isTrue);
      expect(frustumRes.usedClosedForm, isFalse);
      expect(frustumRes.achievedVolumeMl, closeTo(targetVol, 0.5));
    });
  });

  group('MoldValidator Guard Tests', () {
    test('Rejects annular tube >= outer diameter', () {
      const invalid = AnnularTubeMold(
        outerBottomDiameter: 20.0,
        outerTopDiameter: 20.0,
        tubeBottomDiameter: 20.0,
        tubeTopDiameter: 8.0,
        height: 6.0,
      );
      final errors = MoldValidator.validateMold(invalid);
      expect(
        errors.any((e) => e.code == MoldValidationErrorCode.tubeExceedsOuter),
        isTrue,
      );
      expect(
        () => MoldValidator.assertValidMold(invalid),
        throwsA(isA<MoldValidationException>()),
      );
    });

    test('Rejects fillRatio > 1.0 or <= 0 and fillHeight > totalHeight', () {
      const cyl = CircularCylinder(diameter: 20.0, height: 5.0);
      expect(
        MoldValidator.validateMold(cyl, fillRatio: 1.05).first.code,
        MoldValidationErrorCode.invalidFillRatio,
      );
      expect(
        MoldValidator.validateMold(cyl, fillRatio: 0.0).first.code,
        MoldValidationErrorCode.invalidFillRatio,
      );
      expect(
        MoldValidator.validateMold(cyl, fillHeightCm: 6.0).first.code,
        MoldValidationErrorCode.invalidFillHeight,
      );
    });

    test('Rejects spherical cap height > radius', () {
      const badDome = SphericalCapMold(diameter: 20.0, height: 12.0);
      expect(
        MoldValidator.validateMold(badDome).first.code,
        MoldValidationErrorCode.sphericalCapHeightExceedsRadius,
      );
    });

    test('Rejects invalid slantHeight, flutingFactor, polygon sides, and nested multi-cavity', () {
      const badSlant = CircularFrustum(
        bottomDiameter: 10.0,
        topDiameter: 20.0,
        height: 5.0,
        slantHeight: 4.0, // |r_t - r_b| = 5 >= 4
      );
      expect(
        MoldValidator.validateMold(badSlant).first.code,
        MoldValidationErrorCode.invalidSlantHeight,
      );

      const badFlute = AnnularTubeMold(
        outerBottomDiameter: 24.0,
        outerTopDiameter: 24.0,
        tubeBottomDiameter: 7.0,
        tubeTopDiameter: 7.0,
        height: 6.0,
        flutingFactor: 0.5,
      );
      expect(
        MoldValidator.validateMold(badFlute).any(
          (e) => e.code == MoldValidationErrorCode.invalidFlutingFactor,
        ),
        isTrue,
      );

      const badPoly = RegularPolygonMold(sides: 2, sideLength: 10.0, height: 5.0);
      expect(
        MoldValidator.validateMold(badPoly).first.code,
        MoldValidationErrorCode.invalidPolygonSides,
      );

      const nested = MultiCavityMold(
        singleCavity: MultiCavityMold(
          singleCavity: CircularCylinder(diameter: 6.0, height: 3.0),
          cavityCount: 6,
        ),
        cavityCount: 2,
      );
      expect(
        MoldValidator.validateMold(nested).first.code,
        MoldValidationErrorCode.nestedMultiCavity,
      );
    });
  });

  group('ThermalAdvisor Tests', () {
    test('Emits shallowFastBake, deepSlowBake, highFillOverflowRisk, and optimalMatch appropriately', () {
      final shallow = ThermalAdvisor.evaluate(
        depthRatio: 0.60,
        sourceSaToV: 0.5,
        targetSaToV: 0.7,
        targetFillRatio: 0.72,
        targetFillProfile: FillProfile.butterCake,
      );
      expect(
        shallow.any((a) => a.type == ThermalWarningType.shallowFastBake),
        isTrue,
      );

      final deep = ThermalAdvisor.evaluate(
        depthRatio: 1.50,
        sourceSaToV: 0.6,
        targetSaToV: 0.4,
        targetFillRatio: 0.72,
        targetFillProfile: FillProfile.butterCake,
      );
      expect(
        deep.any((a) => a.type == ThermalWarningType.deepSlowBake),
        isTrue,
      );

      final overflow = ThermalAdvisor.evaluate(
        depthRatio: 1.0,
        sourceSaToV: 0.5,
        targetSaToV: 0.5,
        targetFillRatio: 0.90,
        targetFillProfile: FillProfile.chiffonSponge,
      );
      expect(
        overflow.any((a) => a.type == ThermalWarningType.highFillOverflowRisk),
        isTrue,
      );

      final optimal = ThermalAdvisor.evaluate(
        depthRatio: 1.05,
        sourceSaToV: 0.5,
        targetSaToV: 0.52,
        targetFillRatio: 0.72,
        targetFillProfile: FillProfile.butterCake,
      );
      expect(optimal.length, 1);
      expect(optimal.first.type, ThermalWarningType.optimalMatch);
    });
  });
}
