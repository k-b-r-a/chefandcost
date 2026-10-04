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
    this.storageType = CloudSyncStorageType.googleDrive,
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

  @override
  CloudSyncState build() {
    // Check initial connection status asynchronously
    Future.microtask(() => checkStatus());

    return CloudSyncState();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(loading: true);
    try {
      final storageType = await _syncService.getStorageType();

      if (storageType == CloudSyncStorageType.firestore) {
        final activeUid = await _firestoreService.getActiveUserId();
        final signedIn = _firestoreService.isConfigured && (activeUid != null && activeUid.isNotEmpty);
        final email = _firestoreService.authCurrentUser?.email ??
            (activeUid != null ? 'Sync ID: $activeUid' : null);
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
            ref.read(googleUserProvider.notifier).setUser(account);
          } catch (_) {}
        }
      }
      
      final signedIn = storageType == CloudSyncStorageType.localDirectory || account != null;
      String? email;
      if (signedIn) {
        email = storageType == CloudSyncStorageType.localDirectory ? 'Local Backup' : account?.email;
      }
      
      final backups = await _syncService.getBackups();
      
      state = state.copyWith(
        signedIn: signedIn,
        email: email,
        backups: backups,
        storageType: storageType,
        loading: false,
      );
    } catch (e) {
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
      final activeUid = await _firestoreService.getActiveUserId();
      final signedIn = _firestoreService.isConfigured && (activeUid != null && activeUid.isNotEmpty);
      final email = _firestoreService.authCurrentUser?.email ??
          (activeUid != null ? 'Sync ID: $activeUid' : null);
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
            ? 'Account created and connected: $userEmail'
            : 'Signed in as $userEmail',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Authentication failed: ${_formatAuthError(e)}',
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
        successMessage: 'Connected to Firestore via Google: $userEmail',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Google Sign-In failed: ${_formatAuthError(e)}',
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
        successMessage: 'Password reset link sent to $email',
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Password reset failed: ${_formatAuthError(e)}',
      );
    }
  }

  String _formatAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in the Firebase Console.';
        case 'popup-closed-by-user':
          return 'Sign-in cancelled by user.';
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
        if (!_firestoreService.isConfigured) {
          state = state.copyWith(
            loading: false,
            errorMessage: 'Firebase is not initialized. Please configure firebase_options.dart.',
          );
          return;
        }

        // Direct anonymous sign-in session for guest sync
        final uid = await _firestoreService.signInAnonymously();
        state = state.copyWith(
          signedIn: true,
          email: 'Sync ID: $uid',
          loading: false,
          successMessage: 'Connected to Firestore guest session.',
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

      // Refresh database streams in the UI
      ref.read(databaseProvider.notifier).refreshDatabase();

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

      String? activeUid = customUserId ?? await _firestoreService.getActiveUserId();
      if (activeUid == null || activeUid.isEmpty) {
        try {
          activeUid = await _firestoreService.signInAnonymously();
        } catch (e) {
          state = state.copyWith(
            loading: false,
            errorMessage: 'Unable to start Firestore session: $e',
          );
          return null;
        }
      }

      final localDb = ref.read(databaseProvider);
      final mergeResult = await _firestoreService.syncTwoWay(
        db: localDb,
        userId: activeUid,
      );

      // Refresh database streams in the UI
      ref.read(databaseProvider.notifier).refreshDatabase();

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

  Future<void> setCustomFirestoreUserId(String userId) async {
    await _firestoreService.setCustomUserId(userId);
    await checkStatus();
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
