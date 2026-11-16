import 'dart:async';
import 'dart:io' show InternetAddress, Platform;
import 'dart:ui' show AppLifecycleState;
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback, debugPrint, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static bool? debugIsSupportedPlatform;
  static bool? debugIsOffline;
  static bool _isOffline = false;
  static final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);
  static bool get isOffline => debugIsOffline ?? _isOffline;

  static void setDebugOffline(bool? value) {
    debugIsOffline = value;
    isOfflineNotifier.value = value ?? _isOffline;
  }

  static const int kMaxPreloadedBanners = 2;
  static final List<BannerAd> _cachedBannerPool = <BannerAd>[];
  static bool _isPreloadingBanners = false;

  static bool _isInitialized = false;
  static bool _isAppMuted = true;
  static bool _hasAppliedNativeMute = false;
  static RewardedAd? _preloadedRewardedAd;
  static bool _isPreloadingRewardedAd = false;
  static int _rewardedRetryAttempt = 0;
  static const int _maxRewardedRetryAttempts = 3;
  static DateTime? _rewardedAdLoadedAt;
  static DateTime? _lastRewardedLoadAttemptAt;
  static Timer? _periodicRefreshTimer;
  static AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  static bool Function()? isUserAdFreeCallback;

  static const Duration kMinAdRequestCooldown = Duration(seconds: 30);
  static const Duration kRewardedAdStaleThreshold = Duration(minutes: 45);
  static const Duration kBannerAdRefreshThreshold = Duration(seconds: 75);

  /// Incremented by periodic/navigation evaluation to let active banner widgets
  /// check if they are stale or failed past cooldown.
  static final ValueNotifier<int> adRefreshTickNotifier = ValueNotifier<int>(0);

  /// Indicates whether the global ad audio is currently muted (true for banner ads, false only during rewarded ads)
  static bool get isAppMuted => _isAppMuted;

  static final ValueNotifier<bool> rewardedAdReadyNotifier = ValueNotifier<bool>(false);

  static bool get isRewardedAdReady => _preloadedRewardedAd != null;
  static bool get isPreloadingRewardedAd => _isPreloadingRewardedAd;

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

  /// True when running on physical/emulator mobile (excluding debug override in flutter test)
  static bool get _canInvokeNativeAdMob {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Saved Production AdMob IDs (Chef&Cost Android)
  static const String prodAndroidAppId = 'ca-app-pub-9259522959057429~4046276855';
  static const String prodAndroidBannerId = 'ca-app-pub-9259522959057429/9669963616';
  static const String prodAndroidRewardedId = 'ca-app-pub-9259522959057429/1312302302';
  static const String prodAndroidNativeAdId = 'ca-app-pub-9259522959057429/8093333077';

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
  static List<String> testDeviceIds = <String>[];

  /// Enforces muted audio for banner and inline ads across the application.
  static Future<void> muteBannerAds() async {
    _isAppMuted = true;
    if (!_canInvokeNativeAdMob || _hasAppliedNativeMute) return;
    try {
      _hasAppliedNativeMute = true;
      await MobileAds.instance.setAppMuted(true);
      await MobileAds.instance.setAppVolume(0.0);
    } catch (e) {
      _hasAppliedNativeMute = false;
      debugPrint('Error muting banner ads: $e');
    }
  }

  /// Enables audio specifically for full-screen rewarded video ads.
  static Future<void> enableRewardedAdAudio() async {
    _isAppMuted = false;
    _hasAppliedNativeMute = false;
    if (!_canInvokeNativeAdMob) return;
    try {
      await MobileAds.instance.setAppMuted(false);
      await MobileAds.instance.setAppVolume(1.0);
    } catch (e) {
      debugPrint('Error enabling rewarded ad audio: $e');
    }
  }

  /// Safe initialization that is guaranteed never to invoke native AdMob channels
  /// on Web, desktop, or Flutter test environments.
  static Future<void> initialize() async {
    if (!_canInvokeNativeAdMob || _isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      if (testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDeviceIds),
        );
      }
      // Ensure banner ads are never allowed to emit audio (only reward ads unmute)
      await muteBannerAds();
      _isInitialized = true;
      startPeriodicRefresh();
      preloadRewardedAd();
      unawaited(preloadCachedBanners());
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  /// Returns true if the currently preloaded rewarded ad has exceeded [kRewardedAdStaleThreshold].
  static bool isRewardedAdStale({DateTime? now}) {
    if (_preloadedRewardedAd == null || _rewardedAdLoadedAt == null) {
      return false;
    }
    final current = now ?? DateTime.now();
    return current.difference(_rewardedAdLoadedAt!) >= kRewardedAdStaleThreshold;
  }

  /// Evaluates whether a rewarded ad request is necessary and policy-compliant.
  static bool shouldRequestRewardedAd({
    required bool isAdFree,
    DateTime? now,
  }) {
    if (isAdFree) return false;
    if (!isSupportedPlatform) return false;
    if (appLifecycleState != AppLifecycleState.resumed) return false;
    if (_isPreloadingRewardedAd) return false;

    final current = now ?? DateTime.now();
    if (_preloadedRewardedAd != null && !isRewardedAdStale(now: current)) {
      return false;
    }

    if (_lastRewardedLoadAttemptAt != null &&
        current.difference(_lastRewardedLoadAttemptAt!) <
            kMinAdRequestCooldown) {
      return false;
    }

    return true;
  }

  /// Probes network connectivity and updates [isOfflineNotifier].
  static Future<bool> checkConnectivity() async {
    if (debugIsOffline != null) {
      isOfflineNotifier.value = debugIsOffline!;
      return !debugIsOffline!;
    }
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return !isOffline;
      }
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      _isOffline = !online;
      isOfflineNotifier.value = _isOffline;
      return online;
    } catch (_) {
      _isOffline = true;
      isOfflineNotifier.value = true;
      return false;
    }
  }

  /// Marks the device as offline when an AdMob load error indicates a network failure.
  static void markOfflineFromAdError(LoadAdError error) {
    final msg = error.message.toLowerCase();
    if (error.code == 2 ||
        msg.contains('network') ||
        msg.contains('offline') ||
        msg.contains('unable to resolve host')) {
      _isOffline = true;
      isOfflineNotifier.value = true;
    }
  }

  /// Preloads standby [BannerAd] instances into [_cachedBannerPool] while online.
  static Future<void> preloadCachedBanners() async {
    if (!_canInvokeNativeAdMob || isOffline || _isPreloadingBanners) return;
    if (appLifecycleState != AppLifecycleState.resumed) return;
    if (isUserAdFreeCallback?.call() ?? false) return;
    if (_cachedBannerPool.length >= kMaxPreloadedBanners) return;

    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) return;

    _isPreloadingBanners = true;
    try {
      while (_cachedBannerPool.length < kMaxPreloadedBanners &&
          !isOffline &&
          appLifecycleState == AppLifecycleState.resumed &&
          !(isUserAdFreeCallback?.call() ?? false)) {
        final completer = Completer<void>();
        late final BannerAd banner;
        banner = BannerAd(
          adUnitId: unitId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (_) {
              _isOffline = false;
              isOfflineNotifier.value = false;
              if (_cachedBannerPool.length < kMaxPreloadedBanners) {
                _cachedBannerPool.add(banner);
              } else {
                banner.dispose();
              }
              if (!completer.isCompleted) completer.complete();
            },
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              markOfflineFromAdError(error);
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await banner.load();
        await completer.future.timeout(
          const Duration(seconds: 6),
          onTimeout: () {},
        );
        if (isOffline) break;
      }
    } catch (_) {
    } finally {
      _isPreloadingBanners = false;
    }
  }

  /// Claims a preloaded standby [BannerAd] from [_cachedBannerPool] if available.
  static BannerAd? takePreloadedBannerAd({AdSize? preferredSize}) {
    if (_cachedBannerPool.isEmpty) return null;
    if (preferredSize != null) {
      for (int i = 0; i < _cachedBannerPool.length; i++) {
        if (_cachedBannerPool[i].size.width == preferredSize.width &&
            _cachedBannerPool[i].size.height == preferredSize.height) {
          final ad = _cachedBannerPool.removeAt(i);
          if (!isOffline) {
            unawaited(preloadCachedBanners());
          }
          return ad;
        }
      }
    }
    final ad = _cachedBannerPool.removeAt(0);
    if (!isOffline) {
      unawaited(preloadCachedBanners());
    }
    return ad;
  }

  /// Centralized evaluation called by the periodic timer and [AdNavigationObserver].
  static Future<bool> evaluateAndPreloadAdsIfNeeded({
    bool? isAdFree,
    DateTime? now,
  }) async {
    final effectiveAdFree = isAdFree ?? (isUserAdFreeCallback?.call() ?? false);
    if (effectiveAdFree ||
        !isSupportedPlatform ||
        appLifecycleState != AppLifecycleState.resumed) {
      return false;
    }

    final online = await checkConnectivity();
    adRefreshTickNotifier.value++;

    // Freeze preloaded ads while offline so they are never disposed.
    if (!online) {
      return false;
    }

    unawaited(preloadCachedBanners());

    if (!shouldRequestRewardedAd(isAdFree: effectiveAdFree, now: now)) {
      return false;
    }

    if (isRewardedAdStale(now: now)) {
      _preloadedRewardedAd?.dispose();
      _preloadedRewardedAd = null;
      _rewardedAdLoadedAt = null;
      rewardedAdReadyNotifier.value = false;
    }

    await preloadRewardedAd();
    return true;
  }

  /// Starts the lifecycle-aware periodic background refresh timer.
  static void startPeriodicRefresh({
    Duration interval = const Duration(seconds: 60),
  }) {
    _periodicRefreshTimer?.cancel();
    if (!isSupportedPlatform || appLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _periodicRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(evaluateAndPreloadAdsIfNeeded());
    });
  }

  /// Pauses the periodic background refresh timer.
  static void stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  /// Handles app foreground/background transitions.
  static void onAppLifecycleStateChanged(AppLifecycleState state) {
    appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      startPeriodicRefresh();
      unawaited(evaluateAndPreloadAdsIfNeeded());
    } else {
      stopPeriodicRefresh();
    }
  }

  /// Preloads a RewardedAd in the background with exponential retry backoff.
  static Future<void> preloadRewardedAd() async {
    if (!_canInvokeNativeAdMob) return;
    if (appLifecycleState != AppLifecycleState.resumed) return;
    if (isUserAdFreeCallback?.call() ?? false) return;
    if (_preloadedRewardedAd != null || _isPreloadingRewardedAd) return;

    final unitId = rewardedAdUnitId;
    if (unitId.isEmpty) return;

    _lastRewardedLoadAttemptAt = DateTime.now();
    _isPreloadingRewardedAd = true;
    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _preloadedRewardedAd = ad;
            _rewardedAdLoadedAt = DateTime.now();
            _isPreloadingRewardedAd = false;
            _rewardedRetryAttempt = 0;
            rewardedAdReadyNotifier.value = true;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _preloadedRewardedAd = null;
            _isPreloadingRewardedAd = false;
            rewardedAdReadyNotifier.value = false;
            if (_rewardedRetryAttempt < _maxRewardedRetryAttempts) {
              _rewardedRetryAttempt++;
              final backoffSeconds = 1 << _rewardedRetryAttempt;
              Future<void>.delayed(Duration(seconds: backoffSeconds), () {
                preloadRewardedAd();
              });
            }
          },
        ),
      );
    } catch (e) {
      _isPreloadingRewardedAd = false;
      rewardedAdReadyNotifier.value = false;
    }
  }

  static void _presentRewardedAd(
    RewardedAd ad, {
    required void Function() onUserEarnedReward,
    void Function(String error)? onAdFailed,
    required Completer<bool> completer,
  }) async {
    bool rewardEarned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        // Immediately restore muted state so banners and inline ads never play sound
        unawaited(muteBannerAds());
        preloadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        // Immediately restore muted state if rewarded ad fails to show
        unawaited(muteBannerAds());
        preloadRewardedAd();
        onAdFailed?.call(error.message);
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    // Unmute exclusively for the full-screen rewarded video ad
    await enableRewardedAdAudio();

    ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        rewardEarned = true;
        onUserEarnedReward();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );
  }

  /// Loads and shows a 30-second RewardedAd.
  /// Strictly calls [onUserEarnedReward] only inside the reward callback.
  static Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function(String error)? onAdFailed,
    bool simulateWhenUnsupported = false,
  }) async {
    if (!_canInvokeNativeAdMob) {
      if (simulateWhenUnsupported || debugIsSupportedPlatform == true) {
        onUserEarnedReward();
        return true;
      }
      onAdFailed?.call('Platform not supported');
      return false;
    }

    final completer = Completer<bool>();

    if (_preloadedRewardedAd != null) {
      final ad = _preloadedRewardedAd!;
      _preloadedRewardedAd = null;
      rewardedAdReadyNotifier.value = false;
      try {
        _presentRewardedAd(
          ad,
          onUserEarnedReward: onUserEarnedReward,
          onAdFailed: onAdFailed,
          completer: completer,
        );
      } catch (e) {
        onAdFailed?.call(e.toString());
        if (!completer.isCompleted) completer.complete(false);
      }
      return completer.future;
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _presentRewardedAd(
              ad,
              onUserEarnedReward: onUserEarnedReward,
              onAdFailed: onAdFailed,
              completer: completer,
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

  /// Guarded interstitial ad trigger. Immediately returns false when [isAdFree] is true.
  static Future<bool> showInterstitialAd({
    required bool isAdFree,
    VoidCallback? onDismissed,
  }) async {
    if (isAdFree || !_canInvokeNativeAdMob) {
      onDismissed?.call();
      return false;
    }
    onDismissed?.call();
    return false;
  }

  /// Creates a BannerAd instance when on a supported platform.
  static BannerAd? createBannerAd({
    required void Function() onAdLoaded,
    required void Function(LoadAdError error) onAdFailedToLoad,
    AdSize size = AdSize.banner,
  }) {
    // Strictly guarantee sound is silenced for banner ads
    unawaited(muteBannerAds());
    if (!_canInvokeNativeAdMob) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
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
    // Strictly guarantee sound is silenced for native/banner cards
    unawaited(muteBannerAds());
    if (!_canInvokeNativeAdMob) return null;
    return NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: nativeTemplateStyle,
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: true,
        ),
      ),
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
