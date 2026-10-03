import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/screens/cloud_sync_screen.dart';
import 'package:recipetools/utils/cloud_sync_service.dart';

class MockCloudSyncNotifier extends CloudSyncNotifier {
  @override
  CloudSyncState build() {
    return CloudSyncState(
      signedIn: true,
      email: 'Local Backup',
      loading: false,
      storageType: CloudSyncStorageType.localDirectory,
    );
  }

  @override
  Future<void> checkStatus() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudSyncNotifier Tests', () {
    test('Initial state uses default settings and loads successfully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial state is default
      var state = container.read(cloudSyncProvider);
      expect(state.loading, isFalse);
      expect(state.signedIn, isFalse);

      // Trigger status check
      await container.read(cloudSyncProvider.notifier).checkStatus();

      state = container.read(cloudSyncProvider);
      expect(state.loading, isFalse);

      final expectedType = container.read(googleDriveSyncServiceProvider).isDefaultSimulation
          ? CloudSyncStorageType.localDirectory
          : CloudSyncStorageType.googleDrive;
      expect(state.storageType, expectedType);
    });

    test('Switching storage type updates state and persists setting', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);

      // Switch to local directory
      await notifier.setStorageType(CloudSyncStorageType.localDirectory);

      var state = container.read(cloudSyncProvider);
      expect(state.storageType, CloudSyncStorageType.localDirectory);
      expect(state.signedIn, isTrue); // Local backup is always connected
      expect(state.email, 'Local Backup');

      // Switch to Google Drive
      await notifier.setStorageType(CloudSyncStorageType.googleDrive);

      state = container.read(cloudSyncProvider);
      expect(state.storageType, CloudSyncStorageType.googleDrive);
      expect(state.signedIn, isFalse);
      expect(state.email, isNull);
    });

    test('syncTwoWay performs initial backup when no backups exist', () async {
      final dbFile = File('db.sqlite');
      if (!await dbFile.exists()) {
        await dbFile.writeAsString('test-sqlite-data');
      }
      final mockDir = Directory('recipetools_backups');

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        if (await mockDir.exists()) {
          await mockDir.delete(recursive: true);
        }
      });

      await container.read(cloudSyncProvider.notifier).setStorageType(CloudSyncStorageType.localDirectory);

      final result = await container.read(cloudSyncProvider.notifier).syncTwoWay();
      expect(result, isNotNull);
      final state = container.read(cloudSyncProvider);
      expect(state.loading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.backups.isNotEmpty, isTrue);
    });
  });

  group('Two-Way Non-Destructive Merge (LWW) Tests', () {
    late AppDatabase localDb;
    late AppDatabase remoteDb;

    setUp(() {
      localDb = AppDatabase.forTesting(NativeDatabase.memory());
      remoteDb = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await localDb.close();
      await remoteDb.close();
    });

    test('Conflict resolution: remote newer updated_at overwrites local recipe (remote LWW)', () async {
      final now = DateTime.now();
      final olderTime = now.subtract(const Duration(hours: 2));
      final newerTime = now.subtract(const Duration(hours: 1));
      const recipePk = 'recipe-conflict-1';

      await localDb.into(localDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Local Old Name'),
          defaultYield: const drift.Value(2.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(olderTime),
        ),
      );

      await remoteDb.into(remoteDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Remote Newer Name'),
          defaultYield: const drift.Value(4.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(newerTime),
        ),
      );

      final result = await localDb.mergeWithDatabase(remoteDb);

      expect(result.recipesUpdated, 1);
      expect(result.recipesKeptLocal, 0);

      final updatedLocal = await (localDb.select(localDb.recipes)
            ..where((t) => t.recipePk.equals(recipePk)))
          .getSingle();
      expect(updatedLocal.name, 'Remote Newer Name');
      expect(updatedLocal.defaultYield, 4.0);
    });

    test('Conflict resolution: local newer updated_at is preserved and not overwritten', () async {
      final now = DateTime.now();
      final olderTime = now.subtract(const Duration(hours: 2));
      final newerTime = now.subtract(const Duration(hours: 1));
      const recipePk = 'recipe-conflict-2';

      await localDb.into(localDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Local Newer Edits'),
          defaultYield: const drift.Value(6.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(newerTime),
        ),
      );

      await remoteDb.into(remoteDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Remote Older Version'),
          defaultYield: const drift.Value(2.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(olderTime),
        ),
      );

      final result = await localDb.mergeWithDatabase(remoteDb);

      expect(result.recipesUpdated, 0);
      expect(result.recipesKeptLocal, 1);

      final preservedLocal = await (localDb.select(localDb.recipes)
            ..where((t) => t.recipePk.equals(recipePk)))
          .getSingle();
      expect(preservedLocal.name, 'Local Newer Edits');
      expect(preservedLocal.defaultYield, 6.0);
    });

    test('Non-destructive: remote-only recipes added and local-only recipes preserved', () async {
      await localDb.into(localDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value('recipe-local-only'),
          name: const drift.Value('Local Only Recipe'),
          defaultYield: const drift.Value(1.0),
          yieldName: const drift.Value('portions'),
        ),
      );

      await remoteDb.into(remoteDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value('recipe-remote-only'),
          name: const drift.Value('Remote Only Recipe'),
          defaultYield: const drift.Value(1.0),
          yieldName: const drift.Value('portions'),
        ),
      );

      final result = await localDb.mergeWithDatabase(remoteDb);

      expect(result.recipesAdded, 1);
      final allLocal = await localDb.getAllRecipes();
      expect(allLocal.length, 2);
      final names = allLocal.map((r) => r.name).toList();
      expect(names, contains('Local Only Recipe'));
      expect(names, contains('Remote Only Recipe'));
    });

    test('Full recipe sync: ingredients, recipe ingredients, and steps updated on remote win', () async {
      final now = DateTime.now();
      const recipePk = 'recipe-full-sync';
      const localIngPk = 'ing-local';
      const remoteIngPk = 'ing-remote';
      const unitPk = 'unit-test-1';

      await localDb.into(localDb.units).insert(
        UnitsCompanion(
          unitPk: const drift.Value(unitPk),
          name: const drift.Value('test_unit'),
          symbol: const drift.Value('tu'),
        ),
      );
      await remoteDb.into(remoteDb.units).insert(
        UnitsCompanion(
          unitPk: const drift.Value(unitPk),
          name: const drift.Value('test_unit'),
          symbol: const drift.Value('tu'),
        ),
      );

      await localDb.into(localDb.ingredients).insert(
        IngredientsCompanion(
          ingredientPk: const drift.Value(localIngPk),
          name: const drift.Value('Local Ingredient'),
          cost: const drift.Value(10.0),
          quantityForCost: const drift.Value(1.0),
          unitFk: const drift.Value(unitPk),
        ),
      );
      await remoteDb.into(remoteDb.ingredients).insert(
        IngredientsCompanion(
          ingredientPk: const drift.Value(remoteIngPk),
          name: const drift.Value('Remote Ingredient'),
          cost: const drift.Value(20.0),
          quantityForCost: const drift.Value(1.0),
          unitFk: const drift.Value(unitPk),
        ),
      );

      await localDb.into(localDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Pie'),
          defaultYield: const drift.Value(1.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(now.subtract(const Duration(hours: 2))),
        ),
      );
      await localDb.into(localDb.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: recipePk,
          ingredientFk: localIngPk,
          amountNeeded: 100.0,
        ),
      );
      await localDb.into(localDb.recipeSteps).insert(
        RecipeStepsCompanion.insert(
          recipeFk: recipePk,
          stepNumber: 1,
          instruction: 'Old step',
        ),
      );

      await remoteDb.into(remoteDb.recipes).insert(
        RecipesCompanion(
          recipePk: const drift.Value(recipePk),
          name: const drift.Value('Pie Updated'),
          defaultYield: const drift.Value(2.0),
          yieldName: const drift.Value('portions'),
          dateTimeModified: drift.Value(now.subtract(const Duration(hours: 1))),
        ),
      );
      await remoteDb.into(remoteDb.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: recipePk,
          ingredientFk: remoteIngPk,
          amountNeeded: 250.0,
        ),
      );
      await remoteDb.into(remoteDb.recipeSteps).insert(
        RecipeStepsCompanion.insert(
          recipeFk: recipePk,
          stepNumber: 1,
          instruction: 'New improved step',
        ),
      );

      final result = await localDb.mergeWithDatabase(remoteDb);

      expect(result.recipesUpdated, 1);
      expect(result.ingredientsAdded, 1);

      final detail = await localDb.getRecipeDetail(recipePk);
      expect(detail.recipe.name, 'Pie Updated');
      expect(detail.ingredients.length, 1);
      expect(detail.ingredients.first.ingredient.name, 'Remote Ingredient');
      expect(detail.ingredients.first.entry.amountNeeded, 250.0);
      expect(detail.steps.length, 1);
      expect(detail.steps.first.instruction, 'New improved step');
    });
  });

  group('CloudSyncScreen Widget Tests', () {
    testWidgets('Renders Two-Way Cloud Sync button and opens confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncProvider.overrideWith(MockCloudSyncNotifier.new),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CloudSyncScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final syncButton = find.widgetWithText(ElevatedButton, 'Two-Way Cloud Sync');
      expect(syncButton, findsOneWidget);

      await tester.tap(syncButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
