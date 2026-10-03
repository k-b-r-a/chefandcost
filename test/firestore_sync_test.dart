import 'package:cloud_firestore/cloud_firestore.dart';
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
    testWidgets('Selecting Firestore tab displays Spark architecture info', (tester) async {
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

      // Verify Firestore UI elements appear
      expect(find.textContaining('Spark Plan Architecture'), findsOneWidget);
      expect(find.textContaining('Differential Queries'), findsOneWidget);
      expect(find.textContaining('Embedded Ingredients'), findsOneWidget);
      expect(find.textContaining('Non-Destructive LWW'), findsOneWidget);
    });
  });
}
