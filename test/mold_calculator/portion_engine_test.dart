import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/mold_geometry.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/mold_preset.dart';
import 'package:recipetools/features/mold_calculator/domain/services/portion_engine.dart';
import 'package:recipetools/features/mold_calculator/domain/validators/mold_validator.dart';

void main() {
  group('PortionEngine Yield & Waste (Merma) Tests', () {
    test('Grid Orientation Optimizer: 30x20 pan, edgeTrim=0, 8x4 bar => 15 portions, 120 cm² (20%) waste', () {
      const pan = RectangularPrism(length: 30.0, width: 20.0, height: 4.0);
      final res = PortionEngine.calculateGrid(
        mold: pan,
        fillRatio: 0.88,
        pieceLengthCm: 8.0,
        pieceWidthCm: 4.0,
        edgeTrimCm: 0.0,
      );

      expect(res.strategy, CutStrategyType.grid);
      expect(res.fullPortions, 15);
      expect(res.columns, 3);
      expect(res.rows, 5);
      expect(res.rotatedOrientation, isFalse);
      expect(res.usedAreaCm2, closeTo(480.0, 1e-6));
      expect(res.wasteAreaCm2, closeTo(120.0, 1e-6));
      expect(res.wastePercent, closeTo(20.0, 1e-6));
    });

    test('Grid Orientation Optimizer selects rotated 90° layout when it yields more pieces', () {
      const pan = RectangularPrism(length: 30.0, width: 20.0, height: 4.0);
      final res = PortionEngine.calculateGrid(
        mold: pan,
        fillRatio: 0.88,
        pieceLengthCm: 4.0,
        pieceWidthCm: 8.0,
        edgeTrimCm: 0.0,
      );

      expect(res.fullPortions, 15);
      expect(res.rotatedOrientation, isTrue);
      expect(res.wastePercent, closeTo(20.0, 1e-6));
    });

    test('Grid with edgeTrim reduces usable bounds accurately', () {
      const pan = SquarePrism(side: 22.0, height: 5.0);
      // Usable = 20x20 with 1cm trim -> 4x4 of 5x5 = 16 portions
      final res = PortionEngine.calculateGrid(
        mold: pan,
        fillRatio: 0.88,
        pieceLengthCm: 5.0,
        pieceWidthCm: 5.0,
        edgeTrimCm: 1.0,
      );

      expect(res.fullPortions, 16);
      expect(res.usedAreaCm2, closeTo(400.0, 1e-6));
      expect(res.wasteAreaCm2, closeTo(84.0, 1e-6)); // 484 - 400 = 84
    });

    test('Circular pan Cartesian grid packs full squares inside usable circle', () {
      const roundPan = CircularCylinder(diameter: 20.0, height: 5.0);
      final res = PortionEngine.calculateGrid(
        mold: roundPan,
        fillRatio: 0.80,
        pieceLengthCm: 5.0,
        pieceWidthCm: 5.0,
        edgeTrimCm: 0.0,
      );

      expect(res.isCircularPan, isTrue);
      expect(res.fullPortions, greaterThanOrEqualTo(4));
      expect(res.wasteAreaCm2, greaterThan(0.0));
    });

    test('Radial cuts work with arc target, fixed count, and Savarin annular inner arc', () {
      const savarin = AnnularTubeMold(
        outerBottomDiameter: 24.0,
        outerTopDiameter: 24.0,
        tubeBottomDiameter: 8.0,
        tubeTopDiameter: 8.0,
        height: 6.0,
      );

      final fixed = PortionEngine.calculateRadial(
        mold: savarin,
        fillRatio: 0.72,
        fixedSlices: 12,
      );
      expect(fixed.fullPortions, 12);
      expect(fixed.outerArcCm, closeTo((2.0 * math.pi * 12.0) / 12.0, 1e-4));
      expect(fixed.innerArcCm, closeTo((math.pi * 8.0) / 12.0, 1e-4));
      expect(fixed.wastePercent, 0.0);

      final byArc = PortionEngine.calculateRadial(
        mold: const CircularCylinder(diameter: 24.0, height: 5.0),
        fillRatio: 0.72,
        targetArcCm: 5.0,
      );
      // floor(24*pi / 5) = floor(15.0796) = 15
      expect(byArc.fullPortions, 15);
    });

    test('Concentric cuts split inner ring and outer ring portions', () {
      const cake = CircularCylinder(diameter: 26.0, height: 7.5);
      final res = PortionEngine.calculateConcentric(
        mold: cake,
        fillRatio: 0.72,
        innerDiameterCm: 10.0,
        targetArcCm: 5.0,
      );

      // inner: floor(10*pi/5) = 6; outer: floor(26*pi/5) = 16 -> total 22
      expect(res.innerPortions, 6);
      expect(res.outerPortions, 16);
      expect(res.fullPortions, 22);
    });

    test('Linear loaf slicing accounts for end crust trim', () {
      const pullman = RectangularPrism(length: 30.0, width: 10.0, height: 10.0);
      final res = PortionEngine.calculateLinear(
        mold: pullman,
        fillRatio: 0.80,
        sliceThicknessCm: 2.0,
        endTrimCm: 1.0,
      );

      // usable = 30 - 2 = 28 -> 14 slices
      expect(res.fullPortions, 14);
      expect(res.usedLengthCm, closeTo(28.0, 1e-6));
      expect(res.wastePercent, closeTo((2.0 / 30.0) * 100.0, 1e-4));
    });

    test('Invalid portion dimensions throw MoldValidationException', () {
      const pan = SquarePrism(side: 20.0, height: 5.0);
      expect(
        () => PortionEngine.calculateGrid(
          mold: pan,
          fillRatio: 0.8,
          pieceLengthCm: 0.0,
          pieceWidthCm: 5.0,
        ),
        throwsA(isA<MoldValidationException>()),
      );
      expect(
        () => PortionEngine.calculateLinear(
          mold: pan,
          fillRatio: 0.8,
          sliceThicknessCm: -1.0,
        ),
        throwsA(isA<MoldValidationException>()),
      );
    });
  });
}
