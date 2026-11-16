import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CachedOfflineAdPayload {
  final String id;
  final String style;
  final int width;
  final int height;
  final int creativeIndex;
  final int lastSyncedMs;

  const CachedOfflineAdPayload({
    required this.id,
    required this.style,
    required this.width,
    required this.height,
    required this.creativeIndex,
    required this.lastSyncedMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'style': style,
        'width': width,
        'height': height,
        'creativeIndex': creativeIndex,
        'lastSyncedMs': lastSyncedMs,
      };

  factory CachedOfflineAdPayload.fromJson(Map<String, dynamic> json) {
    return CachedOfflineAdPayload(
      id: json['id'] as String? ?? 'offline_pro',
      style: json['style'] as String? ?? 'recipe',
      width: (json['width'] as num?)?.toInt() ?? 320,
      height: (json['height'] as num?)?.toInt() ?? 50,
      creativeIndex: (json['creativeIndex'] as num?)?.toInt() ?? 0,
      lastSyncedMs: (json['lastSyncedMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Persists offline ad metadata and rotates built-in promotional creatives
/// so ad slots never collapse when the device is offline.
class OfflineAdCacheService {
  OfflineAdCacheService._();

  static const String cachePrefKey = 'offline_cached_ads_v1';
  static const int creativeCount = 3;

  static int _rotationCounter = 0;

  static void resetForTesting() {
    _rotationCounter = 0;
  }

  /// Records that a live AdMob ad loaded, persisting its dimensions and timestamp.
  static Future<void> recordLiveAdLoaded({
    required int width,
    required int height,
    required String style,
    SharedPreferences? prefs,
  }) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final payload = CachedOfflineAdPayload(
        id: 'cached_${style}_${width}x$height',
        style: style,
        width: width > 0 ? width : 320,
        height: height > 0 ? height : 50,
        creativeIndex: _rotationCounter % creativeCount,
        lastSyncedMs: DateTime.now().millisecondsSinceEpoch,
      );
      await sp.setString(cachePrefKey, jsonEncode(payload.toJson()));
    } catch (_) {}
  }

  /// Returns the next cached offline ad payload synchronously (using [prefs] if available).
  static CachedOfflineAdPayload getNextCachedAdSync({
    required String style,
    SharedPreferences? prefs,
  }) {
    final index = _rotationCounter % creativeCount;
    _rotationCounter++;

    if (prefs != null) {
      final raw = prefs.getString(cachePrefKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final saved = CachedOfflineAdPayload.fromJson(decoded);
          return CachedOfflineAdPayload(
            id: saved.id,
            style: style,
            width: saved.width,
            height: saved.height,
            creativeIndex: index,
            lastSyncedMs: saved.lastSyncedMs,
          );
        } catch (_) {}
      }
    }

    return CachedOfflineAdPayload(
      id: 'offline_builtin_$index',
      style: style,
      width: 320,
      height: 50,
      creativeIndex: index,
      lastSyncedMs: 0,
    );
  }

  /// Returns the next cached offline ad payload asynchronously.
  static Future<CachedOfflineAdPayload> getNextCachedAd({
    required String style,
    SharedPreferences? prefs,
  }) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      return getNextCachedAdSync(style: style, prefs: sp);
    } catch (_) {
      return getNextCachedAdSync(style: style);
    }
  }
}
