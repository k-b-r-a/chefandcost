import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipetools/utils/cloud_sync_service.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late GoogleDriveSyncService syncService;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('sqlite_restore_sec_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return testDir.path;
        }
        return null;
      },
    );

    syncService = GoogleDriveSyncService(null);
  });

  tearDown(() async {
    try {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Uint8List buildValidDatabaseBytes() {
    final file = File(p.join(testDir.path, 'source_valid.sqlite'));
    final db = sq.sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE recipes (id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE ingredients (id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE units (id INTEGER PRIMARY KEY, name TEXT);
      INSERT INTO recipes (name) VALUES ('Test Recipe');
    ''');
    db.close();
    return file.readAsBytesSync();
  }

  Uint8List buildIncompleteSchemaBytes() {
    final file = File(p.join(testDir.path, 'source_incomplete.sqlite'));
    final db = sq.sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE dummy (id INTEGER PRIMARY KEY, val TEXT);
    ''');
    db.close();
    return file.readAsBytesSync();
  }

  Uint8List buildCorruptedHeaderOnlyBytes() {
    // 16-byte SQLite magic header followed by corrupt garbage bytes
    final header = utf8.encode('SQLite format 3\x00');
    final garbage = List<int>.filled(512, 0xAA);
    return Uint8List.fromList([...header, ...garbage]);
  }

  group('SQLite Database Restore Integrity & Hardening Tests', () {
    test('isValidSqliteBytes identifies 16-byte SQLite format 3 magic header', () {
      final validHeader = Uint8List.fromList(utf8.encode('SQLite format 3\x00'));
      expect(syncService.isValidSqliteBytes(validHeader), isTrue);

      final invalidHeader = Uint8List.fromList(utf8.encode('NOT A SQLITE FILE!'));
      expect(syncService.isValidSqliteBytes(invalidHeader), isFalse);

      expect(syncService.isValidSqliteBytes(Uint8List(10)), isFalse);
    });

    test('validateSqliteIntegrity rejects corrupted file with valid 16-byte header', () async {
      final corrupted = buildCorruptedHeaderOnlyBytes();
      final isValid = await syncService.validateSqliteIntegrityForTesting(corrupted);
      expect(isValid, isFalse, reason: 'Corrupted payload must fail quick_check / open');
    });

    test('validateSqliteIntegrity rejects database missing core required application tables', () async {
      final incomplete = buildIncompleteSchemaBytes();
      final isValid = await syncService.validateSqliteIntegrityForTesting(incomplete);
      expect(isValid, isFalse, reason: 'Database missing recipes/ingredients/units must be rejected');
    });

    test('validateSqliteIntegrity accepts valid SQLite database with expected schema', () async {
      final valid = buildValidDatabaseBytes();
      final isValid = await syncService.validateSqliteIntegrityForTesting(valid);
      expect(isValid, isTrue, reason: 'Valid SQLite database with expected tables must pass');
    });

    test('restoreFromLocalFile rejects corrupted file and leaves existing database untouched', () async {
      final liveDbFile = File(p.join(testDir.path, 'db.sqlite'));
      final originalLiveBytes = Uint8List.fromList(utf8.encode('ORIGINAL_SECURE_LIVE_DATABASE_PAYLOAD'));
      await liveDbFile.writeAsBytes(originalLiveBytes);

      final corruptedBytes = buildCorruptedHeaderOnlyBytes();
      final restoreResult = await syncService.restoreFromLocalFile('', fileBytes: corruptedBytes);

      expect(restoreResult, isFalse, reason: 'Restore must return false for corrupted backup');

      // Crucial verification: Live database must be 100% untouched
      expect(await liveDbFile.exists(), isTrue);
      final currentLiveBytes = await liveDbFile.readAsBytes();
      expect(currentLiveBytes, equals(originalLiveBytes), reason: 'Existing live DB file must NOT be overwritten');
    });

    test('restoreFromLocalFile successfully restores a verified SQLite database', () async {
      final liveDbFile = File(p.join(testDir.path, 'db.sqlite'));
      await liveDbFile.writeAsBytes(Uint8List.fromList(utf8.encode('OLD_DATA')));

      final validBytes = buildValidDatabaseBytes();
      final restoreResult = await syncService.restoreFromLocalFile('', fileBytes: validBytes);

      expect(restoreResult, isTrue, reason: 'Valid backup must restore successfully');

      expect(await liveDbFile.exists(), isTrue);
      final restoredBytes = await liveDbFile.readAsBytes();
      expect(restoredBytes, equals(validBytes));
    });
  });
}
