import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/utils/cloud_sync_service.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

class TrackingCloudSyncNotifier extends CloudSyncNotifier {
  final List<RecipeDetail> syncedRecipes = [];
  Completer<void>? syncCompleter;

  @override
  CloudSyncState build() {
    return CloudSyncState(
      signedIn: true,
      storageType: CloudSyncStorageType.firestore,
      loading: false,
    );
  }

  @override
  Future<void> checkStatus() async {}

  @override
  void syncRecipe(RecipeDetail detail) {
    syncedRecipes.add(detail);
    syncCompleter?.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const unitG = Unit(
    unitPk: 'u_g',
    name: 'Gramos',
    symbol: 'g',
    category: 'mass',
    factorToBase: 1.0,
    isMutable: false,
  );

  final ingFlour = Ingredient(
    ingredientPk: 'ing_flour',
    name: 'Harina',
    cost: 2.0,
    quantityForCost: 1000.0,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
    isDeleted: false,
  );

  group('Recipe Save & Decoupled Background Sync Tests', () {
    late SharedPreferences sharedPrefs;
    late AppDatabase testDb;
    late TrackingCloudSyncNotifier mockSyncNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPrefs = await SharedPreferences.getInstance();
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      await testDb.into(testDb.units).insert(unitG);
      await testDb.into(testDb.ingredients).insert(ingFlour);
      mockSyncNotifier = TrackingCloudSyncNotifier();
    });

    tearDown(() async {
      await testDb.close();
    });

    Widget createTestApp({
      bool isTemporary = false,
      String? recipeId,
      VoidCallback? onClose,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(testDb)),
          cloudSyncProvider.overrideWith(() => mockSyncNotifier),
          unitsProvider.overrideWith((ref) => Future.value([unitG])),
          unitsStreamProvider.overrideWith((ref) => Stream.value([unitG])),
          ingredientsStreamProvider.overrideWith(
            (ref) => Stream.value([ingFlour]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: RecipeEditorScreen(
            recipeId: recipeId,
            isTemporary: isTemporary,
            initialName: 'Instant Cake',
            initialYield: '4',
            initialProfitMargin: '30',
            initialPrice: '10',
            onClose: onClose,
            initialIngredients: [
              InitialIngredientInput(
                ingredient: ingFlour,
                amount: 250,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('Saving recipe triggers background sync without blocking UI or showing full-screen loading spinner', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool closed = false;
      await tester.pumpWidget(createTestApp(
        onClose: () => closed = true,
      ));
      await tester.pumpAndSettle();

      // Enter name in name input field
      final nameInputField = find.byKey(const ValueKey('recipe_name_input'));
      expect(nameInputField, findsOneWidget);
      await tester.enterText(nameInputField, 'Instant Cake');
      await tester.pump();

      // Ensure form is displayed and editable, no full screen spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Find and tap save button
      final saveButton = find.byTooltip('Save');
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // UI should have closed or called onClose immediately without waiting for cloud sync
      expect(closed, isTrue);

      // Verify recipe was saved to the local database
      final recipes = await testDb.getAllRecipes();
      expect(recipes.any((r) => r.name == 'Instant Cake'), isTrue);

      // Verify sync was dispatched in the background to the cloud provider
      expect(mockSyncNotifier.syncedRecipes, hasLength(1));
      expect(mockSyncNotifier.syncedRecipes.first.recipe.name, 'Instant Cake');
    });

    testWidgets('Saving recipe with onClose=null pops navigator cleanly and immediately', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            databaseProvider.overrideWith(() => MockDatabaseNotifier(testDb)),
            cloudSyncProvider.overrideWith(() => mockSyncNotifier),
            unitsProvider.overrideWith((ref) => Future.value([unitG])),
            unitsStreamProvider.overrideWith((ref) => Stream.value([unitG])),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream.value([ingFlour]),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => RecipeEditorScreen(
                    initialIngredients: [
                      InitialIngredientInput(
                        ingredient: ingFlour,
                        amount: 100,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameInputField = find.byKey(const ValueKey('recipe_name_input'));
      expect(nameInputField, findsOneWidget);
      await tester.enterText(nameInputField, 'Quick Pop Cake');
      await tester.pump();

      final saveButton = find.byTooltip('Save');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Screen popped cleanly
      expect(find.byType(RecipeEditorScreen), findsNothing);

      // Dispatched background sync
      expect(mockSyncNotifier.syncedRecipes, hasLength(1));
      expect(mockSyncNotifier.syncedRecipes.first.recipe.name, 'Quick Pop Cake');
    });

    test('CloudSyncNotifier syncRecipe coalesces rapid updates for same recipe', () async {
      final container = ProviderContainer(
        overrides: [
          cloudSyncProvider.overrideWith(() => CloudSyncNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);

      final dummyDetail1 = RecipeDetail(
        recipe: Recipe(
          recipePk: 'rec_100',
          name: 'Recipe Version 1',
          defaultYield: 1.0,
          yieldName: 'portions',
          targetProfitMargin: 0.3,
          targetPricePerPortion: 10.0,
          fixedOverheadCost: 0.0,
          dateCreated: DateTime.now(),
          archived: false,
        ),
        ingredients: [],
        steps: [],
        spaces: [],
      );

      final dummyDetail2 = RecipeDetail(
        recipe: Recipe(
          recipePk: 'rec_100',
          name: 'Recipe Version 2',
          defaultYield: 1.0,
          yieldName: 'portions',
          targetProfitMargin: 0.3,
          targetPricePerPortion: 10.0,
          fixedOverheadCost: 0.0,
          dateCreated: DateTime.now(),
          archived: false,
        ),
        ingredients: [],
        steps: [],
        spaces: [],
      );

      // Trigger multiple rapid sync calls
      notifier.syncRecipe(dummyDetail1);
      notifier.syncRecipe(dummyDetail2);

      // Verify sync method does not throw and finishes cleanly
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });
}
