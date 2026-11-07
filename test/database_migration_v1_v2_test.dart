// ignore_for_file: depend_on_referenced_packages, curly_braces_in_flow_control_structures
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:recipetools/database/database.dart';
import 'package:recipetools/utils/firestore_sync_service.dart';

// Independent theoretical V1 fixture: never generated from the current schema.
void createV1(
  File file, {
  int count = 1,
  bool legacyGroups = false,
  bool partial = false,
}) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('''
      CREATE TABLE units (unit_pk TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
        symbol TEXT NOT NULL, category TEXT, factor_to_base REAL NOT NULL DEFAULT 1,
        is_mutable INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE recipes (recipe_pk TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
        description TEXT, default_yield REAL NOT NULL, yield_name TEXT NOT NULL,
        target_profit_margin REAL NOT NULL DEFAULT 0, target_price_per_portion REAL NOT NULL DEFAULT 0,
        fixed_overhead_cost REAL NOT NULL DEFAULT 0, colour TEXT, date_created INTEGER NOT NULL,
        date_time_modified INTEGER, archived INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE ingredients (ingredient_pk TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
        cost REAL NOT NULL, quantity_for_cost REAL NOT NULL, unit_fk TEXT NOT NULL REFERENCES units(unit_pk),
        date_created INTEGER NOT NULL, date_time_modified INTEGER);
      CREATE TABLE recipe_ingredients (recipe_ingredient_pk TEXT PRIMARY KEY NOT NULL,
        recipe_fk TEXT NOT NULL REFERENCES recipes(recipe_pk),
        ingredient_fk TEXT NOT NULL REFERENCES ingredients(ingredient_pk),
        amount_needed REAL NOT NULL, date_time_modified INTEGER);
      CREATE TABLE recipe_steps (step_pk TEXT PRIMARY KEY NOT NULL,
        recipe_fk TEXT NOT NULL REFERENCES recipes(recipe_pk), step_number INTEGER NOT NULL,
        instruction TEXT NOT NULL, date_time_modified INTEGER);
      INSERT INTO units VALUES ('custom-unit', 'Custom kg', 'kg', 'mass', 1000, 1);
      PRAGMA user_version = 1;
    ''');
    if (legacyGroups) {
      raw.execute('''
        CREATE TABLE groups (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
          icon_name TEXT, color_hex TEXT, is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0);
        INSERT INTO groups VALUES ('venue', 'Barú', NULL, NULL, 1, 1700000000, 1700000000, 0);
        INSERT INTO groups VALUES ('deleted', 'Deleted venue', NULL, NULL, 0, 1700000000, 1700000000, 1);
        ALTER TABLE recipes ADD COLUMN group_id TEXT REFERENCES groups(id);
      ''');
    }
    if (partial) {
      raw.execute('''
        ALTER TABLE ingredients ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;
        ALTER TABLE ingredients ADD COLUMN current_stock REAL DEFAULT 0;
        ALTER TABLE recipes ADD COLUMN category TEXT DEFAULT 'cocina';
      ''');
    }
    for (var i = 0; i < count; i++) {
      raw.execute(
        'INSERT INTO recipes (recipe_pk,name,description,default_yield,yield_name,target_profit_margin,target_price_per_portion,fixed_overhead_cost,date_created,date_time_modified,archived) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [
          'r$i',
          'Receta ñ $i',
          i.isEven ? null : 'Descripción 🍞',
          2.5,
          'porciones',
          0.35,
          12.75,
          1.25,
          1700000000,
          null,
          i.isEven ? 0 : 1,
        ],
      );
      raw.execute(
        'INSERT INTO ingredients (ingredient_pk,name,cost,quantity_for_cost,unit_fk,date_created,date_time_modified) VALUES (?,?,?,?,?,?,?)',
        [
          'i$i',
          'Harina $i',
          i.isEven ? 0 : 3.125,
          1000,
          'custom-unit',
          1700000000,
          1700000100,
        ],
      );
      raw.execute('INSERT INTO recipe_ingredients VALUES (?,?,?,?,?)', [
        'ri$i',
        'r$i',
        'i$i',
        123.45,
        null,
      ]);
      raw.execute('INSERT INTO recipe_steps VALUES (?,?,?,?,?)', [
        's$i',
        'r$i',
        1,
        'Mezclar ñ 🍞',
        null,
      ]);
      if (legacyGroups) {
        raw.execute('UPDATE recipes SET group_id = ? WHERE recipe_pk = ?', [
          i == 0 ? 'venue' : 'deleted',
          'r$i',
        ]);
      }
    }
    if (partial && count > 0) {
      raw.execute(
        "UPDATE ingredients SET is_deleted = 1, current_stock = 42.5 WHERE ingredient_pk = 'i0'",
      );
    }
  } finally {
    raw.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy text timestamps, repeated upgrade and enforced cascade constraints',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-migration-dates-',
      );
      final file = File('${directory.path}/legacy.sqlite');
      createV1(file, count: 2, legacyGroups: true);
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('''
      CREATE TABLE recipe_spaces (
        recipe_id TEXT NOT NULL REFERENCES recipes(recipe_pk) ON DELETE CASCADE,
        space_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(recipe_id, space_id));
      INSERT INTO recipe_spaces VALUES ('r0', 'venue', '2026-11-05 19:57:18', 0);
      INSERT INTO recipe_spaces VALUES ('r1', 'deleted', '2026-11-05T19:57:18Z', 1);
    ''');
      raw.close();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final links = await db.select(db.recipeSpaces).get();
        expect(links, hasLength(2));
        for (final link in links) {
          expect(link.createdAt.toUtc(), DateTime.utc(2026, 11, 5, 19, 57, 18));
        }
        expect(await db.getSpaceIdsForRecipe('r1'), isEmpty);
        await db.migration.onUpgrade(db.createMigrator(), 1, 2);
        await db.migration.onUpgrade(db.createMigrator(), 1, 2);
        expect(await db.getAllRecipes(), hasLength(2));
        expect(await db.select(db.recipeSpaces).get(), hasLength(2));
        // New writes must also decode correctly on a table with the old text default.
        await db.setRecipeSpaces('r1', ['venue']);
        expect(
          (await db.select(db.recipeSpaces).get()).every(
            (link) => link.createdAt.year > 2000,
          ),
          isTrue,
        );
        await db.customStatement('PRAGMA foreign_keys = ON');
        await expectLater(
          db.customStatement(
            "INSERT INTO recipe_spaces(recipe_id,space_id,created_at) VALUES ('missing','venue',1700000000)",
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO recipe_spaces(recipe_id,space_id,created_at) VALUES ('r0','venue',1700000000)",
          ),
          throwsA(isA<Exception>()),
        );
        await db.customStatement(
          "DELETE FROM recipe_ingredients WHERE recipe_fk='r0'",
        );
        await db.customStatement(
          "DELETE FROM recipe_steps WHERE recipe_fk='r0'",
        );
        await db.customStatement("DELETE FROM recipes WHERE recipe_pk='r0'");
        expect(await db.getSpaceIdsForRecipe('r0'), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  for (final scenario in [
    (name: 'empty V1', count: 0, legacy: false, partial: false),
    (
      name: 'populated V1 with Unicode, nulls, decimals and archived recipes',
      count: 3,
      legacy: false,
      partial: false,
    ),
    (
      name: 'legacy active and deleted venue links',
      count: 3,
      legacy: true,
      partial: false,
    ),
    (
      name: 'partially migrated V1 preserves existing added values',
      count: 3,
      legacy: true,
      partial: true,
    ),
    (
      name: 'large V1 preserves 1000 complete recipes',
      count: 1000,
      legacy: false,
      partial: false,
    ),
  ]) {
    test(scenario.name, () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-migration-',
      );
      final file = File('${directory.path}/legacy.sqlite');
      createV1(
        file,
        count: scenario.count,
        legacyGroups: scenario.legacy,
        partial: scenario.partial,
      );
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final recipes = await db
            .getAllRecipes(); // Opens through real migration hooks.
        expect(recipes, hasLength(scenario.count));
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          db.schemaVersion,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(await db.getAllCategories(), hasLength(3));
        expect(
          await db.select(db.recipeIngredients).get(),
          hasLength(scenario.count),
        );
        expect(
          await db.select(db.recipeSteps).get(),
          hasLength(scenario.count),
        );
        for (final recipe in recipes) {
          expect(recipe.defaultYield, 2.5);
          expect(recipe.targetProfitMargin, 0.35);
          expect(recipe.targetPricePerPortion, 12.75);
          expect(recipe.fixedOverheadCost, 1.25);
          expect(recipe.dateCreated.millisecondsSinceEpoch ~/ 1000, 1700000000);
          expect(recipe.dateTimeModified, isNull);
          final index = int.parse(recipe.recipePk.substring(1));
          expect(recipe.archived, index.isOdd);
          expect(recipe.description, index.isEven ? null : 'Descripción 🍞');
        }
        final ingredients = await db.getAllIngredients(includeDeleted: true);
        expect(ingredients, hasLength(scenario.count));
        if (scenario.count > 0) {
          final detail = await db.getRecipeDetail('r0');
          expect(detail.steps.single.instruction, 'Mezclar ñ 🍞');
          expect(
            ingredients.firstWhere((i) => i.ingredientPk == 'i0').currentStock,
            scenario.partial ? 42.5 : 0,
          );
          expect(
            ingredients.firstWhere((i) => i.ingredientPk == 'i0').isDeleted,
            scenario.partial,
          );
          expect(
            await db.getSpaceIdsForRecipe('r0'),
            scenario.legacy ? ['venue'] : isEmpty,
          );
          if (scenario.legacy) {
            expect(await db.getSpaceIdsForRecipe('r1'), isEmpty);
          }
          final dto = FirestoreSyncService.recipeToFirestore(detail);
          expect(
            FirestoreSyncService.recipeFromFirestore(dto).spaceIds,
            detail.spaceIds,
          );
          // Explicit unassignment must survive reopening without legacy resurrection.
          await db.setRecipeSpaces('r0', []);
        }
        final groupCount = (await db.getAllGroups(includeDeleted: true)).length;
        final unitCount = (await db.getAllUnits()).length;
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(await db.getAllRecipes(), hasLength(scenario.count));
        expect(
          await db.getAllGroups(includeDeleted: true),
          hasLength(groupCount),
        );
        expect(await db.getAllUnits(), hasLength(unitCount));
        if (scenario.count > 0) {
          expect(await db.getSpaceIdsForRecipe('r0'), isEmpty);
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
