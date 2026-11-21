import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../utils/recipe_utils.dart';
import '../../domain/entities/mold_geometry.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/entities/portion_yield.dart';
import '../../domain/services/geometry_engine.dart';

/// Tiny contextual schematic icon inside [MoldDimensionForm] illustrating key measurements.
class MoldShapeSchematicPainter extends CustomPainter {
  final MoldShapeType shapeType;
  final Color primaryColor;
  final Color accentColor;
  final Color onSurfaceColor;

  const MoldShapeSchematicPainter({
    required this.shapeType,
    required this.primaryColor,
    required this.accentColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final stroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final dimPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final pad = 5.0;
    final rect = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );

    final effectiveType = shapeType == MoldShapeType.multiCavity
        ? MoldShapeType.circularCylinder
        : shapeType;

    switch (effectiveType) {
      case MoldShapeType.circularCylinder:
      case MoldShapeType.waterDisplacement:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        canvas.drawLine(
          Offset(rect.left, rect.top - 2.5),
          Offset(rect.right, rect.top - 2.5),
          dimPaint,
        );
        break;
      case MoldShapeType.squarePrism:
        final side = math.min(rect.width, rect.height);
        final sq = Rect.fromCenter(
          center: rect.center,
          width: side,
          height: side,
        );
        canvas.drawRect(sq, fill);
        canvas.drawRect(sq, stroke);
        break;
      case MoldShapeType.rectangularPrism:
        final r = Rect.fromLTWH(
          rect.left,
          rect.top + rect.height * 0.15,
          rect.width,
          rect.height * 0.7,
        );
        canvas.drawRect(r, fill);
        canvas.drawRect(r, stroke);
        break;
      case MoldShapeType.circularFrustum:
      case MoldShapeType.rectangularFrustum:
        final p = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right - rect.width * 0.18, rect.bottom)
          ..lineTo(rect.left + rect.width * 0.18, rect.bottom)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.vChannel:
        final p = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.center.dx + 4, rect.bottom)
          ..lineTo(rect.center.dx - 4, rect.bottom)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.annularTube:
        final outer = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right - rect.width * 0.12, rect.bottom)
          ..lineTo(rect.left + rect.width * 0.12, rect.bottom)
          ..close();
        canvas.drawPath(outer, fill);
        canvas.drawPath(outer, stroke);
        final tubeW = rect.width * 0.24;
        final tube = Rect.fromLTWH(
          rect.center.dx - tubeW / 2,
          rect.top,
          tubeW,
          rect.height,
        );
        canvas.drawRect(
          tube,
          Paint()..color = onSurfaceColor.withValues(alpha: 0.15),
        );
        canvas.drawRect(tube, stroke);
        break;
      case MoldShapeType.sphericalCap:
        final arcRect = Rect.fromLTRB(
          rect.left,
          rect.top - rect.height,
          rect.right,
          rect.bottom,
        );
        final p = Path()
          ..moveTo(rect.left, rect.top)
          ..arcTo(arcRect, math.pi, -math.pi, false)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.uChannel:
        final p = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.left, rect.center.dy)
          ..arcToPoint(
            Offset(rect.right, rect.center.dy),
            radius: Radius.circular(rect.width / 2),
            clockwise: false,
          )
          ..lineTo(rect.right, rect.top);
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.regularPolygon:
        final p = Path();
        final r = math.min(rect.width, rect.height) * 0.48;
        for (var i = 0; i < 6; i++) {
          final angle = (math.pi / 3) * i - math.pi / 2;
          final pt = Offset(
            rect.center.dx + r * math.cos(angle),
            rect.center.dy + r * math.sin(angle),
          );
          if (i == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        p.close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.heartShape:
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        final w = rect.width * 0.45;
        final h = rect.height * 0.45;
        final p = Path()
          ..moveTo(cx, cy + h)
          ..cubicTo(cx - w * 1.4, cy + h * 0.2, cx - w, cy - h, cx, cy - h * 0.25)
          ..cubicTo(cx + w, cy - h, cx + w * 1.4, cy + h * 0.2, cx, cy + h)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
      case MoldShapeType.multiCavity:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant MoldShapeSchematicPainter oldDelegate) =>
      oldDelegate.shapeType != shapeType ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
}

/// 2D side cross-section comparing Source and Target mold profiles + fill heights to a shared scale.
class MoldSideCrossSectionPainter extends CustomPainter {
  final MoldGeometry sourceMold;
  final double sourceFillRatio;
  final MoldGeometry targetMold;
  final double targetFillRatio;
  final String sourceLabel;
  final String targetLabel;
  final Color sourceColor;
  final Color targetColor;
  final Color surfaceColor;
  final Color textColor;

  const MoldSideCrossSectionPainter({
    required this.sourceMold,
    required this.sourceFillRatio,
    required this.targetMold,
    required this.targetFillRatio,
    required this.sourceLabel,
    required this.targetLabel,
    required this.sourceColor,
    required this.targetColor,
    required this.surfaceColor,
    required this.textColor,
  });

  double _visualWidth(MoldGeometry m) {
    final g = m is MultiCavityMold ? m.singleCavity : m;
    final w = g.boundingWidth;
    return (w.isFinite && w > 0.0) ? w : 10.0;
  }

  double _visualHeight(MoldGeometry m) {
    final h = m.totalHeight;
    return (h.isFinite && h > 0.0) ? h : 5.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final maxW = math.max(_visualWidth(sourceMold), _visualWidth(targetMold));
    final maxH = math.max(_visualHeight(sourceMold), _visualHeight(targetMold));
    if (maxW <= 0 || maxH <= 0) return;

    const topPad = 24.0;
    const bottomPad = 28.0;
    const sidePad = 14.0;
    const gap = 22.0;

    final slotWidth = (size.width - sidePad * 2 - gap) / 2.0;
    final availHeight = math.max(20.0, size.height - topPad - bottomPad);
    final pxPerCm = math.min(slotWidth / maxW, availHeight / maxH);

    final baselineY = size.height - bottomPad;

    _drawSingleMold(
      canvas: canvas,
      centerX: sidePad + slotWidth / 2.0,
      baselineY: baselineY,
      pxPerCm: pxPerCm,
      mold: sourceMold,
      fillRatio: sourceFillRatio,
      label: sourceLabel,
      color: sourceColor,
    );

    _drawSingleMold(
      canvas: canvas,
      centerX: sidePad + slotWidth + gap + slotWidth / 2.0,
      baselineY: baselineY,
      pxPerCm: pxPerCm,
      mold: targetMold,
      fillRatio: targetFillRatio,
      label: targetLabel,
      color: targetColor,
    );
  }

  void _drawSingleMold({
    required Canvas canvas,
    required double centerX,
    required double baselineY,
    required double pxPerCm,
    required MoldGeometry mold,
    required double fillRatio,
    required String label,
    required Color color,
  }) {
    final cavityCount = mold is MultiCavityMold ? mold.cavityCount : 1;
    final inner = mold is MultiCavityMold ? mold.singleCavity : mold;
    final hCm = _visualHeight(inner);
    final wCm = _visualWidth(inner);
    final hPx = hCm * pxPerCm;
    final topY = baselineY - hPx;

    final outerPath = _buildProfilePath(
      inner: inner,
      centerX: centerX,
      baselineY: baselineY,
      pxPerCm: pxPerCm,
    );

    // Subtle pan interior fill
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );

    // Batter fill clipped to exact mold shape
    final clampedRatio = fillRatio.clamp(0.0, 1.0);
    final fillHeightPx = hPx * clampedRatio;
    final fillTopY = baselineY - fillHeightPx;

    canvas.save();
    canvas.clipPath(outerPath);
    canvas.drawRect(
      Rect.fromLTRB(
        centerX - wCm * pxPerCm,
        fillTopY,
        centerX + wCm * pxPerCm,
        baselineY + 2,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.34)
        ..style = PaintingStyle.fill,
    );

    // Meniscus highlight line
    canvas.drawLine(
      Offset(centerX - wCm * pxPerCm, fillTopY),
      Offset(centerX + wCm * pxPerCm, fillTopY),
      Paint()
        ..color = color
        ..strokeWidth = 1.6,
    );
    canvas.restore();

    // Inner central tube cutout if AnnularTubeMold
    if (inner is AnnularTubeMold) {
      final tubeH = math.min(inner.effectiveTubeHeight, hCm) * pxPerCm;
      final tubeTopW = inner.tubeTopDiameter * pxPerCm;
      final tubeBotW = inner.tubeBottomDiameter * pxPerCm;
      final tubeTopY = baselineY - tubeH;
      final tubePath = Path()
        ..moveTo(centerX - tubeTopW / 2, tubeTopY)
        ..lineTo(centerX + tubeTopW / 2, tubeTopY)
        ..lineTo(centerX + tubeBotW / 2, baselineY)
        ..lineTo(centerX - tubeBotW / 2, baselineY)
        ..close();
      canvas.drawPath(
        tubePath,
        Paint()
          ..color = surfaceColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        tubePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Mold walls outline
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );

    // Top label + multi-cavity badge
    final badgeText = cavityCount > 1 ? '$label (×$cavityCount)' : label;
    _drawCenteredText(
      canvas: canvas,
      text: badgeText,
      center: Offset(centerX, topY - 12),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );

    // Bottom dimension callout
    final hFillCm = GeometryEngine.effectiveFillHeight(mold, clampedRatio);
    final dimText =
        '${RecipeUtils.formatNumber(wCm, decimalDigits: 1, trimTrailingZeros: true)}×${RecipeUtils.formatNumber(hCm, decimalDigits: 1, trimTrailingZeros: true)} cm (h=${RecipeUtils.formatNumber(hFillCm, decimalDigits: 1, trimTrailingZeros: true)})';
    _drawCenteredText(
      canvas: canvas,
      text: dimText,
      center: Offset(centerX, baselineY + 14),
      style: TextStyle(
        color: textColor.withValues(alpha: 0.78),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Path _buildProfilePath({
    required MoldGeometry inner,
    required double centerX,
    required double baselineY,
    required double pxPerCm,
  }) {
    final hPx = _visualHeight(inner) * pxPerCm;
    final topY = baselineY - hPx;

    switch (inner) {
      case CircularFrustum(:final bottomDiameter, :final topDiameter):
        final bw = bottomDiameter * pxPerCm;
        final tw = topDiameter * pxPerCm;
        return Path()
          ..moveTo(centerX - tw / 2, topY)
          ..lineTo(centerX + tw / 2, topY)
          ..lineTo(centerX + bw / 2, baselineY)
          ..lineTo(centerX - bw / 2, baselineY)
          ..close();
      case RectangularFrustum(:final bottomWidth, :final topWidth):
        final bw = bottomWidth * pxPerCm;
        final tw = topWidth * pxPerCm;
        return Path()
          ..moveTo(centerX - tw / 2, topY)
          ..lineTo(centerX + tw / 2, topY)
          ..lineTo(centerX + bw / 2, baselineY)
          ..lineTo(centerX - bw / 2, baselineY)
          ..close();
      case VChannelMold(:final bottomWidth, :final topWidth):
        final bw = bottomWidth * pxPerCm;
        final tw = topWidth * pxPerCm;
        return Path()
          ..moveTo(centerX - tw / 2, topY)
          ..lineTo(centerX + tw / 2, topY)
          ..lineTo(centerX + bw / 2, baselineY)
          ..lineTo(centerX - bw / 2, baselineY)
          ..close();
      case AnnularTubeMold(:final outerBottomDiameter, :final outerTopDiameter):
        final bw = outerBottomDiameter * pxPerCm;
        final tw = outerTopDiameter * pxPerCm;
        return Path()
          ..moveTo(centerX - tw / 2, topY)
          ..lineTo(centerX + tw / 2, topY)
          ..lineTo(centerX + bw / 2, baselineY)
          ..lineTo(centerX - bw / 2, baselineY)
          ..close();
      case SphericalCapMold(:final diameter, :final height):
        final rPx = (diameter / 2.0) * pxPerCm;
        final topHalfW = inner.boundingWidth * 0.5 * pxPerCm;
        final circleCenterY = baselineY - rPx;
        final p = Path()..moveTo(centerX - topHalfW, topY);
        if (height <= diameter / 2.0 + 1e-6) {
          final oval = Rect.fromCircle(
            center: Offset(centerX, circleCenterY),
            radius: rPx,
          );
          final startAngle = math.atan2(topY - circleCenterY, -topHalfW);
          final endAngle = math.atan2(topY - circleCenterY, topHalfW);
          var sweep = endAngle - startAngle;
          if (sweep < 0) sweep += 2 * math.pi;
          // Trace bottom arc from left rim down through pole to right rim
          final bottomSweep = -(2 * math.pi - sweep);
          p.arcTo(oval, startAngle, sweep > math.pi ? sweep : bottomSweep, false);
        } else {
          p
            ..lineTo(centerX - topHalfW, baselineY)
            ..lineTo(centerX + topHalfW, baselineY)
            ..lineTo(centerX + topHalfW, topY);
        }
        p.close();
        return p;
      case UChannelMold(:final width):
        final wPx = width * pxPerCm;
        final rPx = wPx / 2.0;
        final curveStartY = math.max(topY, baselineY - rPx);
        return Path()
          ..moveTo(centerX - wPx / 2, topY)
          ..lineTo(centerX - wPx / 2, curveStartY)
          ..arcToPoint(
            Offset(centerX + wPx / 2, curveStartY),
            radius: Radius.circular(rPx),
            clockwise: false,
          )
          ..lineTo(centerX + wPx / 2, topY)
          ..close();
      default:
        final wPx = _visualWidth(inner) * pxPerCm;
        return Path()
          ..addRect(
            Rect.fromLTWH(centerX - wPx / 2, topY, wPx, hPx),
          );
    }
  }

  void _drawCenteredText({
    required Canvas canvas,
    required String text,
    required Offset center,
    required TextStyle style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant MoldSideCrossSectionPainter oldDelegate) {
    return oldDelegate.sourceMold != sourceMold ||
        oldDelegate.sourceFillRatio != sourceFillRatio ||
        oldDelegate.targetMold != targetMold ||
        oldDelegate.targetFillRatio != targetFillRatio ||
        oldDelegate.sourceColor != sourceColor ||
        oldDelegate.targetColor != targetColor;
  }
}

/// 2D top-down mold silhouette overlaying exact radial, concentric, grid, or linear cuts.
class MoldTopDownCutPainter extends CustomPainter {
  final MoldGeometry mold;
  final PortionYieldResult? yieldResult;
  final Color primaryColor;
  final Color secondaryColor;
  final Color wasteColor;
  final Color surfaceColor;

  const MoldTopDownCutPainter({
    required this.mold,
    required this.yieldResult,
    required this.primaryColor,
    required this.secondaryColor,
    required this.wasteColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final inner = mold is MultiCavityMold ? (mold as MultiCavityMold).singleCavity : mold;
    final panL = (inner.boundingLength > 0 && inner.boundingLength.isFinite)
        ? inner.boundingLength
        : 20.0;
    final panW = (inner.boundingWidth > 0 && inner.boundingWidth.isFinite)
        ? inner.boundingWidth
        : 20.0;

    const pad = 16.0;
    final availW = math.max(10.0, size.width - pad * 2);
    final availH = math.max(10.0, size.height - pad * 2);
    final scale = math.min(availW / panL, availH / panW);

    final drawW = panL * scale;
    final drawH = panW * scale;
    final origin = Offset(
      (size.width - drawW) / 2.0,
      (size.height - drawH) / 2.0,
    );
    final bounds = Rect.fromLTWH(origin.dx, origin.dy, drawW, drawH);

    final panPath = _buildTopPath(inner, bounds, scale);

    // Base pan fill
    canvas.drawPath(
      panPath,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );

    final yr = yieldResult;
    if (yr != null && yr.fullPortions > 0) {
      canvas.save();
      canvas.clipPath(panPath);

      switch (yr.strategy) {
        case CutStrategyType.radial:
          _paintRadial(canvas, inner, bounds, scale, yr);
          break;
        case CutStrategyType.concentric:
          _paintConcentric(canvas, bounds, scale, yr);
          break;
        case CutStrategyType.grid:
          _paintGrid(canvas, bounds, scale, yr);
          break;
        case CutStrategyType.linear:
          _paintLinear(canvas, bounds, scale, yr);
          break;
      }

      canvas.restore();
    }

    // Inner tube mask for annular molds
    if (inner is AnnularTubeMold) {
      final tubeR = (inner.tubeTopDiameter * 0.5) * scale;
      if (tubeR > 0) {
        canvas.drawCircle(
          bounds.center,
          tubeR,
          Paint()
            ..color = surfaceColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          bounds.center,
          tubeR,
          Paint()
            ..color = primaryColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    // Pan outline
    canvas.drawPath(
      panPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  Path _buildTopPath(MoldGeometry inner, Rect bounds, double scale) {
    switch (inner) {
      case CircularCylinder() ||
          CircularFrustum() ||
          AnnularTubeMold() ||
          SphericalCapMold() ||
          WaterDisplacementMold():
        final r = math.min(bounds.width, bounds.height) / 2.0;
        return Path()..addOval(Rect.fromCircle(center: bounds.center, radius: r));
      case RegularPolygonMold(:final sides):
        final n = math.max(3, sides);
        final r = math.min(bounds.width, bounds.height) / 2.0;
        final p = Path();
        for (var i = 0; i < n; i++) {
          final a = (2 * math.pi * i / n) - math.pi / 2;
          final pt = Offset(
            bounds.center.dx + r * math.cos(a),
            bounds.center.dy + r * math.sin(a),
          );
          if (i == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        p.close();
        return p;
      case HeartShapeMold():
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;
        final w = bounds.width * 0.48;
        final h = bounds.height * 0.48;
        return Path()
          ..moveTo(cx, cy + h)
          ..cubicTo(cx - w * 1.4, cy + h * 0.2, cx - w, cy - h, cx, cy - h * 0.25)
          ..cubicTo(cx + w, cy - h, cx + w * 1.4, cy + h * 0.2, cx, cy + h)
          ..close();
      default:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
          );
    }
  }

  void _paintRadial(
    Canvas canvas,
    MoldGeometry inner,
    Rect bounds,
    double scale,
    PortionYieldResult yr,
  ) {
    final slices = yr.fullPortions;
    final outerR = math.max(bounds.width, bounds.height) * 0.65;
    final innerR =
        inner is AnnularTubeMold ? (inner.tubeTopDiameter * 0.5) * scale : 0.0;

    canvas.drawRect(
      bounds,
      Paint()..color = primaryColor.withValues(alpha: 0.14),
    );

    final cutPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;

    for (var i = 0; i < slices; i++) {
      final angle = (2 * math.pi * i / slices) - math.pi / 2;
      final start = Offset(
        bounds.center.dx + innerR * math.cos(angle),
        bounds.center.dy + innerR * math.sin(angle),
      );
      final end = Offset(
        bounds.center.dx + outerR * math.cos(angle),
        bounds.center.dy + outerR * math.sin(angle),
      );
      canvas.drawLine(start, end, cutPaint);
    }
  }

  void _paintConcentric(
    Canvas canvas,
    Rect bounds,
    double scale,
    PortionYieldResult yr,
  ) {
    final outerR = math.min(bounds.width, bounds.height) / 2.0;
    final innerR = ((yr.innerDiameterCm ?? 10.0) / 2.0) * scale;
    final innerSlices = math.max(1, yr.innerPortions ?? 1);
    final outerSlices = math.max(1, yr.outerPortions ?? 1);

    canvas.drawCircle(
      bounds.center,
      outerR,
      Paint()..color = primaryColor.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      bounds.center,
      innerR,
      Paint()..color = secondaryColor.withValues(alpha: 0.25),
    );

    final cutPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;

    canvas.drawCircle(
      bounds.center,
      innerR,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    for (var i = 0; i < innerSlices; i++) {
      final angle = (2 * math.pi * i / innerSlices) - math.pi / 2;
      canvas.drawLine(
        bounds.center,
        Offset(
          bounds.center.dx + innerR * math.cos(angle),
          bounds.center.dy + innerR * math.sin(angle),
        ),
        cutPaint,
      );
    }

    for (var i = 0; i < outerSlices; i++) {
      final angle = (2 * math.pi * i / outerSlices) - math.pi / 2;
      canvas.drawLine(
        Offset(
          bounds.center.dx + innerR * math.cos(angle),
          bounds.center.dy + innerR * math.sin(angle),
        ),
        Offset(
          bounds.center.dx + outerR * 1.15 * math.cos(angle),
          bounds.center.dy + outerR * 1.15 * math.sin(angle),
        ),
        cutPaint,
      );
    }
  }

  void _paintGrid(
    Canvas canvas,
    Rect bounds,
    double scale,
    PortionYieldResult yr,
  ) {
    // Background tinted as waste (merma); each valid cut piece fills over it
    canvas.drawRect(
      bounds,
      Paint()..color = wasteColor.withValues(alpha: 0.18),
    );

    final pieceFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final pieceStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (final r in yr.rects) {
      final rect = Rect.fromLTWH(
        bounds.left + r.x * scale,
        bounds.top + r.y * scale,
        r.width * scale,
        r.height * scale,
      );
      canvas.drawRect(rect, pieceFill);
      canvas.drawRect(rect, pieceStroke);
    }

    // Edge trim guide
    if (yr.edgeTrimCm > 0) {
      final trimPx = yr.edgeTrimCm * scale;
      final trimPaint = Paint()
        ..color = wasteColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      if (yr.isCircularPan) {
        final usableR =
            math.max(0.0, (math.min(bounds.width, bounds.height) / 2) - trimPx);
        canvas.drawCircle(bounds.center, usableR, trimPaint);
      } else {
        final innerRect = bounds.deflate(trimPx);
        if (innerRect.width > 0 && innerRect.height > 0) {
          canvas.drawRect(innerRect, trimPaint);
        }
      }
    }
  }

  void _paintLinear(
    Canvas canvas,
    Rect bounds,
    double scale,
    PortionYieldResult yr,
  ) {
    canvas.drawRect(
      bounds,
      Paint()..color = wasteColor.withValues(alpha: 0.18),
    );

    final sliceThickness = yr.sliceThicknessCm ?? 2.0;
    final endTrim = yr.endTrimCm;
    final slices = yr.fullPortions;

    final startX = bounds.left + endTrim * scale;
    final sliceW = sliceThickness * scale;
    final usedRect = Rect.fromLTWH(
      startX,
      bounds.top,
      slices * sliceW,
      bounds.height,
    );

    canvas.drawRect(
      usedRect,
      Paint()..color = primaryColor.withValues(alpha: 0.20),
    );

    final cutPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;

    for (var i = 0; i <= slices; i++) {
      final x = startX + i * sliceW;
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.bottom),
        cutPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MoldTopDownCutPainter oldDelegate) {
    return oldDelegate.mold != mold ||
        oldDelegate.yieldResult != yieldResult ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.wasteColor != wasteColor;
  }
}
