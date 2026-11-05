import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'url_launcher_stub.dart'
    if (dart.library.js_interop) 'url_launcher_web.dart' as platform_url;

class UrlLauncherService {
  static const MethodChannel _channel = MethodChannel('com.chefandcost.app/url');

  static const String privacyPolicyUrl = 'https://chefycostalpha.web.app/privacy';
  static const String deleteAccountUrl = 'https://chefycostalpha.web.app/delete-account';

  static Future<bool> openUrl(String url) async {
    if (kIsWeb) {
      return platform_url.openWebUrl(url);
    }
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? true;
    } catch (e) {
      debugPrint('Error launching URL via native channel: $e');
      return false;
    }
  }

  static Future<bool> openPrivacyPolicy() => openUrl(privacyPolicyUrl);
  static Future<bool> openDeleteAccount() => openUrl(deleteAccountUrl);
}
