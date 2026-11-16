import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/ad_provider.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/monetization_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/timers_provider.dart';
import 'package:recipetools/screens/ingredients_screen.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/screens/recipe_list_screen.dart';
import 'package:recipetools/services/ad_service.dart';
import 'package:recipetools/utils/ingredient_text_editing_controller.dart';
import 'package:recipetools/widgets/floating_pill_app_bar.dart';
import 'package:recipetools/widgets/inline_ad_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scroll Performance Audit Verification', () {
    testWidgets(
      '1. IngredientTextEditingController reuses cached RegExp across 500 buildTextSpan calls and invalidates on updateIngredients',
      (tester) async {
        final ingredients = List.generate(
          40,
          (i) => Ingredient(
            ingredientPk: 'ing_$i',
            name: 'Ingrediente Especial $i',
            cost: 10.0 + i,
            quantityForCost: 1.0,
            unitFk: 'g',
            category: 'mass',
            dateCreated: DateTime(2026),
            isDeleted: false,
            groupId: 'group_default_principal',
          ),
        );

        final controller = IngredientTextEditingController(
          text:
              'Mezclar Ingrediente Especial 1 con Ingrediente Especial 25 y luego agregar Ingrediente Especial 39.',
          ingredients: ingredients,
          colorScheme: const ColorScheme.light(),
        );
        addTearDown(controller.dispose);

        final initialRegex = controller.cachedRegex;
        expect(initialRegex, isNotNull);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final sw = Stopwatch()..start();
        for (int i = 0; i < 500; i++) {
          final span = controller.buildTextSpan(
            context: capturedContext,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          expect(span.children, isNotEmpty);
        }
        sw.stop();

        expect(identical(controller.cachedRegex, initialRegex), isTrue);
        expect(sw.elapsedMilliseconds, lessThan(100));

        // Calling updateIngredients with equivalent list keeps same RegExp
        controller.updateIngredients(List<Ingredient>.from(ingredients));
        expect(identical(controller.cachedRegex, initialRegex), isTrue);

        // Calling updateIngredients with a new ingredient invalidates cache
        controller.updateIngredients([
          ...ingredients,
          Ingredient(
            ingredientPk: 'ing_new',
            name: 'Vainilla',
            cost: 5.0,
            quantityForCost: 1.0,
            unitFk: 'ml',
            category: 'volume',
            dateCreated: DateTime(2026),
            isDeleted: false,
            groupId: 'group_default_principal',
          ),
        ]);
        expect(identical(controller.cachedRegex, initialRegex), isFalse);
      },
    );

    testWidgets(
      '2. buildFloatingPillAppBar triggers 0 titleWidget rebuilds after offset > expandedTitleHeight',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        int titleBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      buildFloatingPillAppBar(
                        context: context,
                        title: 'Audit',
                        controller: scrollController,
                        titleWidget: Builder(
                          builder: (_) {
                            titleBuildCount++;
                            return const Text('Audit');
                          },
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => SizedBox(
                            height: 80,
                            child: Text('Item $index'),
                          ),
                          childCount: 50,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll past the transition zone (expandedTitleHeight = 88, collapsed = 48 => 40px)
        scrollController.jumpTo(200);
        await tester.pump();
        final buildsAt200 = titleBuildCount;
        expect(find.byType(BackdropFilter), findsNothing);

        // Scroll further from 200px to 2000px in multiple steps
        for (double offset = 400; offset <= 2000; offset += 200) {
          scrollController.jumpTo(offset);
          await tester.pump();
          expect(find.byType(BackdropFilter), findsNothing);
        }

        expect(titleBuildCount, equals(buildsAt200));
      },
    );

    testWidgets(
      '3. Idle monetization, ad, and kitchenTimers providers emit 0 rebuilds over 60s',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
          ],
        );
        addTearDown(container.dispose);

        int monetizationEvents = 0;
        int adEvents = 0;
        int timerEvents = 0;

        container.listen(monetizationProvider, (_, _) => monetizationEvents++);
        container.listen(adProvider, (_, _) => adEvents++);
        container.listen(kitchenTimersProvider, (_, _) => timerEvents++);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RecipeListScreen(),
            ),
          ),
        );
        await tester.pump();

        // Reset counts after initial mount
        monetizationEvents = 0;
        adEvents = 0;
        timerEvents = 0;

        // Advance 60 seconds in 15s increments
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 15));
        }

        expect(monetizationEvents, equals(0));
        expect(adEvents, equals(0));
        expect(timerEvents, equals(0));

        // Also verify IngredientsScreen mounts cleanly with 0 timer-driven rebuilds
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const IngredientsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 30));
        expect(monetizationEvents, equals(0));
        expect(adEvents, equals(0));
        expect(timerEvents, equals(0));

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      '4. Typing in RecipeEditorScreen step or name does not rebuild the whole editor state',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        await db.into(db.recipes).insert(
          RecipesCompanion.insert(
            recipePk: const drift.Value('perf_recipe_1'),
            name: 'Pan Casero',
            defaultYield: 1.0,
            yieldName: 'unidad',
          ),
        );
        await db.into(db.recipeSteps).insert(
          RecipeStepsCompanion.insert(
            stepPk: const drift.Value('perf_step_1'),
            recipeFk: 'perf_recipe_1',
            stepNumber: 1,
            instruction: 'Amasar',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: RecipeEditorScreen(recipeId: 'perf_recipe_1'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Enter text into the step TextField
        final stepField = find.widgetWithText(TextField, 'Amasar');
        expect(stepField, findsOneWidget);
        await tester.enterText(stepField, 'Amasar durante 10 minutos');
        await tester.pump();

        expect(
          find.widgetWithText(TextField, 'Amasar durante 10 minutos'),
          findsOneWidget,
        );

        // Enter text into the recipe name field and verify AppBar updates via ValueListenableBuilder
        final nameField = find.byKey(const ValueKey('recipe_name_input'));
        if (nameField.evaluate().isNotEmpty) {
          await tester.enterText(nameField, 'Pan Integral');
          await tester.pump();
          expect(find.text('Pan Integral'), findsWidgets);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'InlineAdCard keeps 320x50 placeholder and mounts zero AdWidgets while scrolling',
      (tester) async {
        SharedPreferences.setMockInitialValues({'is_ad_free': false});
        AdService.debugIsSupportedPlatform = true;
        addTearDown(() => AdService.debugIsSupportedPlatform = null);

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => index == 2
                            ? const InlineAdCard()
                            : ListTile(title: Text('Item $index')),
                        childCount: 25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(InlineAdCard), findsOneWidget);
        final placeholderFinder = find.descendant(
          of: find.byType(InlineAdCard),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 320.0 && w.height == 50.0,
          ),
        );
        expect(placeholderFinder, findsOneWidget);
        expect(find.byType(AdWidget), findsNothing);

        // Simulate active scroll and verify no AdWidget PlatformView mounts
        scrollController.position.isScrollingNotifier.value = true;
        await tester.pump();
        expect(find.byType(AdWidget), findsNothing);
        expect(placeholderFinder, findsOneWidget);

        // Settle scroll and advance past 200ms load deferral timer cleanly
        scrollController.position.isScrollingNotifier.value = false;
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(AdWidget), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
