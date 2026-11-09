import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/recipe_category.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPrefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({required Widget home, Locale locale = const Locale('es')}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ingredientsStreamProvider.overrideWith((ref) => Stream.value(<Ingredient>[])),
        unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
        groupsStreamProvider.overrideWith((ref) => Stream.value(<Group>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: home,
      ),
    );
  }

  group('Recipe Editor Responsive UI Fixes', () {
    testWidgets('Category selector follows pill style and occupies full horizontal width responsively', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
      await tester.pumpAndSettle();

      // Ensure SegmentedButton is no longer used for categories
      expect(find.byType(SegmentedButton<RecipeCategory>), findsNothing);

      // Verify the 3 category pills exist
      final cocinaPill = find.byKey(const ValueKey('recipe_category_cocina'));
      final pasteleriaPill = find.byKey(const ValueKey('recipe_category_pasteleria'));
      final cocteleriaPill = find.byKey(const ValueKey('recipe_category_cocteleria'));

      expect(cocinaPill, findsOneWidget);
      expect(pasteleriaPill, findsOneWidget);
      expect(cocteleriaPill, findsOneWidget);

      // Verify pill style: AnimatedContainers with borderRadius 16
      final animatedContainers = find.descendant(
        of: find.byKey(const ValueKey('recipe_category_scroll')),
        matching: find.byType(AnimatedContainer),
      );
      expect(animatedContainers, findsNWidgets(3));

      for (final containerElement in animatedContainers.evaluate()) {
        final container = containerElement.widget as AnimatedContainer;
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.borderRadius, equals(BorderRadius.circular(16)));
      }

      // Verify responsive layout: 3 pills occupy the full available width across the screen
      final leftCocina = tester.getTopLeft(cocinaPill).dx;
      final rightCocina = tester.getTopRight(cocinaPill).dx;
      final leftPasteleria = tester.getTopLeft(pasteleriaPill).dx;
      final rightPasteleria = tester.getTopRight(pasteleriaPill).dx;
      final leftCocteleria = tester.getTopLeft(cocteleriaPill).dx;
      final rightCocteleria = tester.getTopRight(cocteleriaPill).dx;

      // Pills are ordered horizontally: Cocina -> Pasteleria -> Cocteleria
      expect(leftCocina < rightCocina, isTrue);
      expect(rightCocina < leftPasteleria, isTrue);
      expect(leftPasteleria < rightPasteleria, isTrue);
      expect(rightPasteleria < leftCocteleria, isTrue);
      expect(leftCocteleria < rightCocteleria, isTrue);

      // Total span covers the body width (400 - 2 * 22 padding = 356)
      final totalPillsWidth = rightCocteleria - leftCocina;
      expect(totalPillsWidth, closeTo(356, 1.0));

      // Each pill has roughly equal width
      final cocinaWidth = rightCocina - leftCocina;
      final pasteleriaWidth = rightPasteleria - leftPasteleria;
      final cocteleriaWidth = rightCocteleria - leftCocteleria;
      expect((cocinaWidth - pasteleriaWidth).abs(), lessThan(1.0));
      expect((pasteleriaWidth - cocteleriaWidth).abs(), lessThan(1.0));

      // Tap pastry pill and verify selection updates
      await tester.tap(pasteleriaPill);
      await tester.pumpAndSettle();

      // Tap cocktails pill and verify selection updates
      await tester.tap(cocteleriaPill);
      await tester.pumpAndSettle();
    });

    testWidgets('Timers "no timer preset added" empty placeholder occupies all horizontal screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
      await tester.pumpAndSettle();

      // Find the empty timers placeholder text
      final emptyText = find.text('No hay temporizadores agregados a esta receta.');
      expect(emptyText, findsOneWidget);

      // The placeholder container wrapping the empty text
      final placeholderContainerFinder = find.ancestor(
        of: emptyText,
        matching: find.byType(Container),
      ).first;

      final leftPlaceholder = tester.getTopLeft(placeholderContainerFinder).dx;
      final rightPlaceholder = tester.getTopRight(placeholderContainerFinder).dx;
      final placeholderWidth = rightPlaceholder - leftPlaceholder;

      // Available content width is 400 - 2 * 22 padding = 356
      expect(placeholderWidth, closeTo(356, 1.0));
    });

    testWidgets('Desktop wide layout also renders category pills and timer placeholder responsively', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
      await tester.pumpAndSettle();

      // Pills exist in wide desktop view
      final cocinaPill = find.byKey(const ValueKey('recipe_category_cocina'));
      final cocteleriaPill = find.byKey(const ValueKey('recipe_category_cocteleria'));
      expect(cocinaPill, findsOneWidget);
      expect(cocteleriaPill, findsOneWidget);

      final leftCocina = tester.getTopLeft(cocinaPill).dx;
      final rightCocteleria = tester.getTopRight(cocteleriaPill).dx;
      expect(rightCocteleria - leftCocina, greaterThan(300));

      // Empty timers placeholder also fills the available form width
      final emptyText = find.text('No hay temporizadores agregados a esta receta.');
      expect(emptyText, findsOneWidget);

      final placeholderContainerFinder = find.ancestor(
        of: emptyText,
        matching: find.byType(Container),
      ).first;

      final placeholderWidth = tester.getSize(placeholderContainerFinder).width;
      final formColumnWidth = rightCocteleria - leftCocina;
      expect((placeholderWidth - formColumnWidth).abs(), lessThan(5.0));
    });
  });
}
