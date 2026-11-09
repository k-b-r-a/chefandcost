import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'cloud_sync_service.dart';

/// Helper to ensure [GoogleSignIn.instance.initialize] is invoked exactly once
/// across the entire app lifecycle with platform-appropriate parameters.
class GoogleSignInInitializer {
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static bool get isInitialized => _initialized;

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _initFuture = null;
  }

  /// Ensures GoogleSignIn has been properly initialized once.
  static Future<void> ensureInitialized() {
    if (_initialized) return Future.value();
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    try {
      if (kIsWeb) {
        await GoogleSignIn.instance.initialize(
          clientId: GoogleDriveSyncService.defaultWebClientId,
          serverClientId: null,
        );
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId: GoogleDriveSyncService.defaultServerClientId,
        );
      }
      _initialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn.initialize notice: $e');
      _initialized = true;
    }
  }
}
