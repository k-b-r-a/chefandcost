import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable application logo widget for Chef&Cost.
///
/// Renders the vector [logo.svg] asset. If [color] is specified,
/// it tints the vector paths; otherwise, it preserves the original
/// warm culinary tones.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 40,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

/// Refined emblem badge container for Chef&Cost logo.
///
/// Wraps [AppLogo] in an elegant rounded squircle with subtle warm culinary
/// gradient/tint and delicate border styling, adapting beautifully between
/// dark and light themes.
class ChefAndCostBadge extends StatelessWidget {
  final double size;
  final double? iconSize;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final Color? backgroundColor;

  const ChefAndCostBadge({
    super.key,
    this.size = 44,
    this.iconSize,
    this.iconColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(size * 0.3);
    final effectiveIconSize = iconSize ?? (size * 0.72);

    final effectiveDecoration = BoxDecoration(
      color: backgroundColor ??
          (gradient == null
              ? (isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : null)
              : null),
      gradient: gradient ??
          (backgroundColor == null && !isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFDF9),
                    Color(0xFFF7EFE6),
                  ],
                )
              : null),
      borderRadius: r,
      border: border ??
          Border.all(
            color: const Color(0xFFB88A67).withValues(alpha: isDark ? 0.35 : 0.28),
            width: 1.2,
          ),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFFB88A67).withValues(alpha: 0.16),
              blurRadius: isDark ? 8 : 10,
              offset: const Offset(0, 3),
            ),
          ],
    );

    return Container(
      width: size,
      height: size,
      decoration: effectiveDecoration,
      alignment: Alignment.center,
      child: AppLogo(
        size: effectiveIconSize,
        color: iconColor,
      ),
    );
  }
}

/// Typographic wordmark widget for "Chef&Cost".
///
/// Features high-end bespoke typography:
/// - "Chef": Metropolis extra bold sans
/// - "&": Butler italic serif in warm culinary bronze/amber
/// - "Cost": Metropolis extra bold sans
///
/// Strictly guarantees single-line rendering without awkward wraps,
/// automatically scaling down to fit its parent constraints via [FittedBox].
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

/// Adaptable brand lockup widget combining [ChefAndCostBadge] and [ChefAndCostText].
///
/// Supports:
/// - Vertical compact mode (default, for NavigationRail) with constrained width
///   and auto-scaling typography that will never overflow or break lines.
/// - Horizontal extended mode (for wide headers, drawers, or dialogs).
/// - Clickable navigation action with tooltip and ripple ink response.
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
          ChefAndCostBadge(
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
      final effectiveCompactWidth = compactWidth ?? 72.0;
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveCompactWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChefAndCostBadge(
              size: badgeSize ?? 46,
            ),
            const SizedBox(height: 7),
            SizedBox(
              width: effectiveCompactWidth,
              child: ChefAndCostText(
                fontSize: fontSize ?? 14.5,
              ),
            ),
          ],
        ),
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
