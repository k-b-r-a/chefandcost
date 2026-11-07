import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../main.dart';

/// Notification style types for [GooeyToast].
enum GooeyToastType {
  success,
  error,
  warning,
  info,
}

/// Visual theme colors and icons for each [GooeyToastType].
class _GooeyToastPalette {
  final Color background;
  final Color accent;
  final Color textColor;
  final Color secondaryTextColor;
  final IconData icon;
  final List<Color> gradientColors;

  const _GooeyToastPalette({
    required this.background,
    required this.accent,
    required this.textColor,
    required this.secondaryTextColor,
    required this.icon,
    required this.gradientColors,
  });

  factory _GooeyToastPalette.fromType(GooeyToastType type, bool isDark) {
    switch (type) {
      case GooeyToastType.success:
        return _GooeyToastPalette(
          background: isDark ? const Color(0xFF11261B) : const Color(0xFF14532D),
          accent: isDark ? const Color(0xFF34D399) : const Color(0xFF86EFAC),
          textColor: const Color(0xFFFFFFFF),
          secondaryTextColor: const Color(0xFFE2E8F0),
          icon: Icons.check_circle_rounded,
          gradientColors: isDark
              ? [const Color(0xFF133322), const Color(0xFF0D2317)]
              : [const Color(0xFF166534), const Color(0xFF14532D)],
        );
      case GooeyToastType.error:
        return _GooeyToastPalette(
          background: isDark ? const Color(0xFF2E1215) : const Color(0xFF7F1D1D),
          accent: isDark ? const Color(0xFFF87171) : const Color(0xFFFCA5A5),
          textColor: const Color(0xFFFFFFFF),
          secondaryTextColor: const Color(0xFFFEE2E2),
          icon: Icons.error_outline_rounded,
          gradientColors: isDark
              ? [const Color(0xFF3D161A), const Color(0xFF260E11)]
              : [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
        );
      case GooeyToastType.warning:
        return _GooeyToastPalette(
          background: isDark ? const Color(0xFF2E1F0B) : const Color(0xFF7C2D12),
          accent: isDark ? const Color(0xFFFBBF24) : const Color(0xFFFDE68A),
          textColor: const Color(0xFFFFFFFF),
          secondaryTextColor: const Color(0xFFFEF3C7),
          icon: Icons.warning_amber_rounded,
          gradientColors: isDark
              ? [const Color(0xFF3D2A0E), const Color(0xFF241808)]
              : [const Color(0xFF9A3412), const Color(0xFF7C2D12)],
        );
      case GooeyToastType.info:
        return _GooeyToastPalette(
          background: isDark ? const Color(0xFF10233D) : const Color(0xFF1E3A8A),
          accent: isDark ? const Color(0xFF60A5FA) : const Color(0xFFBFDBFE),
          textColor: const Color(0xFFFFFFFF),
          secondaryTextColor: const Color(0xFFDBEAFE),
          icon: Icons.info_outline_rounded,
          gradientColors: isDark
              ? [const Color(0xFF142E4F), const Color(0xFF0C1D33)]
              : [const Color(0xFF1E40AF), const Color(0xFF1E3A8A)],
        );
    }
  }
}

/// A high-performance, organic gooey drop toast notification.
///
/// Spawns an animated gooey drop that falls from the top, impacts,
/// melts, and spreads horizontally into a toast notification.
class GooeyToast {
  GooeyToast._();

  static OverlayEntry? _currentEntry;
  static _GooeyToastState? _currentState;

  /// Shows a gooey drop toast notification.
  ///
  /// Can be called with a [context] or without one (falls back to [ChefAndCostApp.navigatorKey]).
  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    GooeyToastType type = GooeyToastType.info,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissible = true,
  }) {
    // If an existing toast is active, remove it immediately
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
      _currentState = null;
    }

    final targetContext = context ?? ChefAndCostApp.navigatorKey.currentContext;
    if (targetContext == null) return;

    final overlay = Overlay.maybeOf(targetContext, rootOverlay: true) ??
        ChefAndCostApp.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return _GooeyToastWidget(
          message: message,
          title: title,
          type: type,
          customIcon: icon,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction,
          dismissible: dismissible,
          onDismissed: () {
            try {
              entry.remove();
            } catch (_) {}
            if (_currentEntry == entry) {
              _currentEntry = null;
              _currentState = null;
            }
          },
          onRegisterState: (state) {
            _currentState = state;
          },
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Shows a success gooey toast.
  static void showSuccess(
    BuildContext? context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GooeyToastType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Shows an error gooey toast.
  static void showError(
    BuildContext? context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 4000),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GooeyToastType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Shows a warning gooey toast.
  static void showWarning(
    BuildContext? context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 3800),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GooeyToastType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Dismisses any currently active toast immediately with an exit animation.
  static void dismiss() {
    if (_currentState != null) {
      _currentState?.triggerExit();
    } else {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }
}

class _GooeyToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final GooeyToastType type;
  final IconData? customIcon;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dismissible;
  final VoidCallback onDismissed;
  final ValueChanged<_GooeyToastState> onRegisterState;

  const _GooeyToastWidget({
    required this.message,
    this.title,
    required this.type,
    this.customIcon,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.dismissible,
    required this.onDismissed,
    required this.onRegisterState,
  });

  @override
  State<_GooeyToastWidget> createState() => _GooeyToastState();
}

class _GooeyToastState extends State<_GooeyToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _exitController;
  Timer? _dismissTimer;

  double _dragOffsetY = 0.0;
  bool _isExiting = false;

  // Key phases of the gooey drop & melt entrance (0.0 to 1.0)
  // Phase 1: 0.00 -> 0.36 = Droplet falling from top
  // Phase 2: 0.36 -> 0.44 = Droplet impacts and squashes into puddle
  // Phase 3: 0.44 -> 0.85 = Puddle melts and spreads horizontally with fluid wobble
  // Phase 4: 0.65 -> 1.00 = Toast content emerges and reveals
  static const double _kFallEnd = 0.36;
  static const double _kSquashEnd = 0.44;
  static const double _kSpreadEnd = 0.85;
  static const double _kContentStart = 0.65;

  @override
  void initState() {
    super.initState();
    widget.onRegisterState(this);

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _enterController.forward().then((_) {
      if (mounted && !_isExiting && widget.duration > Duration.zero) {
        _dismissTimer = Timer(widget.duration, () {
          if (mounted && !_isExiting) {
            triggerExit();
          }
        });
      }
    });

    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });
  }

  void triggerExit() {
    if (_isExiting) return;
    _isExiting = true;
    _dismissTimer?.cancel();
    _exitController.forward();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _enterController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.dismissible || _isExiting) return;
    setState(() {
      // Elastic rubber-band resistance when dragging up or down
      _dragOffsetY += details.primaryDelta ?? 0.0;
      if (_dragOffsetY > 15.0) {
        _dragOffsetY = 15.0; // slight downward stretch resistance
      }
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!widget.dismissible || _isExiting) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY < -25.0 || velocity < -200.0) {
      triggerExit();
    } else {
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  /// High-damping fluid wobble for the horizontal spread
  static double _fluidWobble(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return 1.0 - math.exp(-5.2 * t) * math.cos(7.2 * t);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _GooeyToastPalette.fromType(widget.type, isDark);
    final icon = widget.customIcon ?? palette.icon;

    final screenWidth = mediaQuery.size.width;
    final safeTop = mediaQuery.padding.top;
    final targetY = safeTop + 14.0;
    final maxToastWidth = math.min(screenWidth - 32.0, 440.0);

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _exitController]),
        builder: (context, _) {
          final enterProgress = _enterController.value;
          final exitProgress = _exitController.value;

          // If completely exited, return empty
          if (exitProgress >= 1.0) return const SizedBox.shrink();

          // Calculate exit translations (suction/slide back up)
          final exitOffset = -120.0 * Curves.easeInBack.transform(exitProgress);
          final exitOpacity = (1.0 - exitProgress * 1.5).clamp(0.0, 1.0);
          final exitScaleX = (1.0 - 0.45 * exitProgress).clamp(0.0, 1.0);
          final exitScaleY = (1.0 + 0.25 * exitProgress).clamp(0.0, 1.5);

          // Calculate drag gooey stretch
          final dragDist = _dragOffsetY.abs();
          final dragScaleY = 1.0 + (dragDist / 120.0) * 0.25;
          final dragScaleX = (1.0 - (dragDist / 120.0) * 0.1).clamp(0.85, 1.0);

          // Phase 1 & 2: Droplet falling and impacting puddle
          if (enterProgress <= _kSquashEnd) {
            return Transform.translate(
              offset: Offset(0, exitOffset + _dragOffsetY),
              child: Opacity(
                opacity: exitOpacity,
                child: SizedBox(
                  width: screenWidth,
                  height: targetY + 60.0,
                  child: CustomPaint(
                    size: Size(screenWidth, targetY + 60.0),
                    painter: _GooeyDropPainter(
                      progress: enterProgress,
                      fallEnd: _kFallEnd,
                      squashEnd: _kSquashEnd,
                      targetY: targetY,
                      centerX: screenWidth / 2,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            );
          }

          // Phase 3 & 4: Puddle melting, spreading horizontally, and revealing toast content
          final spreadT = ((enterProgress - _kSquashEnd) / (_kSpreadEnd - _kSquashEnd)).clamp(0.0, 1.0);
          final wobbleFactor = _fluidWobble(spreadT);

          const initialPuddleWidth = 64.0;
          const initialPuddleHeight = 18.0;
          const estimatedFinalHeight = 60.0;

          final currentWidth = ui.lerpDouble(initialPuddleWidth, maxToastWidth, wobbleFactor)!;
          final currentHeight = ui.lerpDouble(initialPuddleHeight, estimatedFinalHeight, Curves.easeOutCubic.transform(spreadT))!;
          final currentRadius = ui.lerpDouble(currentHeight / 2, 20.0, Curves.easeOutQuad.transform(spreadT))!;

          // Content reveal (0.65 to 1.0)
          final contentT = ((enterProgress - _kContentStart) / (1.0 - _kContentStart)).clamp(0.0, 1.0);
          final contentOpacity = Curves.easeOut.transform(contentT);
          final iconScale = Curves.elasticOut.transform(contentT);
          final slideUpOffset = (1.0 - Curves.easeOutQuad.transform(contentT)) * 6.0;

          return Padding(
            padding: EdgeInsets.only(top: targetY),
            child: Transform.translate(
              offset: Offset(0, exitOffset + _dragOffsetY),
              child: Transform.scale(
                scaleX: exitScaleX * dragScaleX,
                scaleY: exitScaleY * dragScaleY,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: exitOpacity,
                  child: GestureDetector(
                    onVerticalDragUpdate: _handleVerticalDragUpdate,
                    onVerticalDragEnd: _handleVerticalDragEnd,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: currentWidth,
                        height: (spreadT < 1.0) ? currentHeight : null,
                        constraints: BoxConstraints(
                          minHeight: currentHeight,
                          maxWidth: maxToastWidth,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: palette.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(currentRadius),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.background.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          children: [
                            // Content inside the toast - ALWAYS present so Stack has a non-positioned child
                            ClipRRect(
                              borderRadius: BorderRadius.circular(currentRadius),
                              child: Opacity(
                                opacity: contentOpacity.clamp(0.0, 1.0),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 10.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Organic bouncy icon
                                      Transform.scale(
                                        scale: iconScale,
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: palette.accent.withValues(alpha: 0.5),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 20,
                                            color: palette.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Text message & optional title
                                      Expanded(
                                        child: Transform.translate(
                                          offset: Offset(0, slideUpOffset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (widget.title != null && widget.title!.isNotEmpty) ...[
                                                Text(
                                                  widget.title!,
                                                  style: theme.textTheme.labelLarge?.copyWith(
                                                    color: palette.textColor,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                              ],
                                              Text(
                                                widget.message,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: palette.secondaryTextColor,
                                                  fontSize: 13.5,
                                                  height: 1.25,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Optional action button
                                      if (widget.actionLabel != null) ...[
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () {
                                            widget.onAction?.call();
                                            triggerExit();
                                          },
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                                            foregroundColor: palette.accent,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            widget.actionLabel!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Dismiss close button
                                      if (widget.dismissible) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          color: Colors.white.withValues(alpha: 0.7),
                                          splashRadius: 18,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          onPressed: triggerExit,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Top surface specular liquid meniscus
                            Positioned(
                              top: 0,
                              left: 14,
                              right: 14,
                              height: 1.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.45),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
  }
}

/// Custom painter for the liquid droplet falling and squashing into a puddle.
class _GooeyDropPainter extends CustomPainter {
  final double progress;
  final double fallEnd;
  final double squashEnd;
  final double targetY;
  final double centerX;
  final _GooeyToastPalette palette;

  _GooeyDropPainter({
    required this.progress,
    required this.fallEnd,
    required this.squashEnd,
    required this.targetY,
    required this.centerX,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= fallEnd) {
      _paintFallingDroplet(canvas);
    } else {
      _paintSquashingPuddle(canvas);
    }
  }

  /// Draws the viscous droplet falling downwards with gravitational acceleration and teardrop stretch.
  void _paintFallingDroplet(Canvas canvas) {
    final t = (progress / fallEnd).clamp(0.0, 1.0);
    final curve = Curves.easeInCubic.transform(t);

    const initialY = -45.0;
    final destinationY = targetY + 22.0;
    final currentY = ui.lerpDouble(initialY, destinationY, curve)!;

    // Fluid teardrop dimensions: elongates as velocity increases
    final width = ui.lerpDouble(24.0, 18.0, t)!;
    final height = ui.lerpDouble(32.0, 52.0, t)!;
    final bulbRadius = width / 2;

    final dropRect = Rect.fromCenter(
      center: Offset(centerX, currentY),
      width: width,
      height: height,
    );

    // Droplet shadow
    if (t > 0.05) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.1, 10.0 * t));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, destinationY + 6.0),
          width: width * (0.5 + 0.5 * t),
          height: math.max(0.5, 6.0 * t),
        ),
        shadowPaint,
      );
    }

    // Droplet path (rounded bulb at bottom, tapering to rounded apex at top)
    final path = Path();
    final apexY = dropRect.top;
    final bulbCenterY = dropRect.bottom - bulbRadius;

    path.moveTo(centerX, apexY);
    // Left curve from apex to bulb
    path.cubicTo(
      centerX - width * 0.15,
      apexY + height * 0.35,
      centerX - bulbRadius,
      bulbCenterY - bulbRadius * 0.4,
      centerX - bulbRadius,
      bulbCenterY,
    );
    // Bottom bulb arc: starting at left (pi radians) and sweeping pi radians around bottom to right
    path.arcTo(
      Rect.fromCircle(center: Offset(centerX, bulbCenterY), radius: bulbRadius),
      math.pi,
      math.pi,
      false,
    );
    // Right curve from bulb back to apex
    path.cubicTo(
      centerX + bulbRadius,
      bulbCenterY - bulbRadius * 0.4,
      centerX + width * 0.15,
      apexY + height * 0.35,
      centerX,
      apexY,
    );
    path.close();

    // Fill with liquid gradient
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX, dropRect.top),
        Offset(centerX, dropRect.bottom),
        palette.gradientColors,
      );
    canvas.drawPath(path, fillPaint);

    // Specular glossy reflection on droplet
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - width * 0.22, bulbCenterY - bulbRadius * 0.2),
        width: width * 0.28,
        height: height * 0.22,
      ),
      glossPaint,
    );
  }

  /// Draws the hydrodynamic squash upon impact before spreading horizontally.
  void _paintSquashingPuddle(Canvas canvas) {
    final t = ((progress - fallEnd) / (squashEnd - fallEnd)).clamp(0.0, 1.0);
    final squashCurve = Curves.easeOutQuad.transform(t);

    final width = ui.lerpDouble(18.0, 64.0, squashCurve)!;
    final height = ui.lerpDouble(52.0, 18.0, squashCurve)!;
    final currentY = targetY + 22.0 - (height / 2);

    final puddleRect = Rect.fromCenter(
      center: Offset(centerX, currentY + height / 2),
      width: width,
      height: height,
    );

    // Impact shadow spreading out
    final shadowPaint = Paint()
      ..color = palette.background.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, targetY + 22.0),
        width: width * 1.1,
        height: height * 0.9,
      ),
      shadowPaint,
    );

    // Puddle shape (organic rounded rectangle / oval)
    final rrect = RRect.fromRectAndRadius(
      puddleRect,
      Radius.circular(height / 2),
    );

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX, puddleRect.top),
        Offset(centerX, puddleRect.bottom),
        palette.gradientColors,
      );
    canvas.drawRRect(rrect, fillPaint);

    // Specular highlight on top of squashed puddle
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, puddleRect.top + height * 0.25),
          width: width * 0.5,
          height: height * 0.25,
        ),
        Radius.circular(height * 0.2),
      ),
      glossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GooeyDropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.palette != palette ||
        oldDelegate.targetY != targetY;
  }
}
