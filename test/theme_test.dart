import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/theme/app_theme.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/widgets/app_logo.dart';

void main() {
  group('Warm Mocha Theme & Color System Definitions', () {
    test('AppColors matches specified color system definitions', () {
      // Primary: #6B3C22 | RGB: (107, 60, 34)
      expect(AppColors.primary, const Color(0xFF6B3C22));
      expect(AppColors.primary.r, closeTo(107 / 255, 0.01));
      expect(AppColors.primary.g, closeTo(60 / 255, 0.01));
      expect(AppColors.primary.b, closeTo(34 / 255, 0.01));

      // Secondary: #EBBB9B | RGB: (235, 187, 155)
      expect(AppColors.secondary, const Color(0xFFEBBB9B));
      expect(AppColors.secondary.r, closeTo(235 / 255, 0.01));
      expect(AppColors.secondary.g, closeTo(187 / 255, 0.01));
      expect(AppColors.secondary.b, closeTo(155 / 255, 0.01));

      // Surface / Clean Canvas: #FFFFFF | RGB: (255, 255, 255)
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.surfacePure, const Color(0xFFFFFFFF));

      // Contrast Roles:
      // On-Primary: #FFFFFF (White text/icons over Primary)
      expect(AppColors.onPrimary, const Color(0xFFFFFFFF));

      // On-Secondary: #6B3C22 (Deep Brown text/icons over Secondary)
      expect(AppColors.onSecondary, const Color(0xFF6B3C22));

      // On-Surface: #2B180E (Deep brown/near-black neutral for base typography)
      expect(AppColors.onSurface, const Color(0xFF2B180E));
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
      expect(theme.colorScheme.primary, const Color(0xFF6B3C22));
      expect(theme.colorScheme.secondary, const Color(0xFFEBBB9B));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSecondary, const Color(0xFF6B3C22));
      expect(theme.colorScheme.onSurface, const Color(0xFF2B180E));

      // Backgrounds & Surface (Clean Canvas #FFFFFF)
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));

      // Clean contrast for card backgrounds, dialogs, and input surfaces (#FFFFFF)
      expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFFFFFFFF));
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFFFFFFFF));

      // Buttons (main brand actions & key buttons in primary #6B3C22 with on-primary #FFFFFF)
      final elevatedStyle = theme.elevatedButtonTheme.style;
      expect(elevatedStyle?.backgroundColor?.resolve({}), const Color(0xFF6B3C22));
      expect(elevatedStyle?.foregroundColor?.resolve({}), const Color(0xFFFFFFFF));

      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle?.foregroundColor?.resolve({}), const Color(0xFF6B3C22));

      // Icons
      expect(theme.iconTheme.color, const Color(0xFF6B3C22));

      // Chips (tinted container with on-secondary mocha text)
      expect(theme.chipTheme.labelStyle?.color, const Color(0xFF6B3C22));
      expect(theme.chipTheme.iconTheme?.color, const Color(0xFF6B3C22));
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
      expect(paletteLight.baseColor, const Color(0xFF6B3C22));
      expect(paletteLight.midColor, const Color(0xFFEBBB9B));
      expect(paletteLight.highlightColor, const Color(0xFFFFFFFF));

      final darkTheme = AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        highContrastText: false,
        fontFamily: 'system',
        animationsEnabled: true,
      );

      final paletteDark = AppIconThemePalette.fromTheme(darkTheme);
      expect(paletteDark.baseColor, const Color(0xFF3D1F10));
      expect(paletteDark.midColor, const Color(0xFFEBBB9B));
      expect(paletteDark.highlightColor, const Color(0xFFFFFFFF));
    });

    test('SettingsState defaults to Warm Mocha primary as initial seedColor', () {
      final initialSettings = SettingsState.initial();
      expect(initialSettings.seedColor, AppColors.primary);
      expect(initialSettings.seedColor, const Color(0xFF6B3C22));
    });
  });
}
