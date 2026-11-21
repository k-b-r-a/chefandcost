import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/initialize_default_database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/widgets/active_group_chip.dart';
import 'package:recipetools/widgets/group_management_sheet.dart';

class _MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

Group _makeGroup({
  required String id,
  required String name,
  String iconName = 'storefront',
  String colorHex = '4CAF50',
  bool isDeleted = false,
}) {
  final now = DateTime(2026, 1, 1);
  return Group(
    id: id,
    name: name,
    iconName: iconName,
    colorHex: colorHex,
    isActive: !isDeleted,
    createdAt: now,
    updatedAt: now,
    isDeleted: isDeleted,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Database Multi-Workspace Visibility Filtering', () {
    setUp(() async {
      await initializeDefaultDatabase(db, const Locale('en'));
      await db.insertGroup(
        GroupsCompanion.insert(
          id: const Value('space-a'),
          name: 'Kitchen A',
          iconName: const Value('restaurant'),
          colorHex: const Value('FF9800'),
        ),
      );
      await db.insertGroup(
        GroupsCompanion.insert(
          id: const Value('space-b'),
          name: 'Kitchen B',
          iconName: const Value('bakery_dining'),
          colorHex: const Value('2196F3'),
        ),
      );
      await db.insertGroup(
        GroupsCompanion.insert(
          id: const Value('space-c'),
          name: 'Bar C',
          iconName: const Value('local_bar'),
          colorHex: const Value('9C27B0'),
        ),
      );

      for (final entry in [
        ('rec-a', 'Recipe Only A'),
        ('rec-b', 'Recipe Only B'),
        ('rec-ab', 'Recipe Shared AB'),
        ('rec-c', 'Recipe Only C'),
        ('rec-unassigned', 'Recipe Unassigned'),
        ('rec-deleted-link', 'Recipe Deleted Link'),
      ]) {
        await db.insertRecipe(
          RecipesCompanion.insert(
            recipePk: Value(entry.$1),
            name: entry.$2,
            defaultYield: 1.0,
            yieldName: 'portion',
          ),
        );
      }

      await db.setRecipeSpaces('rec-a', ['space-a']);
      await db.setRecipeSpaces('rec-b', ['space-b']);
      await db.setRecipeSpaces('rec-ab', ['space-a', 'space-b']);
      await db.setRecipeSpaces('rec-c', ['space-c']);
      await db.setRecipeSpaces('rec-deleted-link', ['space-a']);
      await db.setRecipeSpaces('rec-deleted-link', []);
    });

    test(
      'getRecipes hides recipes whose spaces are all hidden while preserving multi-space and unassigned recipes',
      () async {
        final hideA = await db.getRecipes(hiddenSpaceIds: {'space-a'});
        final hideAPks = hideA.map((r) => r.recipePk).toSet();
        expect(hideAPks, isNot(contains('rec-a')));
        expect(
          hideAPks,
          containsAll([
            'rec-b',
            'rec-ab',
            'rec-c',
            'rec-unassigned',
            'rec-deleted-link',
          ]),
        );

        final hideAB = await db.getRecipes(
          hiddenSpaceIds: {'space-a', 'space-b'},
        );
        final hideABPks = hideAB.map((r) => r.recipePk).toSet();
        expect(hideABPks, isNot(contains('rec-a')));
        expect(hideABPks, isNot(contains('rec-b')));
        expect(hideABPks, isNot(contains('rec-ab')));
        expect(
          hideABPks,
          containsAll(['rec-c', 'rec-unassigned', 'rec-deleted-link']),
        );

        final hideAllSpaces = await db.getRecipes(
          hiddenSpaceIds: {
            'group_default_principal',
            'space-a',
            'space-b',
            'space-c',
          },
        );
        expect(
          hideAllSpaces.map((r) => r.recipePk).toSet(),
          equals({'rec-unassigned', 'rec-deleted-link'}),
        );
      },
    );

    test(
      'watchAllRecipes and watchAllRecipesWithFinancials respect hiddenSpaceIds reactively',
      () async {
        final recipeIterator = StreamIterator(
          db.watchAllRecipes(hiddenSpaceIds: {'space-a'}),
        );
        final finIterator = StreamIterator(
          db.watchAllRecipesWithFinancials(hiddenSpaceIds: {'space-a'}),
        );
        addTearDown(() async {
          await recipeIterator.cancel();
          await finIterator.cancel();
        });

        expect(
          await recipeIterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(
          recipeIterator.current.map((r) => r.recipePk).toSet(),
          equals({'rec-b', 'rec-ab', 'rec-c', 'rec-unassigned', 'rec-deleted-link'}),
        );

        expect(
          await finIterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(
          finIterator.current.map((r) => r.recipe.recipePk).toSet(),
          equals({'rec-b', 'rec-ab', 'rec-c', 'rec-unassigned', 'rec-deleted-link'}),
        );

        // Removing 'space-b' from rec-ab leaves only hidden 'space-a', so both streams hide rec-ab.
        await db.setRecipeSpaces('rec-ab', ['space-a']);

        expect(
          await recipeIterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(
          recipeIterator.current.map((r) => r.recipePk).toSet(),
          equals({'rec-b', 'rec-c', 'rec-unassigned', 'rec-deleted-link'}),
        );

        expect(
          await finIterator.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(
          finIterator.current.map((r) => r.recipe.recipePk).toSet(),
          equals({'rec-b', 'rec-c', 'rec-unassigned', 'rec-deleted-link'}),
        );
      },
    );
  });

  group('2. HiddenWorkspaceIdsNotifier & SharedPreferences Persistence', () {
    test(
      'defaults to empty, toggles, persists across containers, and supports bulk helpers',
      () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

        expect(container.read(hiddenWorkspaceIdsProvider), isEmpty);

        final notifier = container.read(hiddenWorkspaceIdsProvider.notifier);
        await notifier.toggleWorkspaceVisibility('space-a');
        expect(container.read(hiddenWorkspaceIdsProvider), equals({'space-a'}));
        expect(
          prefs.getStringList(
            HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey,
          ),
          equals(['space-a']),
        );

        // Fresh container restores persisted hidden set.
        final restoredContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(restoredContainer.dispose);
        expect(
          restoredContainer.read(hiddenWorkspaceIdsProvider),
          equals({'space-a'}),
        );

        await notifier.hideAllWorkspaces(['space-a', 'space-b', 'space-c']);
        expect(
          container.read(hiddenWorkspaceIdsProvider),
          equals({'space-a', 'space-b', 'space-c'}),
        );

        await notifier.showOnlyWorkspace('space-b', [
          'space-a',
          'space-b',
          'space-c',
        ]);
        expect(
          container.read(hiddenWorkspaceIdsProvider),
          equals({'space-a', 'space-c'}),
        );

        await notifier.removeWorkspaceId('space-a');
        expect(container.read(hiddenWorkspaceIdsProvider), equals({'space-c'}));

        await notifier.showAllWorkspaces();
        expect(container.read(hiddenWorkspaceIdsProvider), isEmpty);
        expect(
          prefs.getStringList(
            HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey,
          ),
          isEmpty,
        );

        container.dispose();
      },
    );

    test(
      'recipesWithFinancialsStreamProvider updates union of visible workspaces as visibility toggles',
      () async {
        await initializeDefaultDatabase(db, const Locale('en'));
        await db.insertGroup(
          GroupsCompanion.insert(id: const Value('space-a'), name: 'Kitchen A'),
        );
        await db.insertGroup(
          GroupsCompanion.insert(id: const Value('space-b'), name: 'Kitchen B'),
        );
        await db.insertRecipe(
          RecipesCompanion.insert(
            recipePk: const Value('rec-a'),
            name: 'Soup A',
            defaultYield: 1,
            yieldName: 'portion',
          ),
        );
        await db.insertRecipe(
          RecipesCompanion.insert(
            recipePk: const Value('rec-b'),
            name: 'Bread B',
            defaultYield: 1,
            yieldName: 'portion',
          ),
        );
        await db.setRecipeSpaces('rec-a', ['space-a']);
        await db.setRecipeSpaces('rec-b', ['space-b']);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        Future<Set<String>> nextRecipeIds() async {
          final completer = Completer<Set<String>>();
          late final ProviderSubscription<AsyncValue<List<RecipeWithFinancials>>>
          sub;
          sub = container.listen(recipesWithFinancialsStreamProvider, (
            _,
            next,
          ) {
            next.whenData((list) {
              if (!completer.isCompleted) {
                completer.complete(
                  list.map((item) => item.recipe.recipePk).toSet(),
                );
              }
            });
          }, fireImmediately: true);
          try {
            return await completer.future.timeout(const Duration(seconds: 5));
          } finally {
            sub.close();
          }
        }

        expect(await nextRecipeIds(), equals({'rec-a', 'rec-b'}));

        final notifier = container.read(hiddenWorkspaceIdsProvider.notifier);
        await notifier.toggleWorkspaceVisibility('space-a');
        expect(await nextRecipeIds(), equals({'rec-b'}));

        await notifier.toggleWorkspaceVisibility('space-b');
        expect(await nextRecipeIds(), isEmpty);

        await notifier.toggleWorkspaceVisibility('space-a');
        expect(await nextRecipeIds(), equals({'rec-a'}));

        await notifier.showAllWorkspaces();
        expect(await nextRecipeIds(), equals({'rec-a', 'rec-b'}));
      },
    );
  });

  group('3. Eye-Icon Toggle UI & ActiveGroupChip', () {
    testWidgets(
      'GroupManagementSheet toggles individual and All Workspaces visibility without closing',
      (tester) async {
        await initializeDefaultDatabase(db, const Locale('en'));
        await db.insertGroup(
          GroupsCompanion.insert(
            id: const Value('space-b'),
            name: 'Kitchen B',
            iconName: const Value('restaurant'),
            colorHex: const Value('FF9800'),
          ),
        );
        await db.insertGroup(
          GroupsCompanion.insert(
            id: const Value('space-c'),
            name: 'Bar C',
            iconName: const Value('local_bar'),
            colorHex: const Value('2196F3'),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: Scaffold(body: GroupManagementSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final spaceBEye = find.byKey(const ValueKey('workspace_visibility_space-b'));
        final allEye = find.byKey(const ValueKey('workspace_visibility_all'));
        expect(spaceBEye, findsOneWidget);
        expect(allEye, findsOneWidget);

        // Initially visible: eye icon is visibility_rounded, row opacity is 1.0.
        expect(
          find.descendant(
            of: spaceBEye,
            matching: find.byIcon(Icons.visibility_rounded),
          ),
          findsOneWidget,
        );
        final rowOpacityBefore = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Kitchen B'),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(rowOpacityBefore.opacity, equals(1.0));

        // Tap eye icon for Kitchen B -> hides it, dims row, persists prefs, stays open.
        await tester.tap(spaceBEye);
        await tester.pumpAndSettle();

        expect(find.byType(GroupManagementSheet), findsOneWidget);
        expect(
          find.descendant(
            of: spaceBEye,
            matching: find.byIcon(Icons.visibility_off_outlined),
          ),
          findsOneWidget,
        );
        final rowOpacityAfter = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Kitchen B'),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(rowOpacityAfter.opacity, equals(0.55));
        expect(
          prefs.getStringList(
            HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey,
          ),
          equals(['space-b']),
        );
        expect(find.text('2/3 visible'), findsOneWidget);

        // Tapping All Workspaces eye restores all visible when partially hidden.
        await tester.tap(allEye);
        await tester.pumpAndSettle();
        expect(
          prefs.getStringList(
            HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey,
          ),
          isEmpty,
        );
        expect(
          find.descendant(
            of: allEye,
            matching: find.byIcon(Icons.visibility_rounded),
          ),
          findsOneWidget,
        );

        // Tapping All Workspaces eye when all visible hides all 3 workspaces.
        await tester.tap(allEye);
        await tester.pumpAndSettle();
        expect(
          prefs
              .getStringList(
                HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey,
              )
              ?.toSet(),
          equals({'group_default_principal', 'space-b', 'space-c'}),
        );
        expect(
          find.descendant(
            of: allEye,
            matching: find.byIcon(Icons.visibility_off_outlined),
          ),
          findsOneWidget,
        );
        expect(find.text('0/3 visible'), findsOneWidget);

        // Clean teardown of Drift stream watchers.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ActiveGroupChip displays All Workspaces, partial count, single workspace, and all-hidden states',
      (tester) async {
        final groups = [
          _makeGroup(id: 'group_default_principal', name: 'Main'),
          _makeGroup(
            id: 'space-b',
            name: 'Kitchen B',
            iconName: 'restaurant',
            colorHex: 'FF9800',
          ),
          _makeGroup(
            id: 'space-c',
            name: 'Bar C',
            iconName: 'local_bar',
            colorHex: '2196F3',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupsStreamProvider.overrideWith((ref) => Stream.value(groups)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: Scaffold(body: ActiveGroupChip()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ActiveGroupChip)),
        );
        final notifier = container.read(hiddenWorkspaceIdsProvider.notifier);

        // 1. All visible
        expect(find.text('All Workspaces'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

        // 2. Partial subset visible (2 of 3)
        await notifier.toggleWorkspaceVisibility('space-c');
        await tester.pumpAndSettle();
        expect(find.text('2/3 visible'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

        // 3. Single visible (Kitchen B)
        await notifier.toggleWorkspaceVisibility('group_default_principal');
        await tester.pumpAndSettle();
        expect(find.text('Kitchen B'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

        // 4. All hidden (0 of 3)
        await notifier.toggleWorkspaceVisibility('space-b');
        await tester.pumpAndSettle();
        expect(find.text('0/3 visible'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      },
    );
  });

  group('4. RecipeEditorScreen Default Space Pre-Selection', () {
    Future<void> pumpEditorWithHidden({
      required WidgetTester tester,
      required List<Group> groups,
      required List<String> initialHiddenIds,
    }) async {
      SharedPreferences.setMockInitialValues({
        HiddenWorkspaceIdsNotifier.prefHiddenWorkspaceIdsKey: initialHiddenIds,
      });
      final testPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            ingredientsStreamProvider.overrideWith(
              (ref) => Stream.value(<Ingredient>[]),
            ),
            unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
            groupsStreamProvider.overrideWith((ref) => Stream.value(groups)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: _DelayedEditorHost(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_editor_btn')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'pre-selects the sole visible workspace when exactly 1 workspace is visible',
      (tester) async {
        final groups = [
          _makeGroup(id: 'group_default_principal', name: 'Main'),
          _makeGroup(id: 'space-b', name: 'Kitchen B'),
          _makeGroup(id: 'space-c', name: 'Bar C'),
        ];

        await pumpEditorWithHidden(
          tester: tester,
          groups: groups,
          initialHiddenIds: ['group_default_principal', 'space-c'],
        );

        final mainChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Main'),
            matching: find.byType(FilterChip),
          ),
        );
        final kitchenBChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Kitchen B'),
            matching: find.byType(FilterChip),
          ),
        );
        final barCChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Bar C'),
            matching: find.byType(FilterChip),
          ),
        );

        expect(mainChip.selected, isFalse);
        expect(kitchenBChip.selected, isTrue);
        expect(barCChip.selected, isFalse);
      },
    );

    testWidgets(
      'falls back to default workspace when multiple workspaces are visible',
      (tester) async {
        final groups = [
          _makeGroup(id: 'space-b', name: 'Kitchen B'),
          _makeGroup(id: 'group_default_principal', name: 'Main'),
          _makeGroup(id: 'space-c', name: 'Bar C'),
        ];

        await pumpEditorWithHidden(
          tester: tester,
          groups: groups,
          initialHiddenIds: ['space-c'],
        );

        final mainChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Main'),
            matching: find.byType(FilterChip),
          ),
        );
        final kitchenBChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Kitchen B'),
            matching: find.byType(FilterChip),
          ),
        );

        expect(mainChip.selected, isTrue);
        expect(kitchenBChip.selected, isFalse);
      },
    );
  });
}

class _DelayedEditorHost extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DelayedEditorHost> createState() => _DelayedEditorHostState();
}

class _DelayedEditorHostState extends ConsumerState<_DelayedEditorHost> {
  bool _showEditor = false;

  @override
  Widget build(BuildContext context) {
    // Ensure groupsStreamProvider has resolved before mounting RecipeEditorScreen.
    ref.watch(groupsStreamProvider);
    if (_showEditor) {
      return const RecipeEditorScreen();
    }
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('open_editor_btn'),
          onPressed: () => setState(() => _showEditor = true),
          child: const Text('Open'),
        ),
      ),
    );
  }
}
