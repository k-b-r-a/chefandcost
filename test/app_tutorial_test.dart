import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/settings_screen.dart';
import 'package:recipetools/services/app_tutorial_service.dart';
import 'package:drift/native.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  group('AppTutorialService persistence tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial tutorial completed status is false', () async {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = await AppTutorialService.isTutorialCompleted(prefs);
      expect(isCompleted, isFalse);
    });

    test('markTutorialCompleted sets completion flag to true', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppTutorialService.markTutorialCompleted(prefs);
      final isCompleted = await AppTutorialService.isTutorialCompleted(prefs);
      expect(isCompleted, isTrue);
    });

    test('resetTutorial resets all completion flags to false', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppTutorialService.markTutorialCompleted(prefs);
      await AppTutorialService.markRecipeListTutorialCompleted(prefs);
      await AppTutorialService.markRecipeEditorTutorialCompleted(prefs);

      expect(await AppTutorialService.isTutorialCompleted(prefs), isTrue);
      expect(await AppTutorialService.isRecipeListTutorialCompleted(prefs), isTrue);
      expect(await AppTutorialService.isRecipeEditorTutorialCompleted(prefs), isTrue);

      await AppTutorialService.resetTutorial(prefs);
      expect(await AppTutorialService.isTutorialCompleted(prefs), isFalse);
      expect(await AppTutorialService.isRecipeListTutorialCompleted(prefs), isFalse);
      expect(await AppTutorialService.isRecipeEditorTutorialCompleted(prefs), isFalse);
    });

    test('RecipeList tutorial persistence flags work correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await AppTutorialService.isRecipeListTutorialCompleted(prefs), isFalse);

      await AppTutorialService.markRecipeListTutorialCompleted(prefs);
      expect(await AppTutorialService.isRecipeListTutorialCompleted(prefs), isTrue);

      await AppTutorialService.resetRecipeListTutorial(prefs);
      expect(await AppTutorialService.isRecipeListTutorialCompleted(prefs), isFalse);
    });

    test('RecipeEditor tutorial persistence flags work correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await AppTutorialService.isRecipeEditorTutorialCompleted(prefs), isFalse);

      await AppTutorialService.markRecipeEditorTutorialCompleted(prefs);
      expect(await AppTutorialService.isRecipeEditorTutorialCompleted(prefs), isTrue);

      await AppTutorialService.resetRecipeEditorTutorial(prefs);
      expect(await AppTutorialService.isRecipeEditorTutorialCompleted(prefs), isFalse);
    });

    test('requestReplay and triggerReplay notify listeners', () {
      int notifyCount = 0;
      void listener() {
        notifyCount++;
      }

      AppTutorialService.replayNotifier.addListener(listener);

      AppTutorialService.requestReplay();
      expect(notifyCount, 1);

      AppTutorialService.triggerReplay();
      expect(notifyCount, 2);

      AppTutorialService.replayNotifier.removeListener(listener);
    });
  });

  group('AppTutorialService Target creation tests', () {
    testWidgets('createTargets creates TargetFocus only for mounted keys', (WidgetTester tester) async {
      final navKey = GlobalKey();
      final quickActionsKey = GlobalKey();
      final recentRecipesKey = GlobalKey();
      final unmountedKey = GlobalKey();

      final keys = AppTutorialKeys(
        navBarKey: navKey,
        quickActionsKey: quickActionsKey,
        recentRecipesKey: recentRecipesKey,
        toolsSectionKey: unmountedKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  key: navKey,
                  height: 50,
                  width: 300,
                  child: const Text('Nav Bar'),
                ),
                SizedBox(
                  key: quickActionsKey,
                  height: 80,
                  width: 300,
                  child: const Text('Quick Actions'),
                ),
                SizedBox(
                  key: recentRecipesKey,
                  height: 100,
                  width: 300,
                  child: const Text('Recent Recipes'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final targets = AppTutorialService.createTargets(context: context, keys: keys);

      // 3 mounted keys should produce 3 targets, skipping the unmounted toolsSectionKey
      expect(targets.length, 3);
      expect(targets[0].identify, 'step_nav_bar');
      expect(targets[1].identify, 'step_quick_actions');
      expect(targets[2].identify, 'step_recent_recipes');
    });

    testWidgets('createRecipeListTargets creates targets for recipe card and finance row', (WidgetTester tester) async {
      final cardKey = GlobalKey();
      final financeKey = GlobalKey();
      final keys = RecipeListTutorialKeys(
        recipeCardKey: cardKey,
        recipeFinanceGridKey: financeKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: cardKey, height: 120, width: 300, child: const Text('Recipe Card')),
                SizedBox(key: financeKey, height: 40, width: 300, child: const Text('Finance Grid')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final targets = AppTutorialService.createRecipeListTargets(context: context, keys: keys);

      expect(targets.length, 2);
      expect(targets[0].identify, 'step_recipe_list_hold');
      expect(targets[1].identify, 'step_recipe_list_finance');
    });

    testWidgets('createRecipeEditorTargets creates targets for finance panel, scale bar, ingredient hold, and gestures', (WidgetTester tester) async {
      final financeKey = GlobalKey();
      final scaleBarKey = GlobalKey();
      final firstIngredientKey = GlobalKey();
      final ingredientsKey = GlobalKey();
      final keys = RecipeEditorTutorialKeys(
        recipeEditorFinanceKey: financeKey,
        recipeEditorScaleBarKey: scaleBarKey,
        recipeEditorFirstIngredientKey: firstIngredientKey,
        recipeEditorIngredientsKey: ingredientsKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: financeKey, height: 80, width: 300, child: const Text('Finance Panel')),
                SizedBox(key: scaleBarKey, height: 40, width: 300, child: const Text('Scale Bar')),
                SizedBox(key: firstIngredientKey, height: 50, width: 300, child: const Text('First Ingredient')),
                SizedBox(key: ingredientsKey, height: 120, width: 300, child: const Text('Ingredients Section')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final targets = AppTutorialService.createRecipeEditorTargets(context: context, keys: keys);

      expect(targets.length, 4);
      expect(targets[0].identify, 'step_recipe_editor_finance');
      expect(targets[1].identify, 'step_recipe_editor_scale_bar');
      expect(targets[2].identify, 'step_recipe_editor_ingredient_hold');
      expect(targets[3].identify, 'step_recipe_editor_gestures');
      expect(targets[2].enableTargetTab, isTrue);
    });

    testWidgets('createRecipeEditorTargets skips unmounted firstIngredientKey gracefully', (WidgetTester tester) async {
      final financeKey = GlobalKey();
      final unmountedIngredientKey = GlobalKey();
      final ingredientsKey = GlobalKey();
      final keys = RecipeEditorTutorialKeys(
        recipeEditorFinanceKey: financeKey,
        recipeEditorFirstIngredientKey: unmountedIngredientKey,
        recipeEditorIngredientsKey: ingredientsKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: financeKey, height: 80, width: 300, child: const Text('Finance Panel')),
                SizedBox(key: ingredientsKey, height: 40, width: 300, child: const Text('Ingredients Section')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final targets = AppTutorialService.createRecipeEditorTargets(context: context, keys: keys);

      expect(targets.length, 2);
      expect(targets[0].identify, 'step_recipe_editor_finance');
      expect(targets[1].identify, 'step_recipe_editor_gestures');
    });

    testWidgets('calculateSafeTargetPosition positions card close to focus target instead of screen edges', (WidgetTester tester) async {
      final topWidgetKey = GlobalKey();
      final bottomWidgetKey = GlobalKey();

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 100,
                  child: SizedBox(key: topWidgetKey, height: 60, width: 200, child: const Text('Top Widget')),
                ),
                Positioned(
                  top: 750,
                  left: 800,
                  child: SizedBox(key: bottomWidgetKey, height: 60, width: 200, child: const Text('Bottom Widget')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));

      // 1. Top widget: plenty of space below -> places close below the widget
      final topPos = AppTutorialService.calculateSafeTargetPosition(
        context: context,
        keyTarget: topWidgetKey,
      );
      expect(topPos.top, isNotNull);
      expect(topPos.bottom, isNull);
      // Target bottom is 160. Gap is 12 -> desired top is 172.
      expect(topPos.top, closeTo(172.0, 5.0));

      // 2. Bottom widget: plenty of space above -> places close above the widget
      final bottomPos = AppTutorialService.calculateSafeTargetPosition(
        context: context,
        keyTarget: bottomWidgetKey,
      );
      expect(bottomPos.bottom, isNotNull);
      expect(bottomPos.top, isNull);
      // Screen height is 900, target top is 750 -> distance from bottom is 150 + gap 12 = 162.
      expect(bottomPos.bottom, closeTo(162.0, 5.0));
    });
  });

  group('Settings Walkthrough replay trigger tests', () {
    late AppDatabase mockDb;
    late SharedPreferences sharedPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppTutorialService.kTutorialCompletedKey: true,
      });
      sharedPrefs = await SharedPreferences.getInstance();
      mockDb = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await mockDb.close();
    });

    Widget createTestWidget(Widget homeWidget) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(mockDb)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: homeWidget,
        ),
      );
    }

    testWidgets('Settings screen renders Tutorial Interactivo tile and tapping resets flag', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      expect(await AppTutorialService.isTutorialCompleted(sharedPrefs), isTrue);

      int replayCount = 0;
      void listener() {
        replayCount++;
      }
      AppTutorialService.replayNotifier.addListener(listener);

      await tester.pumpWidget(createTestWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Find the tutorial repeat tile
      final tutorialTileFinder = find.text('Tutorial Interactivo');
      expect(tutorialTileFinder, findsOneWidget);

      await tester.tap(tutorialTileFinder);
      await tester.pump();

      // Replay notifier should have been fired
      expect(replayCount, 1);

      // Tutorial flag should now be reset to false
      expect(await AppTutorialService.isTutorialCompleted(sharedPrefs), isFalse);

      AppTutorialService.replayNotifier.removeListener(listener);
    });

    testWidgets('SettingsAboutScreen renders Tutorial Interactivo tile in Card 3', (WidgetTester tester) async {
      await AppTutorialService.markTutorialCompleted(sharedPrefs);
      expect(await AppTutorialService.isTutorialCompleted(sharedPrefs), isTrue);

      int replayCount = 0;
      void listener() {
        replayCount++;
      }
      AppTutorialService.replayNotifier.addListener(listener);

      await tester.pumpWidget(createTestWidget(const SettingsAboutScreen()));
      await tester.pumpAndSettle();

      final tileFinder = find.text('Tutorial Interactivo');
      expect(tileFinder, findsOneWidget);

      await tester.ensureVisible(tileFinder);
      await tester.tap(tileFinder);
      await tester.pump();

      expect(replayCount, 1);
      expect(await AppTutorialService.isTutorialCompleted(sharedPrefs), isFalse);

      AppTutorialService.replayNotifier.removeListener(listener);
    });
  });

  group('AppTutorialService concurrency & tablet mutex tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppTutorialService.dismissActiveTutorial();
    });

    tearDown(() {
      AppTutorialService.dismissActiveTutorial();
    });

    testWidgets('Tutorial mutex prevents two tutorials from showing simultaneously', (WidgetTester tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      final homeKeys = AppTutorialKeys(navBarKey: key1);
      final listKeys = RecipeListTutorialKeys(recipeCardKey: key2);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: key1, height: 50, width: 200, child: const Text('Home Target')),
                SizedBox(key: key2, height: 50, width: 200, child: const Text('List Target')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));

      expect(AppTutorialService.isTutorialActive, isFalse);

      // Show Home tutorial
      final startedHome = AppTutorialService.showTutorial(context, keys: homeKeys);
      expect(startedHome, isTrue);
      expect(AppTutorialService.isTutorialActive, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Attempting to show Recipe List tutorial while Home is active should be rejected
      final startedList = AppTutorialService.showRecipeListTutorial(context, keys: listKeys);
      expect(startedList, isFalse);

      // Dismiss active tutorial cleans up lock
      AppTutorialService.dismissActiveTutorial();
      await tester.pump(const Duration(milliseconds: 500));
      expect(AppTutorialService.isTutorialActive, isFalse);

      // Now Recipe List tutorial can start
      final startedListAfterDismiss = AppTutorialService.showRecipeListTutorial(context, keys: listKeys);
      expect(startedListAfterDismiss, isTrue);
      expect(AppTutorialService.isTutorialActive, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      AppTutorialService.dismissActiveTutorial();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Sequential prerequisites on wide/tablet layouts prevent premature triggering', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final key = GlobalKey();
      final listKeys = RecipeListTutorialKeys(recipeCardKey: key);
      final editorKeys = RecipeEditorTutorialKeys(recipeEditorFinanceKey: key);

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: SizedBox(key: key, height: 60, width: 200, child: const Text('Target')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));

      // 1. Neither Home nor List completed -> Recipe List tutorial should not trigger automatically
      final listTriggered = await AppTutorialService.checkAndShowRecipeListTutorial(
        context,
        keys: listKeys,
        prefs: prefs,
        bypassTestCheck: true,
      );
      expect(listTriggered, isFalse);

      // 2. Recipe Editor should not trigger automatically if Home & List are not completed
      final editorTriggered = await AppTutorialService.checkAndShowRecipeEditorTutorial(
        context,
        keys: editorKeys,
        prefs: prefs,
        bypassTestCheck: true,
      );
      expect(editorTriggered, isFalse);

      // Mark Home as completed
      await AppTutorialService.markTutorialCompleted(prefs);

      // Recipe Editor still should NOT trigger on tablet because Recipe List is not completed
      final editorTriggered2 = await AppTutorialService.checkAndShowRecipeEditorTutorial(
        context,
        keys: editorKeys,
        prefs: prefs,
        bypassTestCheck: true,
      );
      expect(editorTriggered2, isFalse);

      // Mark Recipe List as completed
      await AppTutorialService.markRecipeListTutorialCompleted(prefs);

      // Now Recipe Editor can trigger
      final editorTriggered3 = await AppTutorialService.checkAndShowRecipeEditorTutorial(
        context,
        keys: editorKeys,
        prefs: prefs,
        bypassTestCheck: true,
      );
      expect(editorTriggered3, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      AppTutorialService.dismissActiveTutorial();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
