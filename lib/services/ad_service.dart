import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static bool? debugIsSupportedPlatform;
  static bool _isInitialized = false;

  /// Returns true only on physical or emulator Android and iOS devices,
  /// strictly excluding Web, desktop operating systems, and test runners.
  static bool get isSupportedPlatform {
    if (debugIsSupportedPlatform != null) {
      return debugIsSupportedPlatform!;
    }
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Saved Production AdMob IDs (Chef&Cost Android)
  static const String prodAndroidAppId = 'ca-app-pub-1924365084384799~3410415240';
  static const String prodAndroidBannerId = 'ca-app-pub-1924365084384799/3405711669';
  static const String prodAndroidRewardedId = 'ca-app-pub-1924365084384799/4273951104';
  static const String prodAndroidNativeAdId = 'ca-app-pub-1924365084384799/7600941697';

  /// Official Google Universal Test IDs (100% instant fill, safe for testing)
  static const String testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testAndroidNativeAdId = 'ca-app-pub-3940256099942544/2247696110';
  static const String testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const String testIosNativeAdId = 'ca-app-pub-3940256099942544/3986624511';

  /// Set to true to use Google's universal test ad units (instant test ads).
  /// Set to false to use the production AdMob ad unit IDs.
  static bool useUniversalTestAds = false;

  /// Returns the banner ad unit ID based on platform and test toggle
  static String get bannerAdUnitId {
    if (!isSupportedPlatform) return '';
    if (!kIsWeb && Platform.isAndroid) {
      return useUniversalTestAds ? testAndroidBannerId : prodAndroidBannerId;
    } else if (!kIsWeb && Platform.isIOS) {
      return testIosBannerId;
    }
    return '';
  }

  /// Returns the native ad unit ID based on platform and test toggle
  static String get nativeAdUnitId {
    if (!isSupportedPlatform) return '';
    if (!kIsWeb && Platform.isAndroid) {
      return useUniversalTestAds ? testAndroidNativeAdId : prodAndroidNativeAdId;
    } else if (!kIsWeb && Platform.isIOS) {
      return testIosNativeAdId;
    }
    return '';
  }

  /// Returns the rewarded video ad unit ID based on platform and test toggle
  static String get rewardedAdUnitId {
    if (!isSupportedPlatform) return '';
    if (!kIsWeb && Platform.isAndroid) {
      return useUniversalTestAds ? testAndroidRewardedId : prodAndroidRewardedId;
    } else if (!kIsWeb && Platform.isIOS) {
      return testIosRewardedId;
    }
    return '';
  }

  /// Add your test device hashed IDs here to receive test ads safely
  /// when using production ad unit IDs.
  /// Find this ID in `adb logcat` under "Use RequestConfiguration.Builder().setTestDeviceIds(...)".
  static List<String> testDeviceIds = <String>[];

  /// Safe initialization that is guaranteed never to invoke native AdMob channels
  /// on Web, desktop, or Flutter test environments.
  static Future<void> initialize() async {
    if (!isSupportedPlatform || _isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      if (testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDeviceIds),
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  /// Loads and shows a 30-second RewardedAd.
  /// Calls [onUserEarnedReward] upon completion.
  static Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function(String error)? onAdFailed,
  }) async {
    if (!isSupportedPlatform) {
      onAdFailed?.call('Platform not supported');
      return false;
    }

    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (RewardedAd ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
                ad.dispose();
                onAdFailed?.call(error.message);
                if (!completer.isCompleted) completer.complete(false);
              },
            );

            ad.show(
              onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
                onUserEarnedReward();
                if (!completer.isCompleted) completer.complete(true);
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('RewardedAd failed to load: $error');
            onAdFailed?.call(error.message);
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
      onAdFailed?.call(e.toString());
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  /// Creates a BannerAd instance when on a supported platform.
  static BannerAd? createBannerAd({
    required void Function() onAdLoaded,
    required void Function(LoadAdError error) onAdFailedToLoad,
  }) {
    if (!isSupportedPlatform) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    );
  }

  /// Creates a NativeAd instance with NativeTemplateStyle when on a supported platform.
  static NativeAd? createNativeAd({
    required NativeTemplateStyle nativeTemplateStyle,
    required void Function(NativeAd ad) onAdLoaded,
    required void Function(LoadAdError error) onAdFailedToLoad,
  }) {
    if (!isSupportedPlatform) return null;
    return NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: nativeTemplateStyle,
      listener: NativeAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    );
  }
}
