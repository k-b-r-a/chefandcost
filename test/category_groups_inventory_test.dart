import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/initialize_default_database.dart';
import 'package:recipetools/database/recipe_category.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/utils/firestore_sync_service.dart';
import 'package:recipetools/widgets/active_group_chip.dart';
import 'package:recipetools/widgets/group_management_sheet.dart';
import 'package:recipetools/widgets/recipe_category_badge.dart';
import 'package:recipetools/widgets/recipe_category_filter_chips_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Database Schema & Migration Tests', () {
    test('editing one recipe keeps the complete reactive feed', () async {
      for (var i = 0; i < 3; i++) {
        await db.insertRecipe(
          RecipesCompanion.insert(
            recipePk: Value('feed-$i'),
            name: 'Recipe $i',
            defaultYield: 1,
            yieldName: 'portion',
          ),
        );
      }
      final iterator = StreamIterator(db.watchAllRecipesWithFinancials());
      try {
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(iterator.current, hasLength(3));
        await (db.update(db.recipes)..where((r) => r.recipePk.equals('feed-0')))
            .write(const RecipesCompanion(name: Value('Edited recipe')));
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(iterator.current, hasLength(3));
        expect(
          iterator.current.map((r) => r.recipe.name),
          contains('Edited recipe'),
        );
      } finally {
        await iterator.cancel();
      }
    });
    test('Drift schemaVersion is 2', () {
      expect(db.schemaVersion, equals(2));
    });

    test(
      'initializeDefaultDatabase seeds preset categories and default group',
      () async {
        final categories = await db.getAllCategories();
        expect(categories.length, equals(3));
        final catIds = categories.map((c) => c.id).toSet();
        expect(catIds, containsAll(['cocina', 'pasteleria', 'cocteleria']));

        final groups = await db.getAllGroups();
        expect(groups, isNotEmpty);
        expect(groups.any((g) => g.name == 'Principal' || g.name == 'Main'), isTrue);
      },
    );

    test(
      'Default group links ingredients but leaves recipes unassigned',
      () async {
        final units = await db.getAllUnits();
        final unitPk = units.first.unitPk;

        // Insert ingredient and recipe without explicit groupId
        final ingPk = 'test-ing-1';
        await db
            .into(db.ingredients)
            .insert(
              IngredientsCompanion(
                ingredientPk: Value(ingPk),
                name: const Value('Test Ingr'),
                cost: const Value(10.0),
                quantityForCost: const Value(1.0),
                unitFk: Value(unitPk),
                dateCreated: Value(DateTime.now()),
              ),
            );

        final recipePk = 'test-rec-1';
        await db
            .into(db.recipes)
            .insert(
              RecipesCompanion(
                recipePk: Value(recipePk),
                name: const Value('Test Recipe'),
                defaultYield: const Value(2.0),
                yieldName: const Value('portions'),
                dateCreated: Value(DateTime.now()),
              ),
            );

        // Run initializeDefaultDatabase to simulate migration / startup backfill
        await initializeDefaultDatabase(db);

        // Verify defaults
        final insertedIng = await db.getIngredientById(ingPk);
        expect(insertedIng, isNotNull);
        expect(insertedIng!.currentStock, equals(0.0));
        expect(insertedIng.groupId, isNotNull);

        final insertedRecipe = (await db.getAllRecipes()).firstWhere(
          (r) => r.recipePk == recipePk,
        );
        expect(insertedRecipe.category, equals('cocina'));
        expect(insertedRecipe.groupId, isNull);
      },
    );

    test(
      'recipe spaces are many-to-many, filter strictly, and tombstone safely',
      () async {
        final groups = await db.getAllGroups();
        final first = groups.first;
        final secondId = 'group-second';
        await db.insertGroup(
          GroupsCompanion.insert(id: Value(secondId), name: 'Kitchen B'),
        );
        await db
            .into(db.recipes)
            .insert(
              RecipesCompanion.insert(
                recipePk: const Value('recipe-spaces-test'),
                name: 'Shared recipe',
                defaultYield: 1,
                yieldName: 'portion',
              ),
            );
        await db.setRecipeSpaces('recipe-spaces-test', [first.id, secondId]);
        await db.customStatement(
          "UPDATE recipe_spaces SET created_at = ? WHERE recipe_id = ?",
          ['2026-11-05 19:57:18', 'recipe-spaces-test'],
        );
        await db.repairRecipeSpaceTimestamps();
        final repairedLinks = await db.select(db.recipeSpaces).get();
        expect(repairedLinks.first.createdAt.year, 2026);
        expect(
          await db.getSpaceIdsForRecipe('recipe-spaces-test'),
          containsAll([first.id, secondId]),
        );
        expect(
          (await db.getRecipes(spaceId: first.id)).map((r) => r.recipePk),
          contains('recipe-spaces-test'),
        );
        expect(
          (await db.getRecipes(spaceId: secondId)).map((r) => r.recipePk),
          contains('recipe-spaces-test'),
        );
        expect(await db.getRecipes(spaceId: 'unassigned-space'), isEmpty);
        await db.setRecipeSpaces('recipe-spaces-test', [secondId]);
        expect(await db.getSpaceIdsForRecipe('recipe-spaces-test'), [secondId]);
        await db.duplicateRecipe('recipe-spaces-test', 'Copy with spaces');
        final copy = (await db.getAllRecipes()).firstWhere(
          (r) => r.name == 'Copy with spaces',
        );
        expect(await db.getSpaceIdsForRecipe(copy.recipePk), [secondId]);
        final before = (await db.getRecipeDetail(
          copy.recipePk,
        )).recipe.dateTimeModified;
        await db.setRecipeSpaces(copy.recipePk, [], markModified: false);
        expect(
          (await db.getRecipeDetail(copy.recipePk)).recipe.dateTimeModified,
          before,
        );
        await db.setRecipeSpaces(copy.recipePk, [first.id]);
        await db.mergeGroupFromRemote(
          first.copyWith(
            isDeleted: true,
            updatedAt: DateTime.now().add(const Duration(seconds: 1)),
          ),
        );
        expect(await db.getSpaceIdsForRecipe(copy.recipePk), isEmpty);
        await db.setRecipeSpaces(copy.recipePk, [first.id, 'missing-space']);
        expect(await db.getSpaceIdsForRecipe(copy.recipePk), isEmpty);
        await db.softDeleteGroup(secondId);
        expect(await db.getSpaceIdsForRecipe('recipe-spaces-test'), isEmpty);
      },
    );
  });

  group('2. Ingredient Inventory DB Schema & Sync Models', () {
    test(
      'Ingredients table contains inventory columns and handles updates',
      () async {
        final units = await db.getAllUnits();
        final unitPk = units.first.unitPk;

        final now = DateTime.now();
        await db.insertIngredient(
          IngredientsCompanion(
            ingredientPk: const Value('ing-inv-1'),
            name: const Value('Mantequilla repostera'),
            cost: const Value(4.5),
            quantityForCost: const Value(500.0),
            unitFk: Value(unitPk),
            currentStock: const Value(1250.0),
            minimumStock: const Value(250.0),
            stockUnit: const Value('g'),
            costPerStockUnit: const Value(0.009),
            lastStockUpdate: Value(now),
          ),
        );

        final ing = await db.getIngredientById('ing-inv-1');
        expect(ing, isNotNull);
        expect(ing!.currentStock, equals(1250.0));
        expect(ing.minimumStock, equals(250.0));
        expect(ing.stockUnit, equals('g'));
        expect(ing.costPerStockUnit, equals(0.009));
        expect(ing.lastStockUpdate, isNotNull);

        // Update stock
        await db.updateIngredient(
          ing.copyWith(
            currentStock: Value(1000.0),
            lastStockUpdate: Value(DateTime.now()),
          ),
        );

        final updated = await db.getIngredientById('ing-inv-1');
        expect(updated!.currentStock, equals(1000.0));
      },
    );

    test(
      'Firestore serialization and deserialization maps inventory fields gracefully',
      () {
        final now = DateTime.now();
        final ing = Ingredient(
          ingredientPk: 'ing-sync-1',
          name: 'Azúcar Morena',
          cost: 2.0,
          quantityForCost: 1000.0,
          unitFk: 'unit-g',
          dateCreated: now,
          dateTimeModified: now,
          isDeleted: false,
          groupId: 'grp-main',
          category: 'pasteleria',
          currentStock: 5000.0,
          minimumStock: 1000.0,
          stockUnit: 'g',
          costPerStockUnit: 0.002,
          lastStockUpdate: now,
        );

        final serialized = FirestoreSyncService.ingredientToFirestore(ing);
        expect(serialized['current_stock'], equals(5000.0));
        expect(serialized['minimum_stock'], equals(1000.0));
        expect(serialized['stock_unit'], equals('g'));
        expect(serialized['cost_per_stock_unit'], equals(0.002));
        expect(serialized['group_id'], equals('grp-main'));

        // Deserialization with complete data
        final deserialized = FirestoreSyncService.ingredientFromFirestore(
          serialized,
        );
        expect(deserialized.ingredientPk, equals('ing-sync-1'));
        expect(deserialized.currentStock, equals(5000.0));
        expect(deserialized.minimumStock, equals(1000.0));
        expect(deserialized.stockUnit, equals('g'));

        // Deserialization with missing/legacy null values
        final legacyDoc = <String, dynamic>{
          'ingredientPk': 'ing-legacy',
          'name': 'Sal',
          'cost': 0.5,
          'quantityForCost': 1000.0,
          'unitFk': 'unit-g',
          'dateCreated': now.toIso8601String(),
        };
        final fromLegacy = FirestoreSyncService.ingredientFromFirestore(
          legacyDoc,
        );
        expect(fromLegacy.ingredientPk, equals('ing-legacy'));
        expect(fromLegacy.currentStock, equals(0.0)); // Default fallback
        expect(fromLegacy.minimumStock, isNull);
        expect(fromLegacy.stockUnit, isNull);
        expect(fromLegacy.costPerStockUnit, isNull);
      },
    );
  });

  group('3. Customizable Groups DAO & Queries', () {
    test('Create, update, and soft-delete groups reactively', () async {
      final initialGroups = await db.getAllGroups();
      final initialCount = initialGroups.length;

      // Create new venue / group
      final groupId = 'group-baru-kitchen';
      await db.insertGroup(
        GroupsCompanion(
          id: Value(groupId),
          name: const Value('Barú Cocina'),
          colorHex: const Value('FF9800'),
          iconName: const Value('restaurant'),
          isActive: const Value(true),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isDeleted: const Value(false),
        ),
      );

      var allGroups = await db.getAllGroups();
      expect(allGroups.length, equals(initialCount + 1));
      final baru = await db.getGroupById(groupId);
      expect(baru, isNotNull);
      expect(baru!.name, equals('Barú Cocina'));

      // Update / Rename
      await db.updateGroup(baru.copyWith(name: 'Barú Central Kitchen'));
      final renamed = await db.getGroupById(groupId);
      expect(renamed!.name, equals('Barú Central Kitchen'));

      // Soft delete
      await db.softDeleteGroup(groupId);
      final activeGroups = await db.getAllGroups(includeDeleted: false);
      expect(activeGroups.any((g) => g.id == groupId), isFalse);

      final withDeleted = await db.getAllGroups(includeDeleted: true);
      final deletedGroup = withDeleted.firstWhere((g) => g.id == groupId);
      expect(deletedGroup.isDeleted, isTrue);
      expect(deletedGroup.isActive, isFalse);
    });
  });

  group('4. Recipe Categories & Filtering Queries', () {
    test(
      'Filter recipes by category (cocina, pasteleria, cocteleria)',
      () async {
        await db.insertRecipe(
          const RecipesCompanion(
            recipePk: Value('rec-cocina'),
            name: Value('Lomo Saltado'),
            defaultYield: Value(1.0),
            yieldName: Value('plato'),
            category: Value('cocina'),
          ),
        );

        await db.insertRecipe(
          const RecipesCompanion(
            recipePk: Value('rec-pasteleria'),
            name: Value('Cheesecake de Frutos Rojos'),
            defaultYield: Value(8.0),
            yieldName: Value('porciones'),
            category: Value('pasteleria'),
          ),
        );

        await db.insertRecipe(
          const RecipesCompanion(
            recipePk: Value('rec-cocteleria'),
            name: Value('Mojito Clásico'),
            defaultYield: Value(1.0),
            yieldName: Value('vaso'),
            category: Value('cocteleria'),
          ),
        );

        // Filter cocina
        final cocinaRecipes = await db.getRecipes(category: 'cocina');
        expect(cocinaRecipes.any((r) => r.recipePk == 'rec-cocina'), isTrue);
        expect(
          cocinaRecipes.any((r) => r.recipePk == 'rec-pasteleria'),
          isFalse,
        );
        expect(
          cocinaRecipes.any((r) => r.recipePk == 'rec-cocteleria'),
          isFalse,
        );

        // Filter pasteleria
        final pasteleriaRecipes = await db.getRecipes(category: 'pasteleria');
        expect(
          pasteleriaRecipes.any((r) => r.recipePk == 'rec-pasteleria'),
          isTrue,
        );
        expect(
          pasteleriaRecipes.any((r) => r.recipePk == 'rec-cocina'),
          isFalse,
        );

        // Filter cocteleria
        final cocteleriaRecipes = await db.getRecipes(category: 'cocteleria');
        expect(
          cocteleriaRecipes.any((r) => r.recipePk == 'rec-cocteleria'),
          isTrue,
        );
        expect(
          cocteleriaRecipes.any((r) => r.recipePk == 'rec-cocina'),
          isFalse,
        );

        // All recipes (no filter)
        final all = await db.getRecipes();
        expect(all.length, greaterThanOrEqualTo(3));
      },
    );

    test(
      'RecipeCategory enum parses values and provides colors/icons correctly',
      () {
        expect(
          RecipeCategory.fromString('cocina'),
          equals(RecipeCategory.cocina),
        );
        expect(
          RecipeCategory.fromString('pasteleria'),
          equals(RecipeCategory.pasteleria),
        );
        expect(
          RecipeCategory.fromString('Pastelería'),
          equals(RecipeCategory.pasteleria),
        );
        expect(
          RecipeCategory.fromString('cocteleria'),
          equals(RecipeCategory.cocteleria),
        );
        expect(
          RecipeCategory.fromString('Coctelería'),
          equals(RecipeCategory.cocteleria),
        );
        expect(RecipeCategory.fromString(null), equals(RecipeCategory.cocina));
      },
    );
  });

  group('5. UI Components & Widgets Tests', () {
    testWidgets(
      'RecipeCategoryFilterChipsRow renders all 4 options and responds to tap',
      (tester) async {
        RecipeCategory? selected;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('es'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return RecipeCategoryFilterChipsRow(
                    selectedCategory: selected,
                    onCategorySelected: (cat) {
                      setState(() => selected = cat);
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Cocina'), findsOneWidget);
        expect(find.text('Pastelería'), findsOneWidget);
        expect(find.text('Coctelería'), findsOneWidget);

        // Tap on Pastelería
        await tester.tap(find.text('Pastelería'));
        await tester.pumpAndSettle();
        expect(selected, equals(RecipeCategory.pasteleria));

        // Tap on Todos
        await tester.tap(find.text('Todos'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
      },
    );

    testWidgets(
      'RecipeCategoryBadge renders compact tag with correct label and icon',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('es'),
            home: Scaffold(
              body: Column(
                children: [
                  RecipeCategoryBadge(categoryString: 'cocina'),
                  RecipeCategoryBadge(categoryString: 'pasteleria'),
                  RecipeCategoryBadge(categoryString: 'cocteleria'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cocina'), findsOneWidget);
        expect(find.text('Pastelería'), findsOneWidget);
        expect(find.text('Coctelería'), findsOneWidget);
      },
    );

    testWidgets(
      'ActiveGroupChip renders and opens GroupManagementSheet on tap',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(() => MockDatabaseNotifier(db)),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('es'),
              home: Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(60),
                  child: ActiveGroupChip(),
                ),
                body: SizedBox(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify ActiveGroupChip displays default group name
        expect(find.byType(ActiveGroupChip), findsOneWidget);

        // Tap to open sheet
        await tester.tap(find.byType(ActiveGroupChip));
        await tester.pumpAndSettle();

        expect(find.byType(GroupManagementSheet), findsOneWidget);
        expect(find.text('Espacios de trabajo'), findsOneWidget);

        // Dismiss sheet and tear down widget tree cleanly
        Navigator.of(tester.element(find.byType(GroupManagementSheet))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}
