import 'dart:math' as math;

/// Epsilon for clamping floating-point rounding noise to zero.
const double kMoldEpsilon = 1e-9;

/// Supported 2D/3D mold and recipient geometries.
enum MoldShapeType {
  circularCylinder,
  squarePrism,
  rectangularPrism,
  circularFrustum,
  rectangularFrustum,
  vChannel,
  annularTube,
  sphericalCap,
  uChannel,
  regularPolygon,
  heartShape,
  waterDisplacement,
  multiCavity,
}

double _clampZero(double value) {
  if (!value.isFinite) return 0.0;
  if (value.abs() < kMoldEpsilon || value < 0.0) return 0.0;
  return value;
}

double _clampHeight(double y, double totalHeight) {
  if (!y.isFinite || !totalHeight.isFinite || totalHeight <= 0.0) return 0.0;
  if (y <= 0.0) return 0.0;
  if (y >= totalHeight) return totalHeight;
  return y;
}

/// Base sealed class for all baking/culinary mold geometries.
///
/// All linear dimensions are in centimeters (cm) so that 1 cm³ ≡ 1 ml.
sealed class MoldGeometry {
  const MoldGeometry();

  MoldShapeType get shapeType;
  double get totalHeight;
  double get boundingWidth;
  double get boundingLength;

  double baseArea();
  double topArea();
  double crossSectionAreaAt(double y);
  double volumeAtHeight(double y);
  double wettedSurfaceAreaAt(double y);

  double get totalVolume => volumeAtHeight(totalHeight);

  Map<String, dynamic> toJson();

  static MoldGeometry fromJson(Map<String, dynamic> json) {
    final typeName = json['shapeType'] as String?;
    final type = MoldShapeType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MoldShapeType.circularCylinder,
    );

    double readDouble(String key, double fallback) {
      final raw = json[key];
      if (raw is num) return raw.toDouble();
      return fallback;
    }

    double? readNullableDouble(String key) {
      final raw = json[key];
      if (raw is num) return raw.toDouble();
      return null;
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is num) return raw.toInt();
      return fallback;
    }

    switch (type) {
      case MoldShapeType.circularCylinder:
        return CircularCylinder(
          diameter: readDouble('diameter', 20.0),
          height: readDouble('height', 5.0),
        );
      case MoldShapeType.squarePrism:
        return SquarePrism(
          side: readDouble('side', 20.0),
          height: readDouble('height', 5.0),
        );
      case MoldShapeType.rectangularPrism:
        return RectangularPrism(
          length: readDouble('length', 30.0),
          width: readDouble('width', 20.0),
          height: readDouble('height', 5.0),
        );
      case MoldShapeType.circularFrustum:
        return CircularFrustum(
          bottomDiameter: readDouble('bottomDiameter', 16.0),
          topDiameter: readDouble('topDiameter', 22.0),
          height: readDouble('height', 8.0),
          slantHeight: readNullableDouble('slantHeight'),
        );
      case MoldShapeType.rectangularFrustum:
        return RectangularFrustum(
          bottomLength: readDouble('bottomLength', 19.0),
          bottomWidth: readDouble('bottomWidth', 8.0),
          topLength: readDouble('topLength', 22.0),
          topWidth: readDouble('topWidth', 10.0),
          height: readDouble('height', 7.0),
        );
      case MoldShapeType.vChannel:
        return VChannelMold(
          bottomWidth: readDouble('bottomWidth', 2.0),
          topWidth: readDouble('topWidth', 10.0),
          length: readDouble('length', 25.0),
          height: readDouble('height', 7.0),
        );
      case MoldShapeType.annularTube:
        return AnnularTubeMold(
          outerBottomDiameter: readDouble('outerBottomDiameter', 24.0),
          outerTopDiameter: readDouble('outerTopDiameter', 24.0),
          tubeBottomDiameter: readDouble('tubeBottomDiameter', 7.0),
          tubeTopDiameter: readDouble('tubeTopDiameter', 7.0),
          height: readDouble('height', 6.0),
          tubeHeight: readNullableDouble('tubeHeight'),
          flutingFactor: readDouble('flutingFactor', 1.0),
        );
      case MoldShapeType.sphericalCap:
        return SphericalCapMold(
          diameter: readDouble('diameter', 20.0),
          height: readDouble('height', 10.0),
        );
      case MoldShapeType.uChannel:
        return UChannelMold(
          width: readDouble('width', 8.0),
          length: readDouble('length', 30.0),
          height: readDouble('height', 7.0),
        );
      case MoldShapeType.regularPolygon:
        return RegularPolygonMold(
          sides: readInt('sides', 6),
          sideLength: readDouble('sideLength', 12.0),
          height: readDouble('height', 5.0),
        );
      case MoldShapeType.heartShape:
        return HeartShapeMold(
          width: readDouble('width', 20.0),
          length: readDouble('length', 20.0),
          height: readDouble('height', 5.0),
          shapeFactor: readDouble('shapeFactor', 0.82),
        );
      case MoldShapeType.waterDisplacement:
        return WaterDisplacementMold(
          measuredVolumeMl: readDouble('measuredVolumeMl', 1500.0),
          height: readDouble('height', 6.0),
          fillCurveExponent: readDouble('fillCurveExponent', 1.0),
        );
      case MoldShapeType.multiCavity:
        final inner = json['singleCavity'];
        final single = inner is Map<String, dynamic>
            ? MoldGeometry.fromJson(inner)
            : const CircularCylinder(diameter: 7.0, height: 3.5);
        return MultiCavityMold(
          singleCavity: single,
          cavityCount: readInt('cavityCount', 12),
        );
    }
  }
}

/// Straight-walled round cylinder mold.
final class CircularCylinder extends MoldGeometry {
  final double diameter;
  final double height;

  const CircularCylinder({
    required this.diameter,
    required this.height,
  });

  double get radius => diameter / 2.0;

  @override
  MoldShapeType get shapeType => MoldShapeType.circularCylinder;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => diameter;

  @override
  double get boundingLength => diameter;

  @override
  double baseArea() {
    if (diameter <= 0.0) return 0.0;
    return _clampZero(math.pi * radius * radius);
  }

  @override
  double topArea() => baseArea();

  @override
  double crossSectionAreaAt(double y) => baseArea();

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, totalHeight);
    return _clampZero(baseArea() * yc);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, totalHeight);
    if (diameter <= 0.0) return 0.0;
    return _clampZero(baseArea() + math.pi * diameter * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'diameter': diameter,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircularCylinder &&
          other.diameter == diameter &&
          other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, diameter, height);
}

/// Straight-walled square prism pan.
final class SquarePrism extends MoldGeometry {
  final double side;
  final double height;

  const SquarePrism({
    required this.side,
    required this.height,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.squarePrism;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => side;

  @override
  double get boundingLength => side;

  @override
  double baseArea() {
    if (side <= 0.0) return 0.0;
    return _clampZero(side * side);
  }

  @override
  double topArea() => baseArea();

  @override
  double crossSectionAreaAt(double y) => baseArea();

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, totalHeight);
    return _clampZero(baseArea() * yc);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, totalHeight);
    if (side <= 0.0) return 0.0;
    return _clampZero(baseArea() + 4.0 * side * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'side': side,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SquarePrism && other.side == side && other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, side, height);
}

/// Straight-walled rectangular prism pan (GN, sheet, Pullman).
final class RectangularPrism extends MoldGeometry {
  final double length;
  final double width;
  final double height;

  const RectangularPrism({
    required this.length,
    required this.width,
    required this.height,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.rectangularPrism;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => width;

  @override
  double get boundingLength => length;

  @override
  double baseArea() {
    if (length <= 0.0 || width <= 0.0) return 0.0;
    return _clampZero(length * width);
  }

  @override
  double topArea() => baseArea();

  @override
  double crossSectionAreaAt(double y) => baseArea();

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, totalHeight);
    return _clampZero(baseArea() * yc);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, totalHeight);
    if (length <= 0.0 || width <= 0.0) return 0.0;
    return _clampZero(baseArea() + 2.0 * (length + width) * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'length': length,
        'width': width,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RectangularPrism &&
          other.length == length &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, length, width, height);
}

/// Truncated cone (frustum) or full cone (when [bottomDiameter] == 0).
final class CircularFrustum extends MoldGeometry {
  final double bottomDiameter;
  final double topDiameter;
  final double height;
  final double? slantHeight;

  const CircularFrustum({
    required this.bottomDiameter,
    required this.topDiameter,
    required this.height,
    this.slantHeight,
  });

  double get bottomRadius => bottomDiameter / 2.0;
  double get topRadius => topDiameter / 2.0;

  @override
  MoldShapeType get shapeType => MoldShapeType.circularFrustum;

  @override
  double get totalHeight {
    if (slantHeight != null) {
      final dr = (topRadius - bottomRadius).abs();
      if (slantHeight! > dr) {
        return math.sqrt(slantHeight! * slantHeight! - dr * dr);
      }
    }
    return height;
  }

  @override
  double get boundingWidth => math.max(bottomDiameter, topDiameter);

  @override
  double get boundingLength => boundingWidth;

  double radiusAt(double y) {
    final h = totalHeight;
    if (h <= 0.0) return bottomRadius;
    final yc = _clampHeight(y, h);
    return bottomRadius + (yc / h) * (topRadius - bottomRadius);
  }

  @override
  double baseArea() {
    if (bottomDiameter <= 0.0) return 0.0;
    return _clampZero(math.pi * bottomRadius * bottomRadius);
  }

  @override
  double topArea() {
    if (topDiameter <= 0.0) return 0.0;
    return _clampZero(math.pi * topRadius * topRadius);
  }

  @override
  double crossSectionAreaAt(double y) {
    final r = radiusAt(y);
    if (r <= 0.0) return 0.0;
    return _clampZero(math.pi * r * r);
  }

  @override
  double volumeAtHeight(double y) {
    final h = totalHeight;
    final yc = _clampHeight(y, h);
    if (yc <= 0.0) return 0.0;
    final ry = radiusAt(yc);
    final rb = bottomRadius;
    return _clampZero((math.pi * yc / 3.0) * (rb * rb + rb * ry + ry * ry));
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final h = totalHeight;
    final yc = _clampHeight(y, h);
    final ry = radiusAt(yc);
    final rb = bottomRadius;
    final dr = ry - rb;
    final slant = math.sqrt(yc * yc + dr * dr);
    return _clampZero(baseArea() + math.pi * (rb + ry) * slant);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'bottomDiameter': bottomDiameter,
        'topDiameter': topDiameter,
        'height': height,
        if (slantHeight != null) 'slantHeight': slantHeight,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircularFrustum &&
          other.bottomDiameter == bottomDiameter &&
          other.topDiameter == topDiameter &&
          other.height == height &&
          other.slantHeight == slantHeight;

  @override
  int get hashCode =>
      Object.hash(shapeType, bottomDiameter, topDiameter, height, slantHeight);
}

/// Tapered rectangular loaf/budinera mold evaluated using the prismoidal formula.
final class RectangularFrustum extends MoldGeometry {
  final double bottomLength;
  final double bottomWidth;
  final double topLength;
  final double topWidth;
  final double height;

  const RectangularFrustum({
    required this.bottomLength,
    required this.bottomWidth,
    required this.topLength,
    required this.topWidth,
    required this.height,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.rectangularFrustum;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => math.max(bottomWidth, topWidth);

  @override
  double get boundingLength => math.max(bottomLength, topLength);

  double lengthAt(double y) {
    if (height <= 0.0) return bottomLength;
    final yc = _clampHeight(y, height);
    return bottomLength + (yc / height) * (topLength - bottomLength);
  }

  double widthAt(double y) {
    if (height <= 0.0) return bottomWidth;
    final yc = _clampHeight(y, height);
    return bottomWidth + (yc / height) * (topWidth - bottomWidth);
  }

  @override
  double baseArea() {
    if (bottomLength <= 0.0 || bottomWidth <= 0.0) return 0.0;
    return _clampZero(bottomLength * bottomWidth);
  }

  @override
  double topArea() {
    if (topLength <= 0.0 || topWidth <= 0.0) return 0.0;
    return _clampZero(topLength * topWidth);
  }

  @override
  double crossSectionAreaAt(double y) {
    final ly = lengthAt(y);
    final wy = widthAt(y);
    if (ly <= 0.0 || wy <= 0.0) return 0.0;
    return _clampZero(ly * wy);
  }

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0) return 0.0;
    final ly = lengthAt(yc);
    final wy = widthAt(yc);
    final aBase = baseArea();
    final aTopY = _clampZero(ly * wy);
    final aMid = _clampZero(((bottomLength + ly) / 2.0) * ((bottomWidth + wy) / 2.0));
    return _clampZero((yc / 6.0) * (aBase + aTopY + 4.0 * aMid));
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    final ly = lengthAt(yc);
    final wy = widthAt(yc);
    final dw = (wy - bottomWidth) / 2.0;
    final dl = (ly - bottomLength) / 2.0;
    final slantLongWall = math.sqrt(yc * yc + dw * dw);
    final slantShortWall = math.sqrt(yc * yc + dl * dl);
    return _clampZero(
      baseArea() +
          (bottomLength + ly) * slantLongWall +
          (bottomWidth + wy) * slantShortWall,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'bottomLength': bottomLength,
        'bottomWidth': bottomWidth,
        'topLength': topLength,
        'topWidth': topWidth,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RectangularFrustum &&
          other.bottomLength == bottomLength &&
          other.bottomWidth == bottomWidth &&
          other.topLength == topLength &&
          other.topWidth == topWidth &&
          other.height == height;

  @override
  int get hashCode => Object.hash(
        shapeType,
        bottomLength,
        bottomWidth,
        topLength,
        topWidth,
        height,
      );
}

/// V-channel or truncated V-trough mold extruded along [length].
final class VChannelMold extends MoldGeometry {
  final double bottomWidth;
  final double topWidth;
  final double length;
  final double height;

  const VChannelMold({
    required this.bottomWidth,
    required this.topWidth,
    required this.length,
    required this.height,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.vChannel;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => math.max(bottomWidth, topWidth);

  @override
  double get boundingLength => length;

  double widthAt(double y) {
    if (height <= 0.0) return bottomWidth;
    final yc = _clampHeight(y, height);
    return bottomWidth + (yc / height) * (topWidth - bottomWidth);
  }

  @override
  double baseArea() => _clampZero(bottomWidth * length);

  @override
  double topArea() => _clampZero(topWidth * length);

  @override
  double crossSectionAreaAt(double y) => _clampZero(widthAt(y) * length);

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0 || length <= 0.0) return 0.0;
    final wy = widthAt(yc);
    return _clampZero(((bottomWidth + wy) / 2.0) * yc * length);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (length <= 0.0) return 0.0;
    final wy = widthAt(yc);
    final dw = (wy - bottomWidth) / 2.0;
    final sideSlant = math.sqrt(yc * yc + dw * dw);
    final endCaps = (bottomWidth + wy) * yc;
    return _clampZero(baseArea() + 2.0 * length * sideSlant + endCaps);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'bottomWidth': bottomWidth,
        'topWidth': topWidth,
        'length': length,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VChannelMold &&
          other.bottomWidth == bottomWidth &&
          other.topWidth == topWidth &&
          other.length == length &&
          other.height == height;

  @override
  int get hashCode =>
      Object.hash(shapeType, bottomWidth, topWidth, length, height);
}

/// Annular / central-tube mold (Bundt, Savarin, Chiffon).
final class AnnularTubeMold extends MoldGeometry {
  final double outerBottomDiameter;
  final double outerTopDiameter;
  final double tubeBottomDiameter;
  final double tubeTopDiameter;
  final double height;
  final double? tubeHeight;
  final double flutingFactor;

  const AnnularTubeMold({
    required this.outerBottomDiameter,
    required this.outerTopDiameter,
    required this.tubeBottomDiameter,
    required this.tubeTopDiameter,
    required this.height,
    this.tubeHeight,
    this.flutingFactor = 1.0,
  });

  double get effectiveTubeHeight => tubeHeight ?? height;

  CircularFrustum get _outer => CircularFrustum(
        bottomDiameter: outerBottomDiameter,
        topDiameter: outerTopDiameter,
        height: height,
      );

  CircularFrustum get _tube => CircularFrustum(
        bottomDiameter: tubeBottomDiameter,
        topDiameter: tubeTopDiameter,
        height: effectiveTubeHeight,
      );

  @override
  MoldShapeType get shapeType => MoldShapeType.annularTube;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => math.max(outerBottomDiameter, outerTopDiameter);

  @override
  double get boundingLength => boundingWidth;

  @override
  double baseArea() =>
      _clampZero(flutingFactor * (_outer.baseArea() - _tube.baseArea()));

  @override
  double topArea() {
    final tubeTop =
        height <= effectiveTubeHeight + kMoldEpsilon ? _tube.topArea() : 0.0;
    return _clampZero(flutingFactor * (_outer.topArea() - tubeTop));
  }

  @override
  double crossSectionAreaAt(double y) {
    final yc = _clampHeight(y, height);
    final tubeArea = yc <= effectiveTubeHeight + kMoldEpsilon
        ? _tube.crossSectionAreaAt(yc)
        : 0.0;
    return _clampZero(
      flutingFactor * (_outer.crossSectionAreaAt(yc) - tubeArea),
    );
  }

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0) return 0.0;
    final tubeH = math.min(yc, effectiveTubeHeight);
    return _clampZero(
      flutingFactor * (_outer.volumeAtHeight(yc) - _tube.volumeAtHeight(tubeH)),
    );
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    final tubeH = math.min(yc, effectiveTubeHeight);
    final annularBase = _clampZero(_outer.baseArea() - _tube.baseArea());
    final outerWall = _clampZero(_outer.wettedSurfaceAreaAt(yc) - _outer.baseArea());
    final tubeWall = _clampZero(_tube.wettedSurfaceAreaAt(tubeH) - _tube.baseArea());
    final tubeCap = yc > effectiveTubeHeight ? _tube.topArea() : 0.0;
    return _clampZero(annularBase + outerWall + tubeWall + tubeCap);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'outerBottomDiameter': outerBottomDiameter,
        'outerTopDiameter': outerTopDiameter,
        'tubeBottomDiameter': tubeBottomDiameter,
        'tubeTopDiameter': tubeTopDiameter,
        'height': height,
        if (tubeHeight != null) 'tubeHeight': tubeHeight,
        'flutingFactor': flutingFactor,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnularTubeMold &&
          other.outerBottomDiameter == outerBottomDiameter &&
          other.outerTopDiameter == outerTopDiameter &&
          other.tubeBottomDiameter == tubeBottomDiameter &&
          other.tubeTopDiameter == tubeTopDiameter &&
          other.height == height &&
          other.tubeHeight == tubeHeight &&
          other.flutingFactor == flutingFactor;

  @override
  int get hashCode => Object.hash(
        shapeType,
        outerBottomDiameter,
        outerTopDiameter,
        tubeBottomDiameter,
        tubeTopDiameter,
        height,
        tubeHeight,
        flutingFactor,
      );
}

/// Hemispherical or spherical cap dome mold (pole at y = 0, rim at y = height).
final class SphericalCapMold extends MoldGeometry {
  final double diameter;
  final double height;

  const SphericalCapMold({
    required this.diameter,
    required this.height,
  });

  factory SphericalCapMold.fromRadius({
    required double radius,
    required double height,
  }) {
    return SphericalCapMold(diameter: radius * 2.0, height: height);
  }

  double get radius => diameter / 2.0;

  @override
  MoldShapeType get shapeType => MoldShapeType.sphericalCap;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth {
    final r = radius;
    if (r <= 0.0 || height <= 0.0 || height > r) return diameter;
    return 2.0 * math.sqrt(_clampZero(2.0 * r * height - height * height));
  }

  @override
  double get boundingLength => boundingWidth;

  @override
  double baseArea() => 0.0;

  @override
  double topArea() => crossSectionAreaAt(height);

  @override
  double crossSectionAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0 || radius <= 0.0) return 0.0;
    return _clampZero(math.pi * _clampZero(2.0 * radius * yc - yc * yc));
  }

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0 || radius <= 0.0) return 0.0;
    return _clampZero((math.pi * yc * yc / 3.0) * (3.0 * radius - yc));
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (yc <= 0.0 || radius <= 0.0) return 0.0;
    return _clampZero(2.0 * math.pi * radius * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'diameter': diameter,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SphericalCapMold &&
          other.diameter == diameter &&
          other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, diameter, height);
}

/// U-channel mold: semicircular bottom (r = width / 2) with straight upper walls.
final class UChannelMold extends MoldGeometry {
  final double width;
  final double length;
  final double height;

  const UChannelMold({
    required this.width,
    required this.length,
    required this.height,
  });

  double get radius => width / 2.0;

  @override
  MoldShapeType get shapeType => MoldShapeType.uChannel;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => width;

  @override
  double get boundingLength => length;

  @override
  double baseArea() => 0.0;

  @override
  double topArea() => crossSectionAreaAt(height);

  @override
  double crossSectionAreaAt(double y) {
    final yc = _clampHeight(y, height);
    final r = radius;
    if (yc <= 0.0 || r <= 0.0 || length <= 0.0) return 0.0;
    if (yc <= r) {
      final halfChord = math.sqrt(_clampZero(2.0 * r * yc - yc * yc));
      return _clampZero(2.0 * halfChord * length);
    }
    return _clampZero(width * length);
  }

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    final r = radius;
    if (yc <= 0.0 || r <= 0.0 || length <= 0.0) return 0.0;
    if (yc <= r) {
      final cosVal = ((r - yc) / r).clamp(-1.0, 1.0);
      final theta = math.acos(cosVal);
      final halfChord = math.sqrt(_clampZero(2.0 * r * yc - yc * yc));
      final aSeg = _clampZero(r * r * theta - (r - yc) * halfChord);
      return _clampZero(aSeg * length);
    }
    final aEnd = 0.5 * math.pi * r * r + width * (yc - r);
    return _clampZero(aEnd * length);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    final r = radius;
    if (yc <= 0.0 || r <= 0.0 || length <= 0.0) return 0.0;
    if (yc <= r) {
      final cosVal = ((r - yc) / r).clamp(-1.0, 1.0);
      final theta = math.acos(cosVal);
      final halfChord = math.sqrt(_clampZero(2.0 * r * yc - yc * yc));
      final aSeg = _clampZero(r * r * theta - (r - yc) * halfChord);
      return _clampZero(2.0 * r * theta * length + 2.0 * aSeg);
    }
    final aEnd = 0.5 * math.pi * r * r + width * (yc - r);
    final arcLen = math.pi * r + 2.0 * (yc - r);
    return _clampZero(arcLen * length + 2.0 * aEnd);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'width': width,
        'length': length,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UChannelMold &&
          other.width == width &&
          other.length == length &&
          other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, width, length, height);
}

/// Straight-walled regular n-gon prism mold.
final class RegularPolygonMold extends MoldGeometry {
  final int sides;
  final double sideLength;
  final double height;

  const RegularPolygonMold({
    required this.sides,
    required this.sideLength,
    required this.height,
  });

  double get circumradius {
    if (sides < 3 || sideLength <= 0.0) return 0.0;
    return sideLength / (2.0 * math.sin(math.pi / sides));
  }

  @override
  MoldShapeType get shapeType => MoldShapeType.regularPolygon;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => 2.0 * circumradius;

  @override
  double get boundingLength => boundingWidth;

  @override
  double baseArea() {
    if (sides < 3 || sideLength <= 0.0) return 0.0;
    return _clampZero(
      (sides * sideLength * sideLength) / (4.0 * math.tan(math.pi / sides)),
    );
  }

  @override
  double topArea() => baseArea();

  @override
  double crossSectionAreaAt(double y) => baseArea();

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    return _clampZero(baseArea() * yc);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (sides < 3 || sideLength <= 0.0) return 0.0;
    return _clampZero(baseArea() + sides * sideLength * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'sides': sides,
        'sideLength': sideLength,
        'height': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularPolygonMold &&
          other.sides == sides &&
          other.sideLength == sideLength &&
          other.height == height;

  @override
  int get hashCode => Object.hash(shapeType, sides, sideLength, height);
}

/// Heart or petal composite mold parameterized by bounding box & shape factor.
final class HeartShapeMold extends MoldGeometry {
  final double width;
  final double length;
  final double height;
  final double shapeFactor;

  const HeartShapeMold({
    required this.width,
    required this.length,
    required this.height,
    this.shapeFactor = 0.82,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.heartShape;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => width;

  @override
  double get boundingLength => length;

  @override
  double baseArea() {
    if (width <= 0.0 || length <= 0.0 || shapeFactor <= 0.0) return 0.0;
    return _clampZero(shapeFactor * width * length);
  }

  @override
  double topArea() => baseArea();

  @override
  double crossSectionAreaAt(double y) => baseArea();

  @override
  double volumeAtHeight(double y) {
    final yc = _clampHeight(y, height);
    return _clampZero(baseArea() * yc);
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (width <= 0.0 || length <= 0.0) return 0.0;
    final approxPerimeter = 2.0 * (width + length) * 0.86;
    return _clampZero(baseArea() + approxPerimeter * yc);
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'width': width,
        'length': length,
        'height': height,
        'shapeFactor': shapeFactor,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeartShapeMold &&
          other.width == width &&
          other.length == length &&
          other.height == height &&
          other.shapeFactor == shapeFactor;

  @override
  int get hashCode =>
      Object.hash(shapeType, width, length, height, shapeFactor);
}

/// Custom irregular mold defined via measured water displacement volume.
final class WaterDisplacementMold extends MoldGeometry {
  final double measuredVolumeMl;
  final double height;
  final double fillCurveExponent;

  const WaterDisplacementMold({
    required this.measuredVolumeMl,
    required this.height,
    this.fillCurveExponent = 1.0,
  });

  double get _meanCrossSectionArea =>
      height > 0.0 ? _clampZero(measuredVolumeMl / height) : 0.0;

  double get _equivalentDiameter => _meanCrossSectionArea > 0.0
      ? 2.0 * math.sqrt(_meanCrossSectionArea / math.pi)
      : 0.0;

  @override
  MoldShapeType get shapeType => MoldShapeType.waterDisplacement;

  @override
  double get totalHeight => height;

  @override
  double get boundingWidth => _equivalentDiameter;

  @override
  double get boundingLength => _equivalentDiameter;

  @override
  double baseArea() {
    if (fillCurveExponent == 1.0) return _meanCrossSectionArea;
    return fillCurveExponent > 1.0 ? 0.0 : _meanCrossSectionArea;
  }

  @override
  double topArea() => crossSectionAreaAt(height);

  @override
  double crossSectionAreaAt(double y) {
    if (height <= 0.0 || measuredVolumeMl <= 0.0 || fillCurveExponent <= 0.0) {
      return 0.0;
    }
    final yc = _clampHeight(y, height);
    if ((fillCurveExponent - 1.0).abs() < kMoldEpsilon) {
      return _meanCrossSectionArea;
    }
    if (yc <= 0.0) {
      return fillCurveExponent > 1.0 ? 0.0 : _meanCrossSectionArea;
    }
    return _clampZero(
      fillCurveExponent *
          _meanCrossSectionArea *
          math.pow(yc / height, fillCurveExponent - 1.0),
    );
  }

  @override
  double volumeAtHeight(double y) {
    if (height <= 0.0 || measuredVolumeMl <= 0.0 || fillCurveExponent <= 0.0) {
      return 0.0;
    }
    final yc = _clampHeight(y, height);
    if (yc <= 0.0) return 0.0;
    return _clampZero(
      measuredVolumeMl * math.pow(yc / height, fillCurveExponent),
    );
  }

  @override
  double wettedSurfaceAreaAt(double y) {
    final yc = _clampHeight(y, height);
    if (measuredVolumeMl <= 0.0 || height <= 0.0) return 0.0;
    return _clampZero(
      _meanCrossSectionArea + math.pi * _equivalentDiameter * yc,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'measuredVolumeMl': measuredVolumeMl,
        'height': height,
        'fillCurveExponent': fillCurveExponent,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterDisplacementMold &&
          other.measuredVolumeMl == measuredVolumeMl &&
          other.height == height &&
          other.fillCurveExponent == fillCurveExponent;

  @override
  int get hashCode =>
      Object.hash(shapeType, measuredVolumeMl, height, fillCurveExponent);
}

/// Multi-cavity wrapper (e.g., muffin tray, tartlet tray, silicone mold sheet).
final class MultiCavityMold extends MoldGeometry {
  final MoldGeometry singleCavity;
  final int cavityCount;

  const MultiCavityMold({
    required this.singleCavity,
    required this.cavityCount,
  });

  @override
  MoldShapeType get shapeType => MoldShapeType.multiCavity;

  @override
  double get totalHeight => singleCavity.totalHeight;

  @override
  double get boundingWidth => singleCavity.boundingWidth;

  @override
  double get boundingLength => singleCavity.boundingLength;

  @override
  double baseArea() => _clampZero(singleCavity.baseArea() * cavityCount);

  @override
  double topArea() => _clampZero(singleCavity.topArea() * cavityCount);

  @override
  double crossSectionAreaAt(double y) =>
      _clampZero(singleCavity.crossSectionAreaAt(y) * cavityCount);

  @override
  double volumeAtHeight(double y) =>
      _clampZero(singleCavity.volumeAtHeight(y) * cavityCount);

  @override
  double wettedSurfaceAreaAt(double y) =>
      _clampZero(singleCavity.wettedSurfaceAreaAt(y) * cavityCount);

  @override
  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'cavityCount': cavityCount,
        'singleCavity': singleCavity.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiCavityMold &&
          other.singleCavity == singleCavity &&
          other.cavityCount == cavityCount;

  @override
  int get hashCode => Object.hash(shapeType, singleCavity, cavityCount);
}
