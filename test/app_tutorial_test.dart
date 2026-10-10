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

    test('resetTutorial resets completion flag to false', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppTutorialService.markTutorialCompleted(prefs);
      expect(await AppTutorialService.isTutorialCompleted(prefs), isTrue);

      await AppTutorialService.resetTutorial(prefs);
      expect(await AppTutorialService.isTutorialCompleted(prefs), isFalse);
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
}
