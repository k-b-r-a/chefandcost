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
      hasAcceptedTerms: true,
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
        isDeleted: false,
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
          RecipeIngredientWithData(
            entry: recipeIngredient,
            ingredient: ingredient,
          ),
        ],
        steps: [step],
        spaceIds: const ['space-baru', 'space-kitchen'],
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
      expect(
        firestoreMap['steps'][0]['instruction'],
        'Laminate dough with butter block',
      );
      expect(firestoreMap['space_ids'], ['space-baru', 'space-kitchen']);
      expect(firestoreMap['updatedAt'], isA<Timestamp>());
    });

    test(
      'recipeFromFirestore restores Recipe, ingredients, and steps exactly',
      () {
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
          'dateTimeModified': now
              .add(const Duration(minutes: 30))
              .toIso8601String(),
          'archived': false,
          'ingredients': [
            {
              'recipeIngredientPk': 'ri-bag-1',
              'recipeFk': 'rec-2',
              'ingredientFk': 'ing-flour',
              'amountNeeded': 500.0,
              'dateTimeModified': now.toIso8601String(),
            },
          ],
          'steps': [
            {
              'stepPk': 'st-bag-1',
              'recipeFk': 'rec-2',
              'stepNumber': 1,
              'instruction': 'Knead and bulk ferment for 4 hours',
              'dateTimeModified': now.toIso8601String(),
            },
          ],
          'space_ids': ['space-baru', 'space-kitchen'],
        };

        final parsed = FirestoreSyncService.recipeFromFirestore(map);

        expect(parsed.recipe.recipePk, 'rec-2');
        expect(parsed.recipe.name, 'Baguette');
        expect(parsed.recipe.defaultYield, 2.0);
        expect(parsed.ingredients, hasLength(1));
        expect(parsed.ingredients.first.recipeIngredientPk, 'ri-bag-1');
        expect(parsed.ingredients.first.amountNeeded, 500.0);
        expect(parsed.steps, hasLength(1));
        expect(parsed.spaceIds, ['space-baru', 'space-kitchen']);
        expect(parsed.steps.first.stepPk, 'st-bag-1');
        expect(
          parsed.steps.first.instruction,
          'Knead and bulk ferment for 4 hours',
        );
      },
    );

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
        isDeleted: false,
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

    test(
      'Differential query getAllRecipeDetails filters by modifiedSince',
      () async {
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
        final differentialList = await db.getAllRecipeDetails(
          modifiedSince: t2,
        );
        expect(differentialList.map((d) => d.recipe.recipePk).toList(), [
          'rec-new',
        ]);

        // Query all (no filter)
        final allList = await db.getAllRecipeDetails();
        expect(allList.length, 2);
      },
    );

    test(
      'mergeRecipeFromRemote respects LWW: updates when remote is newer',
      () async {
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
      },
    );

    test(
      'mergeRecipeFromRemote respects LWW: preserves local when local is newer',
      () async {
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
      },
    );

    test('mergeIngredientFromRemote preserves newer local edits', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 2, 1);

      // Add default unit for foreign key constraint
      await db.mergeUnitFromRemote(
        Unit(
          unitPk: 'unit-kg',
          name: 'Kilogram',
          symbol: 'kg',
          category: 'mass',
          factorToBase: 1000,
          isMutable: false,
        ),
      );

      // Local newer ingredient
      await db.mergeIngredientFromRemote(
        Ingredient(
          ingredientPk: 'ing-salt',
          name: 'Local Premium Salt',
          cost: 5.0,
          quantityForCost: 1.0,
          unitFk: 'unit-kg',
          dateCreated: t1,
          dateTimeModified: t2,
          isDeleted: false,
        ),
      );

      // Older remote edit
      final res = await db.mergeIngredientFromRemote(
        Ingredient(
          ingredientPk: 'ing-salt',
          name: 'Older Remote Salt',
          cost: 2.0,
          quantityForCost: 1.0,
          unitFk: 'unit-kg',
          dateCreated: t1,
          dateTimeModified: t1,
          isDeleted: false,
        ),
      );

      expect(res, 0);
      final ing = await db.getIngredientById('ing-salt');
      expect(ing?.name, 'Local Premium Salt');
      expect(ing?.cost, 5.0);
    });

    test(
      'mergeRecipeFromRemote upserts nestedIngredients and getRecipeDetail loads them',
      () async {
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
          isDeleted: false,
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
      },
    );

    test(
      'RecipeUtils.saveRecipe updates ingredient dateTimeModified and returns complete detail',
      () async {
        final now = DateTime.utc(2026, 1, 1);
        final ingredient = Ingredient(
          ingredientPk: 'ing-flour-test',
          name: 'Flour',
          cost: 2.0,
          quantityForCost: 1000.0,
          unitFk: 'unit-g',
          dateCreated: now,
          dateTimeModified: now,
          isDeleted: false,
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
      },
    );

    test(
      'mergeIngredientFromRemote safely auto-creates missing unit to avoid FK failure',
      () async {
        final now = DateTime.utc(2026, 5, 1);
        final ingredientWithUnknownUnit = Ingredient(
          ingredientPk: 'ing-mystery',
          name: 'Mystery Ingredient',
          cost: 10.0,
          quantityForCost: 1.0,
          unitFk: 'unit-unknown-uuid-1234',
          dateCreated: now,
          dateTimeModified: now,
          isDeleted: false,
        );

        // Should not throw SqliteException for foreign key violation
        final res = await db.mergeIngredientFromRemote(
          ingredientWithUnknownUnit,
        );
        expect(res, 1);

        final inserted = await db.getIngredientById('ing-mystery');
        expect(inserted, isNotNull);
        expect(inserted?.name, 'Mystery Ingredient');

        // The unit should have been created as a stub to satisfy the FK constraint
        final unit =
            (await (db.select(db.units)
                      ..where((t) => t.unitPk.equals('unit-unknown-uuid-1234')))
                    .get())
                .firstOrNull;
        expect(unit, isNotNull);
      },
    );

    test(
      'mergeIngredientFromRemote does not throw Too many elements when multiple units share symbol g',
      () async {
        final now = DateTime.utc(2026, 5, 1);
        // Insert duplicate units with symbol 'g' (e.g. from sync or custom units)
        await db
            .into(db.units)
            .insert(
              UnitsCompanion(
                unitPk: const Value('unit-g-device-1'),
                name: const Value('unit_grams'),
                symbol: const Value('g'),
                category: const Value('mass'),
                factorToBase: const Value(1.0),
                isMutable: const Value(false),
              ),
            );
        await db
            .into(db.units)
            .insert(
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
          isDeleted: false,
        );

        // Should safely pick first matching unit without throwing "Too many elements"
        final res = await db.mergeIngredientFromRemote(
          ingredientWithUnknownUnit,
        );
        expect(res, 1);
      },
    );

    test(
      'mergeRecipeFromRemote safely auto-creates missing ingredient stub to avoid FK failure',
      () async {
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
        expect(
          detail.ingredients.first.entry.ingredientFk,
          'ing-nonexistent-9999',
        );
      },
    );

    test(
      'recipeFromFirestore and ingredientFromFirestore handle Timestamps, nulls and missing fields safely',
      () {
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

        final parsed = FirestoreSyncService.recipeFromFirestore(
          rawFirestoreDoc,
        );
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
      },
    );
  });

  group('Soft Delete Repository and DAO Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'deleteIngredient soft-deletes ingredient and sets deletedAt and dateTimeModified',
      () async {
        final now = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final ing = Ingredient(
          ingredientPk: 'ing-soft-1',
          name: 'Fresh Basil',
          cost: 1.5,
          quantityForCost: 50.0,
          unitFk: 'unit-g',
          dateCreated: now,
          isDeleted: false,
        );
        await db.into(db.ingredients).insert(ing);

        final beforeDelete = await db.getAllIngredients();
        expect(beforeDelete.any((i) => i.ingredientPk == 'ing-soft-1'), isTrue);

        await db.deleteIngredient(ing);

        final afterDelete = await db.getAllIngredients();
        expect(afterDelete.any((i) => i.ingredientPk == 'ing-soft-1'), isFalse);

        final allIncludingDeleted = await db.getAllIngredients(
          includeDeleted: true,
        );
        final deletedIng = allIncludingDeleted.firstWhere(
          (i) => i.ingredientPk == 'ing-soft-1',
        );
        expect(deletedIng.isDeleted, isTrue);
        expect(deletedIng.deletedAt, isNotNull);
        expect(deletedIng.dateTimeModified, isNotNull);
      },
    );

    test('restoreIngredient reactivates soft-deleted ingredient', () async {
      final now = DateTime.utc(2026, 6, 1, 10, 0, 0);
      final ing = Ingredient(
        ingredientPk: 'ing-soft-restore',
        name: 'Rosemary',
        cost: 2.0,
        quantityForCost: 30.0,
        unitFk: 'unit-g',
        dateCreated: now,
        isDeleted: true,
        deletedAt: now,
      );
      await db.into(db.ingredients).insert(ing);

      expect(await db.getIngredientById('ing-soft-restore'), isNull);

      await db.restoreIngredient('ing-soft-restore');

      final restored = await db.getIngredientById('ing-soft-restore');
      expect(restored, isNotNull);
      expect(restored!.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test(
      'watchAllIngredients emits only non-deleted ingredients by default',
      () async {
        final now = DateTime.utc(2026, 6, 1);
        await db
            .into(db.ingredients)
            .insert(
              Ingredient(
                ingredientPk: 'ing-stream-act',
                name: 'Thyme Active',
                cost: 1.0,
                quantityForCost: 20.0,
                unitFk: 'unit-g',
                dateCreated: now,
                isDeleted: false,
              ),
            );
        await db
            .into(db.ingredients)
            .insert(
              Ingredient(
                ingredientPk: 'ing-stream-del',
                name: 'Thyme Deleted',
                cost: 1.0,
                quantityForCost: 20.0,
                unitFk: 'unit-g',
                dateCreated: now,
                isDeleted: true,
                deletedAt: now,
              ),
            );

        final activeList = await db.watchAllIngredients().first;
        expect(
          activeList.any((i) => i.ingredientPk == 'ing-stream-act'),
          isTrue,
        );
        expect(
          activeList.any((i) => i.ingredientPk == 'ing-stream-del'),
          isFalse,
        );

        final allList = await db
            .watchAllIngredients(includeDeleted: true)
            .first;
        expect(allList.any((i) => i.ingredientPk == 'ing-stream-del'), isTrue);
      },
    );

    test('searchIngredients excludes soft-deleted ingredients', () async {
      final now = DateTime.utc(2026, 6, 1);
      await db
          .into(db.ingredients)
          .insert(
            Ingredient(
              ingredientPk: 'ing-search-1',
              name: 'Matcha Powder Active',
              cost: 10.0,
              quantityForCost: 100.0,
              unitFk: 'unit-g',
              dateCreated: now,
              isDeleted: false,
            ),
          );
      await db
          .into(db.ingredients)
          .insert(
            Ingredient(
              ingredientPk: 'ing-search-2',
              name: 'Matcha Powder Deleted',
              cost: 10.0,
              quantityForCost: 100.0,
              unitFk: 'unit-g',
              dateCreated: now,
              isDeleted: true,
              deletedAt: now,
            ),
          );

      final searchResults = await db.searchIngredients('Matcha').first;
      expect(
        searchResults.any((i) => i.ingredientPk == 'ing-search-1'),
        isTrue,
      );
      expect(
        searchResults.any((i) => i.ingredientPk == 'ing-search-2'),
        isFalse,
      );
    });

    test(
      'getRecipeDetail retains soft-deleted ingredients for display',
      () async {
        final now = DateTime.utc(2026, 6, 1);
        final rec = Recipe(
          recipePk: 'rec-detail-filter',
          name: 'Filtered Recipe',
          defaultYield: 1.0,
          yieldName: 'portion',
          targetProfitMargin: 0.5,
          targetPricePerPortion: 10.0,
          fixedOverheadCost: 0.0,
          dateCreated: now,
          archived: false,
        );
        final ingActive = Ingredient(
          ingredientPk: 'ing-act',
          name: 'Active Sugar',
          cost: 2.0,
          quantityForCost: 1000.0,
          unitFk: 'unit-g',
          dateCreated: now,
          isDeleted: false,
        );
        final ingDeleted = Ingredient(
          ingredientPk: 'ing-del',
          name: 'Deleted Spice',
          cost: 5.0,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: now,
          isDeleted: true,
          deletedAt: now,
        );
        await db.into(db.recipes).insert(rec);
        await db.into(db.ingredients).insert(ingActive);
        await db.into(db.ingredients).insert(ingDeleted);
        await db
            .into(db.recipeIngredients)
            .insert(
              RecipeIngredient(
                recipeIngredientPk: 'ri-act',
                recipeFk: 'rec-detail-filter',
                ingredientFk: 'ing-act',
                amountNeeded: 200.0,
              ),
            );
        await db
            .into(db.recipeIngredients)
            .insert(
              RecipeIngredient(
                recipeIngredientPk: 'ri-del',
                recipeFk: 'rec-detail-filter',
                ingredientFk: 'ing-del',
                amountNeeded: 50.0,
              ),
            );

        final detail = await db.getRecipeDetail('rec-detail-filter');
        expect(detail.ingredients.length, 2);
        final editorIngredients = detail.ingredients
            .map(
              (ri) => RecipeIngredientData(
                ingredient: ri.ingredient.copyWith(isDeleted: false),
                initialAmount: ri.entry.amountNeeded.toString(),
              ),
            )
            .toList();
        try {
          final saved = await RecipeUtils.saveRecipe(
            db: db,
            recipePk: detail.recipe.recipePk,
            name: detail.recipe.name,
            description: '',
            yieldText: '1',
            yieldName: 'portion',
            profitMarginText: '0',
            priceText: '0',
            ingredients: editorIngredients,
            steps: [],
          );
          expect(saved.ingredients, hasLength(2));
          expect(
            saved.ingredients
                .firstWhere((ri) => ri.ingredient.ingredientPk == 'ing-del')
                .ingredient
                .isDeleted,
            isTrue,
          );
          final visibleDeleted = RecipeIngredientData(
            ingredient: saved.ingredients
                .firstWhere((ri) => ri.ingredient.isDeleted)
                .ingredient,
            initialAmount: '50',
          );
          expect(visibleDeleted.totalCost, 0);
          visibleDeleted.amountController.dispose();
        } finally {
          for (final ingredient in editorIngredients) {
            ingredient.amountController.dispose();
          }
        }
        expect(detail.ingredients.first.ingredient.ingredientPk, 'ing-act');
        expect(
          detail.ingredients.any(
            (ri) =>
                ri.ingredient.ingredientPk == 'ing-del' &&
                ri.ingredient.isDeleted,
          ),
          isTrue,
        );
      },
    );
  });

  group('Sync Deletion Tracking and Inbound Sync Filtering Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Delete ingredient locally -> sync -> verify ingredient is NOT re-downloaded when local deletion >= remote updated_at',
      () async {
        final tCreated = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final tDeleted = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final tRemoteOld = DateTime.utc(2026, 6, 1, 11, 0, 0);

        // Local ingredient was deleted at 12:00
        final localIng = Ingredient(
          ingredientPk: 'ing-sync-del',
          name: 'Local Deleted Salt',
          cost: 1.0,
          quantityForCost: 1000.0,
          unitFk: 'unit-g',
          dateCreated: tCreated,
          dateTimeModified: tCreated,
          isDeleted: true,
          deletedAt: tDeleted,
        );
        await db.into(db.ingredients).insert(localIng);

        // Remote attempts to push an older active salt (11:00 < 12:00)
        final remoteIng = Ingredient(
          ingredientPk: 'ing-sync-del',
          name: 'Old Remote Salt',
          cost: 1.0,
          quantityForCost: 1000.0,
          unitFk: 'unit-g',
          dateCreated: tCreated,
          dateTimeModified: tRemoteOld,
          isDeleted: false,
        );

        final res = await db.mergeIngredientFromRemote(remoteIng);
        expect(res, 0); // Must be rejected / ignored

        // Local ingredient must remain deleted
        final inDb = await db.getIngredientById(
          'ing-sync-del',
          includeDeleted: true,
        );
        expect(inDb?.isDeleted, isTrue);
        expect(inDb?.deletedAt?.toUtc(), tDeleted);
        expect(inDb?.name, 'Local Deleted Salt');
      },
    );

    test(
      'Inbound sync filtering: Firestore sends is_deleted: true -> applies deletion to Drift',
      () async {
        final t1 = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final t2 = DateTime.utc(2026, 6, 1, 14, 0, 0);

        // Local active ingredient at 10:00
        final localActive = Ingredient(
          ingredientPk: 'ing-remote-del',
          name: 'Local Active Pepper',
          cost: 3.0,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: t1,
          dateTimeModified: t1,
          isDeleted: false,
        );
        await db.into(db.ingredients).insert(localActive);

        // Remote sends deleted tombstone at 14:00
        final remoteDeleted = Ingredient(
          ingredientPk: 'ing-remote-del',
          name: 'Remote Deleted Pepper',
          cost: 3.0,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: t1,
          dateTimeModified: t2,
          isDeleted: true,
          deletedAt: t2,
        );

        final res = await db.mergeIngredientFromRemote(remoteDeleted);
        expect(res, 2); // Applied update

        final inDb = await db.getIngredientById(
          'ing-remote-del',
          includeDeleted: true,
        );
        expect(inDb?.isDeleted, isTrue);
        expect(inDb?.deletedAt?.toUtc(), t2);
      },
    );

    test(
      'Inbound sync filtering: Remote ingredient active and newer than local deletion -> resurrects ingredient',
      () async {
        final t1 = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final tDeleted = DateTime.utc(2026, 6, 1, 11, 0, 0);
        final tRemoteNew = DateTime.utc(2026, 6, 1, 15, 0, 0);

        final localIng = Ingredient(
          ingredientPk: 'ing-resurrect',
          name: 'Deleted Ginger',
          cost: 2.0,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: t1,
          dateTimeModified: t1,
          isDeleted: true,
          deletedAt: tDeleted,
        );
        await db.into(db.ingredients).insert(localIng);

        final remoteNewer = Ingredient(
          ingredientPk: 'ing-resurrect',
          name: 'Resurrected Ginger',
          cost: 2.5,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: t1,
          dateTimeModified: tRemoteNew,
          isDeleted: false,
        );

        final res = await db.mergeIngredientFromRemote(remoteNewer);
        expect(res, 2); // Resurrected

        final inDb = await db.getIngredientById('ing-resurrect');
        expect(inDb, isNotNull);
        expect(inDb?.isDeleted, isFalse);
        expect(inDb?.deletedAt, isNull);
        expect(inDb?.name, 'Resurrected Ginger');
        expect(inDb?.cost, 2.5);
      },
    );

    test(
      'Ingredient serialization preserves is_deleted and deleted_at for Firestore sync push',
      () {
        final now = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final ing = Ingredient(
          ingredientPk: 'ing-tombstone',
          name: 'Deleted Herb',
          cost: 1.0,
          quantityForCost: 50.0,
          unitFk: 'unit-g',
          dateCreated: now,
          isDeleted: true,
          deletedAt: now,
        );

        final firestoreMap = FirestoreSyncService.ingredientToFirestore(ing);
        expect(firestoreMap['is_deleted'], isTrue);
        expect(firestoreMap['deleted_at'], now.toIso8601String());

        final restored = FirestoreSyncService.ingredientFromFirestore(
          firestoreMap,
        );
        expect(restored.ingredientPk, 'ing-tombstone');
        expect(restored.isDeleted, isTrue);
        expect(restored.deletedAt?.toUtc(), now);
      },
    );
  });

  group('Recipe Dependency Conflict Resolver Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Case 1 (Recipe Updated AFTER Deletion: recipe.updated_at > ingredient.deleted_at): keeps deleted ingredient visible without restoring it',
      () async {
        final tCreated = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final tDeleted = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final tRecipeUpdated = DateTime.utc(2026, 6, 1, 14, 0, 0);

        // 1. Local ingredient was deleted at 12:00
        final localIng = Ingredient(
          ingredientPk: 'ing-c1-cinnamon',
          name: 'Cinnamon Powder',
          cost: 4.0,
          quantityForCost: 100.0,
          unitFk: 'unit-g',
          dateCreated: tCreated,
          dateTimeModified: tCreated,
          isDeleted: true,
          deletedAt: tDeleted,
        );
        await db.into(db.ingredients).insert(localIng);

        // 2. Incoming remote recipe was modified at 14:00 (after deletion) referencing Cinnamon
        final remoteRecipe = Recipe(
          recipePk: 'rec-c1-rolls',
          name: 'Cinnamon Rolls',
          defaultYield: 8.0,
          yieldName: 'rolls',
          targetProfitMargin: 0.6,
          targetPricePerPortion: 4.0,
          fixedOverheadCost: 0.5,
          dateCreated: tCreated,
          dateTimeModified: tRecipeUpdated,
          archived: false,
        );
        final remoteRi = RecipeIngredient(
          recipeIngredientPk: 'ri-c1-1',
          recipeFk: 'rec-c1-rolls',
          ingredientFk: 'ing-c1-cinnamon',
          amountNeeded: 25.0,
          dateTimeModified: tRecipeUpdated,
        );

        final res = await db.mergeRecipeFromRemote(
          remoteRecipe: remoteRecipe,
          remoteIngredients: [remoteRi],
          remoteSteps: [],
        );
        expect(res, 1);

        // Verification: ingredient must be reactivated (isDeleted == false, deletedAt == null)
        final inDbIng = await db.getIngredientById(
          'ing-c1-cinnamon',
          includeDeleted: true,
        );
        expect(inDbIng, isNotNull);
        expect(inDbIng!.isDeleted, isTrue);
        expect(inDbIng.deletedAt, isNotNull);

        // Verification: recipe detail must retain the ingredient reference
        final detail = await db.getRecipeDetail('rec-c1-rolls');
        expect(detail.ingredients, hasLength(1));
        expect(
          detail.ingredients.first.ingredient.ingredientPk,
          'ing-c1-cinnamon',
        );
        expect(detail.ingredients.first.entry.amountNeeded, 25.0);
      },
    );

    test(
      'Case 2 (Deletion NEWER Than Recipe: ingredient.deleted_at >= recipe.updated_at): retains deletion and its recipe reference',
      () async {
        final tRecipeUpdated = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final tDeleted = DateTime.utc(2026, 6, 1, 15, 0, 0);

        // 1. Local ingredient was deleted at 15:00
        final localIng = Ingredient(
          ingredientPk: 'ing-c2-nutmeg',
          name: 'Nutmeg',
          cost: 3.0,
          quantityForCost: 50.0,
          unitFk: 'unit-g',
          dateCreated: tRecipeUpdated,
          dateTimeModified: tRecipeUpdated,
          isDeleted: true,
          deletedAt: tDeleted,
        );
        await db.into(db.ingredients).insert(localIng);

        // 2. Incoming remote recipe was last edited at 10:00 (before deletion) referencing Nutmeg
        final remoteRecipe = Recipe(
          recipePk: 'rec-c2-nog',
          name: 'Eggnog',
          defaultYield: 4.0,
          yieldName: 'glasses',
          targetProfitMargin: 0.5,
          targetPricePerPortion: 3.0,
          fixedOverheadCost: 0.2,
          dateCreated: tRecipeUpdated,
          dateTimeModified: tRecipeUpdated,
          archived: false,
        );
        final remoteRi = RecipeIngredient(
          recipeIngredientPk: 'ri-c2-1',
          recipeFk: 'rec-c2-nog',
          ingredientFk: 'ing-c2-nutmeg',
          amountNeeded: 5.0,
          dateTimeModified: tRecipeUpdated,
        );

        // Merging should succeed without database crash or invalid foreign key
        final res = await db.mergeRecipeFromRemote(
          remoteRecipe: remoteRecipe,
          remoteIngredients: [remoteRi],
          remoteSteps: [],
        );
        expect(res, 1);

        // Verification: ingredient remains deleted
        final inDbIng = await db.getIngredientById(
          'ing-c2-nutmeg',
          includeDeleted: true,
        );
        expect(inDbIng, isNotNull);
        expect(inDbIng!.isDeleted, isTrue);
        expect(inDbIng.deletedAt?.toUtc(), tDeleted);

        // Verification: dead ingredient reference was detached from recipe
        final detail = await db.getRecipeDetail('rec-c2-nog');
        expect(detail.ingredients, hasLength(1));
        expect(detail.ingredients.single.ingredient.isDeleted, isTrue);
        expect(RecipeUtils.calculateSummaryFromDetail(detail).totalCost, 0);
      },
    );

    test(
      'Case 3 (Simultaneous / Ambiguous): foreign-key assignments wrapped safely with stub creation',
      () async {
        final now = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final remoteRecipe = Recipe(
          recipePk: 'rec-c3-phantom',
          name: 'Mystery Soup',
          defaultYield: 2.0,
          yieldName: 'bowls',
          targetProfitMargin: 0.5,
          targetPricePerPortion: 4.0,
          fixedOverheadCost: 0.0,
          dateCreated: now,
          dateTimeModified: now,
          archived: false,
        );
        final remoteRi = RecipeIngredient(
          recipeIngredientPk: 'ri-c3-1',
          recipeFk: 'rec-c3-phantom',
          ingredientFk: 'ing-completely-unknown-12345',
          amountNeeded: 10.0,
          dateTimeModified: now,
        );

        // Should not throw SQLite foreign key constraint exception
        final res = await db.mergeRecipeFromRemote(
          remoteRecipe: remoteRecipe,
          remoteIngredients: [remoteRi],
          remoteSteps: [],
        );
        expect(res, 1);

        final detail = await db.getRecipeDetail('rec-c3-phantom');
        expect(detail.ingredients, hasLength(1));
        expect(
          detail.ingredients.first.ingredient.ingredientPk,
          'ing-completely-unknown-12345',
        );
      },
    );

    test(
      'Case 3b: Nested deleted ingredient remains deleted after a newer recipe',
      () async {
        final tCreated = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final tDeleted = DateTime.utc(2026, 6, 1, 11, 0, 0);
        final tRecipeUpdated = DateTime.utc(2026, 6, 1, 13, 0, 0);

        final nestedDeleted = Ingredient(
          ingredientPk: 'ing-c3b-nested',
          name: 'Nested Cardamom',
          cost: 6.0,
          quantityForCost: 50.0,
          unitFk: 'unit-g',
          dateCreated: tCreated,
          dateTimeModified: tDeleted,
          isDeleted: true,
          deletedAt: tDeleted,
        );

        final remoteRecipe = Recipe(
          recipePk: 'rec-c3b-chai',
          name: 'Chai Tea',
          defaultYield: 2.0,
          yieldName: 'cups',
          targetProfitMargin: 0.7,
          targetPricePerPortion: 2.5,
          fixedOverheadCost: 0.1,
          dateCreated: tCreated,
          dateTimeModified: tRecipeUpdated,
          archived: false,
        );

        final remoteRi = RecipeIngredient(
          recipeIngredientPk: 'ri-c3b-1',
          recipeFk: 'rec-c3b-chai',
          ingredientFk: 'ing-c3b-nested',
          amountNeeded: 5.0,
          dateTimeModified: tRecipeUpdated,
        );

        final res = await db.mergeRecipeFromRemote(
          remoteRecipe: remoteRecipe,
          remoteIngredients: [remoteRi],
          remoteSteps: [],
          nestedIngredients: [nestedDeleted],
        );
        expect(res, 1);

        final ingInDb = await db.getIngredientById(
          'ing-c3b-nested',
          includeDeleted: true,
        );
        expect(ingInDb, isNotNull);
        expect(ingInDb!.isDeleted, isTrue);

        final detail = await db.getRecipeDetail('rec-c3b-chai');
        expect(detail.ingredients, hasLength(1));
        expect(
          detail.ingredients.first.ingredient.ingredientPk,
          'ing-c3b-nested',
        );
      },
    );
  });

  group('Drift Schema Migration v1 to v2 Tests', () {
    test(
      'Database schema version is 2 and table schema includes is_deleted and deleted_at',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        expect(db.schemaVersion, 2);

        final cols = await db
            .customSelect("PRAGMA table_info('ingredients');")
            .get();
        final colNames = cols.map((row) => row.data['name'] as String).toList();
        expect(colNames, contains('is_deleted'));
        expect(colNames, contains('deleted_at'));

        final deletedCols = await db
            .customSelect("PRAGMA table_info('deleted_records');")
            .get();
        final deletedColNames =
            deletedCols.map((row) => row.data['name'] as String).toList();
        expect(deletedColNames, contains('record_pk'));
        expect(deletedColNames, contains('entity_type'));
        expect(deletedColNames, contains('deleted_at'));

        await db.close();
      },
    );

    test('Incremental migration v1 to v2 preserves existing user data', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Drop current ingredients table and re-create as v1 (without is_deleted and deleted_at)
      await db.customStatement('DROP TABLE ingredients;');
      await db.customStatement('''
        CREATE TABLE ingredients (
          ingredient_pk TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          cost REAL NOT NULL,
          quantity_for_cost REAL NOT NULL,
          unit_fk TEXT NOT NULL REFERENCES units(unit_pk),
          date_created INTEGER NOT NULL,
          date_time_modified INTEGER
        );
      ''');
      await db.customStatement('''
        INSERT INTO ingredients (ingredient_pk, name, cost, quantity_for_cost, unit_fk, date_created)
        VALUES ('ing-v1-flour', 'Original Pre-Migration Flour', 2.5, 1000.0, 'unit-g', 1700000000);
      ''');

      // Execute onUpgrade migration step from 1 to 2
      final migrator = db.createMigrator();
      await db.migration.onUpgrade(migrator, 1, 2);

      // Verify original data is preserved and columns have appropriate defaults
      final allIngs = await db.getAllIngredients();
      expect(allIngs.any((i) => i.ingredientPk == 'ing-v1-flour'), isTrue);
      final flour = allIngs.firstWhere((i) => i.ingredientPk == 'ing-v1-flour');
      expect(flour.name, 'Original Pre-Migration Flour');
      expect(flour.cost, 2.5);
      expect(flour.isDeleted, isFalse);
      expect(flour.deletedAt, isNull);

      // Verify soft delete functions properly on the migrated row
      await db.deleteIngredient(flour);
      final activeAfterDelete = await db.getAllIngredients();
      expect(
        activeAfterDelete.any((i) => i.ingredientPk == 'ing-v1-flour'),
        isFalse,
      );

      final deletedRecord = await db.getIngredientById(
        'ing-v1-flour',
        includeDeleted: true,
      );
      expect(deletedRecord?.isDeleted, isTrue);
      expect(deletedRecord?.deletedAt, isNotNull);

      await db.close();
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
    testWidgets(
      'Selecting Firestore tab when signed in displays profile card and sync info',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudSyncProvider.overrideWith(
                MockFirestoreCloudSyncNotifier.new,
              ),
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
      },
    );

    testWidgets(
      'Selecting Firestore tab when NOT signed in displays inline Auth Card with Google & Email',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudSyncProvider.overrideWith(
                MockFirestoreLoggedOutCloudSyncNotifier.new,
              ),
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
        expect(
          find.text('Sign In'),
          findsNWidgets(2),
        ); // Segmented toggle & submit button
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Email address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Forgot password?'), findsOneWidget);

        // Tap 'Create Account' in segmented button
        await tester.tap(find.text('Create Account'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Forgot password link should disappear in Register mode
        expect(find.text('Forgot password?'), findsNothing);

        // Trigger submit with empty fields to verify inline error validation
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pump();

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Delta Sync, Tombstones & Batching Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Recipe insert and update properly update dateTimeModified', () async {
      final initialTime = DateTime.utc(2025, 1, 1, 10, 0);
      final recipe = Recipe(
        recipePk: 'rec-delta-1',
        name: 'Delta Sourdough',
        defaultYield: 4.0,
        yieldName: 'Loaves',
        targetProfitMargin: 0.6,
        targetPricePerPortion: 5.0,
        fixedOverheadCost: 1.0,
        archived: false,
        dateCreated: initialTime,
        dateTimeModified: initialTime,
      );

      await db.insertRecipe(recipe.toCompanion(false));
      var fetched = (await (db.select(db.recipes)
                ..where((t) => t.recipePk.equals('rec-delta-1'))
                ..limit(1))
              .get())
          .firstOrNull;
      expect(fetched, isNotNull);
      final modified = fetched!.dateTimeModified;
      expect(modified, isNotNull);
      expect(
        modified!.isAfter(initialTime.subtract(const Duration(seconds: 1))),
        isTrue,
      );

      final modifiedBefore = modified;
      await Future.delayed(const Duration(milliseconds: 10));

      final updated = fetched.copyWith(name: 'Updated Sourdough');
      await db.updateRecipe(updated);
      fetched = (await (db.select(db.recipes)
                ..where((t) => t.recipePk.equals('rec-delta-1'))
                ..limit(1))
              .get())
          .firstOrNull;
      expect(fetched!.name, 'Updated Sourdough');
      expect(fetched.dateTimeModified!.isAfter(modifiedBefore), isTrue);
    });

    test(
      'Recipe physical delete automatically records tombstones in DeletedRecords',
      () async {
        final now = DateTime.now().toUtc();
        final recipe = Recipe(
          recipePk: 'rec-del-tomb',
          name: 'To Delete',
          defaultYield: 1.0,
          yieldName: 'portion',
          targetProfitMargin: 0.5,
          targetPricePerPortion: 2.0,
          fixedOverheadCost: 0.0,
          archived: false,
          dateCreated: now,
          dateTimeModified: now,
        );
        await db.insertRecipe(recipe.toCompanion(false));

        final unit = Unit(
          unitPk: 'unit-g',
          name: 'Gram',
          symbol: 'g',
          factorToBase: 1.0,
          isMutable: false,
        );
        await db.into(db.units).insert(unit);

        final ing = Ingredient(
          ingredientPk: 'ing-del-tomb',
          name: 'Flour',
          unitFk: 'unit-g',
          cost: 5.0,
          quantityForCost: 1000.0,
          dateCreated: now,
          dateTimeModified: now,
          isDeleted: false,
        );
        await db.insertIngredient(ing.toCompanion(false));

        final recipeIng = RecipeIngredient(
          recipeIngredientPk: 'rec-del-tomb_ing-del-tomb',
          recipeFk: 'rec-del-tomb',
          ingredientFk: 'ing-del-tomb',
          amountNeeded: 250.0,
          dateTimeModified: now,
        );
        await db.insertRecipeIngredient(recipeIng.toCompanion(false));

        final step = RecipeStep(
          stepPk: 'step-del-tomb',
          recipeFk: 'rec-del-tomb',
          stepNumber: 1,
          instruction: 'Mix well',
          dateTimeModified: now,
        );
        await db.insertRecipeStep(step.toCompanion(false));

        // Verify DeletedRecords is empty before deletion
        var tombstones = await db.getAllDeletedRecords();
        expect(tombstones, isEmpty);

        // Delete recipe physically
        await db.deleteRecipe(recipe);

        // Verify recipe was physically deleted from SQLite
        final checkRecipe = (await (db.select(db.recipes)
                  ..where((t) => t.recipePk.equals('rec-del-tomb'))
                  ..limit(1))
                .get())
            .firstOrNull;
        expect(checkRecipe, isNull);

        // Verify tombstones were recorded for recipe, step, and recipe ingredient
        tombstones = await db.getAllDeletedRecords();
        expect(tombstones.length, 3);
        expect(
          tombstones.any(
            (t) =>
                t.recordPk == 'rec-del-tomb' && t.entityType == 'recipes',
          ),
          isTrue,
        );
        expect(
          tombstones.any(
            (t) =>
                t.recordPk == 'step-del-tomb' &&
                t.entityType == 'recipe_steps',
          ),
          isTrue,
        );
        expect(
          tombstones.any(
            (t) =>
                t.recordPk == 'rec-del-tomb_ing-del-tomb' &&
                t.entityType == 'recipe_ingredients',
          ),
          isTrue,
        );
      },
    );

    test(
      'Ingredient soft delete and restore update DeletedRecords accordingly',
      () async {
        final now = DateTime.now().toUtc();
        final unit = Unit(
          unitPk: 'unit-g2',
          name: 'Gram',
          symbol: 'g',
          factorToBase: 1.0,
          isMutable: false,
        );
        await db.into(db.units).insert(unit);

        final ing = Ingredient(
          ingredientPk: 'ing-soft-tomb',
          name: 'Sugar',
          unitFk: 'unit-g2',
          cost: 2.0,
          quantityForCost: 1000.0,
          dateCreated: now,
          dateTimeModified: now,
          isDeleted: false,
        );
        await db.insertIngredient(ing.toCompanion(false));

        // Soft delete records a tombstone
        await db.deleteIngredient(ing);
        var tombstones = await db.getAllDeletedRecords();
        expect(tombstones.length, 1);
        expect(tombstones.first.recordPk, 'ing-soft-tomb');
        expect(tombstones.first.entityType, 'ingredients');

        // Restoring clears the tombstone
        await db.restoreIngredient(ing.ingredientPk);
        tombstones = await db.getAllDeletedRecords();
        expect(tombstones, isEmpty);
      },
    );

    test(
      'Inbound tombstone deletes local record physically without local tombstone echo',
      () async {
        final now = DateTime.now().toUtc();
        final olderTime = now.subtract(const Duration(hours: 1));
        final newerTime = now;

        final unit = Unit(
          unitPk: 'unit-kg',
          name: 'Kilogram',
          symbol: 'kg',
          factorToBase: 1000.0,
          isMutable: false,
        );
        await db.into(db.units).insert(unit);

        final ing = Ingredient(
          ingredientPk: 'ing-inbound-del',
          name: 'Salt',
          unitFk: 'unit-kg',
          cost: 1.0,
          quantityForCost: 1.0,
          dateCreated: olderTime,
          dateTimeModified: olderTime,
          isDeleted: false,
        );
        await db.insertIngredient(ing.toCompanion(false));

        // Inbound remote ingredient is marked as deleted with a newer timestamp
        final localIng =
            await db.getIngredientById('ing-inbound-del', includeDeleted: true);
        expect(localIng, isNotNull);

        final localTime = localIng!.dateTimeModified ?? localIng.dateCreated;
        expect(newerTime.isAfter(localTime), isTrue);

        // Physically delete without tombstone echo (as firestore_sync_service does on inbound isDeleted)
        await db.deleteIngredientPhysically('ing-inbound-del', recordTombstone: false);

        // Should be removed from local database
        final local =
            await db.getIngredientById('ing-inbound-del', includeDeleted: true);
        expect(local, isNull);

        // Local tombstones should NOT be generated (avoiding bounce-back)
        final tombstones = await db.getAllDeletedRecords();
        expect(tombstones.where((t) => t.recordPk == 'ing-inbound-del'), isEmpty);
      },
    );

    test('Per-user last_sync_timestamp storage and retrieval', () async {
      final service = FirestoreSyncService();

      expect(await service.getLastSyncedAt('user-alice'), isNull);
      expect(await service.getLastSyncedAt('user-bob'), isNull);

      final t1 = DateTime.utc(2026, 3, 1, 12, 0);
      final t2 = DateTime.utc(2026, 3, 2, 15, 30);

      await service.setLastSyncedAt('user-alice', t1);
      await service.setLastSyncedAt('user-bob', t2);

      final aliceSynced = await service.getLastSyncedAt('user-alice');
      final bobSynced = await service.getLastSyncedAt('user-bob');

      expect(aliceSynced, t1);
      expect(bobSynced, t2);

      await service.clearLastSyncedAt('user-alice');
      expect(await service.getLastSyncedAt('user-alice'), isNull);
      expect(await service.getLastSyncedAt('user-bob'), t2);
    });

    test('FirestoreBatchQueue chunks mutations into <= 450 per commit', () async {
      int commitCount = 0;
      final batchSizes = <int>[];

      final queue = FirestoreBatchQueue(
        null,
        maxBatchSize: 450,
        onCommit: (batchSize) async {
          commitCount++;
          batchSizes.add(batchSize);
        },
      );

      // Enqueue 950 mutations
      for (int i = 0; i < 950; i++) {
        await queue.queueDelete(null);
      }
      await queue.commit();

      // Expected chunks: 450, 450, 50 = 3 commits total
      expect(commitCount, 3);
      expect(batchSizes, [450, 450, 50]);
      expect(batchSizes.every((s) => s <= 450), isTrue);
    });
  });
}
