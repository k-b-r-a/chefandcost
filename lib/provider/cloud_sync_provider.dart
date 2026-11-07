import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/sample_manufacturing_recipe.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/firestore_sync_service.dart';
import 'database_provider.dart';

class CloudSyncState {
  final bool signedIn;
  final String? email;
  final List<BackupFile> backups;
  final bool loading;
  final bool isSyncing;
  final String? errorMessage;
  final String? successMessage;
  final String? syncError;
  final CloudSyncStorageType storageType;
  final bool hasAcceptedTerms;
  final bool isSubscribed;
  final String? subscriptionPlan;
  final DateTime? subscriptionExpiresAt;

  CloudSyncState({
    this.signedIn = false,
    this.email,
    this.backups = const [],
    this.loading = false,
    this.isSyncing = false,
    this.errorMessage,
    this.successMessage,
    this.syncError,
    this.storageType = CloudSyncStorageType.firestore,
    this.hasAcceptedTerms = false,
    this.isSubscribed = false,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
  });

  bool get hasActiveSubscription => isSubscribed;

  CloudSyncState copyWith({
    bool? signedIn,
    String? email,
    List<BackupFile>? backups,
    bool? loading,
    bool? isSyncing,
    String? errorMessage,
    String? successMessage,
    String? syncError,
    CloudSyncStorageType? storageType,
    bool? hasAcceptedTerms,
    bool? isSubscribed,
    String? subscriptionPlan,
    DateTime? subscriptionExpiresAt,
  }) {
    return CloudSyncState(
      signedIn: signedIn ?? this.signedIn,
      email: email ?? this.email,
      backups: backups ?? this.backups,
      loading: loading ?? this.loading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
      successMessage: successMessage,
      syncError: syncError,
      storageType: storageType ?? this.storageType,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
    );
  }
}

class CloudSyncNotifier extends Notifier<CloudSyncState> {
  GoogleDriveSyncService get _syncService => ref.read(googleDriveSyncServiceProvider);
  FirestoreSyncService get _firestoreService => ref.read(firestoreSyncServiceProvider);

  static const String monthlySubscriptionId = 'monthly_1_99';
  static const String annualSubscriptionId = 'annual_14_99';
  static const double monthlySubscriptionPrice = 1.99;
  static const double annualSubscriptionPrice = 14.99;

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
      final prefs = await SharedPreferences.getInstance();
      final acceptedTermsPref = prefs.getBool('cloud_terms_accepted') ?? false;
      final isSubscribedPref = prefs.getBool('cloud_sync_is_subscribed') ?? false;
      final planPref = prefs.getString('cloud_sync_subscription_plan');
      final expiresPref = prefs.getInt('cloud_sync_subscription_expires_at');
      final expiresAt = expiresPref != null ? DateTime.fromMillisecondsSinceEpoch(expiresPref) : null;
      bool activeSubscribed = isSubscribedPref;
      if (activeSubscribed && expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        activeSubscribed = false;
        await prefs.setBool('cloud_sync_is_subscribed', false);
      }

      final storageType = await _syncService.getStorageType();
      if (_disposed) return;

      if (storageType == CloudSyncStorageType.firestore) {
        final user = _firestoreService.authCurrentUser;
        final signedIn = _firestoreService.isConfigured && user != null;
        final email = user?.email;
        final hasAccepted = acceptedTermsPref || signedIn;
        if (signedIn && !acceptedTermsPref) {
          await prefs.setBool('cloud_terms_accepted', true);
        }
        if (_disposed) return;
        state = state.copyWith(
          signedIn: signedIn,
          email: email,
          backups: const [],
          storageType: storageType,
          hasAcceptedTerms: hasAccepted,
          isSubscribed: activeSubscribed,
          subscriptionPlan: activeSubscribed ? planPref : null,
          subscriptionExpiresAt: expiresAt,
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
      final hasAccepted = acceptedTermsPref || signedIn;
      if (signedIn && !acceptedTermsPref) {
        await prefs.setBool('cloud_terms_accepted', true);
      }
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
        hasAcceptedTerms: hasAccepted,
        isSubscribed: activeSubscribed,
        subscriptionPlan: activeSubscribed ? planPref : null,
        subscriptionExpiresAt: expiresAt,
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

  Future<void> setSubscription({
    required bool isSubscribed,
    String? plan,
    DateTime? expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloud_sync_is_subscribed', isSubscribed);
    if (plan != null) {
      await prefs.setString('cloud_sync_subscription_plan', plan);
    } else {
      await prefs.remove('cloud_sync_subscription_plan');
    }
    if (expiresAt != null) {
      await prefs.setInt('cloud_sync_subscription_expires_at', expiresAt.millisecondsSinceEpoch);
    } else {
      await prefs.remove('cloud_sync_subscription_expires_at');
    }
    state = state.copyWith(
      isSubscribed: isSubscribed,
      subscriptionPlan: plan,
      subscriptionExpiresAt: expiresAt,
    );
  }

  Future<void> purchaseSubscription(String planId) async {
    final now = DateTime.now();
    final isAnnual = planId.contains('annual') || planId == annualSubscriptionId;
    final expiresAt = now.add(isAnnual ? const Duration(days: 365) : const Duration(days: 30));
    await setSubscription(
      isSubscribed: true,
      plan: isAnnual ? annualSubscriptionId : monthlySubscriptionId,
      expiresAt: expiresAt,
    );
  }

  Future<void> cancelSubscription() async {
    await setSubscription(isSubscribed: false, plan: null, expiresAt: null);
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
        hasAcceptedTerms: state.hasAcceptedTerms || signedIn,
        isSubscribed: state.isSubscribed,
        subscriptionPlan: state.subscriptionPlan,
        subscriptionExpiresAt: state.subscriptionExpiresAt,
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
      hasAcceptedTerms: state.hasAcceptedTerms || type == CloudSyncStorageType.localDirectory,
      isSubscribed: state.isSubscribed,
      subscriptionPlan: state.subscriptionPlan,
      subscriptionExpiresAt: state.subscriptionExpiresAt,
    );
  }

  /// Persists acceptance of Cloud Sync Terms of Service and Privacy Policy
  Future<void> acceptTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cloud_terms_accepted', true);
      state = state.copyWith(hasAcceptedTerms: true);
    } catch (_) {
      state = state.copyWith(hasAcceptedTerms: true);
    }
  }

  /// Signs in with Email and Password (or registers if isRegister is true)
  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool isRegister = false,
  }) async {
    if (!state.hasAcceptedTerms) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'cloud_sync_terms_required_warning',
      );
      return;
    }
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
    if (!state.hasAcceptedTerms) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'cloud_sync_terms_required_warning',
      );
      return;
    }
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
      if (cred == null) {
        // Clean cancellation - no error banner, spinner dismisses cleanly
        state = state.copyWith(loading: false);
        return;
      }
      final userEmail = cred.user?.email ?? 'Google User';
      state = state.copyWith(
        signedIn: true,
        email: userEmail,
        loading: false,
        successMessage: 'Conectado a Firestore con Google: $userEmail',
      );
    } catch (e) {
      final err = _formatAuthError(e, isGoogle: true);
      state = state.copyWith(
        loading: false,
        errorMessage: err == 'error_sign_in_canceled' ? null : err,
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
    if (error is GoogleDriveScopeDeniedException) {
      return 'error_drive_permission_denied';
    }
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'error_sign_in_canceled';
      }
      return error.description ?? error.code.name;
    }
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
        case 'cancelled-popup-request':
          return 'error_sign_in_canceled';
        case 'user-disabled':
          return 'Esta cuenta ha sido inhabilitada.';
        case 'network-request-failed':
          return 'error_network';
        case 'requires-recent-login':
          return 'error_requires_recent_login';
        default:
          return error.message ?? error.code;
      }
    }
    if (error is SocketException) {
      return 'error_network';
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code == 'sign_in_canceled' || code == '12501' || message.contains('canceled') || message.contains('cancelled')) {
        return 'error_sign_in_canceled';
      }
      if (code == 'network_error' || code == '7' || message.contains('network')) {
        return 'error_network';
      }
    }
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('canceled') || errStr.contains('cancelled') || errStr.contains('12501')) {
      return 'error_sign_in_canceled';
    }
    if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed host lookup')) {
      return 'error_network';
    }
    if (errStr.contains('permission') && (errStr.contains('denied') || errStr.contains('scope'))) {
      return 'error_drive_permission_denied';
    }
    if (errStr.contains('drive.googleapis.com') || errStr.contains('194514517992') || errStr.contains('api is disabled')) {
      return 'El servicio de Google Drive no está disponible o requiere activación en Google Cloud. Puedes usar Firestore para sincronizar.';
    }
    if (errStr.contains('requires-recent-login')) {
      return 'error_requires_recent_login';
    }
    return error.toString();
  }

  Future<void> signIn() async {
    final currentStorage = await _syncService.getStorageType();
    if (!state.hasAcceptedTerms && currentStorage != CloudSyncStorageType.localDirectory) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'cloud_sync_terms_required_warning',
      );
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final storageType = currentStorage;
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
        // Clean dismissal on cancel
        state = state.copyWith(
          loading: false,
        );
      }
    } catch (e) {
      final formatted = _formatAuthError(e);
      state = state.copyWith(
        loading: false,
        errorMessage: formatted == 'error_sign_in_canceled' ? null : formatted,
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
        hasAcceptedTerms: state.hasAcceptedTerms,
        isSubscribed: state.isSubscribed,
        subscriptionPlan: state.subscriptionPlan,
        subscriptionExpiresAt: state.subscriptionExpiresAt,
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
      hasAcceptedTerms: state.hasAcceptedTerms,
      isSubscribed: state.isSubscribed,
      subscriptionPlan: state.subscriptionPlan,
      subscriptionExpiresAt: state.subscriptionExpiresAt,
    );
  }

  /// Permanently deletes the user's account and all associated cloud data in Firestore.
  /// Complies with Google Play Account Deletion policy.
  Future<bool> deleteAccountAndCloudData({String? password}) async {
    state = state.copyWith(loading: true, errorMessage: null, successMessage: null);
    final storageType = await _syncService.getStorageType();
    if (storageType == CloudSyncStorageType.firestore) {
      try {
        await _firestoreService.deleteAccountAndCloudData(reauthPassword: password);
        ref.read(googleUserProvider.notifier).setUser(null);
        state = CloudSyncState(
          storageType: storageType,
          signedIn: false,
          email: null,
          loading: false,
          hasAcceptedTerms: state.hasAcceptedTerms,
          successMessage: 'cloud_sync_delete_account_success',
        );
        return true;
      } catch (e) {
        state = state.copyWith(
          loading: false,
          errorMessage: _formatAuthError(e),
        );
        return false;
      }
    }
    state = state.copyWith(loading: false);
    return false;
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
    if (state.storageType == CloudSyncStorageType.firestore && !state.isSubscribed) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'cloud_sync_subscription_required',
      );
      return false;
    }
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

  Future<void> disconnectGoogleAccount() async {
    state = state.copyWith(loading: true);
    try {
      await _syncService.disconnect();
      ref.read(googleUserProvider.notifier).setUser(null);
      state = CloudSyncState(
        storageType: state.storageType,
        signedIn: false,
        email: null,
        backups: const [],
        loading: false,
        hasAcceptedTerms: state.hasAcceptedTerms,
        isSubscribed: state.isSubscribed,
        subscriptionPlan: state.subscriptionPlan,
        subscriptionExpiresAt: state.subscriptionExpiresAt,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: _formatAuthError(e),
      );
    }
  }

  Future<bool> deleteAllBackups() async {
    state = state.copyWith(loading: true);
    try {
      final success = await _syncService.deleteAllBackups();
      final list = await _syncService.getBackups();
      state = state.copyWith(
        backups: list,
        loading: false,
        successMessage: success ? 'cloud_sync_delete_all_backups_success' : null,
        errorMessage: success ? null : 'Failed to delete backups.',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Delete error: $e',
      );
      return false;
    }
  }

  Future<bool> deleteFirestoreCloudData() async {
    state = state.copyWith(loading: true);
    try {
      await _firestoreService.deleteFirestoreCloudData();
      state = state.copyWith(
        loading: false,
        successMessage: 'cloud_sync_delete_cloud_data_success',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Error deleting cloud data: $e',
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

    state = state.copyWith(isSyncing: true, syncError: null);
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
            isSyncing: false,
            successMessage: 'Initial sync complete: Cloud backup created.',
          );
          return const SyncMergeResult();
        } else {
          state = state.copyWith(
            isSyncing: false,
            syncError: 'Failed to create initial cloud backup.',
            errorMessage: 'Failed to create initial cloud backup.',
          );
          return null;
        }
      }

      final backupId = targetBackupId ?? backups.first.id;
      tempFile = await _syncService.downloadBackupToTemp(backupId);
      if (tempFile == null || !await tempFile.exists()) {
        state = state.copyWith(
          isSyncing: false,
          syncError: 'Failed to download cloud backup for merging.',
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
        isSyncing: false,
        successMessage: buffer.toString(),
      );

      return mergeResult;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        syncError: 'Sync error: $e',
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
    if (!state.isSubscribed) {
      state = state.copyWith(
        isSyncing: false,
        syncError: 'cloud_sync_subscription_required',
        errorMessage: 'cloud_sync_subscription_required',
      );
      return null;
    }
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      if (!_firestoreService.isConfigured) {
        state = state.copyWith(
          isSyncing: false,
          syncError: 'Firebase is not configured. Please see firebase_options.dart setup instructions.',
          errorMessage: 'Firebase is not configured. Please see firebase_options.dart setup instructions.',
        );
        return null;
      }

      final currentUser = _firestoreService.authCurrentUser;
      if (currentUser == null) {
        state = state.copyWith(
          isSyncing: false,
          syncError: 'Please sign in with Email or Google before syncing.',
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
        isSyncing: false,
        successMessage: buffer.toString(),
      );

      return mergeResult;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        syncError: 'Firestore sync error: $e',
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

  final List<RecipeDetail> _pendingRecipeSyncs = [];
  bool _isProcessingRecipeSync = false;

  /// Syncs a recipe to cloud storage asynchronously in the background.
  /// Decouples sync execution from the UI lifecycle so saving and interacting
  /// with recipes is instant and never blocks or freezes the UI.
  void syncRecipe(RecipeDetail detail) {
    if (isSampleManufacturingRecipe(detail.recipe.recipePk)) return;
    if (state.signedIn && state.storageType == CloudSyncStorageType.firestore && state.isSubscribed) {
      _enqueueRecipeSync(detail);
    }
  }

  /// Alias for background recipe synchronization.
  void saveRecipeInBackground(RecipeDetail detail) => syncRecipe(detail);

  void _enqueueRecipeSync(RecipeDetail detail) {
    final existingIndex = _pendingRecipeSyncs.indexWhere(
      (d) => d.recipe.recipePk == detail.recipe.recipePk,
    );
    if (existingIndex >= 0) {
      _pendingRecipeSyncs[existingIndex] = detail;
    } else {
      _pendingRecipeSyncs.add(detail);
    }
    _processNextRecipeSync();
  }

  Future<void> _processNextRecipeSync() async {
    if (_isProcessingRecipeSync || _pendingRecipeSyncs.isEmpty || _disposed) {
      return;
    }
    _isProcessingRecipeSync = true;
    while (_pendingRecipeSyncs.isNotEmpty && !_disposed) {
      final nextDetail = _pendingRecipeSyncs.removeAt(0);
      try {
        await _firestoreService.saveRecipe(nextDetail);
      } catch (e) {
        debugPrint('Background cloud sync recipe error: $e');
      }
    }
    _isProcessingRecipeSync = false;
  }

  Future<void> saveRecipe(RecipeDetail detail) async {
    if (isSampleManufacturingRecipe(detail.recipe.recipePk)) return;
    if (state.signedIn && state.storageType == CloudSyncStorageType.firestore && state.isSubscribed) {
      try {
        await _firestoreService.saveRecipe(detail);
      } catch (e) {
        debugPrint('Cloud sync save recipe error: $e');
      }
    }
  }

  Future<bool> forceOverwriteCloud() async {
    if (state.storageType == CloudSyncStorageType.firestore && !state.isSubscribed) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'cloud_sync_subscription_required',
      );
      return false;
    }
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
