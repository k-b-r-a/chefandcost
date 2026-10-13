import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service that listens for recipe files (.chefy) opened via Android intents
/// (ACTION_VIEW when tapping files in File Manager/WhatsApp/Downloads or ACTION_SEND).
class RecipeFileIntentService {
  static const MethodChannel _channel =
      MethodChannel('com.chefandcost.app/file_intent');

  static final StreamController<Map<String, String>> _fileStreamController =
      StreamController<Map<String, String>>.broadcast();

  static Stream<Map<String, String>> get fileStream =>
      _fileStreamController.stream;

  static bool _initialized = false;
  static String? _lastHandledContent;
  static DateTime? _lastHandledTime;

  /// Prevents processing the exact same file payload multiple times in rapid succession
  static bool _shouldHandle(String content) {
    final now = DateTime.now();
    if (_lastHandledContent == content &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 4)) {
      return false;
    }
    _lastHandledContent = content;
    _lastHandledTime = now;
    return true;
  }

  /// Initializes listening for file intents delivered while app is running.
  static void initialize() {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final fileName = map['fileName']?.toString() ?? 'recipe.chefy';
          final content = map['content']?.toString() ?? '';
          if (content.isNotEmpty && _shouldHandle(content)) {
            _fileStreamController.add({
              'fileName': fileName,
              'content': content,
            });
          }
        }
      }
    });
  }

  /// Checks for any file intent that launched the app on cold start.
  static Future<Map<String, String>?> getInitialFile() async {
    if (kIsWeb) return null;
    try {
      final result = await _channel.invokeMethod<Map>('getInitialFile');
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        final fileName = map['fileName']?.toString() ?? 'recipe.chefy';
        final content = map['content']?.toString() ?? '';
        if (content.isNotEmpty && _shouldHandle(content)) {
          return {
            'fileName': fileName,
            'content': content,
          };
        }
      }
    } catch (e) {
      debugPrint('Error getting initial file intent: $e');
    }
    return null;
  }
}
