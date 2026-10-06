import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable application icon widget for Chef&Cost.
///
/// Renders the official [icon.svg] app icon asset.
class AppIcon extends StatelessWidget {
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppIcon({
    super.key,
    this.size = 48,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = SvgPicture.asset(
      'assets/images/icon.svg',
      width: size,
      height: size,
      fit: fit,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: iconWidget,
      );
    }
    return iconWidget;
  }
}

/// Backwards compatibility alias for AppIcon.
typedef AppLogo = AppIcon;

/// Refined emblem badge container for Chef&Cost icon.
class ChefAndCostBadge extends StatelessWidget {
  final double size;
  final double? iconSize;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final Color? backgroundColor;

  const ChefAndCostBadge({
    super.key,
    this.size = 44,
    this.iconSize,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? size;
    return AppIcon(
      size: effectiveIconSize,
      borderRadius: borderRadius,
    );
  }
}

/// Typographic wordmark widget for "Chef&Cost".
class ChefAndCostText extends StatelessWidget {
  final double fontSize;
  final Color? textColor;
  final Color? ampersandColor;
  final double letterSpacing;

  const ChefAndCostText({
    super.key,
    this.fontSize = 14.5,
    this.textColor,
    this.ampersandColor,
    this.letterSpacing = -0.2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedTextColor = textColor ??
        (isDark ? Colors.white : theme.colorScheme.onSurface);
    final resolvedAmpColor =
        ampersandColor ?? const Color(0xFFB88A67);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            height: 1.0,
          ),
          children: [
            TextSpan(
              text: 'Chef',
              style: TextStyle(
                fontFamily: 'Metropolis',
                fontWeight: FontWeight.w800,
                letterSpacing: letterSpacing,
                color: resolvedTextColor,
              ),
            ),
            TextSpan(
              text: '&',
              style: TextStyle(
                fontFamily: 'Butler',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: fontSize * 1.08,
                color: resolvedAmpColor,
              ),
            ),
            TextSpan(
              text: 'Cost',
              style: TextStyle(
                fontFamily: 'Metropolis',
                fontWeight: FontWeight.w800,
                letterSpacing: letterSpacing,
                color: resolvedTextColor,
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// Adaptable brand lockup widget combining [AppIcon] and [ChefAndCostText].
class ChefAndCostBrand extends StatelessWidget {
  final bool isExtended;
  final VoidCallback? onTap;
  final String? tooltip;
  final double? badgeSize;
  final double? fontSize;
  final double? compactWidth;
  final bool showTagline;

  const ChefAndCostBrand({
    super.key,
    this.isExtended = false,
    this.onTap,
    this.tooltip,
    this.badgeSize,
    this.fontSize,
    this.compactWidth,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (isExtended) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIcon(
            size: badgeSize ?? 38,
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChefAndCostText(
                fontSize: fontSize ?? 17.0,
              ),
              if (showTagline) ...[
                const SizedBox(height: 2),
                Text(
                  'KITCHEN & RECIPES',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    } else {
      content = AppIcon(
        size: badgeSize ?? 44,
      );
    }

    if (onTap != null) {
      return Tooltip(
        message: tooltip ?? 'Chef&Cost - Inicio',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: content,
            ),
          ),
        ),
      );
    }

    return content;
  }
}
