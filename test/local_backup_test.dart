import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/cloud_sync_screen.dart';
import 'package:recipetools/screens/settings_screen.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/utils/cloud_sync_service.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  group('SQLite header validation tests', () {
    test('isValidSqliteBytes detects genuine SQLite 3 header', () {
      final service = GoogleDriveSyncService(null);

      // Standard SQLite header: "SQLite format 3\000"
      final validHeader = Uint8List.fromList([
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
        0x01, 0x02, 0x03,
      ]);
      expect(service.isValidSqliteBytes(validHeader), isTrue);

      final invalidHeader = Uint8List.fromList([
        0x50, 0x4b, 0x03, 0x04, // ZIP header
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(service.isValidSqliteBytes(invalidHeader), isFalse);

      final tooShort = Uint8List.fromList([0x53, 0x51]);
      expect(service.isValidSqliteBytes(tooShort), isFalse);
    });

    test('restoreFromLocalFile handles invalid file safely and resets loading to false', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(() => MockDatabaseNotifier(AppDatabase.forTesting(NativeDatabase.memory()))),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4]);

      final result = await notifier.restoreFromLocalFile(
        filePath: 'dummy.sqlite',
        fileBytes: invalidBytes,
      );

      expect(result, isFalse);
      expect(container.read(cloudSyncProvider).loading, isFalse);
    });
  });

  group('Local Backup UI Widget Tests', () {
    late AppDatabase mockDb;
    late SharedPreferences mockPrefs;

    setUp(() async {
      mockDb = AppDatabase.forTesting(NativeDatabase.memory());
      mockPrefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await mockDb.close();
    });

    Widget createCloudSyncTestWidget({Locale locale = const Locale('es')}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWith(() => MockDatabaseNotifier(mockDb)),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudSyncScreen(),
        ),
      );
    }

    Widget createSettingsGeneralTestWidget({Locale locale = const Locale('es')}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWith(() => MockDatabaseNotifier(mockDb)),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsGeneralScreen(),
        ),
      );
    }

    testWidgets('CloudSyncScreen renders Local Backup Card with Load Local Backup button', (WidgetTester tester) async {
      await tester.pumpWidget(createCloudSyncTestWidget());
      await tester.pumpAndSettle();

      final loadBackupBtn = find.text('Cargar Copia de Seguridad Local');
      await tester.scrollUntilVisible(loadBackupBtn, 200, scrollable: find.byType(Scrollable).first);
      expect(loadBackupBtn, findsOneWidget);

      final localBackupTitle = find.text('Copia Local y Restauración');
      expect(localBackupTitle, findsOneWidget);
    });

    testWidgets('CloudSyncScreen renders English Load Local Backup button', (WidgetTester tester) async {
      await tester.pumpWidget(createCloudSyncTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final loadBackupBtn = find.text('Load Local Backup');
      await tester.scrollUntilVisible(loadBackupBtn, 200, scrollable: find.byType(Scrollable).first);
      expect(loadBackupBtn, findsOneWidget);

      final localBackupTitle = find.text('Local Backup & Restore');
      expect(localBackupTitle, findsOneWidget);
    });

    testWidgets('SettingsGeneralScreen renders Load Local Backup tile', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsGeneralTestWidget());
      await tester.pumpAndSettle();

      final loadTile = find.text('Cargar Copia de Seguridad Local');
      expect(loadTile, findsOneWidget);
    });
  });
}
