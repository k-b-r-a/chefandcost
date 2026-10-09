import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/screens/cloud_sync_screen.dart';
import 'package:recipetools/utils/cloud_sync_service.dart';
import 'package:recipetools/utils/firestore_sync_service.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirestoreCloudSyncNotifier extends CloudSyncNotifier {
  @override
  CloudSyncState build() {
    return CloudSyncState(
      signedIn: true,
      email: 'Sync ID: user-test-123',
      loading: false,
      storageType: CloudSyncStorageType.firestore,
    );
  }

  @override
  Future<void> checkStatus() async {}
}

class MockFirestoreLoggedOutCloudSyncNotifier extends CloudSyncNotifier {
  @override
  CloudSyncState build() {
    return CloudSyncState(
      signedIn: false,
      email: null,
      loading: false,
      storageType: CloudSyncStorageType.firestore,
    );
  }

  @override
  Future<void> checkStatus() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Firestore Serialization & Deserialization Tests', () {
    test('recipeToFirestore embeds ingredients and steps correctly', () {
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);
      final recipe = Recipe(
        recipePk: 'rec-1',
        name: 'Croissant',
        description: 'Flaky pastry',
        defaultYield: 6.0,
        yieldName: 'pieces',
        targetProfitMargin: 0.65,
        targetPricePerPortion: 3.5,
        fixedOverheadCost: 0.5,
        colour: '#FFB800',
        dateCreated: now,
        dateTimeModified: now.add(const Duration(hours: 1)),
        archived: false,
      );

      final ingredient = Ingredient(
        ingredientPk: 'ing-1',
        name: 'Butter',
        cost: 4.5,
        quantityForCost: 250.0,
        unitFk: 'unit-g',
        dateCreated: now,
        dateTimeModified: null,
      );

      final recipeIngredient = RecipeIngredient(
        recipeIngredientPk: 'ri-1',
        recipeFk: 'rec-1',
        ingredientFk: 'ing-1',
        amountNeeded: 200.0,
        dateTimeModified: now,
      );

      final step = RecipeStep(
        stepPk: 'step-1',
        recipeFk: 'rec-1',
        stepNumber: 1,
        instruction: 'Laminate dough with butter block',
        dateTimeModified: now,
      );

      final detail = RecipeDetail(
        recipe: recipe,
        ingredients: [
          RecipeIngredientWithData(entry: recipeIngredient, ingredient: ingredient),
        ],
        steps: [step],
      );

      final firestoreMap = FirestoreSyncService.recipeToFirestore(detail);

      expect(firestoreMap['recipePk'], 'rec-1');
      expect(firestoreMap['name'], 'Croissant');
      expect(firestoreMap['defaultYield'], 6.0);
      expect(firestoreMap['ingredients'], hasLength(1));
      expect(firestoreMap['ingredients'][0]['recipeIngredientPk'], 'ri-1');
      expect(firestoreMap['ingredients'][0]['amountNeeded'], 200.0);
      expect(firestoreMap['ingredients'][0]['name'], 'Butter');
      expect(firestoreMap['ingredients'][0]['cost'], 4.5);
      expect(firestoreMap['ingredients'][0]['unitFk'], 'unit-g');
      expect(firestoreMap['steps'], hasLength(1));
      expect(firestoreMap['steps'][0]['stepPk'], 'step-1');
      expect(firestoreMap['steps'][0]['instruction'], 'Laminate dough with butter block');
      expect(firestoreMap['updatedAt'], isA<Timestamp>());
    });

    test('recipeFromFirestore restores Recipe, ingredients, and steps exactly', () {
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);
      final map = {
        'recipePk': 'rec-2',
        'name': 'Baguette',
        'description': 'Crispy crust',
        'defaultYield': 2.0,
        'yieldName': 'loaves',
        'targetProfitMargin': 0.7,
        'targetPricePerPortion': 2.0,
        'fixedOverheadCost': 0.2,
        'colour': '#A0522D',
        'dateCreated': now.toIso8601String(),
        'dateTimeModified': now.add(const Duration(minutes: 30)).toIso8601String(),
        'archived': false,
        'ingredients': [
          {
            'recipeIngredientPk': 'ri-bag-1',
            'recipeFk': 'rec-2',
            'ingredientFk': 'ing-flour',
            'amountNeeded': 500.0,
            'dateTimeModified': now.toIso8601String(),
          }
        ],
        'steps': [
          {
            'stepPk': 'st-bag-1',
            'recipeFk': 'rec-2',
            'stepNumber': 1,
            'instruction': 'Knead and bulk ferment for 4 hours',
            'dateTimeModified': now.toIso8601String(),
          }
        ],
      };

      final parsed = FirestoreSyncService.recipeFromFirestore(map);

      expect(parsed.recipe.recipePk, 'rec-2');
      expect(parsed.recipe.name, 'Baguette');
      expect(parsed.recipe.defaultYield, 2.0);
      expect(parsed.ingredients, hasLength(1));
      expect(parsed.ingredients.first.recipeIngredientPk, 'ri-bag-1');
      expect(parsed.ingredients.first.amountNeeded, 500.0);
      expect(parsed.steps, hasLength(1));
      expect(parsed.steps.first.stepPk, 'st-bag-1');
      expect(parsed.steps.first.instruction, 'Knead and bulk ferment for 4 hours');
    });

    test('ingredient and unit serialization/deserialization', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final ing = Ingredient(
        ingredientPk: 'ing-sugar',
        name: 'White Sugar',
        cost: 2.0,
        quantityForCost: 1000.0,
        unitFk: 'unit-g',
        dateCreated: now,
        dateTimeModified: now.add(const Duration(days: 2)),
      );

      final ingMap = FirestoreSyncService.ingredientToFirestore(ing);
      final parsedIng = FirestoreSyncService.ingredientFromFirestore(ingMap);

      expect(parsedIng.ingredientPk, 'ing-sugar');
      expect(parsedIng.name, 'White Sugar');
      expect(parsedIng.cost, 2.0);
      expect(parsedIng.quantityForCost, 1000.0);

      final unit = Unit(
        unitPk: 'unit-pinch',
        name: 'Pinch',
        symbol: 'pn',
        category: 'mass',
        factorToBase: 0.36,
        isMutable: true,
      );

      final unitMap = FirestoreSyncService.unitToFirestore(unit);
      final parsedUnit = FirestoreSyncService.unitFromFirestore(unitMap);

      expect(parsedUnit.unitPk, 'unit-pinch');
      expect(parsedUnit.name, 'Pinch');
      expect(parsedUnit.symbol, 'pn');
      expect(parsedUnit.factorToBase, 0.36);
      expect(parsedUnit.isMutable, isTrue);
    });
  });

  group('Database Differential and LWW Remote Merge Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Differential query getAllRecipeDetails filters by modifiedSince', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 2, 1);
      final t3 = DateTime.utc(2026, 3, 1);

      await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-old',
          name: 'Old Recipe',
          defaultYield: 1,
          yieldName: 'portion',
          targetProfitMargin: 0,
          targetPricePerPortion: 0,
          fixedOverheadCost: 0,
          dateCreated: t1,
          dateTimeModified: t1,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [],
      );

      await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-new',
          name: 'New Recipe',
          defaultYield: 1,
          yieldName: 'portion',
          targetProfitMargin: 0,
          targetPricePerPortion: 0,
          fixedOverheadCost: 0,
          dateCreated: t1,
          dateTimeModified: t3,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [],
      );

      // Query since t2
      final differentialList = await db.getAllRecipeDetails(modifiedSince: t2);
      expect(differentialList.map((d) => d.recipe.recipePk).toList(), ['rec-new']);

      // Query all (no filter)
      final allList = await db.getAllRecipeDetails();
      expect(allList.length, 2);
    });

    test('mergeRecipeFromRemote respects LWW: updates when remote is newer', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 2, 1);

      // 1. Initial local record
      await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-lww',
          name: 'Local Version',
          defaultYield: 1,
          yieldName: 'portion',
          targetProfitMargin: 0,
          targetPricePerPortion: 0,
          fixedOverheadCost: 0,
          dateCreated: t1,
          dateTimeModified: t1,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [],
      );

      // 2. Remote update with newer timestamp (t2 > t1)
      final res = await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-lww',
          name: 'Remote Newer Version',
          defaultYield: 4,
          yieldName: 'portions',
          targetProfitMargin: 0.5,
          targetPricePerPortion: 10,
          fixedOverheadCost: 1,
          dateCreated: t1,
          dateTimeModified: t2,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [
          RecipeStep(
            stepPk: 'step-new',
            recipeFk: 'rec-lww',
            stepNumber: 1,
            instruction: 'New remote step',
            dateTimeModified: t2,
          ),
        ],
      );

      expect(res, 2); // 2 indicates updated
      final updated = await db.getRecipeDetail('rec-lww');
      expect(updated.recipe.name, 'Remote Newer Version');
      expect(updated.steps, hasLength(1));
      expect(updated.steps.first.instruction, 'New remote step');
    });

    test('mergeRecipeFromRemote respects LWW: preserves local when local is newer', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t3 = DateTime.utc(2026, 3, 1);

      // 1. Local record with newer edit (t3)
      await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-local-newer',
          name: 'Local Fresh Edit',
          defaultYield: 2,
          yieldName: 'portions',
          targetProfitMargin: 0,
          targetPricePerPortion: 0,
          fixedOverheadCost: 0,
          dateCreated: t1,
          dateTimeModified: t3,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [],
      );

      // 2. Incoming older remote edit (t1)
      final res = await db.mergeRecipeFromRemote(
        remoteRecipe: Recipe(
          recipePk: 'rec-local-newer',
          name: 'Older Remote Edit',
          defaultYield: 1,
          yieldName: 'portion',
          targetProfitMargin: 0,
          targetPricePerPortion: 0,
          fixedOverheadCost: 0,
          dateCreated: t1,
          dateTimeModified: t1,
          archived: false,
        ),
        remoteIngredients: [],
        remoteSteps: [],
      );

      expect(res, 0); // 0 indicates kept local
      final detail = await db.getRecipeDetail('rec-local-newer');
      expect(detail.recipe.name, 'Local Fresh Edit');
    });

    test('mergeIngredientFromRemote preserves newer local edits', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 2, 1);

      // Add default unit for foreign key constraint
      await db.mergeUnitFromRemote(Unit(
        unitPk: 'unit-kg',
        name: 'Kilogram',
        symbol: 'kg',
        category: 'mass',
        factorToBase: 1000,
        isMutable: false,
      ));

      // Local newer ingredient
      await db.mergeIngredientFromRemote(Ingredient(
        ingredientPk: 'ing-salt',
        name: 'Local Premium Salt',
        cost: 5.0,
        quantityForCost: 1.0,
        unitFk: 'unit-kg',
        dateCreated: t1,
        dateTimeModified: t2,
      ));

      // Older remote edit
      final res = await db.mergeIngredientFromRemote(Ingredient(
        ingredientPk: 'ing-salt',
        name: 'Older Remote Salt',
        cost: 2.0,
        quantityForCost: 1.0,
        unitFk: 'unit-kg',
        dateCreated: t1,
        dateTimeModified: t1,
      ));

      expect(res, 0);
      final ing = await db.getIngredientById('ing-salt');
      expect(ing?.name, 'Local Premium Salt');
      expect(ing?.cost, 5.0);
    });

    test('mergeRecipeFromRemote upserts nestedIngredients and getRecipeDetail loads them', () async {
      final now = DateTime.utc(2026, 4, 1);
      final remoteRecipe = Recipe(
        recipePk: 'rec-nested',
        name: 'Cookie Recipe',
        defaultYield: 12,
        yieldName: 'cookies',
        targetProfitMargin: 0.5,
        targetPricePerPortion: 1.5,
        fixedOverheadCost: 0.1,
        dateCreated: now,
        dateTimeModified: now,
        archived: false,
      );

      final remoteIngredient = RecipeIngredient(
        recipeIngredientPk: 'ri-cookie-1',
        recipeFk: 'rec-nested',
        ingredientFk: 'ing-choc-chips',
        amountNeeded: 150.0,
        dateTimeModified: now,
      );

      final nestedIngredient = Ingredient(
        ingredientPk: 'ing-choc-chips',
        name: 'Chocolate Chips',
        cost: 3.0,
        quantityForCost: 200.0,
        unitFk: 'unit-g',
        dateCreated: now,
        dateTimeModified: now,
      );

      await db.mergeRecipeFromRemote(
        remoteRecipe: remoteRecipe,
        remoteIngredients: [remoteIngredient],
        remoteSteps: [],
        nestedIngredients: [nestedIngredient],
      );

      final detail = await db.getRecipeDetail('rec-nested');
      expect(detail.ingredients, hasLength(1));
      expect(detail.ingredients.first.ingredient.name, 'Chocolate Chips');
      expect(detail.ingredients.first.entry.amountNeeded, 150.0);
    });

    test('RecipeUtils.saveRecipe updates ingredient dateTimeModified and returns complete detail', () async {
      final now = DateTime.utc(2026, 1, 1);
      final ingredient = Ingredient(
        ingredientPk: 'ing-flour-test',
        name: 'Flour',
        cost: 2.0,
        quantityForCost: 1000.0,
        unitFk: 'unit-g',
        dateCreated: now,
        dateTimeModified: now,
      );
      await db.into(db.ingredients).insert(ingredient);

      final ingData = RecipeIngredientData(
        ingredient: ingredient,
        initialAmount: '350',
      );

      final detail = await RecipeUtils.saveRecipe(
        db: db,
        name: 'Pancake',
        description: 'Fluffy pancakes',
        yieldText: '4',
        yieldName: 'portions',
        profitMarginText: '50',
        priceText: '2.5',
        ingredients: [ingData],
        steps: [],
      );

      expect(detail.recipe.name, 'Pancake');
      expect(detail.ingredients, hasLength(1));
      expect(detail.ingredients.first.ingredient.name, 'Flour');
      expect(detail.ingredients.first.entry.amountNeeded, 350.0);

      final dbIng = await db.getIngredientById('ing-flour-test');
      expect(dbIng?.dateTimeModified, isNotNull);
      expect(dbIng!.dateTimeModified!.isAfter(now), isTrue);
    });

    test('mergeIngredientFromRemote safely auto-creates missing unit to avoid FK failure', () async {
      final now = DateTime.utc(2026, 5, 1);
      final ingredientWithUnknownUnit = Ingredient(
        ingredientPk: 'ing-mystery',
        name: 'Mystery Ingredient',
        cost: 10.0,
        quantityForCost: 1.0,
        unitFk: 'unit-unknown-uuid-1234',
        dateCreated: now,
        dateTimeModified: now,
      );

      // Should not throw SqliteException for foreign key violation
      final res = await db.mergeIngredientFromRemote(ingredientWithUnknownUnit);
      expect(res, 1);

      final inserted = await db.getIngredientById('ing-mystery');
      expect(inserted, isNotNull);
      expect(inserted?.name, 'Mystery Ingredient');

      // The unit should have been created as a stub to satisfy the FK constraint
      final unit = (await (db.select(db.units)..where((t) => t.unitPk.equals('unit-unknown-uuid-1234'))).get()).firstOrNull;
      expect(unit, isNotNull);
    });

    test('mergeIngredientFromRemote does not throw Too many elements when multiple units share symbol g', () async {
      final now = DateTime.utc(2026, 5, 1);
      // Insert duplicate units with symbol 'g' (e.g. from sync or custom units)
      await db.into(db.units).insert(
        UnitsCompanion(
          unitPk: const Value('unit-g-device-1'),
          name: const Value('unit_grams'),
          symbol: const Value('g'),
          category: const Value('mass'),
          factorToBase: const Value(1.0),
          isMutable: const Value(false),
        ),
      );
      await db.into(db.units).insert(
        UnitsCompanion(
          unitPk: const Value('unit-g-device-2'),
          name: const Value('Custom Grams'),
          symbol: const Value('g'),
          category: const Value('mass'),
          factorToBase: const Value(1.0),
          isMutable: const Value(true),
        ),
      );

      final ingredientWithUnknownUnit = Ingredient(
        ingredientPk: 'ing-multi-g-test',
        name: 'Sugar Multi Unit',
        cost: 5.0,
        quantityForCost: 1.0,
        unitFk: 'unit-not-existing-yet',
        dateCreated: now,
        dateTimeModified: now,
      );

      // Should safely pick first matching unit without throwing "Too many elements"
      final res = await db.mergeIngredientFromRemote(ingredientWithUnknownUnit);
      expect(res, 1);
    });

    test('mergeRecipeFromRemote safely auto-creates missing ingredient stub to avoid FK failure', () async {
      final now = DateTime.utc(2026, 5, 1);
      final remoteRecipe = Recipe(
        recipePk: 'rec-orphan-ing',
        name: 'Orphan Ingredient Recipe',
        defaultYield: 2,
        yieldName: 'portions',
        targetProfitMargin: 0.3,
        targetPricePerPortion: 5.0,
        fixedOverheadCost: 0.0,
        dateCreated: now,
        dateTimeModified: now,
        archived: false,
      );

      final orphanRi = RecipeIngredient(
        recipeIngredientPk: 'ri-orphan-1',
        recipeFk: 'rec-orphan-ing',
        ingredientFk: 'ing-nonexistent-9999',
        amountNeeded: 50.0,
        dateTimeModified: now,
      );

      // Should not throw SqliteException for foreign key violation even without nestedIngredients
      final res = await db.mergeRecipeFromRemote(
        remoteRecipe: remoteRecipe,
        remoteIngredients: [orphanRi],
        remoteSteps: [],
      );
      expect(res, 1);

      final detail = await db.getRecipeDetail('rec-orphan-ing');
      expect(detail.recipe.name, 'Orphan Ingredient Recipe');
      expect(detail.ingredients, hasLength(1));
      expect(detail.ingredients.first.entry.ingredientFk, 'ing-nonexistent-9999');
    });

    test('recipeFromFirestore and ingredientFromFirestore handle Timestamps, nulls and missing fields safely', () {
      final now = DateTime.utc(2026, 5, 1);
      final rawFirestoreDoc = {
        'recipePk': 'rec-corrupted',
        'name': 'Resilient Recipe',
        'defaultYield': 4, // int instead of double
        'yieldName': null,
        'targetProfitMargin': null,
        'targetPricePerPortion': null,
        'fixedOverheadCost': null,
        'colour': null,
        'dateCreated': Timestamp.fromDate(now), // Timestamp instead of String
        'dateTimeModified': null,
        'ingredients': [
          {
            'recipeIngredientPk': null,
            'recipeFk': null,
            'ingredientFk': 'ing-raw-1',
            'amountNeeded': 100, // int instead of double
            'dateTimeModified': null,
            'ingredient': {
              'ingredientPk': 'ing-raw-1',
              'name': 'Raw Sugar',
              'cost': null,
              'quantityForCost': null,
              'unitFk': null,
              'dateCreated': Timestamp.fromDate(now),
              'dateTimeModified': null,
            },
          },
        ],
        'steps': [
          {
            'stepPk': null,
            'recipeFk': null,
            'stepNumber': null,
            'instruction': null,
            'dateTimeModified': null,
          },
        ],
      };

      final parsed = FirestoreSyncService.recipeFromFirestore(rawFirestoreDoc);
      expect(parsed.recipe.recipePk, 'rec-corrupted');
      expect(parsed.recipe.name, 'Resilient Recipe');
      expect(parsed.recipe.defaultYield, 4.0);
      expect(parsed.recipe.yieldName, 'porciones');
      expect(parsed.recipe.targetProfitMargin, 0.0);
      expect(parsed.recipe.dateCreated.toUtc(), now.toUtc());
      expect(parsed.ingredients, hasLength(1));
      expect(parsed.ingredients.first.amountNeeded, 100.0);
      expect(parsed.nestedIngredients, hasLength(1));
      expect(parsed.nestedIngredients.first.name, 'Raw Sugar');
      expect(parsed.nestedIngredients.first.cost, 0.0);
      expect(parsed.steps, hasLength(1));
      expect(parsed.steps.first.instruction, '');
    });
  });

  group('Firestore User & Sync Preferences Tests', () {
    test('Setting and clearing custom sync user ID', () async {
      final service = FirestoreSyncService();

      expect(await service.getActiveUserId(), isNull);

      await service.setCustomUserId('device-pair-777');
      expect(await service.getActiveUserId(), 'device-pair-777');

      await service.clearCustomUserId();
      expect(await service.getActiveUserId(), isNull);
    });
  });

  group('CloudSyncScreen Firestore UI Integration', () {
    testWidgets('Selecting Firestore tab when signed in displays profile card and sync info', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncProvider.overrideWith(MockFirestoreCloudSyncNotifier.new),
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

      // Verify Firestore connected card elements appear
      expect(find.textContaining('Connected to Firestore'), findsOneWidget);
      expect(find.textContaining('Sync ID: user-test-123'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verify sync action button is visible
      expect(find.textContaining('Sync Now'), findsOneWidget);
    });

    testWidgets('Selecting Firestore tab when NOT signed in displays inline Auth Card with Google & Email', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncProvider.overrideWith(MockFirestoreLoggedOutCloudSyncNotifier.new),
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

      // Verify inline auth card elements appear
      expect(find.text('Connect Your Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign In'), findsNWidgets(2)); // Segmented toggle & submit button
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);

      // Tap 'Create Account' in segmented button
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Forgot password link should disappear in Register mode
      expect(find.text('Forgot password?'), findsNothing);

      // Trigger submit with empty fields to verify inline error validation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });
  });
}
