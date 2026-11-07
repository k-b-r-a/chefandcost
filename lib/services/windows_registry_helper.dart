import 'dart:io';
import 'package:flutter/foundation.dart';

/// Desktop initialization helper for Windows file associations.
/// Registers the `.chefy` extension in `HKEY_CURRENT_USER\Software\Classes`
/// so that administrator privileges are never required.
class WindowsRegistryHelper {
  static const String progId = 'ChefAndCost.RecipeFile';
  static const String fileExtension = '.chefy';
  static const String fileTypeName = 'Chef&Cost Recipe';
  static const String mimeType = 'application/vnd.chefandcost.recipe';

  /// Registers `.chefy` file association, ProgID, DefaultIcon and Shell Open command in HKCU.
  static Future<void> registerFileAssociation() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      final exePath = Platform.resolvedExecutable;
      // Skip registry changes inside test runners or headless testing environments
      if (exePath.contains('flutter_tester') ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }

      final commands = [
        // Register .chefy pointing to ProgID
        [
          'add',
          r'HKCU\Software\Classes\.chefy',
          '/ve',
          '/d',
          progId,
          '/f',
        ],
        // Register MIME Content Type
        [
          'add',
          r'HKCU\Software\Classes\.chefy',
          '/v',
          'Content Type',
          '/d',
          mimeType,
          '/f',
        ],
        // Register ProgID label
        [
          'add',
          r'HKCU\Software\Classes\ChefAndCost.RecipeFile',
          '/ve',
          '/d',
          fileTypeName,
          '/f',
        ],
        // Register DefaultIcon to executable's first icon resource (app_icon.ico)
        [
          'add',
          r'HKCU\Software\Classes\ChefAndCost.RecipeFile\DefaultIcon',
          '/ve',
          '/d',
          '"$exePath",0',
          '/f',
        ],
        // Register Open command to launch executable with "%1"
        [
          'add',
          r'HKCU\Software\Classes\ChefAndCost.RecipeFile\shell\open\command',
          '/ve',
          '/d',
          '"$exePath" "%1"',
          '/f',
        ],
      ];

      for (final cmd in commands) {
        await Process.run('reg', cmd);
      }
    } catch (e) {
      debugPrint('WindowsRegistryHelper: registration error: $e');
    }
  }
}
