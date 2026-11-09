import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors for Chef&Cost Warm Mocha theme:
///
/// - Primary:
///   * HSV: (27, 0.68, 0.42)
///   * HEX: #6B3C22 | RGB: (107, 60, 34)
///   * Role: Brand primary actions, elevated buttons, headers, icons, borders, and main dark accents.
/// - Secondary:
///   * HSV: (28, 0.34, 0.92)
///   * HEX: #EBBB9B | RGB: (235, 187, 155)
///   * Role: Secondary buttons, chip containers, card accents, subtle borders, and contextual background highlights.
/// - Surface / Clean Canvas:
///   * HSV: (0, 0.0, 1.00)
///   * HEX: #FFFFFF | RGB: (255, 255, 255)
///   * Role: Primary surface backgrounds, card bases, dialogs, and input fills.
/// - Contrast Roles:
///   * On-Primary: #FFFFFF (White text/icons over Primary).
///   * On-Secondary: #6B3C22 (Deep Brown text/icons over Secondary).
///   * On-Surface: #2B180E (Deep brown/near-black neutral for base typography to preserve the warm hue).
class AppColors {
  AppColors._();

  /// Primary: #6B3C22 | RGB: (107, 60, 34) | HSV: (27, 0.68, 0.42)
  /// Role: Brand primary actions, elevated buttons, headers, icons, borders, and main dark accents.
  static const Color primary = Color(0xFF6B3C22);

  /// Secondary: #EBBB9B | RGB: (235, 187, 155) | HSV: (28, 0.34, 0.92)
  /// Role: Secondary buttons, chip containers, card accents, subtle borders, and contextual background highlights.
  static const Color secondary = Color(0xFFEBBB9B);

  /// Surface / Clean Canvas: #FFFFFF | RGB: (255, 255, 255) | HSV: (0, 0.0, 1.00)
  /// Role: Primary surface backgrounds, card bases, dialogs, and input fills.
  static const Color surface = Color(0xFFFFFFFF);

  /// Pure Neutral Light: #FFFFFF
  static const Color surfacePure = Color(0xFFFFFFFF);

  /// On-Primary: #FFFFFF (White text/icons over Primary)
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// On-Secondary: #6B3C22 (Deep Brown text/icons over Secondary)
  static const Color onSecondary = Color(0xFF6B3C22);

  /// On-Surface: #2B180E (Deep brown/near-black neutral for base typography to preserve the warm hue)
  static const Color onSurface = Color(0xFF2B180E);
  static const Color onSurfaceVariant = Color(0xFF6B3C22);

  // --- Derived and complementary tones for Warm Mocha Material 3 compliance ---

  /// Primary container / subtle warmth tint
  static const Color primaryContainer = Color(0xFFF6E2D5);
  static const Color onPrimaryContainer = Color(0xFF381F10);

  /// Secondary container / chip containers & contextual background highlights
  static const Color secondaryContainer = Color(0xFFF9ECE2);
  static const Color onSecondaryContainer = Color(0xFF6B3C22);

  /// Tertiary warm cinnamon
  static const Color tertiary = Color(0xFF8D532F);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFDCC9);
  static const Color onTertiaryContainer = Color(0xFF351500);

  /// Borders & outlines
  static const Color outline = Color(0xFF6B3C22);
  static const Color outlineVariant = Color(0xFFEBBB9B);

  /// Material 3 tonal surface steps for Warm Mocha light mode
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFCF9F6);
  static const Color surfaceContainer = Color(0xFFF7F3EE);
  static const Color surfaceContainerHigh = Color(0xFFF2ECE6);
  static const Color surfaceContainerHighest = Color(0xFFECE4DC);

  // --- Dark Mode Palette for Warm Mocha ---
  static const Color primaryDark = Color(0xFFEBBB9B);
  static const Color onPrimaryDark = Color(0xFF3D1F10);
  static const Color primaryContainerDark = Color(0xFF6B3C22);
  static const Color onPrimaryContainerDark = Color(0xFFFDF8F5);

  static const Color secondaryDark = Color(0xFFEBBB9B);
  static const Color onSecondaryDark = Color(0xFF3D1F10);
  static const Color secondaryContainerDark = Color(0xFF53311E);
  static const Color onSecondaryContainerDark = Color(0xFFFDF8F5);

  static const Color surfaceDark = Color(0xFF1B1410);
  static const Color onSurfaceDark = Color(0xFFFAF6F2);
  static const Color onSurfaceVariantDark = Color(0xFFDFC6B6);
  static const Color outlineDark = Color(0xFFA3897B);
  static const Color outlineVariantDark = Color(0xFF554136);

  static const Color surfaceContainerLowestDark = Color(0xFF120C09);
  static const Color surfaceContainerLowDark = Color(0xFF201712);
  static const Color surfaceContainerDark = Color(0xFF261D17);
  static const Color surfaceContainerHighDark = Color(0xFF312720);
  static const Color surfaceContainerHighestDark = Color(0xFF3D312A);
}

/// Instant page transition builder for accessibility/performance when animations are disabled.
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Core application theme configurator.
/// Supports both the standard app theme (deep purple base and presets)
/// and the dedicated Warm Mocha theme when selected by the user.
class AppTheme {
  AppTheme._();

  /// Light ColorScheme for the Warm Mocha theme option
  static ColorScheme get warmMochaLightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFF382D26),
        onInverseSurface: AppColors.surface,
        inversePrimary: AppColors.primaryDark,
        surfaceTint: AppColors.primary,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
      );

  /// Dark ColorScheme for the Warm Mocha theme option
  static ColorScheme get warmMochaDarkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        onPrimary: AppColors.onPrimaryDark,
        primaryContainer: AppColors.primaryContainerDark,
        onPrimaryContainer: AppColors.onPrimaryContainerDark,
        secondary: AppColors.secondaryDark,
        onSecondary: AppColors.onSecondaryDark,
        secondaryContainer: AppColors.secondaryContainerDark,
        onSecondaryContainer: AppColors.onSecondaryContainerDark,
        tertiary: Color(0xFFE5BE9B),
        onTertiary: Color(0xFF432A13),
        tertiaryContainer: Color(0xFF5C3F26),
        onTertiaryContainer: Color(0xFFFFDCC5),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        onSurfaceVariant: AppColors.onSurfaceVariantDark,
        outline: AppColors.outlineDark,
        outlineVariant: AppColors.outlineVariantDark,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.surface,
        onInverseSurface: AppColors.surfaceDark,
        inversePrimary: AppColors.primary,
        surfaceTint: AppColors.primaryDark,
        surfaceContainerLowest: AppColors.surfaceContainerLowestDark,
        surfaceContainerLow: AppColors.surfaceContainerLowDark,
        surfaceContainer: AppColors.surfaceContainerDark,
        surfaceContainerHigh: AppColors.surfaceContainerHighDark,
        surfaceContainerHighest: AppColors.surfaceContainerHighestDark,
      );

  /// Builds the app's [ThemeData].
  /// When [seedColor] is [AppColors.primary], it activates the handcrafted
  /// Warm Mocha theme. For any other seed color (including the default deep purple base),
  /// it builds the standard theme without applying Warm Mocha styles.
  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
    required bool highContrastText,
    required String fontFamily,
    required bool animationsEnabled,
  }) {
    final isWarmMocha = seedColor.toARGB32() == AppColors.primary.toARGB32() ||
        seedColor == AppColors.primary;

    if (isWarmMocha) {
      return _buildWarmMochaTheme(
        brightness: brightness,
        highContrastText: highContrastText,
        fontFamily: fontFamily,
        animationsEnabled: animationsEnabled,
      );
    }

    return _buildStandardTheme(
      brightness: brightness,
      seedColor: seedColor,
      highContrastText: highContrastText,
      fontFamily: fontFamily,
      animationsEnabled: animationsEnabled,
    );
  }

  /// Builds the dedicated Warm Mocha theme option.
  static ThemeData _buildWarmMochaTheme({
    required Brightness brightness,
    required bool highContrastText,
    required String fontFamily,
    required bool animationsEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    var colorScheme = isDark ? warmMochaDarkColorScheme : warmMochaLightColorScheme;

    if (highContrastText) {
      final textColor = isDark ? Colors.white : Colors.black;
      colorScheme = colorScheme.copyWith(
        onSurface: textColor,
        onSurfaceVariant: textColor,
        primary: isDark ? Colors.white : Colors.black,
        secondary: isDark ? Colors.white : Colors.black,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSecondary: isDark ? Colors.black : Colors.white,
        onError: isDark ? Colors.black : Colors.white,
      );
    }

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceContainerDark : AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: isDark ? AppColors.onSurfaceDark : AppColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? AppColors.onSurfaceDark : AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.onSurfaceDark : AppColors.primary,
        ),
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.primaryDark : AppColors.primary,
      ),
      // Key buttons & main brand actions
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Cards: clean contrast (#FFFFFF base) & subtle secondary accents
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surface,
        surfaceTintColor: isDark ? AppColors.secondaryDark : AppColors.secondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark.withValues(alpha: 0.4)
                : AppColors.secondary.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      // Chips: secondary / background tint with onSecondary text/icons
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.secondaryContainerDark
            : AppColors.secondaryContainer,
        selectedColor: isDark ? AppColors.secondaryDark : AppColors.secondary,
        labelStyle: TextStyle(
          color: isDark ? AppColors.onSurfaceDark : AppColors.onSecondary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.onSurfaceDark : AppColors.onSecondary,
          size: 18,
        ),
        side: BorderSide(
          color: isDark
              ? AppColors.secondaryDark.withValues(alpha: 0.3)
              : AppColors.secondary.withValues(alpha: 0.6),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      // Input surfaces: clean contrast (#FFFFFF fill) with primary borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceContainerDark : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark
                : AppColors.secondary.withValues(alpha: 0.65),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark
                : AppColors.secondary.withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.8,
          ),
        ),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: colorScheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.primary.withValues(alpha: 0.6),
        indicatorColor: colorScheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? AppColors.outlineVariantDark.withValues(alpha: 0.35)
            : AppColors.secondary.withValues(alpha: 0.35),
      ),
      pageTransitionsTheme: animationsEnabled
          ? const PageTransitionsTheme()
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoTransitionsBuilder(),
                TargetPlatform.iOS: NoTransitionsBuilder(),
                TargetPlatform.macOS: NoTransitionsBuilder(),
                TargetPlatform.windows: NoTransitionsBuilder(),
                TargetPlatform.linux: NoTransitionsBuilder(),
                TargetPlatform.fuchsia: NoTransitionsBuilder(),
              },
            ),
    );

    return _applyTypography(
      baseTheme: baseTheme,
      fontFamily: fontFamily,
      highContrastText: highContrastText,
      isDark: isDark,
    );
  }

  /// Builds the standard app theme for the base theme (deep purple) or other presets.
  static ThemeData _buildStandardTheme({
    required Brightness brightness,
    required Color seedColor,
    required bool highContrastText,
    required String fontFamily,
    required bool animationsEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    if (highContrastText) {
      final textColor = isDark ? Colors.white : Colors.black;
      colorScheme = colorScheme.copyWith(
        onSurface: textColor,
        onSurfaceVariant: textColor,
        primary: isDark ? Colors.white : Colors.black,
        secondary: isDark ? Colors.white : Colors.black,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSecondary: isDark ? Colors.black : Colors.white,
        onError: isDark ? Colors.black : Colors.white,
      );
    }

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      pageTransitionsTheme: animationsEnabled
          ? const PageTransitionsTheme()
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoTransitionsBuilder(),
                TargetPlatform.iOS: NoTransitionsBuilder(),
                TargetPlatform.macOS: NoTransitionsBuilder(),
                TargetPlatform.windows: NoTransitionsBuilder(),
                TargetPlatform.linux: NoTransitionsBuilder(),
                TargetPlatform.fuchsia: NoTransitionsBuilder(),
              },
            ),
    );

    return _applyTypography(
      baseTheme: baseTheme,
      fontFamily: fontFamily,
      highContrastText: highContrastText,
      isDark: isDark,
    );
  }

  static ThemeData _applyTypography({
    required ThemeData baseTheme,
    required String fontFamily,
    required bool highContrastText,
    required bool isDark,
  }) {
    var textTheme = baseTheme.textTheme;
    if (fontFamily == 'sans') {
      textTheme = textTheme.apply(fontFamily: 'Metropolis');
    } else if (fontFamily == 'butler') {
      textTheme = textTheme.apply(fontFamily: 'Butler');
    } else if (fontFamily == 'serif') {
      textTheme = GoogleFonts.nunitoTextTheme(textTheme);
    } else if (fontFamily == 'mono') {
      textTheme = GoogleFonts.inconsolataTextTheme(textTheme);
    } else if (fontFamily == 'amatic') {
      textTheme = GoogleFonts.amaticScTextTheme(textTheme);
    } else if (fontFamily == 'caveat') {
      textTheme = GoogleFonts.caveatTextTheme(textTheme);
    }

    if (highContrastText) {
      final textColor = isDark ? Colors.white : Colors.black;
      textTheme = textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
        decorationColor: textColor,
      );
    }

    return baseTheme.copyWith(textTheme: textTheme);
  }
}
