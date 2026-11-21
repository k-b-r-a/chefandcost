import '../entities/mold_geometry.dart';

enum MoldValidationErrorCode {
  nonPositiveDimension,
  negativeBottomDimension,
  bothTopAndBottomZero,
  invalidFillRatio,
  invalidFillHeight,
  invalidSlantHeight,
  tubeExceedsOuter,
  invalidTubeHeight,
  invalidFlutingFactor,
  sphericalCapHeightExceedsRadius,
  invalidPolygonSides,
  invalidShapeFactor,
  invalidCavityCount,
  nestedMultiCavity,
  invalidPortionDimension,
  edgeTrimExceedsMold,
}

class MoldValidationError {
  final MoldValidationErrorCode code;
  final String field;
  final String? details;

  const MoldValidationError({
    required this.code,
    required this.field,
    this.details,
  });

  @override
  String toString() => 'MoldValidationError($code, $field, $details)';
}

class MoldValidationException implements Exception {
  final List<MoldValidationError> errors;

  const MoldValidationException(this.errors);

  @override
  String toString() => 'MoldValidationException(${errors.join(', ')})';
}

/// Validates physical constraints and edge-case guards for [MoldGeometry].
class MoldValidator {
  MoldValidator._();

  static void _requirePositive(
    List<MoldValidationError> errors,
    double value,
    String field,
  ) {
    if (!value.isFinite || value <= 0.0) {
      errors.add(
        MoldValidationError(
          code: MoldValidationErrorCode.nonPositiveDimension,
          field: field,
        ),
      );
    }
  }

  static List<MoldValidationError> validateMold(
    MoldGeometry mold, {
    double? fillRatio,
    double? fillHeightCm,
  }) {
    final errors = <MoldValidationError>[];

    switch (mold) {
      case CircularCylinder(:final diameter, :final height):
        _requirePositive(errors, diameter, 'diameter');
        _requirePositive(errors, height, 'height');
      case SquarePrism(:final side, :final height):
        _requirePositive(errors, side, 'side');
        _requirePositive(errors, height, 'height');
      case RectangularPrism(:final length, :final width, :final height):
        _requirePositive(errors, length, 'length');
        _requirePositive(errors, width, 'width');
        _requirePositive(errors, height, 'height');
      case CircularFrustum(
          :final bottomDiameter,
          :final topDiameter,
          :final height,
          :final slantHeight,
        ):
        if (!bottomDiameter.isFinite || bottomDiameter < 0.0) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.negativeBottomDimension,
              field: 'bottomDiameter',
            ),
          );
        }
        _requirePositive(errors, topDiameter, 'topDiameter');
        if (bottomDiameter <= 0.0 && topDiameter <= 0.0) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.bothTopAndBottomZero,
              field: 'topDiameter',
            ),
          );
        }
        if (slantHeight != null) {
          final dr = (topDiameter - bottomDiameter).abs() / 2.0;
          if (!slantHeight.isFinite || slantHeight <= dr) {
            errors.add(
              const MoldValidationError(
                code: MoldValidationErrorCode.invalidSlantHeight,
                field: 'slantHeight',
              ),
            );
          }
        } else {
          _requirePositive(errors, height, 'height');
        }
      case RectangularFrustum(
          :final bottomLength,
          :final bottomWidth,
          :final topLength,
          :final topWidth,
          :final height,
        ):
        _requirePositive(errors, bottomLength, 'bottomLength');
        _requirePositive(errors, bottomWidth, 'bottomWidth');
        _requirePositive(errors, topLength, 'topLength');
        _requirePositive(errors, topWidth, 'topWidth');
        _requirePositive(errors, height, 'height');
      case VChannelMold(
          :final bottomWidth,
          :final topWidth,
          :final length,
          :final height,
        ):
        if (!bottomWidth.isFinite || bottomWidth < 0.0) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.negativeBottomDimension,
              field: 'bottomWidth',
            ),
          );
        }
        _requirePositive(errors, topWidth, 'topWidth');
        if (bottomWidth <= 0.0 && topWidth <= 0.0) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.bothTopAndBottomZero,
              field: 'topWidth',
            ),
          );
        }
        _requirePositive(errors, length, 'length');
        _requirePositive(errors, height, 'height');
      case AnnularTubeMold(
          :final outerBottomDiameter,
          :final outerTopDiameter,
          :final tubeBottomDiameter,
          :final tubeTopDiameter,
          :final height,
          :final tubeHeight,
          :final flutingFactor,
        ):
        _requirePositive(errors, outerBottomDiameter, 'outerBottomDiameter');
        _requirePositive(errors, outerTopDiameter, 'outerTopDiameter');
        _requirePositive(errors, tubeBottomDiameter, 'tubeBottomDiameter');
        _requirePositive(errors, tubeTopDiameter, 'tubeTopDiameter');
        _requirePositive(errors, height, 'height');
        if (tubeBottomDiameter >= outerBottomDiameter) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.tubeExceedsOuter,
              field: 'tubeBottomDiameter',
            ),
          );
        }
        if (tubeTopDiameter >= outerTopDiameter) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.tubeExceedsOuter,
              field: 'tubeTopDiameter',
            ),
          );
        }
        if (tubeHeight != null &&
            (!tubeHeight.isFinite ||
                tubeHeight <= 0.0 ||
                tubeHeight > height + kMoldEpsilon)) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.invalidTubeHeight,
              field: 'tubeHeight',
            ),
          );
        }
        if (!flutingFactor.isFinite ||
            flutingFactor < 0.80 - kMoldEpsilon ||
            flutingFactor > 1.0 + kMoldEpsilon) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.invalidFlutingFactor,
              field: 'flutingFactor',
            ),
          );
        }
      case SphericalCapMold(:final diameter, :final height):
        _requirePositive(errors, diameter, 'diameter');
        _requirePositive(errors, height, 'height');
        if (diameter > 0.0 && height > (diameter / 2.0) + kMoldEpsilon) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.sphericalCapHeightExceedsRadius,
              field: 'height',
            ),
          );
        }
      case UChannelMold(:final width, :final length, :final height):
        _requirePositive(errors, width, 'width');
        _requirePositive(errors, length, 'length');
        _requirePositive(errors, height, 'height');
      case RegularPolygonMold(:final sides, :final sideLength, :final height):
        if (sides < 3) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.invalidPolygonSides,
              field: 'sides',
            ),
          );
        }
        _requirePositive(errors, sideLength, 'sideLength');
        _requirePositive(errors, height, 'height');
      case HeartShapeMold(
          :final width,
          :final length,
          :final height,
          :final shapeFactor,
        ):
        _requirePositive(errors, width, 'width');
        _requirePositive(errors, length, 'length');
        _requirePositive(errors, height, 'height');
        if (!shapeFactor.isFinite ||
            shapeFactor <= 0.0 ||
            shapeFactor > 1.0 + kMoldEpsilon) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.invalidShapeFactor,
              field: 'shapeFactor',
            ),
          );
        }
      case WaterDisplacementMold(
          :final measuredVolumeMl,
          :final height,
          :final fillCurveExponent,
        ):
        _requirePositive(errors, measuredVolumeMl, 'measuredVolumeMl');
        _requirePositive(errors, height, 'height');
        _requirePositive(errors, fillCurveExponent, 'fillCurveExponent');
      case MultiCavityMold(:final singleCavity, :final cavityCount):
        if (cavityCount < 1) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.invalidCavityCount,
              field: 'cavityCount',
            ),
          );
        }
        if (singleCavity is MultiCavityMold) {
          errors.add(
            const MoldValidationError(
              code: MoldValidationErrorCode.nestedMultiCavity,
              field: 'singleCavity',
            ),
          );
        } else {
          errors.addAll(validateMold(singleCavity));
        }
    }

    if (fillRatio != null) {
      if (!fillRatio.isFinite ||
          fillRatio <= 0.0 ||
          fillRatio > 1.0 + kMoldEpsilon) {
        errors.add(
          const MoldValidationError(
            code: MoldValidationErrorCode.invalidFillRatio,
            field: 'fillRatio',
          ),
        );
      }
    }

    if (fillHeightCm != null) {
      final hTotal = mold.totalHeight;
      if (!fillHeightCm.isFinite ||
          fillHeightCm <= 0.0 ||
          (hTotal > 0.0 && fillHeightCm > hTotal + kMoldEpsilon)) {
        errors.add(
          const MoldValidationError(
            code: MoldValidationErrorCode.invalidFillHeight,
            field: 'fillHeight',
          ),
        );
      }
    }

    return errors;
  }

  static void assertValidMold(
    MoldGeometry mold, {
    double? fillRatio,
    double? fillHeightCm,
  }) {
    final errors = validateMold(
      mold,
      fillRatio: fillRatio,
      fillHeightCm: fillHeightCm,
    );
    if (errors.isNotEmpty) {
      throw MoldValidationException(errors);
    }
  }
}
