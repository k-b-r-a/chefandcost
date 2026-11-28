import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'url_launcher_stub.dart'
    if (dart.library.js_interop) 'url_launcher_web.dart' as platform_url;

class UrlLauncherService {
  static const MethodChannel _channel = MethodChannel('com.chefandcost.app/url');

  static const String privacyPolicyUrl = 'https://chefycost.web.app/privacy';
  static const String deleteAccountUrl = 'https://chefycost.web.app/delete-account';

  static Future<bool> openUrl(String url) async {
    if (kIsWeb) {
      return platform_url.openWebUrl(url);
    }
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? true;
    } on MissingPluginException {
      return _openDesktopFallback(url);
    } catch (e) {
      debugPrint('Error launching URL via native channel: $e');
      return _openDesktopFallback(url);
    }
  }

  static Future<bool> _openDesktopFallback(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    try {
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [uri.toString()]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [uri.toString()]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('Desktop URL fallback error: $e');
    }
    return false;
  }

  static Future<bool> openPrivacyPolicy() => openUrl(privacyPolicyUrl);
  static Future<bool> openDeleteAccount() => openUrl(deleteAccountUrl);
}
