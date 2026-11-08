import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/theme/app_theme.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/widgets/app_logo.dart';

void main() {
  group('Warm Mocha Theme & Color Palette', () {
    test('AppColors matches specified Warm Mocha color specifications', () {
      // 1. Primary: #5C381E (Warm Deep Mocha / Chocolate Brown)
      expect(AppColors.primary, const Color(0xFF5C381E));

      // 2. Secondary / Background Tint: #E8B896 (Warm Peach / Soft Cinnamon Beige)
      expect(AppColors.secondary, const Color(0xFFE8B896));

      // 3. Surface / Neutral Light: #FAF6F0 (or pure #FFFFFF)
      expect(AppColors.surface, const Color(0xFFFAF6F0));
      expect(AppColors.surfacePure, const Color(0xFFFFFFFF));

      // 4. On-Primary: #FFFFFF (White text/icons on primary colored surfaces)
      expect(AppColors.onPrimary, const Color(0xFFFFFFFF));

      // 5. On-Secondary: #5C381E (Mocha text on secondary tinted backgrounds)
      expect(AppColors.onSecondary, const Color(0xFF5C381E));
    });

    test('Light theme configures palette, surfaces, buttons, chips, and cards correctly', () {
      final theme = AppTheme.buildTheme(
        brightness: Brightness.light,
        seedColor: AppColors.primary,
        highContrastText: false,
        fontFamily: 'system',
        animationsEnabled: true,
      );

      // Color scheme tokens
      expect(theme.colorScheme.primary, const Color(0xFF5C381E));
      expect(theme.colorScheme.secondary, const Color(0xFFE8B896));
      expect(theme.colorScheme.surface, const Color(0xFFFAF6F0));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSecondary, const Color(0xFF5C381E));

      // Backgrounds & Surface
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF6F0));

      // Clean contrast for card backgrounds and input surfaces (#FFFFFF)
      expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFFFFFFFF));

      // Buttons (main brand actions & key buttons in primary #5C381E with on-primary #FFFFFF)
      final elevatedStyle = theme.elevatedButtonTheme.style;
      expect(elevatedStyle?.backgroundColor?.resolve({}), const Color(0xFF5C381E));
      expect(elevatedStyle?.foregroundColor?.resolve({}), const Color(0xFFFFFFFF));

      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle?.foregroundColor?.resolve({}), const Color(0xFF5C381E));

      // Icons
      expect(theme.iconTheme.color, const Color(0xFF5C381E));

      // Chips (tinted container with on-secondary mocha text)
      expect(theme.chipTheme.labelStyle?.color, const Color(0xFF5C381E));
      expect(theme.chipTheme.iconTheme?.color, const Color(0xFF5C381E));
    });

    test('Dark theme configures surfaces and accents gracefully', () {
      final theme = AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        highContrastText: false,
        fontFamily: 'system',
        animationsEnabled: true,
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.surface, AppColors.surfaceDark);
      expect(theme.scaffoldBackgroundColor, AppColors.surfaceDark);
    });

    test('AppIconThemePalette resolves to Warm Mocha palette', () {
      final lightTheme = AppTheme.buildTheme(
        brightness: Brightness.light,
        seedColor: AppColors.primary,
        highContrastText: false,
        fontFamily: 'system',
        animationsEnabled: true,
      );

      final paletteLight = AppIconThemePalette.fromTheme(lightTheme);
      expect(paletteLight.baseColor, const Color(0xFF5C381E));
      expect(paletteLight.midColor, const Color(0xFFE8B896));
      expect(paletteLight.highlightColor, const Color(0xFFFAF6F0));

      final darkTheme = AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        highContrastText: false,
        fontFamily: 'system',
        animationsEnabled: true,
      );

      final paletteDark = AppIconThemePalette.fromTheme(darkTheme);
      expect(paletteDark.baseColor, const Color(0xFF331D0F));
      expect(paletteDark.midColor, const Color(0xFFE8B896));
      expect(paletteDark.highlightColor, const Color(0xFFFAF6F0));
    });

    test('SettingsState defaults to Warm Mocha primary as initial seedColor', () {
      final initialSettings = SettingsState.initial();
      expect(initialSettings.seedColor, AppColors.primary);
    });
  });
}
