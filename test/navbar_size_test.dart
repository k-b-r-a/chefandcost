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
  group('Navbar Size Settings Tests', () {
    test('SettingsState defaults to normal navBarSize', () {
      final initial = SettingsState.initial();
      expect(initial.navBarSize, 'normal');

      final copied = initial.copyWith(navBarSize: 'compact');
      expect(copied.navBarSize, 'compact');
    });

    test('SettingsNotifier updates navBarSize and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).navBarSize, 'normal');

      notifier.setNavBarSize('compact');
      expect(container.read(settingsProvider).navBarSize, 'compact');
      expect(prefs.getString('navBarSize'), 'compact');

      notifier.setNavBarSize('large');
      expect(container.read(settingsProvider).navBarSize, 'large');
      expect(prefs.getString('navBarSize'), 'large');
    });

    testWidgets('SettingsStylesScreen displays navbar size segment and switches sizes', (WidgetTester tester) async {
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
            home: SettingsStylesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find navbar size SegmentedButton options
      expect(find.byType(SegmentedButton<String>), findsWidgets);

      // Verify compact, normal, large options exist
      final compactFinder = find.text('Compacto');
      final normalFinder = find.text('Normal');
      final largeFinder = find.text('Grande');

      await tester.scrollUntilVisible(compactFinder.first, 200);
      expect(compactFinder, findsWidgets);
      expect(normalFinder, findsWidgets);
      expect(largeFinder, findsWidgets);

      // Tap 'Compacto'
      await tester.tap(compactFinder.first);
      await tester.pumpAndSettle();
      expect(prefs.getString('navBarSize'), 'compact');

      // Tap 'Grande'
      await tester.tap(largeFinder.first);
      await tester.pumpAndSettle();
      expect(prefs.getString('navBarSize'), 'large');
    });

    testWidgets('Mobile FloatingNavBar resizes based on navBarSize', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'navBarSize': 'compact'});
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

      // In compact mode with labels, pillHeight is 46.0
      final compactSizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(AnimatedAlign),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(compactSizedBox.height, 46.0);
    });

    testWidgets('Wide screen NavigationRail resizes based on navBarSize', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'navBarSize': 'large'});
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

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.minWidth, 96.0);
    });
  });
}
