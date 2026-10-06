import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:recipetools/widgets/app_icon_svg_data.dart';

/// Palette defining the 3 layers of the official Chef&Cost icon:
/// - [baseColor]: Replaces the deep rich base / silhouette (#6B3208)
/// - [midColor]: Replaces the utensils & mid accents (#B88A67)
/// - [highlightColor]: Replaces the flame & hat highlights (#EACCA6)
class AppIconThemePalette {
  final Color baseColor;
  final Color midColor;
  final Color highlightColor;

  const AppIconThemePalette({
    required this.baseColor,
    required this.midColor,
    required this.highlightColor,
  });

  /// The original brand palette (warm roasted chocolate, caramel, and cream champagne).
  static const AppIconThemePalette original = AppIconThemePalette(
    baseColor: Color(0xFF6B3208),
    midColor: Color(0xFFB88A67),
    highlightColor: Color(0xFFEACCA6),
  );

  // Preset Handcrafted Palettes for Light & Dark Modes:
  static const AppIconThemePalette deepPurpleLight = AppIconThemePalette(
    baseColor: Color(0xFF3C1361),
    midColor: Color(0xFF8338EC),
    highlightColor: Color(0xFFE2D4F7),
  );
  static const AppIconThemePalette deepPurpleDark = AppIconThemePalette(
    baseColor: Color(0xFF240B3B),
    midColor: Color(0xFF9D4EDD),
    highlightColor: Color(0xFFF3EAFF),
  );

  static const AppIconThemePalette blueLight = AppIconThemePalette(
    baseColor: Color(0xFF0F3261),
    midColor: Color(0xFF2563EB),
    highlightColor: Color(0xFFBFDBFE),
  );
  static const AppIconThemePalette blueDark = AppIconThemePalette(
    baseColor: Color(0xFF0A1F3D),
    midColor: Color(0xFF3B82F6),
    highlightColor: Color(0xFFDBEAFE),
  );

  static const AppIconThemePalette tealLight = AppIconThemePalette(
    baseColor: Color(0xFF07433E),
    midColor: Color(0xFF0D9488),
    highlightColor: Color(0xFF99F6E4),
  );
  static const AppIconThemePalette tealDark = AppIconThemePalette(
    baseColor: Color(0xFF042A27),
    midColor: Color(0xFF14B8A6),
    highlightColor: Color(0xFFCCFBF1),
  );

  static const AppIconThemePalette greenLight = AppIconThemePalette(
    baseColor: Color(0xFF14471B),
    midColor: Color(0xFF16A34A),
    highlightColor: Color(0xFFBBF7D0),
  );
  static const AppIconThemePalette greenDark = AppIconThemePalette(
    baseColor: Color(0xFF0B2D11),
    midColor: Color(0xFF22C55E),
    highlightColor: Color(0xFFDCFCE7),
  );

  static const AppIconThemePalette amberLight = AppIconThemePalette(
    baseColor: Color(0xFF5C3204),
    midColor: Color(0xFFC67C13),
    highlightColor: Color(0xFFFDE68A),
  );
  static const AppIconThemePalette amberDark = AppIconThemePalette(
    baseColor: Color(0xFF3B1E01),
    midColor: Color(0xFFE0921B),
    highlightColor: Color(0xFFFEF3C7),
  );

  static const AppIconThemePalette orangeLight = AppIconThemePalette(
    baseColor: Color(0xFF6B3208),
    midColor: Color(0xFFB88A67),
    highlightColor: Color(0xFFEACCA6),
  );
  static const AppIconThemePalette orangeDark = AppIconThemePalette(
    baseColor: Color(0xFF4A1F02),
    midColor: Color(0xFFC97A3E),
    highlightColor: Color(0xFFF5DCBE),
  );

  static const AppIconThemePalette redLight = AppIconThemePalette(
    baseColor: Color(0xFF5C0D15),
    midColor: Color(0xFFDC2626),
    highlightColor: Color(0xFFFECACA),
  );
  static const AppIconThemePalette redDark = AppIconThemePalette(
    baseColor: Color(0xFF3D070D),
    midColor: Color(0xFFEF4444),
    highlightColor: Color(0xFFFEE2E2),
  );

  static const AppIconThemePalette pinkLight = AppIconThemePalette(
    baseColor: Color(0xFF5B1138),
    midColor: Color(0xFFDB2777),
    highlightColor: Color(0xFFFBCFE8),
  );
  static const AppIconThemePalette pinkDark = AppIconThemePalette(
    baseColor: Color(0xFF3B0923),
    midColor: Color(0xFFF43F5E),
    highlightColor: Color(0xFFFCE7F3),
  );

  /// Converts a [Color] into a 6-digit hex string (#RRGGBB).
  static String colorToHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = (color.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = (color.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b';
  }

  /// Dynamically computes a balanced 3-color palette for any arbitrary HSL color.
  static AppIconThemePalette dynamicPalette(HSLColor hsl, bool isDark) {
    final h = hsl.hue;
    final s = hsl.saturation;
    if (!isDark) {
      final base = HSLColor.fromAHSL(1.0, h, (s * 0.9).clamp(0.4, 0.9), 0.18).toColor();
      final mid = HSLColor.fromAHSL(1.0, h, (s * 0.85).clamp(0.4, 0.85), 0.45).toColor();
      final highlight = HSLColor.fromAHSL(1.0, h, (s * 0.4).clamp(0.15, 0.5), 0.86).toColor();
      return AppIconThemePalette(
        baseColor: base,
        midColor: mid,
        highlightColor: highlight,
      );
    } else {
      final base = HSLColor.fromAHSL(1.0, h, (s * 0.95).clamp(0.4, 0.95), 0.11).toColor();
      final mid = HSLColor.fromAHSL(1.0, h, (s * 0.85).clamp(0.4, 0.9), 0.55).toColor();
      final highlight = HSLColor.fromAHSL(1.0, h, (s * 0.35).clamp(0.15, 0.45), 0.92).toColor();
      return AppIconThemePalette(
        baseColor: base,
        midColor: mid,
        highlightColor: highlight,
      );
    }
  }

  /// Automatically matches the best palette based on active [ThemeData].
  static AppIconThemePalette fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark ||
        theme.colorScheme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    final hue = hsl.hue;

    if (hue >= 355 || hue < 18) {
      return isDark ? redDark : redLight;
    } else if (hue >= 18 && hue < 38) {
      return isDark ? orangeDark : orangeLight;
    } else if (hue >= 38 && hue < 65) {
      return isDark ? amberDark : amberLight;
    } else if (hue >= 65 && hue < 150) {
      return isDark ? greenDark : greenLight;
    } else if (hue >= 150 && hue < 192) {
      return isDark ? tealDark : tealLight;
    } else if (hue >= 192 && hue < 240) {
      return isDark ? blueDark : blueLight;
    } else if (hue >= 240 && hue < 295) {
      return isDark ? deepPurpleDark : deepPurpleLight;
    } else if (hue >= 295 && hue < 355) {
      return isDark ? pinkDark : pinkLight;
    }

    return dynamicPalette(hsl, isDark);
  }

  /// Substitutes the original SVG color codes with this palette's colors.
  String applyToSvg(String template) {
    final baseHex = colorToHex(baseColor);
    final midHex = colorToHex(midColor);
    final highlightHex = colorToHex(highlightColor);

    return template
        .replaceAll('#6B3208', baseHex)
        .replaceAll('#6b3208', baseHex)
        .replaceAll('#B88A67', midHex)
        .replaceAll('#b88a67', midHex)
        .replaceAll('#EACCA6', highlightHex)
        .replaceAll('#eacca6', highlightHex);
  }
}

/// Reusable application icon widget for Chef&Cost.
///
/// Dynamically updates its vector colors to match the active application theme
/// (both seed accent colors and light/dark modes).
class AppIcon extends StatelessWidget {
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool adaptToTheme;
  final AppIconThemePalette? customPalette;

  const AppIcon({
    super.key,
    this.size = 48,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.adaptToTheme = true,
    this.customPalette,
  });

  @override
  Widget build(BuildContext context) {
    final AppIconThemePalette palette;
    if (customPalette != null) {
      palette = customPalette!;
    } else if (adaptToTheme) {
      palette = AppIconThemePalette.fromTheme(Theme.of(context));
    } else {
      palette = AppIconThemePalette.original;
    }

    final themedSvg = palette.applyToSvg(kAppIconSvgTemplate);

    final iconWidget = SvgPicture.string(
      themedSvg,
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
  final bool adaptToTheme;
  final AppIconThemePalette? customPalette;

  const ChefAndCostBadge({
    super.key,
    this.size = 44,
    this.iconSize,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
    this.backgroundColor,
    this.adaptToTheme = true,
    this.customPalette,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? size;
    return AppIcon(
      size: effectiveIconSize,
      borderRadius: borderRadius,
      adaptToTheme: adaptToTheme,
      customPalette: customPalette,
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
    final palette = AppIconThemePalette.fromTheme(theme);
    final resolvedAmpColor = ampersandColor ?? palette.midColor;

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
  final bool adaptToTheme;

  const ChefAndCostBrand({
    super.key,
    this.isExtended = false,
    this.onTap,
    this.tooltip,
    this.badgeSize,
    this.fontSize,
    this.compactWidth,
    this.showTagline = false,
    this.adaptToTheme = true,
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
            adaptToTheme: adaptToTheme,
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
        adaptToTheme: adaptToTheme,
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
