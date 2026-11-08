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
    'Step items use bottom line border in default theme and full rounded border in alternative theme',
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
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        ).first,
      );

      final defaultBoxDec = defaultStepContainer.decoration as BoxDecoration;
      expect(defaultBoxDec.border, isNotNull);
      expect(defaultBoxDec.border is Border, isTrue);
      final defaultBorder = defaultBoxDec.border as Border;
      expect(defaultBorder.bottom, isNot(BorderSide.none));
      expect(defaultBorder.top, BorderSide.none);
      expect(defaultBorder.left, BorderSide.none);
      expect(defaultBorder.right, BorderSide.none);
      expect(defaultBoxDec.borderRadius, isNull);

      // 2. In alternative non-default theme (Colors.blue)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        ).first,
      );

      final altBoxDec = altStepContainer.decoration as BoxDecoration;
      expect(altBoxDec.borderRadius, BorderRadius.circular(15));
      expect(altBoxDec.border is Border, isTrue);
      final altBorder = altBoxDec.border as Border;
      expect(altBorder.isUniform, isTrue);
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
    },
  );
}
