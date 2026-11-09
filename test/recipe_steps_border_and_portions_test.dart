import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Step items have no border card container in any theme',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('step_border_recipe'),
          name: 'Cookies',
          defaultYield: 1.0,
          yieldName: 'portions',
        ),
      );
      await db.into(db.recipeSteps).insert(
        RecipeStepsCompanion.insert(
          stepPk: const drift.Value('step_1_pk'),
          recipeFk: 'step_border_recipe',
          stepNumber: 1,
          instruction: 'Mix dry ingredients well',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(container.dispose);

      // 1. In default Warm Mocha theme
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'step_border_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stepTextFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Mix dry ingredients well',
      );
      expect(stepTextFieldFinder, findsOneWidget);

      // Find step Container holding this step
      final defaultStepContainer = tester.widget<Container>(
        find.ancestor(
          of: stepTextFieldFinder,
          matching: find.byType(Container),
        ).first,
      );

      // Step container has no border card decoration and text field has no border pill
      expect(defaultStepContainer.decoration, isNull);
      final defaultStepTextField = tester.widget<TextField>(stepTextFieldFinder);
      expect(defaultStepTextField.decoration?.border, equals(InputBorder.none));
      expect(defaultStepTextField.decoration?.enabledBorder, equals(InputBorder.none));
      expect(defaultStepTextField.decoration?.focusedBorder, equals(InputBorder.none));
      expect(defaultStepTextField.decoration?.filled, isFalse);

      // 2. In alternative non-default theme (Colors.blue)
      final altPrefs = await SharedPreferences.getInstance();
      await altPrefs.setInt('seedColor', Colors.blue.toARGB32());
      final altContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(altPrefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(altContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: altContainer,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: Colors.blue,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'step_border_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final altStepContainer = tester.widget<Container>(
        find.ancestor(
          of: stepTextFieldFinder,
          matching: find.byType(Container),
        ).first,
      );

      // In alternative themes, step container also has no border card decoration
      expect(altStepContainer.decoration, isNull);
    },
  );

  testWidgets(
    'Portions in web layout does not show duplicate 2nd portions text or scale bar portions pill',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('web_portions_recipe'),
          name: 'Pie',
          defaultYield: 4.0,
          yieldName: 'portions',
          targetProfitMargin: const drift.Value(0.30),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'web_portions_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right panel shows the portions stepper and portions title
      expect(find.byKey(const ValueKey('right_panel_yield_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('decrement_portions_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('increment_portions_button')), findsOneWidget);

      // The 2nd duplicate portions text field with hintText "portions"/"porciones" is deleted
      final duplicatePortionsFieldFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText != null &&
            (w.decoration!.hintText!.toLowerCase() == 'portions' ||
                w.decoration!.hintText!.toLowerCase() == 'porciones'),
      );
      expect(duplicatePortionsFieldFinder, findsNothing);

      // On wide web page layout, the scale bar custom portions pill chip is not rendered
      expect(find.byKey(const ValueKey('scale_chip_custom_portions')), findsNothing);

      // Financial inputs in web layout use UnderlineInputBorder (line like ingredients in recipe)
      final yieldField = tester.widget<TextField>(find.byKey(const ValueKey('right_panel_yield_field')));
      expect(yieldField.decoration?.border, equals(InputBorder.none));
      expect(yieldField.decoration?.enabledBorder, equals(InputBorder.none));
      expect(yieldField.decoration?.focusedBorder, equals(InputBorder.none));
      expect(yieldField.decoration?.filled, isFalse);

      final marginEditableFinder = find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text.startsWith('30') ?? false),
      );
      expect(marginEditableFinder, findsOneWidget);
      final marginField = tester.widget<TextField>(marginEditableFinder);
      expect(marginField.decoration?.border, isA<UnderlineInputBorder>());
      expect(marginField.decoration?.enabledBorder, isA<UnderlineInputBorder>());
      expect(marginField.decoration?.focusedBorder, isA<UnderlineInputBorder>());
      expect(marginField.decoration?.filled, isFalse);

      final marginContainer = tester.widget<Container>(
        find.ancestor(
          of: marginEditableFinder,
          matching: find.byType(Container),
        ).first,
      );
      expect(marginContainer.decoration, isNull);
    },
  );

  testWidgets(
    'Financial inputs in mobile bottom sheet use card container and black numbers in light mode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('mobile_finance_recipe'),
          name: 'Bread',
          defaultYield: 2.0,
          yieldName: 'portions',
          targetProfitMargin: const drift.Value(0.30),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'mobile_finance_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand bottom financials
      final collapsedFinder = find.byKey(const ValueKey('collapsed_financials'));
      expect(collapsedFinder, findsOneWidget);
      await tester.tap(collapsedFinder);
      await tester.pumpAndSettle();

      // Find the financial input TextFields (margin starting with '30')
      final marginInputFinder = find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text.startsWith('30') ?? false),
      );
      expect(marginInputFinder, findsOneWidget);

      final marginTextField = tester.widget<TextField>(marginInputFinder);
      expect(marginTextField.decoration?.border, equals(InputBorder.none));
      expect(marginTextField.decoration?.enabledBorder, equals(InputBorder.none));
      expect(marginTextField.decoration?.focusedBorder, equals(InputBorder.none));
      expect(marginTextField.decoration?.filled, isFalse);

      // The enclosing card Container has BoxDecoration (card container)
      final cardContainer = tester.widget<Container>(
        find.ancestor(
          of: marginInputFinder,
          matching: find.byType(Container),
        ).first,
      );
      expect(cardContainer.decoration is BoxDecoration, isTrue);
      expect((cardContainer.decoration as BoxDecoration).borderRadius, equals(BorderRadius.circular(14)));

      // Verify financial input number text style uses black in light mode, not theme primary color
      expect(marginTextField.style?.color, equals(Colors.black));
      expect(marginTextField.style?.color, isNot(equals(AppColors.primary)));
    },
  );

  testWidgets(
    'Financial numbers use black and white colors instead of active theme primary',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          recipePk: const drift.Value('finance_colors_recipe'),
          name: 'Pie',
          defaultYield: 4.0,
          yieldName: 'portions',
          targetProfitMargin: const drift.Value(0.25),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
        ],
      );
      addTearDown(container.dispose);

      // 1. Light Mode (Warm Mocha theme) -> numbers should be Colors.black
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'finance_colors_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand bottom financials
      final collapsedFinder = find.byKey(const ValueKey('collapsed_financials'));
      expect(collapsedFinder, findsOneWidget);
      await tester.tap(collapsedFinder);
      await tester.pumpAndSettle();

      final marginInputFinder = find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text.startsWith('25') ?? false),
      );
      expect(marginInputFinder, findsOneWidget);
      final marginFieldLight = tester.widget<TextField>(marginInputFinder);
      expect(marginFieldLight.style?.color, equals(Colors.black));

      // 2. Dark Mode -> numbers should be Colors.white
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.buildTheme(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              highContrastText: false,
              fontFamily: 'system',
              animationsEnabled: false,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: RecipeEditorScreen(
                recipeId: 'finance_colors_recipe',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final marginFieldDark = tester.widget<TextField>(marginInputFinder);
      expect(marginFieldDark.style?.color, equals(Colors.white));
    },
  );
}
