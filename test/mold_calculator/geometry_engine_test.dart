import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/fill_profile.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/mold_geometry.dart';
import 'package:recipetools/features/mold_calculator/domain/services/geometry_engine.dart';

void main() {
  group('MoldGeometry & GeometryEngine Volume / Surface Area Tests', () {
    test('Cylinder Volume: d=20cm, h=5cm, fill=1.0 => 1570.80 ml', () {
      const cylinder = CircularCylinder(diameter: 20.0, height: 5.0);
      final v = GeometryEngine.effectiveVolume(cylinder, 1.0);
      expect(v, closeTo(1570.7963, 0.01));
      expect(cylinder.baseArea(), closeTo(math.pi * 100.0, 0.001));
      expect(cylinder.wettedSurfaceAreaAt(5.0), closeTo(math.pi * 100 + math.pi * 20 * 5, 0.01));
    });

    test('Frustum Non-Linear Fill: d_b=16, d_t=22, h=8, fill=0.5 => ~964.47 ml (not 50%)', () {
      const frustum = CircularFrustum(
        bottomDiameter: 16.0,
        topDiameter: 22.0,
        height: 8.0,
      );
      final hFill = GeometryEngine.effectiveFillHeight(frustum, 0.5);
      expect(hFill, 4.0);
      expect(frustum.radiusAt(4.0) * 2.0, closeTo(19.0, 1e-6));

      final vHalf = GeometryEngine.effectiveVolume(frustum, 0.5);
      final vTotal = frustum.totalVolume;
      // V(4) = pi*4/3 * (8^2 + 8*9.5 + 9.5^2) = 964.4689... ml
      expect(vHalf, closeTo(964.47, 0.02));
      expect(vHalf / vTotal, lessThan(0.5));
    });

    test('Frustum slantHeight computes vertical height and cone works with bottomDiameter=0', () {
      const slantFrustum = CircularFrustum(
        bottomDiameter: 16.0,
        topDiameter: 22.0,
        height: 1.0, // ignored when slantHeight is set
        slantHeight: 5.0, // dr = 3, h = sqrt(25 - 9) = 4
      );
      expect(slantFrustum.totalHeight, closeTo(4.0, 1e-6));

      const cone = CircularFrustum(
        bottomDiameter: 0.0,
        topDiameter: 12.0,
        height: 10.0,
      );
      expect(cone.baseArea(), 0.0);
      expect(cone.totalVolume, closeTo((math.pi * 36.0 * 10.0) / 3.0, 0.01));
    });

    test('Annular Tube (Savarin): D=24, d_tube=8, h=6, eta=1.0 => 2412.74 ml', () {
      const savarin = AnnularTubeMold(
        outerBottomDiameter: 24.0,
        outerTopDiameter: 24.0,
        tubeBottomDiameter: 8.0,
        tubeTopDiameter: 8.0,
        height: 6.0,
        flutingFactor: 1.0,
      );
      expect(savarin.totalVolume, closeTo(2412.74, 0.02));

      final bundt = AnnularTubeMold(
        outerBottomDiameter: 24.0,
        outerTopDiameter: 24.0,
        tubeBottomDiameter: 8.0,
        tubeTopDiameter: 8.0,
        height: 6.0,
        flutingFactor: 0.88,
      );
      expect(bundt.totalVolume, closeTo(2412.7431 * 0.88, 0.02));
    });

    test('Annular Tube with shorter central tube stops subtracting above tubeHeight', () {
      const shortTube = AnnularTubeMold(
        outerBottomDiameter: 20.0,
        outerTopDiameter: 20.0,
        tubeBottomDiameter: 6.0,
        tubeTopDiameter: 6.0,
        height: 10.0,
        tubeHeight: 6.0,
        flutingFactor: 1.0,
      );
      final expected =
          math.pi * 100.0 * 10.0 - math.pi * 9.0 * 6.0;
      expect(shortTube.totalVolume, closeTo(expected, 0.01));
    });

    test('Spherical Cap (Dome): R=10, h=10 (hemisphere) => 2094.40 ml', () {
      final hemisphere = SphericalCapMold.fromRadius(radius: 10.0, height: 10.0);
      expect(hemisphere.totalVolume, closeTo(2094.40, 0.02));
      expect(hemisphere.wettedSurfaceAreaAt(10.0), closeTo(2.0 * math.pi * 100.0, 0.02));
    });

    test('SquarePrism, RectangularPrism, and RectangularFrustum (prismoidal)', () {
      const sq = SquarePrism(side: 20.0, height: 5.0);
      expect(sq.totalVolume, closeTo(2000.0, 1e-6));

      const rect = RectangularPrism(length: 30.0, width: 20.0, height: 4.0);
      expect(rect.totalVolume, closeTo(2400.0, 1e-6));

      const loaf = RectangularFrustum(
        bottomLength: 19.0,
        bottomWidth: 8.0,
        topLength: 22.0,
        topWidth: 10.0,
        height: 7.0,
      );
      // Exact integral of (19 + 3t)(8 + 2t)*7 dt from 0..1:
      // 7 * [152 + (62)/2 + 6/3] = 7 * [152 + 31 + 2] = 7 * 185 = 1295 ml
      expect(loaf.totalVolume, closeTo(1295.0, 1e-6));
    });

    test('VChannel, UChannel, RegularPolygon, HeartShape, WaterDisplacement & MultiCavity', () {
      const vChannel = VChannelMold(
        bottomWidth: 2.0,
        topWidth: 10.0,
        length: 25.0,
        height: 7.0,
      );
      expect(vChannel.totalVolume, closeTo(((2.0 + 10.0) / 2.0) * 7.0 * 25.0, 1e-6));

      const uChannel = UChannelMold(width: 10.0, length: 20.0, height: 8.0);
      // Semicircle bottom (r=5): 0.5*pi*25*20 = 250*pi, plus upper 3*10*20 = 600
      expect(uChannel.volumeAtHeight(5.0), closeTo(250.0 * math.pi, 0.02));
      expect(uChannel.totalVolume, closeTo(250.0 * math.pi + 600.0, 0.02));

      const hex = RegularPolygonMold(sides: 6, sideLength: 10.0, height: 5.0);
      final expectedHexArea = (6.0 * 100.0) / (4.0 * math.tan(math.pi / 6.0));
      expect(hex.baseArea(), closeTo(expectedHexArea, 0.01));
      expect(hex.totalVolume, closeTo(expectedHexArea * 5.0, 0.05));

      const heart = HeartShapeMold(width: 20.0, length: 20.0, height: 5.0, shapeFactor: 0.82);
      expect(heart.totalVolume, closeTo(0.82 * 400.0 * 5.0, 1e-6));

      const water = WaterDisplacementMold(measuredVolumeMl: 1200.0, height: 6.0);
      expect(water.volumeAtHeight(3.0), closeTo(600.0, 1e-6));

      const tray = MultiCavityMold(
        singleCavity: CircularCylinder(diameter: 7.0, height: 3.5),
        cavityCount: 12,
      );
      expect(
        tray.totalVolume,
        closeTo(const CircularCylinder(diameter: 7.0, height: 3.5).totalVolume * 12, 1e-6),
      );
    });

    test('All MoldGeometry variants round-trip cleanly through JSON', () {
      final molds = <MoldGeometry>[
        const CircularCylinder(diameter: 20, height: 5),
        const SquarePrism(side: 20, height: 5),
        const RectangularPrism(length: 30, width: 20, height: 4),
        const CircularFrustum(bottomDiameter: 16, topDiameter: 22, height: 8),
        const RectangularFrustum(
          bottomLength: 19,
          bottomWidth: 8,
          topLength: 22,
          topWidth: 10,
          height: 7,
        ),
        const VChannelMold(bottomWidth: 2, topWidth: 10, length: 25, height: 7),
        const AnnularTubeMold(
          outerBottomDiameter: 20,
          outerTopDiameter: 25,
          tubeBottomDiameter: 9,
          tubeTopDiameter: 7,
          height: 9,
          flutingFactor: 0.88,
        ),
        const SphericalCapMold(diameter: 20, height: 10),
        const UChannelMold(width: 8, length: 30, height: 7),
        const RegularPolygonMold(sides: 6, sideLength: 10, height: 5),
        const HeartShapeMold(width: 20, length: 20, height: 5, shapeFactor: 0.82),
        const WaterDisplacementMold(measuredVolumeMl: 1500, height: 6),
        const MultiCavityMold(
          singleCavity: CircularCylinder(diameter: 7, height: 3.5),
          cavityCount: 12,
        ),
      ];

      for (final m in molds) {
        final decoded = MoldGeometry.fromJson(m.toJson());
        expect(decoded, m);
      }
    });

    test('Scaling computation computes k_V, k_A, leftover batter & unscaled fill', () {
      const src = CircularCylinder(diameter: 24.0, height: 5.0);
      const tgt = CircularCylinder(diameter: 20.0, height: 5.0);

      final res = GeometryEngine.computeScaling(
        source: src,
        sourceFillRatio: 0.72,
        target: tgt,
        targetFillRatio: 0.72,
        targetFillProfile: FillProfile.butterCake,
      );

      // (20/24)^2 = 25/36 = 0.69444...
      expect(res.volumeScaleFactor, closeTo(25.0 / 36.0, 1e-5));
      expect(res.areaScaleFactor, closeTo(25.0 / 36.0, 1e-5));
      expect(res.depthRatio, closeTo(1.0, 1e-5));
      expect(res.leftoverBatterMl, greaterThan(0.0));
      expect(res.deficitBatterMl, 0.0);
      // 0.72 * (36/25) = 1.0368 > 1.0 => overflows target at 1x!
      expect(res.unscaledOverflowsTarget, isTrue);
    });
  });
}
