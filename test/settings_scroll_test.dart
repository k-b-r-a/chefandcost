import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/main.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Screen Bottom Scroll Padding Tests', () {
    testWidgets('SettingsScreen has bottom padding for mobile floating nav bar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliverPaddingFinder = find.byType(SliverPadding);
      expect(sliverPaddingFinder, findsWidgets);

      final sliverPadding = tester.widget<SliverPadding>(sliverPaddingFinder.first);
      final padding = sliverPadding.padding as EdgeInsets;

      // On mobile with 24 bottom padding, bottom should be 100 + 24 = 124
      expect(padding.bottom, 124.0);
    });

    testWidgets('SettingsScreen uses standard 16 bottom padding on wide screens', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliverPaddingFinder = find.byType(SliverPadding);
      expect(sliverPaddingFinder, findsWidgets);

      final sliverPadding = tester.widget<SliverPadding>(sliverPaddingFinder.first);
      final padding = sliverPadding.padding as EdgeInsets;

      expect(padding.bottom, 16.0);
    });

    testWidgets('When scrolled to bottom, last setting is not covered by floating nav bar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'navBarSize': 'normal'});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const RecipetoolsApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to settings tab (index 4)
      final settingsNavBtn = find.text('Configuración');
      expect(settingsNavBtn, findsOneWidget);
      await tester.tap(settingsNavBtn);
      await tester.pumpAndSettle();

      // Scroll to the bottom of the SettingsScreen CustomScrollView
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Find the last setting tile (Tutorial Interactivo)
      final lastSettingFinder = find.text('Tutorial Interactivo');
      expect(lastSettingFinder, findsOneWidget);

      final lastSettingRect = tester.getRect(lastSettingFinder);

      // Find the floating nav bar container
      final navBarFinder = find.ancestor(
        of: find.byType(AnimatedAlign),
        matching: find.byType(ConstrainedBox),
      ).first;
      expect(navBarFinder, findsOneWidget);
      final navBarRect = tester.getRect(navBarFinder);

      // The last setting tile's bottom must be above the nav bar's top
      expect(
        lastSettingRect.bottom,
        lessThanOrEqualTo(navBarRect.top),
        reason: 'The last setting must not be covered by the floating nav bar when scrolled to bottom',
      );
    });
  });
}
