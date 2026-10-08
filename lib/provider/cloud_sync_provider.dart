import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import '../database/database.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/firestore_sync_service.dart';
import 'database_provider.dart';

class CloudSyncState {
  final bool signedIn;
  final String? email;
  final List<BackupFile> backups;
  final bool loading;
  final String? errorMessage;
  final String? successMessage;
  final CloudSyncStorageType storageType;

  CloudSyncState({
    this.signedIn = false,
    this.email,
    this.backups = const [],
    this.loading = false,
    this.errorMessage,
    this.successMessage,
    this.storageType = CloudSyncStorageType.firestore,
  });

  CloudSyncState copyWith({
    bool? signedIn,
    String? email,
    List<BackupFile>? backups,
    bool? loading,
    String? errorMessage,
    String? successMessage,
    CloudSyncStorageType? storageType,
  }) {
    return CloudSyncState(
      signedIn: signedIn ?? this.signedIn,
      email: email ?? this.email,
      backups: backups ?? this.backups,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      storageType: storageType ?? this.storageType,
    );
  }
}

class CloudSyncNotifier extends Notifier<CloudSyncState> {
  GoogleDriveSyncService get _syncService => ref.read(googleDriveSyncServiceProvider);
  FirestoreSyncService get _firestoreService => ref.read(firestoreSyncServiceProvider);

  bool _disposed = false;

  @override
  CloudSyncState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });

    // Check initial connection status asynchronously
    Future.microtask(() {
      if (!_disposed) {
        checkStatus();
      }
    });

    return CloudSyncState();
  }

  Future<void> checkStatus() async {
    if (_disposed) return;
    state = state.copyWith(loading: true);
    try {
      final storageType = await _syncService.getStorageType();
      if (_disposed) return;

      if (storageType == CloudSyncStorageType.firestore) {
        final user = _firestoreService.authCurrentUser;
        final signedIn = _firestoreService.isConfigured && user != null;
        final email = user?.email;
        if (_disposed) return;
        state = state.copyWith(
          signedIn: signedIn,
          email: email,
          backups: const [],
          storageType: storageType,
          loading: false,
        );
        return;
      }
      
      GoogleSignInAccount? account;
      if (storageType == CloudSyncStorageType.googleDrive) {
        if (!kIsWeb) {
          try {
            await GoogleSignIn.instance.initialize(
              clientId: GoogleDriveSyncService.defaultClientId,
              serverClientId: GoogleDriveSyncService.defaultServerClientId,
            );
            account = await GoogleSignIn.instance.attemptLightweightAuthentication();
            if (!_disposed) {
              ref.read(googleUserProvider.notifier).setUser(account);
            }
          } catch (_) {}
        }
      }
      
      final signedIn = storageType == CloudSyncStorageType.localDirectory || account != null;
      String? email;
      if (signedIn) {
        email = storageType == CloudSyncStorageType.localDirectory ? 'Local Backup' : account?.email;
      }
      
      final backups = await _syncService.getBackups();
      if (_disposed) return;
      
      state = state.copyWith(
        signedIn: signedIn,
        email: email,
        backups: backups,
        storageType: storageType,
        loading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        errorMessage: 'Failed to verify cloud sync connection status.',
      );
    }
  }

  Future<void> setStorageType(CloudSyncStorageType type) async {
    state = state.copyWith(loading: true);
    await _syncService.signOut(); // Sign out of existing connection
    await _syncService.setStorageType(type);
    
    if (type == CloudSyncStorageType.firestore) {
      final user = _firestoreService.authCurrentUser;
      final signedIn = _firestoreService.isConfigured && user != null;
      final email = user?.email;
      state = CloudSyncState(
        storageType: type,
        signedIn: signedIn,
        email: email,
        backups: const [],
        loading: false,
      );
      return;
    }

    final backups = await _syncService.getBackups();
    
    state = CloudSyncState(
      storageType: type,
      signedIn: type == CloudSyncStorageType.localDirectory, // Local Backup mode is always connected
      email: type == CloudSyncStorageType.localDirectory ? 'Local Backup' : null,
      backups: backups,
      loading: false,
    );
  }

  /// Signs in with Email and Password (or registers if isRegister is true)
  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool isRegister = false,
  }) async {
    state = state.copyWith(loading: true);
    try {
      if (!_firestoreService.isConfigured) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Firebase is not initialized. Please configure firebase_options.dart.',
        );
        return;
      }
      final cred = isRegister
          ? await _firestoreService.registerWithEmail(email, password)
          : await _firestoreService.signInWithEmail(email, password);
      final userEmail = cred.user?.email ?? email.trim();
      state = state.copyWith(
        signedIn: true,
        email: userEmail,
        loading: false,
        successMessage: isRegister
            ? '¡Cuenta creada exitosamente! ($userEmail)'
            : 'Sesión iniciada como $userEmail',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: _formatAuthError(e),
      );
    }
  }

  /// Signs in with Google account (native popup on web, GoogleSignIn on mobile)
  Future<void> signInWithGoogle() async {
    state = state.copyWith(loading: true);
    try {
      if (!_firestoreService.isConfigured) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Firebase is not initialized. Please configure firebase_options.dart.',
        );
        return;
      }
      final cred = await _firestoreService.signInWithGoogle();
      final userEmail = cred?.user?.email ?? 'Google User';
      state = state.copyWith(
        signedIn: true,
        email: userEmail,
        loading: false,
        successMessage: 'Conectado a Firestore con Google: $userEmail',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: _formatAuthError(e, isGoogle: true),
      );
    }
  }

  /// Sends a password reset email
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(loading: true);
    try {
      await _firestoreService.sendPasswordReset(email);
      state = state.copyWith(
        loading: false,
        successMessage: 'Enlace para restablecer contraseña enviado a $email',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: _formatAuthError(e),
      );
    }
  }

  String _formatAuthError(Object error, {bool isGoogle = false}) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No existe ninguna cuenta con este correo. Cambia a "Crear cuenta" para registrarte.';
        case 'wrong-password':
          return 'Contraseña incorrecta. Por favor verifica tus datos.';
        case 'invalid-credential':
          if (isGoogle) {
            return 'No se pudo verificar la credencial de Google con Firebase. Asegúrate de que el proveedor Google esté activo en Firebase Console y de haber configurado el certificado SHA-1.';
          }
          return 'Correo o contraseña incorrectos. Si aún no tienes cuenta, selecciona "Crear cuenta".';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con este correo electrónico. Cambia a "Iniciar sesión".';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'invalid-email':
          return 'El formato del correo electrónico es inválido.';
        case 'admin-restricted-operation':
        case 'operation-not-allowed':
          return 'Este método no está activado en Firebase. En Firebase Console > Authentication > Sign-in method activa "Correo/Contraseña" o "Google".';
        case 'popup-closed-by-user':
          return 'Inicio de sesión con Google cancelado.';
        case 'user-disabled':
          return 'Esta cuenta ha sido inhabilitada.';
        default:
          return error.message ?? error.code;
      }
    }
    return error.toString();
  }

  Future<void> signIn() async {
    state = state.copyWith(loading: true);
    try {
      final storageType = await _syncService.getStorageType();
      if (storageType == CloudSyncStorageType.firestore) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Please sign in with Email or Google.',
        );
        return;
      }

      final account = await _syncService.signIn();
      if (storageType == CloudSyncStorageType.localDirectory) {
        final backups = await _syncService.getBackups();
        state = state.copyWith(
          signedIn: true,
          email: 'Local Backup',
          backups: backups,
          loading: false,
          successMessage: 'Connected successfully.',
        );
      } else if (account != null) {
        ref.read(googleUserProvider.notifier).setUser(account);
        final backups = await _syncService.getBackups();
        state = state.copyWith(
          signedIn: true,
          email: account.email,
          backups: backups,
          loading: false,
          successMessage: 'Connected successfully.',
        );
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Sign-in cancelled by user.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Connection failed: ${_formatAuthError(e)}',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true);
    final storageType = await _syncService.getStorageType();
    if (storageType == CloudSyncStorageType.firestore) {
      await _firestoreService.clearCustomUserId();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      ref.read(googleUserProvider.notifier).setUser(null);
      state = CloudSyncState(
        storageType: storageType,
        signedIn: false,
        email: null,
      );
      return;
    }
    await _syncService.signOut();
    ref.read(googleUserProvider.notifier).setUser(null);
    
    final list = storageType == CloudSyncStorageType.localDirectory
        ? await _syncService.getBackups()
        : const <BackupFile>[];
    state = CloudSyncState(
      storageType: storageType,
      backups: list,
    );
  }

  Future<void> refreshBackups() async {
    state = state.copyWith(loading: true);
    try {
      final list = await _syncService.getBackups();
      state = state.copyWith(backups: list, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Failed to retrieve backups: $e',
      );
    }
  }

  Future<bool> createBackup() async {
    state = state.copyWith(loading: true);
    try {
      final success = await _syncService.createBackup();
      if (success) {
        final list = await _syncService.getBackups();
        state = state.copyWith(
          backups: list,
          loading: false,
          successMessage: 'Backup created successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Failed to create backup.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Backup operation error: $e',
      );
      return false;
    }
  }

  Future<bool> restoreBackup(String backupId) async {
    state = state.copyWith(loading: true);
    try {
      final success = await _syncService.restoreBackup(backupId);
      if (success) {
        ref.read(databaseProvider.notifier).refreshDatabase();
        state = state.copyWith(
          loading: false,
          successMessage: 'Database restored successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Failed to restore database.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Restore operation error: $e',
      );
      return false;
    }
  }

  Future<bool> restoreFromLocalFile({
    required String filePath,
    Uint8List? fileBytes,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final success = await _syncService.restoreFromLocalFile(
        filePath,
        fileBytes: fileBytes,
      );

      if (success) {
        ref.read(databaseProvider.notifier).refreshDatabase();
        ref.invalidate(recipesStreamProvider);
        ref.invalidate(recipesWithFinancialsStreamProvider);
        ref.invalidate(ingredientsStreamProvider);
        ref.invalidate(unitsProvider);
        ref.invalidate(unitsStreamProvider);

        state = state.copyWith(
          loading: false,
          successMessage: 'Copia de seguridad local cargada con éxito.',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'El archivo seleccionado no es válido o no se pudo restaurar.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Error al restaurar copia local: $e',
      );
      return false;
    } finally {
      if (state.loading) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<bool> exportLocalBackup(String targetDirPath) async {
    state = state.copyWith(loading: true);
    try {
      final file = await _syncService.exportDatabaseToDirectory(targetDirPath);
      if (file != null) {
        state = state.copyWith(
          loading: false,
          successMessage: 'Copia de seguridad guardada exitosamente en el dispositivo.',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'No se pudo guardar la copia de seguridad.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Error al exportar: $e',
      );
      return false;
    } finally {
      if (state.loading) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<bool> deleteBackup(String backupId) async {
    state = state.copyWith(loading: true);
    try {
      final success = await _syncService.deleteBackup(backupId);
      if (success) {
        final list = await _syncService.getBackups();
        state = state.copyWith(
          backups: list,
          loading: false,
          successMessage: 'Backup deleted successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Failed to delete backup.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Delete operation error: $e',
      );
      return false;
    }
  }

  Future<bool> downloadBackup(String backupId, String fileName, String targetDirPath) async {
    state = state.copyWith(loading: true);
    try {
      final file = await _syncService.downloadBackupToLocal(backupId, fileName, targetDirPath);
      if (file != null) {
        state = state.copyWith(
          loading: false,
          successMessage: 'Backup saved: ${p.basename(file.path)}',
        );
        return true;
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Failed to save backup.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Save operation error: $e',
      );
      return false;
    }
  }

  Future<SyncMergeResult?> syncTwoWay({String? targetBackupId}) async {
    if (state.storageType == CloudSyncStorageType.firestore) {
      return await syncFirestore();
    }

    state = state.copyWith(loading: true);
    File? tempFile;
    AppDatabase? remoteDb;
    try {
      final backups = await _syncService.getBackups();

      // If there are no backups on the cloud, perform initial backup
      if (backups.isEmpty && targetBackupId == null) {
        final success = await _syncService.createBackup();
        if (success) {
          final updatedBackups = await _syncService.getBackups();
          state = state.copyWith(
            backups: updatedBackups,
            loading: false,
            successMessage: 'Initial sync complete: Cloud backup created.',
          );
          return const SyncMergeResult();
        } else {
          state = state.copyWith(
            loading: false,
            errorMessage: 'Failed to create initial cloud backup.',
          );
          return null;
        }
      }

      final backupId = targetBackupId ?? backups.first.id;
      tempFile = await _syncService.downloadBackupToTemp(backupId);
      if (tempFile == null || !await tempFile.exists()) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Failed to download cloud backup for merging.',
        );
        return null;
      }

      remoteDb = AppDatabase.forPath(tempFile.path);
      final localDb = ref.read(databaseProvider);
      final mergeResult = await localDb.mergeWithDatabase(remoteDb);

      await remoteDb.close();
      remoteDb = null;

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      // Two-way sync: push the merged database back to cloud
      final backupCreated = await _syncService.createBackup();
      if (!backupCreated) {
        debugPrint('Warning: Cloud backup of merged database failed.');
      }

      // Refresh database streams in the UI without closing the database
      _invalidateDataStreams();

      // Refresh backups list
      final updatedBackups = await _syncService.getBackups();

      final buffer = StringBuffer('Sync complete: ');
      if (mergeResult.hasChanges) {
        final parts = <String>[];
        if (mergeResult.recipesAdded > 0) parts.add('${mergeResult.recipesAdded} recipes added');
        if (mergeResult.recipesUpdated > 0) parts.add('${mergeResult.recipesUpdated} recipes updated');
        if (mergeResult.ingredientsAdded > 0) parts.add('${mergeResult.ingredientsAdded} ingredients added');
        if (mergeResult.ingredientsUpdated > 0) parts.add('${mergeResult.ingredientsUpdated} ingredients updated');
        if (mergeResult.recipesKeptLocal > 0) parts.add('${mergeResult.recipesKeptLocal} local edits preserved');
        buffer.write(parts.join(', '));
      } else {
        buffer.write('Database already in sync');
      }

      state = state.copyWith(
        backups: updatedBackups,
        loading: false,
        successMessage: buffer.toString(),
      );

      return mergeResult;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Sync error: $e',
      );
      return null;
    } finally {
      await remoteDb?.close();
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<SyncMergeResult?> syncFirestore({String? customUserId}) async {
    state = state.copyWith(loading: true);
    try {
      if (!_firestoreService.isConfigured) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Firebase is not configured. Please see firebase_options.dart setup instructions.',
        );
        return null;
      }

      final currentUser = _firestoreService.authCurrentUser;
      if (currentUser == null) {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Please sign in with Email or Google before syncing.',
        );
        return null;
      }

      final activeUid = customUserId ?? currentUser.uid;

      final localDb = ref.read(databaseProvider);
      final mergeResult = await _firestoreService.syncTwoWay(
        db: localDb,
        userId: activeUid,
      );

      // Refresh database streams in the UI without closing the database
      _invalidateDataStreams();

      final buffer = StringBuffer('Firestore sync complete: ');
      if (mergeResult.hasChanges) {
        final parts = <String>[];
        if (mergeResult.recipesAdded > 0) parts.add('${mergeResult.recipesAdded} recipes added');
        if (mergeResult.recipesUpdated > 0) parts.add('${mergeResult.recipesUpdated} recipes updated');
        if (mergeResult.ingredientsAdded > 0) parts.add('${mergeResult.ingredientsAdded} ingredients added');
        if (mergeResult.ingredientsUpdated > 0) parts.add('${mergeResult.ingredientsUpdated} ingredients updated');
        if (mergeResult.recipesKeptLocal > 0) parts.add('${mergeResult.recipesKeptLocal} local edits preserved');
        buffer.write(parts.join(', '));
      } else {
        buffer.write('Database already up to date');
      }

      state = state.copyWith(
        signedIn: true,
        email: _firestoreService.authCurrentUser?.email ?? 'Sync ID: $activeUid',
        loading: false,
        successMessage: buffer.toString(),
      );

      return mergeResult;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Firestore sync error: $e',
      );
      return null;
    }
  }

  void _invalidateDataStreams() {
    ref.invalidate(recipesStreamProvider);
    ref.invalidate(recipesWithFinancialsStreamProvider);
    ref.invalidate(ingredientsStreamProvider);
    ref.invalidate(unitsProvider);
    ref.invalidate(unitsStreamProvider);
  }

  Future<void> setCustomFirestoreUserId(String userId) async {
    await _firestoreService.setCustomUserId(userId);
    await checkStatus();
  }

  Future<void> saveRecipe(RecipeDetail detail) async {
    if (state.signedIn && state.storageType == CloudSyncStorageType.firestore) {
      try {
        await _firestoreService.saveRecipe(detail);
      } catch (e) {
        debugPrint('Cloud sync save recipe error: $e');
      }
    }
  }

  Future<bool> forceOverwriteCloud() async {
    state = state.copyWith(loading: true);
    try {
      if (state.storageType == CloudSyncStorageType.firestore) {
        if (!_firestoreService.isConfigured) {
          state = state.copyWith(
            loading: false,
            errorMessage: 'Firebase is not configured.',
          );
          return false;
        }

        final currentUser = _firestoreService.authCurrentUser;
        final activeUid = currentUser?.uid ?? await _firestoreService.getActiveUserId();
        if (activeUid == null || activeUid.isEmpty) {
          state = state.copyWith(
            loading: false,
            errorMessage: 'Please sign in or set a Sync ID before overwriting cloud data.',
          );
          return false;
        }

        final localDb = ref.read(databaseProvider);
        await _firestoreService.forceOverwriteCloud(
          db: localDb,
          userId: activeUid,
        );
        _invalidateDataStreams();
        state = state.copyWith(
          loading: false,
          successMessage: 'Cloud data successfully overwritten with local copy.',
        );
        return true;
      } else {
        // Google Drive / Local Directory
        final backups = await _syncService.getBackups();
        for (final b in backups) {
          await _syncService.deleteBackup(b.id);
        }
        final success = await _syncService.createBackup();
        final updatedBackups = await _syncService.getBackups();
        if (success) {
          state = state.copyWith(
            backups: updatedBackups,
            loading: false,
            successMessage: 'Cloud data successfully overwritten with local copy.',
          );
          return true;
        } else {
          state = state.copyWith(
            backups: updatedBackups,
            loading: false,
            errorMessage: 'Failed to upload local copy to cloud.',
          );
          return false;
        }
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Force overwrite failed: $e',
      );
      return false;
    }
  }
}

class GoogleUserNotifier extends Notifier<GoogleSignInAccount?> {
  @override
  GoogleSignInAccount? build() {
    return null;
  }

  void setUser(GoogleSignInAccount? user) {
    state = user;
  }
}

final googleUserProvider = NotifierProvider<GoogleUserNotifier, GoogleSignInAccount?>(GoogleUserNotifier.new);

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final user = ref.watch(googleUserProvider);
  return GoogleDriveSyncService(user);
});

final cloudSyncProvider = NotifierProvider<CloudSyncNotifier, CloudSyncState>(CloudSyncNotifier.new);
