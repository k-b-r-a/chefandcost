import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/utils/firestore_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final old = DateTime.utc(2026, 1, 1);
  final recent = DateTime.utc(2026, 2, 1);

  Future<int> pull(
    DateTime time,
    List<String> spaces, {
    String name = 'Remote',
  }) => db.mergeRecipeFromRemote(
    remoteRecipe: Recipe(
      recipePk: 'recipe',
      name: name,
      defaultYield: 1,
      targetProfitMargin: 0,
      targetPricePerPortion: 0,
      fixedOverheadCost: 0,
      archived: false,
      yieldName: 'portion',
      dateCreated: old,
      dateTimeModified: time,
    ),
    remoteIngredients: [],
    remoteSteps: [],
    remoteSpaceIds: spaces,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final id in ['a', 'b']) {
      await db.insertGroup(
        GroupsCompanion.insert(
          id: Value(id),
          name: id,
          createdAt: Value(old),
          updatedAt: Value(old),
        ),
      );
    }
  });
  tearDown(() => db.close());

  test('newer remote replaces spaces and explicit empty removes all', () async {
    await pull(old, ['a', 'b']);
    expect(await pull(recent, []), 2);
    expect(await db.getSpaceIdsForRecipe('recipe'), isEmpty);
    expect(await db.getRecipes(spaceId: 'a'), isEmpty);
    expect(await db.getAllRecipes(), hasLength(1));
  });

  test('older remote cannot overwrite newer local recipe or spaces', () async {
    await pull(recent, ['a'], name: 'Local newer');
    expect(await pull(old, ['b']), 0);
    expect(await db.getSpaceIdsForRecipe('recipe'), ['a']);
    expect((await db.getRecipeDetail('recipe')).recipe.name, 'Local newer');
  });

  test(
    'equal timestamp conflict consistently retains local assignments',
    () async {
      await pull(recent, ['a']);
      expect(await pull(recent, ['b']), 0);
      expect(await db.getSpaceIdsForRecipe('recipe'), ['a']);
    },
  );

  test('retrying identical downloads is idempotent', () async {
    expect(await pull(old, ['a', 'a', 'b']), 1);
    for (var i = 0; i < 5; i++) {
      expect(await pull(old, ['a', 'b']), 0);
    }
    expect(await db.select(db.recipeSpaces).get(), hasLength(2));
    expect(await db.getAllRecipes(), hasLength(1));
  });

  test('newer recipe cannot resurrect remotely deleted space', () async {
    await pull(old, ['a']);
    final space = (await db.getGroupById('a'))!;
    await db.mergeGroupFromRemote(
      space.copyWith(isDeleted: true, updatedAt: recent),
    );
    await pull(recent.add(const Duration(days: 1)), ['a', 'b']);
    expect(await db.getSpaceIdsForRecipe('recipe'), ['b']);
    expect(await db.getRecipes(spaceId: 'a'), isEmpty);
  });

  test('older group edit cannot undo deletion', () async {
    final space = (await db.getGroupById('a'))!;
    await db.mergeGroupFromRemote(
      space.copyWith(isDeleted: true, updatedAt: recent),
    );
    await db.mergeGroupFromRemote(space.copyWith(name: 'Stale name'));
    expect((await db.getGroupById('a'))!.isDeleted, isTrue);
  });

  test(
    'unassignment tombstone can be reactivated without duplicate links',
    () async {
      await pull(old, ['a']);
      await pull(recent, []);
      await pull(recent.add(const Duration(days: 1)), ['a']);
      expect(await db.getSpaceIdsForRecipe('recipe'), ['a']);
      expect(await db.select(db.recipeSpaces).get(), hasLength(1));
    },
  );

  test('legacy group field is used only when space_ids is absent', () {
    final legacy = {'recipePk': 'r', 'groupId': 'a'};
    expect(FirestoreSyncService.recipeFromFirestore(legacy).spaceIds, ['a']);
    expect(
      FirestoreSyncService.recipeFromFirestore({
        ...legacy,
        'space_ids': [],
      }).spaceIds,
      isEmpty,
    );
    expect(
      FirestoreSyncService.recipeFromFirestore({
        ...legacy,
        'space_ids': ['b'],
      }).spaceIds,
      ['b'],
    );
  });

  test(
    'mixed array values are ignored and document id fallback is preserved',
    () {
      final parsed = FirestoreSyncService.recipeFromFirestore({
        'space_ids': ['a', null, 42, false, 'b'],
        'dateCreated': Timestamp.fromDate(old),
        'dateTimeModified': recent.toIso8601String(),
      }, fallbackId: 'document-id');
      expect(parsed.recipe.recipePk, 'document-id');
      expect(parsed.spaceIds, ['a', 'b']);
      expect(parsed.recipe.dateCreated.toUtc(), old);
      expect(parsed.recipe.dateTimeModified!.toUtc(), recent);
    },
  );

  test('malformed space_ids does not crash the entire sync', () {
    for (final value in [
      'a',
      42,
      false,
      {'a': true},
    ]) {
      expect(
        FirestoreSyncService.recipeFromFirestore({'space_ids': value}).spaceIds,
        isEmpty,
      );
    }
  });

  test(
    'round trip retains explicit unassignment and shared assignments',
    () async {
      await pull(old, ['a', 'b']);
      for (final ids in [
        <String>['a', 'b'],
        <String>[],
      ]) {
        await db.setRecipeSpaces('recipe', ids);
        final data = FirestoreSyncService.recipeToFirestore(
          await db.getRecipeDetail('recipe'),
        );
        expect(
          FirestoreSyncService.recipeFromFirestore(data).spaceIds,
          unorderedEquals(ids),
        );
      }
    },
  );
}
