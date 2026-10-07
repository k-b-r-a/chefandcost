import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/settings_screen.dart';
import 'package:recipetools/utils/app_logger.dart';

import 'package:drift/native.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  group('AppLogger tests', () {
    test('Logs are added and formatted correctly', () {
      AppLogger.clear();
      AppLogger.info('Test info message');
      AppLogger.warn('Test warning message');
      AppLogger.error('Test error message');
      AppLogger.debug('Test debug message');

      final logs = AppLogger.logs;
      expect(logs.length, 4);
      expect(logs[0].level, LogLevel.info);
      expect(logs[0].message, 'Test info message');
      expect(logs[1].level, LogLevel.warn);
      expect(logs[2].level, LogLevel.error);
      expect(logs[3].level, LogLevel.debug);

      final exported = AppLogger.exportText();
      expect(exported, contains('[INFO] Test info message'));
      expect(exported, contains('[WARN] Test warning message'));
      expect(exported, contains('[ERROR] Test error message'));
      expect(exported, contains('[DEBUG] Test debug message'));

      AppLogger.clear();
      expect(AppLogger.logs, isEmpty);
    });
  });

  group('SettingsAboutScreen widget tests', () {
    late AppDatabase mockDb;

    setUp(() {
      mockDb = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await mockDb.close();
    });

    Widget createTestWidget({Locale locale = const Locale('es')}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWith(() => MockDatabaseNotifier(mockDb)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsAboutScreen(),
        ),
      );
    }

    testWidgets('Displays App Header, Version, DB Schema, and Beta Badge', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Chef&Cost'), findsOneWidget);
      expect(find.textContaining('0.1.0-beta+5'), findsOneWidget);
      expect(find.textContaining('Esquema DB v1'), findsOneWidget);
      expect(find.text('Canal Beta'), findsOneWidget);
    });

    testWidgets('Displays Developer Info and copies email to clipboard', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Esteban Z.'), findsOneWidget);
      expect(find.text('Creador & Desarrollador Principal'), findsOneWidget);
      expect(find.text('tebotan99@gmail.com'), findsOneWidget);

      final copyButton = find.byIcon(Icons.copy_rounded);
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(find.text('Correo copiado al portapapeles'), findsOneWidget);
    });

    testWidgets('Opens Changelog dialog and displays releases', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final changelogTile = find.text('Registro de Cambios');
      expect(changelogTile, findsOneWidget);

      await tester.tap(changelogTile);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('v0.1.0-beta+5'),
        ),
        findsOneWidget,
      );
      expect(find.text('v0.1.0-beta+4'), findsOneWidget);

      final beta2 = find.text('v0.1.0-beta+2');
      await tester.scrollUntilVisible(beta2, 100, scrollable: find.byType(Scrollable).last);
      expect(beta2, findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Opens Privacy Terms dialog and displays policies', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final privacyTile = find.text('Términos y Privacidad');
      expect(privacyTile, findsOneWidget);

      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Almacenamiento Local Prioritario'), findsOneWidget);
      expect(find.text('Propiedad Total de tus Datos'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Displays Licenses tile and Beta Debug Logging tile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final licensesTile = find.text('Licencias de Código Abierto');
      await tester.scrollUntilVisible(licensesTile, 200);
      expect(licensesTile, findsOneWidget);

      final debugTile = find.text('Diagnóstico y Depuración (Beta)');
      await tester.scrollUntilVisible(debugTile, 200);
      expect(debugTile, findsOneWidget);

      // Tap Debug Logs
      await tester.tap(debugTile);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Test Log'), findsOneWidget);
      expect(find.text('Limpiar Registros'), findsOneWidget);
      expect(find.text('Copiar Todo'), findsOneWidget);

      // Tap Test Log button
      await tester.tap(find.text('Test Log'));
      await tester.pumpAndSettle();

      // Tap Copy All button
      await tester.tap(find.text('Copiar Todo'));
      await tester.pumpAndSettle();
      expect(find.text('Registros copiados al portapapeles'), findsOneWidget);
    });
  });
}
