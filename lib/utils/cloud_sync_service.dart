import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart' as sq;

class GoogleDriveScopeDeniedException implements Exception {
  const GoogleDriveScopeDeniedException();
  @override
  String toString() => 'GoogleDriveScopeDeniedException: Google Drive AppData permission was denied.';
}

enum CloudSyncStorageType { googleDrive, localDirectory, firestore }

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class BackupFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime dateCreated;

  BackupFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.dateCreated,
  });
}

class GoogleDriveSyncService {
  static const defaultAndroidClientId = '194514517992-748uug2nkb8n29obqlfil2ue7t5ih97o.apps.googleusercontent.com';
  static const defaultWebClientId = '194514517992-vcj4bbuljsrea1qaoathcc3a2ssg5ush.apps.googleusercontent.com';
  static const defaultClientId = kIsWeb ? defaultWebClientId : defaultAndroidClientId;
  static const defaultServerClientId = defaultWebClientId;
  static const _storageTypeKey = 'google_drive_storage_type';
  static const _simSignInKey = 'google_drive_sim_signed_in';
  static const _simEmailKey = 'google_drive_sim_email';

  // Check if the current platform defaults to simulation mode
  bool get isDefaultSimulation =>
      kIsWeb || (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS));

  final GoogleSignInAccount? _currentUser;

  GoogleDriveSyncService(this._currentUser);

  /// Gets the current storage type from settings.
  Future<CloudSyncStorageType> getStorageType() async {
    if (kIsWeb) {
      return CloudSyncStorageType.firestore;
    }
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_storageTypeKey) ?? CloudSyncStorageType.firestore.index;
    return CloudSyncStorageType.values[index];
  }

  /// Sets the storage type.
  Future<void> setStorageType(CloudSyncStorageType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageTypeKey, type.index);
  }

  /// Checks if the user is currently signed in/connected.
  Future<bool> isSignedIn() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_simSignInKey) ?? false;
    }
    return _currentUser != null;
  }

  /// Gets the signed-in user's email address or sandbox identifier.
  Future<String?> getUserEmail() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_simEmailKey) ?? 'sandbox.user@gmail.com';
    }
    return _currentUser?.email;
  }

  /// Connects / signs in. Returns the authenticated account on success.
  Future<GoogleSignInAccount?> signIn() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_simSignInKey, true);
      await prefs.setString(_simEmailKey, 'sandbox.user@gmail.com');
      return null;
    }

    // Ensure previous session is cleared so Google shows the Account Picker dialog
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    await GoogleSignIn.instance.initialize(
      clientId: defaultClientId,
      serverClientId: defaultServerClientId,
    );
    
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == '12501') {
        return null;
      }
      rethrow;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('canceled') || str.contains('cancelled') || str.contains('12501')) {
        return null;
      }
      rethrow;
    }

    // Immediately prompt and verify driveAppdataScope authorization
    try {
      final authHeaders = await account.authorizationClient.authorizationHeaders([
        drive.DriveApi.driveAppdataScope,
      ], promptIfNecessary: true);

      if (authHeaders == null) {
        await GoogleSignIn.instance.signOut();
        throw const GoogleDriveScopeDeniedException();
      }
    } catch (e) {
      if (e is GoogleDriveScopeDeniedException) rethrow;
      final str = e.toString().toLowerCase();
      if (str.contains('canceled') || str.contains('cancelled') || str.contains('denied') || str.contains('12501')) {
        await GoogleSignIn.instance.signOut();
        throw const GoogleDriveScopeDeniedException();
      }
      rethrow;
    }

    return account;
  }

  /// Signs the user out locally.
  Future<void> signOut() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_simSignInKey, false);
      return;
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleSignIn.signOut failed or unimplemented: $e');
    }
  }

  /// Disconnects from Google account and revokes access permissions.
  Future<void> disconnect() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      await signOut();
      return;
    }
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('GoogleSignIn.disconnect notice: $e');
    }
    await signOut();
  }

  /// Gets the local SQLite file directory.
  Future<File> _getDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'db.sqlite'));
  }

  /// Gets the local sandbox backup folder directory.
  Future<Directory> _getMockDriveDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final mockDir = Directory(p.join(docDir.path, 'recipetools_backups'));
    if (!await mockDir.exists()) {
      await mockDir.create(recursive: true);
    }
    return mockDir;
  }

  static const _webSimBackupsKey = 'web_sim_backups_list';

  Future<List<BackupFile>> _getWebSimBackups() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_webSimBackupsKey) ?? [];
    return rawList.map((entry) {
      final parts = entry.split('|');
      return BackupFile(
        id: parts[0],
        name: parts.length > 1 ? parts[1] : 'backup.sqlite',
        sizeBytes: parts.length > 2 ? (int.tryParse(parts[2]) ?? 16384) : 16384,
        dateCreated: parts.length > 3 ? (DateTime.tryParse(parts[3]) ?? DateTime.now()) : DateTime.now(),
      );
    }).toList();
  }

  Future<void> _saveWebSimBackups(List<BackupFile> list) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = list
        .map((b) => '${b.id}|${b.name}|${b.sizeBytes}|${b.dateCreated.toIso8601String()}')
        .toList();
    await prefs.setStringList(_webSimBackupsKey, rawList);
  }

  /// Lists all backups.
  Future<List<BackupFile>> getBackups() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      if (kIsWeb) {
        final list = await _getWebSimBackups();
        list.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
        return list;
      }

      final mockDir = await _getMockDriveDirectory();
      final List<BackupFile> list = [];
      if (!await mockDir.exists()) return list;
      
      final files = mockDir.listSync();
      for (var file in files) {
        if (file is File && p.basename(file.path).startsWith('backup_') && file.path.endsWith('.sqlite')) {
          final stats = file.statSync();
          final name = p.basename(file.path);
          list.add(
            BackupFile(
              id: file.path,
              name: name,
              sizeBytes: stats.size,
              dateCreated: stats.changed,
            ),
          );
        }
      }
      list.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
      return list;
    }

    try {
      final client = await _getGoogleClient();
      if (client == null) return [];
      
      final driveApi = drive.DriveApi(client);
      
      final fileList = await driveApi.files.list(
        q: "mimeType = 'application/x-sqlite3' or name contains 'backup_'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, size, createdTime)',
      );

      final List<BackupFile> backups = [];
      if (fileList.files != null) {
        for (var file in fileList.files!) {
          backups.add(
            BackupFile(
              id: file.id ?? '',
              name: file.name ?? 'recipe_backup.sqlite',
              sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
              dateCreated: file.createdTime ?? DateTime.now(),
            ),
          );
        }
      }
      backups.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
      return backups;
    } catch (e) {
      debugPrint('Error getting Google Drive backups: $e');
      final errorStr = e.toString();
      if (errorStr.contains('403') || errorStr.contains('disabled') || errorStr.contains('drive.googleapis.com')) {
        throw Exception(
          'Google Drive API is disabled for project 194514517992. Enable it at: https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=194514517992',
        );
      }
      throw Exception('Google Drive error: $e');
    }
  }

  /// Creates a backup of the current database.
  Future<bool> createBackup() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupFileName = 'backup_$timestamp.sqlite';

    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      if (kIsWeb) {
        final list = await _getWebSimBackups();
        list.add(
          BackupFile(
            id: 'web_backup_$timestamp',
            name: backupFileName,
            sizeBytes: 32768,
            dateCreated: DateTime.now(),
          ),
        );
        await _saveWebSimBackups(list);
        return true;
      }

      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) return false;
      final mockDir = await _getMockDriveDirectory();
      final backupDest = File(p.join(mockDir.path, backupFileName));
      await dbFile.copy(backupDest.path);
      return true;
    }

    if (kIsWeb) return false;

    final dbFile = await _getDatabaseFile();
    if (!await dbFile.exists()) return false;

    try {
      final client = await _getGoogleClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);
      final bytes = await dbFile.readAsBytes();

      final driveFile = drive.File()
        ..name = backupFileName
        ..parents = ['appDataFolder'];

      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/x-sqlite3',
      );

      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      return result.id != null;
    } catch (e) {
      debugPrint('Error creating Google Drive backup: $e');
      return false;
    }
  }

  /// Restores the database from a backup.
  Future<bool> restoreBackup(String backupId) async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      if (kIsWeb) {
        return true;
      }

      final dbFile = await _getDatabaseFile();
      final sourceFile = File(backupId);
      if (!await sourceFile.exists()) return false;

      final bytes = await sourceFile.readAsBytes();
      if (!await _validateSqliteIntegrity(bytes)) {
        debugPrint('[CloudSync] Local directory backup failed SQLite integrity validation.');
        return false;
      }

      final walFile = File('${dbFile.path}-wal');
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      final shmFile = File('${dbFile.path}-shm');
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      await sourceFile.copy(dbFile.path);
      return true;
    }

    if (kIsWeb) return false;

    final dbFile = await _getDatabaseFile();

    try {
      final client = await _getGoogleClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);

      final mediaResponse = await driveApi.files.get(
        backupId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> fileBytes = [];
      await for (var data in mediaResponse.stream) {
        fileBytes.addAll(data);
      }

      if (fileBytes.isEmpty) return false;

      final bytes = Uint8List.fromList(fileBytes);
      if (!await _validateSqliteIntegrity(bytes)) {
        debugPrint('[CloudSync] Remote Google Drive backup failed SQLite integrity validation.');
        return false;
      }

      final walFile = File('${dbFile.path}-wal');
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      final shmFile = File('${dbFile.path}-shm');
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      await dbFile.writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Error restoring Google Drive backup: $e');
      return false;
    }
  }

  /// Checks whether a given list of bytes matches the SQLite 3 magic header.
  bool isValidSqliteBytes(List<int> bytes) {
    if (bytes.length < 16) return false;
    const sqliteHeader = [
      0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00
    ];
    for (int i = 0; i < 16; i++) {
      if (bytes[i] != sqliteHeader[i]) return false;
    }
    return true;
  }

  /// Validates that [bytes] represents a valid, non-corrupt SQLite 3 database
  /// with the required schema tables before overwriting the user database.
  Future<bool> _validateSqliteIntegrity(Uint8List bytes) async {
    if (kIsWeb) return true;
    if (!isValidSqliteBytes(bytes)) {
      debugPrint('[CloudSync] Rejected database restore: invalid SQLite header.');
      return false;
    }

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

  /// Visible for testing deep SQLite validation
  @visibleForTesting
  Future<bool> validateSqliteIntegrityForTesting(Uint8List bytes) => _validateSqliteIntegrity(bytes);

  /// Restores the database from a user-selected local file on the device.
  Future<bool> restoreFromLocalFile(String filePath, {Uint8List? fileBytes}) async {
    if (kIsWeb) return false;

    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.parent.exists()) {
        await dbFile.parent.create(recursive: true);
      }
      Uint8List? bytes = fileBytes;

      if (bytes == null || bytes.isEmpty) {
        if (filePath.isEmpty) {
          debugPrint('No file path or bytes provided for restore.');
          return false;
        }
        final sourceFile = File(filePath);
        if (!await sourceFile.exists()) {
          debugPrint('Source file does not exist at $filePath');
          return false;
        }
        bytes = await sourceFile.readAsBytes();
      }

      // 1. Magic header check
      if (!isValidSqliteBytes(bytes)) {
        debugPrint('Invalid SQLite header in restored file.');
        return false;
      }

      // 2. Deep SQLite integrity and schema check
      if (!await _validateSqliteIntegrity(bytes)) {
        debugPrint('SQLite file corrupted or missing required schema tables.');
        return false;
      }

      final walFile = File('${dbFile.path}-wal');
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      final shmFile = File('${dbFile.path}-shm');
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      await dbFile.writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Error restoring from local file: $e');
      return false;
    }
  }

  /// Exports the current SQLite database to a local file on the device.
  Future<File?> exportDatabaseToDirectory(String targetDirPath, {String? fileName}) async {
    if (kIsWeb) return null;

    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) return null;

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final exportName = fileName ?? 'backup_$timestamp.sqlite';
      final destFile = File(p.join(targetDirPath, exportName));

      return await dbFile.copy(destFile.path);
    } catch (e) {
      debugPrint('Error exporting database: $e');
      return null;
    }
  }

  /// Deletes a backup.
  Future<bool> deleteBackup(String backupId) async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      if (kIsWeb) {
        final list = await _getWebSimBackups();
        list.removeWhere((b) => b.id == backupId);
        await _saveWebSimBackups(list);
        return true;
      }

      final file = File(backupId);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    }

    try {
      final client = await _getGoogleClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);
      await driveApi.files.delete(backupId);
      return true;
    } catch (e) {
      debugPrint('Error deleting Google Drive backup: $e');
      return false;
    }
  }

  /// Deletes all backups stored in Google Drive AppData folder (or local directory in simulation mode).
  Future<bool> deleteAllBackups() async {
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    if (isSim) {
      if (kIsWeb) {
        await _saveWebSimBackups([]);
        return true;
      }
      final mockDir = await _getMockDriveDirectory();
      if (await mockDir.exists()) {
        final files = mockDir.listSync();
        for (final f in files) {
          if (f is File && f.path.endsWith('.sqlite')) {
            try { f.deleteSync(); } catch (_) {}
          }
        }
      }
      return true;
    }

    try {
      final client = await _getGoogleClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      );

      if (fileList.files != null) {
        for (var file in fileList.files!) {
          if (file.id != null) {
            try {
              await driveApi.files.delete(file.id!);
            } catch (e) {
              debugPrint('Error deleting file ${file.id}: $e');
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting all Google Drive backups: $e');
      return false;
    }
  }

  /// Downloads/exports a backup file to a target local directory path.
  Future<File?> downloadBackupToLocal(String backupId, String fileName, String targetDirPath) async {
    if (kIsWeb) return null;
    final isSim = (await getStorageType()) == CloudSyncStorageType.localDirectory;
    final exportFile = File(p.join(targetDirPath, fileName));

    if (isSim) {
      final sourceFile = File(backupId);
      if (!await sourceFile.exists()) return null;
      await sourceFile.copy(exportFile.path);
      return exportFile;
    }

    try {
      final client = await _getGoogleClient();
      if (client == null) return null;

      final driveApi = drive.DriveApi(client);
      final mediaResponse = await driveApi.files.get(
        backupId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> fileBytes = [];
      await for (var data in mediaResponse.stream) {
        fileBytes.addAll(data);
      }

      if (fileBytes.isEmpty) return null;

      await exportFile.writeAsBytes(fileBytes);
      return exportFile;
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      return null;
    }
  }

  /// Downloads a backup file to a temporary location for merging and inspection.
  Future<File?> downloadBackupToTemp(String backupId) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'sync_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite';
    return downloadBackupToLocal(backupId, fileName, tempDir.path);
  }

  /// Authenticated HTTP client helper for Google API access.
  Future<http.Client?> _getGoogleClient() async {
    final account = _currentUser;
    if (account == null) return null;

    try {
      final authHeaders = await account.authorizationClient.authorizationHeaders([
        drive.DriveApi.driveAppdataScope,
      ], promptIfNecessary: true);

      if (authHeaders == null) return null;
      return GoogleAuthClient(authHeaders);
    } catch (e) {
      debugPrint('Error obtaining Google API authorization headers: $e');
      return null;
    }
  }
}
