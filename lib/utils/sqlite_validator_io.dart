import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sq;

Future<bool> validateSqliteIntegrityPlatform(Uint8List bytes) async {
  final tempDir = Directory.systemTemp;
  final tempFile = File(p.join(
    tempDir.path,
    'db_validate_${DateTime.now().microsecondsSinceEpoch}_${bytes.length}.sqlite',
  ));

  sq.Database? db;
  try {
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      db = sq.sqlite3.open(tempFile.path, mode: sq.OpenMode.readOnly);
    } catch (openErr) {
      debugPrint('[CloudSync] Failed to open SQLite database: $openErr');
      return false;
    }

    // 1. Run PRAGMA quick_check to verify b-tree and page integrity
    final quickCheckResult = db.select('PRAGMA quick_check;');
    if (quickCheckResult.isEmpty) return false;
    final statusString = quickCheckResult.first.values.first?.toString().toLowerCase();
    if (statusString != 'ok') {
      debugPrint('[CloudSync] PRAGMA quick_check failed: $statusString');
      return false;
    }

    // 2. Verify that core application schema tables exist in sqlite_master
    final tablesQuery = db.select("SELECT name FROM sqlite_master WHERE type='table';");
    final existingTables = tablesQuery
        .map((row) => row['name']?.toString().toLowerCase())
        .whereType<String>()
        .toSet();

    const requiredTables = {'recipes', 'ingredients', 'units'};
    final missing = requiredTables.difference(existingTables);
    if (missing.isNotEmpty) {
      debugPrint('[CloudSync] SQLite backup missing required application tables: $missing');
      return false;
    }

    return true;
  } catch (e) {
    debugPrint('[CloudSync] Unexpected error during SQLite integrity check: $e');
    return false;
  } finally {
    try {
      db?.close();
    } catch (_) {}
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}
