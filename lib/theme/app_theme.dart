import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors for Chef&Cost theme based on the Warm Mocha design system:
///
/// Color Palette:
/// - Primary: #5C381E (Warm Deep Mocha / Chocolate Brown)
///   Use for main brand actions, key buttons, headers, icons, and primary text/borders.
/// - Secondary / Background Tint: #E8B896 (Warm Peach / Soft Cinnamon Beige)
///   Use for secondary accents, subtle card highlights, chips, and tinted containers.
/// - Surface / Neutral Light: #FAF6F0 (or pure #FFFFFF)
///   Use for main backgrounds, input surfaces, and card backgrounds to maintain clean contrast.
/// - On-Primary: #FFFFFF
///   White text/icons on primary colored surfaces.
/// - On-Secondary: #5C381E
///   Mocha text on secondary tinted backgrounds.
class AppColors {
  AppColors._();

  /// Primary: #5C381E (Warm Deep Mocha / Chocolate Brown)
  /// Used for main brand actions, key buttons, headers, icons, and primary text/borders.
  static const Color primary = Color(0xFF5C381E);

  /// Secondary / Background Tint: #E8B896 (Warm Peach / Soft Cinnamon Beige)
  /// Used for secondary accents, subtle card highlights, chips, and tinted containers.
  static const Color secondary = Color(0xFFE8B896);

  /// Surface / Neutral Light: #FAF6F0
  /// Used for main backgrounds, input surfaces, and card backgrounds to maintain clean contrast.
  static const Color surface = Color(0xFFFAF6F0);

  /// Pure Neutral Light: #FFFFFF
  /// Clean contrast for input surfaces, card backgrounds, and elevated dialogs.
  static const Color surfacePure = Color(0xFFFFFFFF);

  /// On-Primary: #FFFFFF
  /// White text/icons on primary colored surfaces.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// On-Secondary: #5C381E
  /// Mocha text on secondary tinted backgrounds.
  static const Color onSecondary = Color(0xFF5C381E);

  // --- Derived and complementary tones for comprehensive Material 3 compliance ---

  /// Primary container / subtle warmth tint
  static const Color primaryContainer = Color(0xFFF3DEC8);
  static const Color onPrimaryContainer = Color(0xFF381F0D);

  /// Secondary container / tinted containers & subtle chips
  static const Color secondaryContainer = Color(0xFFF8E7DB);
  static const Color onSecondaryContainer = Color(0xFF5C381E);

  /// Tertiary warm cinnamon
  static const Color tertiary = Color(0xFF8C532B);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFDCC5);
  static const Color onTertiaryContainer = Color(0xFF321400);

  /// Main text & surfaces for light mode
  static const Color onSurface = Color(0xFF2E1A0F);
  static const Color onSurfaceVariant = Color(0xFF5C381E);
  static const Color outline = Color(0xFF5C381E);
  static const Color outlineVariant = Color(0xFFE8B896);

  /// Material 3 tonal surface steps for light mode
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAF6F0);
  static const Color surfaceContainer = Color(0xFFF4EDE6);
  static const Color surfaceContainerHigh = Color(0xFFEFE5DC);
  static const Color surfaceContainerHighest = Color(0xFFE8DCD2);

  // --- Dark Mode Palette ---
  static const Color primaryDark = Color(0xFFE8B896);
  static const Color onPrimaryDark = Color(0xFF3B1E0A);
  static const Color primaryContainerDark = Color(0xFF5C381E);
  static const Color onPrimaryContainerDark = Color(0xFFFAF6F0);

  static const Color secondaryDark = Color(0xFFE8B896);
  static const Color onSecondaryDark = Color(0xFF3B1E0A);
  static const Color secondaryContainerDark = Color(0xFF4C2F1E);
  static const Color onSecondaryContainerDark = Color(0xFFFAF6F0);

  static const Color surfaceDark = Color(0xFF1B1410);
  static const Color onSurfaceDark = Color(0xFFFAF6F0);
  static const Color onSurfaceVariantDark = Color(0xFFDCC2B0);
  static const Color outlineDark = Color(0xFF9E8474);
  static const Color outlineVariantDark = Color(0xFF503E33);

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
class AppTheme {
  AppTheme._();

  /// Default Light ColorScheme according to the Warm Mocha Palette
  static ColorScheme get lightColorScheme => const ColorScheme(
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

  /// Default Dark ColorScheme according to the Warm Mocha Palette
  static ColorScheme get darkColorScheme => const ColorScheme(
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

  /// Builds a complete [ThemeData] configured with the Warm Mocha design system
  /// or a custom user-chosen seed color.
  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
    required bool highContrastText,
    required String fontFamily,
    required bool animationsEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    final isWarmMocha = seedColor == AppColors.primary;

    ColorScheme colorScheme;
    if (isWarmMocha) {
      colorScheme = isDark ? darkColorScheme : lightColorScheme;
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
    }

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
      // Cards: clean contrast & subtle secondary highlights
      cardTheme: CardTheme(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfacePure,
        surfaceTintColor: isDark ? AppColors.secondaryDark : AppColors.secondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark.withValues(alpha: 0.4)
                : AppColors.secondary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      // Chips: secondary / background tint with onSecondary text/icons
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.secondaryContainerDark
            : AppColors.secondary.withValues(alpha: 0.28),
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
      // Input surfaces: clean contrast with primary borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfacePure,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark
                : AppColors.secondary.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.outlineVariantDark
                : AppColors.secondary.withValues(alpha: 0.6),
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
      tabBarTheme: TabBarTheme(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.primary.withValues(alpha: 0.6),
        indicatorColor: colorScheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? AppColors.outlineVariantDark.withValues(alpha: 0.35)
            : AppColors.secondary.withValues(alpha: 0.35),
      ),
      fontFamily: fontFamily == 'sans'
          ? 'Metropolis'
          : fontFamily == 'butler'
              ? 'Butler'
              : null,
      pageTransitionsTheme: animationsEnabled
          ? const PageTransitionsTheme()
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: const NoTransitionsBuilder(),
                TargetPlatform.iOS: const NoTransitionsBuilder(),
                TargetPlatform.macOS: const NoTransitionsBuilder(),
                TargetPlatform.windows: const NoTransitionsBuilder(),
                TargetPlatform.linux: const NoTransitionsBuilder(),
                TargetPlatform.fuchsia: const NoTransitionsBuilder(),
              },
            ),
    );

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
