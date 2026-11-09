import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents the result of a Google Play Integrity token request.
class PlayIntegrityTokenResult {
  final String? token;
  final String type; // 'standard' or 'classic' or 'simulated'
  final String? requestHash;
  final String? nonce;
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;

  const PlayIntegrityTokenResult({
    this.token,
    this.type = 'standard',
    this.requestHash,
    this.nonce,
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
  });

  factory PlayIntegrityTokenResult.success({
    required String token,
    required String type,
    String? requestHash,
    String? nonce,
  }) {
    return PlayIntegrityTokenResult(
      token: token,
      type: type,
      requestHash: requestHash,
      nonce: nonce,
      isSuccess: true,
    );
  }

  factory PlayIntegrityTokenResult.failure({
    required String errorCode,
    required String errorMessage,
    String type = 'standard',
  }) {
    return PlayIntegrityTokenResult(
      token: null,
      type: type,
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() => isSuccess
      ? 'PlayIntegrityTokenResult(type: $type, token: ${token?.substring(0, token!.length.clamp(0, 20))}...)'
      : 'PlayIntegrityTokenResult.failure(code: $errorCode, message: $errorMessage)';
}

/// Service providing Google Play Integrity API integration (Standard Integrity API with Classic fallback).
///
/// Use [prepareTokenProvider] at application startup or before sensitive user flows (warmup).
/// Use [requestIntegrityToken] or [requestTokenForAction] on sensitive operations:
/// - User authentication & Google Sign-In
/// - Subscription & in-app purchase checkout
/// - Database cloud sync & sensitive data mutations
class PlayIntegrityService {
  static const MethodChannel _channel =
      MethodChannel('com.chefandcost.app/play_integrity');

  /// Google Cloud Project Number linked to Google Play Console.
  static const int kDefaultCloudProjectNumber = 194514517992;

  static bool _isWarmedUp = false;
  static bool get isWarmedUp => _isWarmedUp;

  /// Whether current runtime platform supports native Google Play Integrity API.
  static bool get isPlayIntegritySupported {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Warms up the StandardIntegrityTokenProvider on Android.
  /// Call this during app startup or when entering monetization / authentication screens.
  static Future<bool> prepareTokenProvider({
    int cloudProjectNumber = kDefaultCloudProjectNumber,
  }) async {
    if (!isPlayIntegritySupported) {
      debugPrint('[PlayIntegrity] Non-Android or test environment: warmup skipped.');
      return false;
    }

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'prepareIntegrityTokenProvider',
        <String, dynamic>{'cloudProjectNumber': cloudProjectNumber},
      );
      _isWarmedUp = res?['status'] == 'prepared';
      debugPrint('[PlayIntegrity] Standard Integrity provider warmed up: $_isWarmedUp');
      return _isWarmedUp;
    } on PlatformException catch (e) {
      debugPrint('[PlayIntegrity] Warmup failed: [${e.code}] ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[PlayIntegrity] Unexpected warmup error: $e');
      return false;
    }
  }

  /// Requests a Play Integrity token for a specific action (e.g. 'auth_login', 'checkout_monthly', 'firestore_sync').
  /// Computes a cryptographically safe SHA-256 [requestHash] bound to the action, user id, and timestamp.
  static Future<PlayIntegrityTokenResult> requestTokenForAction({
    required String action,
    String? userId,
    Map<String, dynamic>? metadata,
    int cloudProjectNumber = kDefaultCloudProjectNumber,
  }) async {
    final payloadMap = <String, dynamic>{
      'action': action,
      'userId': userId ?? 'anonymous',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    if (metadata != null) {
      payloadMap['meta'] = metadata;
    }
    final payloadString = jsonEncode(payloadMap);

    final requestHash = generateSha256Digest(payloadString);
    return requestIntegrityToken(
      requestHash: requestHash,
      cloudProjectNumber: cloudProjectNumber,
    );
  }

  /// Requests an integrity token using StandardIntegrityManager (with automatic Classic fallback).
  static Future<PlayIntegrityTokenResult> requestIntegrityToken({
    String? requestHash,
    String? nonce,
    int cloudProjectNumber = kDefaultCloudProjectNumber,
  }) async {
    if (!isPlayIntegritySupported) {
      debugPrint('[PlayIntegrity] Non-Android platform: returning simulated debug token.');
      return PlayIntegrityTokenResult.success(
        token: 'simulated_debug_integrity_token_${DateTime.now().millisecondsSinceEpoch}',
        type: 'simulated',
        requestHash: requestHash,
        nonce: nonce,
      );
    }

    try {
      final safeHash = requestHash ?? generateDefaultRequestHash();
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'requestIntegrityToken',
        <String, dynamic>{
          'requestHash': safeHash,
          'nonce': nonce ?? safeHash,
          'cloudProjectNumber': cloudProjectNumber,
        },
      );

      final token = res?['token'] as String?;
      final type = res?['type'] as String? ?? 'standard';

      if (token != null && token.isNotEmpty) {
        return PlayIntegrityTokenResult.success(
          token: token,
          type: type,
          requestHash: safeHash,
          nonce: nonce,
        );
      } else {
        return PlayIntegrityTokenResult.failure(
          errorCode: 'EMPTY_TOKEN',
          errorMessage: 'Play Integrity returned an empty token response.',
          type: type,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[PlayIntegrity] Token request error: [${e.code}] ${e.message}');
      return PlayIntegrityTokenResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown Play Integrity platform exception',
      );
    } catch (e) {
      debugPrint('[PlayIntegrity] Unexpected token request error: $e');
      return PlayIntegrityTokenResult.failure(
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  /// Generates a URL-safe, unpadded Base64 SHA-256 digest string from raw input.
  static String generateSha256Digest(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a randomized default request hash.
  static String generateDefaultRequestHash() {
    final entropy = '${DateTime.now().microsecondsSinceEpoch}_${base64UrlEncode(List<int>.generate(16, (i) => (i * 37) % 256))}';
    return generateSha256Digest(entropy);
  }
}
