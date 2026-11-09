import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/database/initialize_default_database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/widgets/active_group_chip.dart';
import 'package:recipetools/widgets/group_management_sheet.dart';
import 'package:recipetools/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spaces and Default Group Localization Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await db.close();
    });

    test('First open defaults activeGroupIdProvider to kAllGroupsId and activeGroupProvider to null', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // On first open, activeGroupIdProvider must be kAllGroupsId
      final activeId = container.read(activeGroupIdProvider);
      expect(activeId, equals(kAllGroupsId));

      // activeGroupProvider must be null (representing all spaces active)
      final activeGroup = container.read(activeGroupProvider);
      expect(activeGroup, isNull);
    });

    test('resolveDefaultGroupName returns Principal for Spanish and Main for English', () {
      final nameEs = resolveDefaultGroupName(const Locale('es'));
      expect(nameEs, equals('Principal'));

      final nameEn = resolveDefaultGroupName(const Locale('en'));
      expect(nameEn, equals('Main'));
    });

    test('initializeDefaultDatabase creates group with Spanish name Principal when locale is es', () async {
      await initializeDefaultDatabase(db, const Locale('es'));
      final groups = await db.getAllGroups();
      expect(groups, isNotEmpty);
      expect(groups.first.name, equals('Principal'));
    });

    test('initializeDefaultDatabase creates group with English name Main when locale is en', () async {
      await initializeDefaultDatabase(db, const Locale('en'));
      final groups = await db.getAllGroups();
      expect(groups, isNotEmpty);
      expect(groups.first.name, equals('Main'));
    });

    test('initializeDefaultDatabase updates default group name if phone language changes', () async {
      // First initialize with Spanish
      await initializeDefaultDatabase(db, const Locale('es'));
      var groups = await db.getAllGroups();
      expect(groups.first.name, equals('Principal'));

      // Re-initialize with English (e.g. system phone language is English)
      await initializeDefaultDatabase(db, const Locale('en'));
      groups = await db.getAllGroups();
      expect(groups.first.name, equals('Main'));
    });

    testWidgets('ActiveGroupChip on first open displays All Workspaces / Todos los espacios', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await initializeDefaultDatabase(db, const Locale('es'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(db)),
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

      // Should display 'Todos los espacios' since all spaces are active on first open
      expect(find.text('Todos los espacios'), findsOneWidget);

      // Tap ActiveGroupChip to open GroupManagementSheet
      await tester.tap(find.byType(ActiveGroupChip));
      await tester.pumpAndSettle();

      expect(find.byType(GroupManagementSheet), findsOneWidget);
      // 'Todos los espacios' is listed and selected
      expect(find.text('Todos los espacios'), findsWidgets);
      // The default group 'Principal' is also listed
      expect(find.text('Principal'), findsOneWidget);

      Navigator.of(tester.element(find.byType(GroupManagementSheet))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('ActiveGroupChip in English displays All Workspaces and Main', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await initializeDefaultDatabase(db, const Locale('en'));

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

      // In English, should display 'All Workspaces' on first open
      expect(find.text('All Workspaces'), findsOneWidget);

      // Tap ActiveGroupChip to open GroupManagementSheet
      await tester.tap(find.byType(ActiveGroupChip));
      await tester.pumpAndSettle();

      expect(find.byType(GroupManagementSheet), findsOneWidget);
      // The default group 'Main' is listed in English
      expect(find.text('Main'), findsOneWidget);

      Navigator.of(tester.element(find.byType(GroupManagementSheet))).pop();
      await tester.pumpAndSettle();
    });
  });
}

class _MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}
