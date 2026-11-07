import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service that listens for recipe files (.chefy) opened via platform intents
/// (Android/iOS) or command-line arguments (Windows/macOS/Linux).
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
  static String? _pendingCliFilePath;

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

  /// Sets an initial command-line file path (e.g. from Windows double-click launch).
  static void setInitialCliFilePath(String? path) {
    if (path == null || path.trim().isEmpty) return;
    final trimmed = path.trim();
    if (trimmed.toLowerCase().endsWith('.chefy')) {
      _pendingCliFilePath = trimmed;
    }
  }

  /// Directly reads and emits a .chefy file from a given filesystem path.
  static Future<bool> handleFilePath(String filePath) async {
    if (kIsWeb) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final fileName = filePath.split(RegExp(r'[\\/]')).last;
        if (content.isNotEmpty && _shouldHandle(content)) {
          _fileStreamController.add({
            'fileName': fileName,
            'content': content,
          });
          return true;
        }
      }
    } catch (e) {
      debugPrint('RecipeFileIntentService: error reading file $filePath: $e');
    }
    return false;
  }

  /// Initializes listening for file intents delivered while app is running.
  static void initialize() {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          var fileName = map['fileName']?.toString() ?? 'recipe.chefy';
          if (!fileName.toLowerCase().endsWith('.chefy')) {
            fileName = '$fileName.chefy';
          }
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

    // Check CLI argument path first (e.g., Windows launch / double-click)
    if (_pendingCliFilePath != null) {
      final path = _pendingCliFilePath!;
      _pendingCliFilePath = null;
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final fileName = path.split(RegExp(r'[\\/]')).last;
          if (content.isNotEmpty && _shouldHandle(content)) {
            return {
              'fileName': fileName,
              'content': content,
            };
          }
        }
      } catch (e) {
        debugPrint('RecipeFileIntentService: error reading initial CLI file $path: $e');
      }
    }

    // Query native mobile method channel (Android / iOS)
    try {
      final result = await _channel.invokeMethod<Map>('getInitialFile');
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        var fileName = map['fileName']?.toString() ?? 'recipe.chefy';
        if (!fileName.toLowerCase().endsWith('.chefy')) {
          fileName = '$fileName.chefy';
        }
        final content = map['content']?.toString() ?? '';
        if (content.isNotEmpty && _shouldHandle(content)) {
          return {
            'fileName': fileName,
            'content': content,
          };
        }
      }
    } on MissingPluginException {
      // No implementation on current platform (e.g. desktop/unit test)
    } catch (e) {
      debugPrint('Error getting initial file intent: $e');
    }
    return null;
  }

  /// Resets internal state for unit test isolation
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _lastHandledContent = null;
    _lastHandledTime = null;
    _pendingCliFilePath = null;
  }
}
