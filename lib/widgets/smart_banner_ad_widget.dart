import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import '../services/offline_ad_cache_service.dart';
import 'ad_free_pass_button.dart';
import 'offline_cached_ad_widget.dart';

enum SmartBannerAdStyle {
  recipe,
  ingredient,
  standard,
}

class SmartBannerAdWidget extends ConsumerStatefulWidget {
  final SmartBannerAdStyle style;

  const SmartBannerAdWidget({
    super.key,
    this.style = SmartBannerAdStyle.recipe,
  });

  @override
  ConsumerState<SmartBannerAdWidget> createState() => _SmartBannerAdWidgetState();
}

class _SmartBannerAdWidgetState extends ConsumerState<SmartBannerAdWidget>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  BannerAd? _bannerAd;
  CachedOfflineAdPayload? _cachedOfflinePayload;
  DateTime? _lastLoadAttemptAt;
  bool _isNativeLoaded = false;
  bool _isBannerLoaded = false;
  bool _isLoading = false;
  bool _loadFailed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cachedOfflinePayload = OfflineAdCacheService.getNextCachedAdSync(
      style: widget.style.name,
    );
    AdService.adRefreshTickNotifier.addListener(_onGlobalRefreshTick);
    AdService.isOfflineNotifier.addListener(_onOfflineStateChanged);
    _loadAdIfNeeded();
  }

  void _onOfflineStateChanged() {
    if (!mounted) return;
    if (!AdService.isOffline &&
        _nativeAd == null &&
        _bannerAd == null &&
        !_isLoading) {
      _loadFailed = false;
      _loadAdIfNeeded();
    } else if (AdService.isOffline && _nativeAd == null && _bannerAd == null) {
      setState(() {});
    }
  }

  void _onGlobalRefreshTick() {
    if (!mounted || _isLoading || AdService.isOffline) return;
    final adState = ref.read(adNotifierProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;

    if (_loadFailed &&
        _nativeAd == null &&
        _bannerAd == null &&
        _lastLoadAttemptAt != null &&
        DateTime.now().difference(_lastLoadAttemptAt!) >=
            AdService.kMinAdRequestCooldown) {
      _loadFailed = false;
      _loadAdIfNeeded();
    }
  }

  void _loadAdIfNeeded() {
    if (!AdService.isSupportedPlatform) return;
    final adState = ref.read(adNotifierProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_nativeAd != null || _bannerAd != null || _isLoading || _loadFailed) return;

    if (widget.style == SmartBannerAdStyle.standard) {
      final pooled = AdService.takePreloadedBannerAd();
      if (pooled != null) {
        unawaited(
          OfflineAdCacheService.recordLiveAdLoaded(
            width: pooled.size.width,
            height: pooled.size.height,
            style: widget.style.name,
          ),
        );
        if (mounted) {
          setState(() {
            _bannerAd = pooled;
            _isBannerLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        } else {
          pooled.dispose();
        }
        return;
      }
    }

    if (AdService.isOffline) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
      return;
    }

    _lastLoadAttemptAt = DateTime.now();
    _isLoading = true;

    // For recipe and ingredient styles, prefer Native Ad for seamless app-card look
    if (widget.style != SmartBannerAdStyle.standard) {
      _loadNativeAd();
    } else {
      _loadBannerAd();
    }
  }

  void _loadNativeAd() {
    final isRecipe = widget.style == SmartBannerAdStyle.recipe;
    final primaryColor = isRecipe ? const Color(0xFF1E88E5) : const Color(0xFF2E7D32);

    final templateStyle = NativeTemplateStyle(
      templateType: TemplateType.small,
      mainBackgroundColor: const Color(0xFF1E1E2C),
      cornerRadius: isRecipe ? 16.0 : 14.0,
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        size: 13.5,
        style: NativeTemplateFontStyle.bold,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white70,
        size: 11.0,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white54,
        size: 10.0,
      ),
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: primaryColor,
        size: 12.0,
        style: NativeTemplateFontStyle.bold,
      ),
    );

    _nativeAd = AdService.createNativeAd(
      nativeTemplateStyle: templateStyle,
      onAdLoaded: (ad) {
        unawaited(
          OfflineAdCacheService.recordLiveAdLoaded(
            width: 320,
            height: 96,
            style: widget.style.name,
          ),
        );
        if (mounted) {
          setState(() {
            _isNativeLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('Native ad failed, falling back to banner: $error');
        if (mounted) {
          setState(() {
            _nativeAd?.dispose();
            _nativeAd = null;
            _isNativeLoaded = false;
          });
          // Fallback to banner ad if native fails
          _loadBannerAd();
        }
      },
    );

    _nativeAd?.load();
  }

  void _loadBannerAd() {
    final pooled = AdService.takePreloadedBannerAd();
    if (pooled != null) {
      unawaited(
        OfflineAdCacheService.recordLiveAdLoaded(
          width: pooled.size.width,
          height: pooled.size.height,
          style: widget.style.name,
        ),
      );
      if (mounted) {
        setState(() {
          _bannerAd = pooled;
          _isBannerLoaded = true;
          _isLoading = false;
          _loadFailed = false;
        });
      } else {
        pooled.dispose();
      }
      return;
    }

    _bannerAd = AdService.createBannerAd(
      onAdLoaded: () {
        unawaited(
          OfflineAdCacheService.recordLiveAdLoaded(
            width: _bannerAd?.size.width ?? 320,
            height: _bannerAd?.size.height ?? 50,
            style: widget.style.name,
          ),
        );
        if (mounted) {
          setState(() {
            _isBannerLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        AdService.markOfflineFromAdError(error);
        if (mounted) {
          setState(() {
            _bannerAd?.dispose();
            _bannerAd = null;
            _isBannerLoaded = false;
            _isLoading = false;
            _loadFailed = true;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  void _disposeAds() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isNativeLoaded = false;
    _isBannerLoaded = false;
    _isLoading = false;
    _loadFailed = false;
  }

  @override
  void dispose() {
    AdService.adRefreshTickNotifier.removeListener(_onGlobalRefreshTick);
    AdService.isOfflineNotifier.removeListener(_onOfflineStateChanged);
    _disposeAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Listen to changes in ad-free state to dispose ad when unlocked
    ref.listen<bool>(adNotifierProvider.select((s) => s.isAdFree), (previous, next) {
      if (next && (_nativeAd != null || _bannerAd != null)) {
        setState(() {
          _disposeAds();
        });
      } else if (!next && _nativeAd == null && _bannerAd == null && !_isLoading && !_loadFailed) {
        _loadAdIfNeeded();
      }
    });
    ref.listen<bool>(monetizationProvider.select((s) => s.isAdFree), (previous, next) {
      if (next && (_nativeAd != null || _bannerAd != null)) {
        setState(() {
          _disposeAds();
        });
      } else if (!next && _nativeAd == null && _bannerAd == null && !_isLoading && !_loadFailed) {
        _loadAdIfNeeded();
      }
    });

    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final isAdFree = ref.watch(adNotifierProvider.select((s) => s.isAdFree));
    final isMonetizationAdFree =
        ref.watch(monetizationProvider.select((s) => s.isAdFree));
    if (isAdFree || isMonetizationAdFree) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isRecipeStyle = widget.style == SmartBannerAdStyle.recipe;
    final primaryColor = isRecipeStyle ? theme.colorScheme.primary : theme.colorScheme.secondary;

    // 1. If Native Ad is loaded, render as native card
    if (_isNativeLoaded && _nativeAd != null) {
      return RepaintBoundary(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 860,
              minHeight: 90,
              maxHeight: 110,
            ),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isRecipeStyle ? 16 : 14),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Stack(
                children: [
                  AdWidget(ad: _nativeAd!),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => AdFreePassDialog.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 12,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '8h',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

    // 2. Standard banner style handling
    if (widget.style == SmartBannerAdStyle.standard) {
      if (_isBannerLoaded && _bannerAd != null) {
        return RepaintBoundary(
          child: Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            color: theme.colorScheme.surface,
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      }
      if (_loadFailed || AdService.isOffline) {
        return RepaintBoundary(
          child: OfflineCachedAdWidget(
            payload: _cachedOfflinePayload ??
                OfflineAdCacheService.getNextCachedAdSync(
                  style: widget.style.name,
                ),
            width: 320.0,
            height: 50.0,
            accentColor: primaryColor,
            compact: true,
          ),
        );
      }
      final bannerWidth = _bannerAd?.size.width.toDouble() ?? 320.0;
      final bannerHeight = _bannerAd?.size.height.toDouble() ?? 50.0;
      return Container(
        alignment: Alignment.center,
        width: bannerWidth,
        height: bannerHeight,
        child: SizedBox(
          width: bannerWidth,
          height: bannerHeight,
        ),
      );
    }

    // 3. If Banner Ad is loaded (fallback for recipe or ingredient style)
    if (_isBannerLoaded && _bannerAd != null) {
      final adWidth = _bannerAd!.size.width.toDouble();
      final adHeight = _bannerAd!.size.height.toDouble();
      final cardBorderRadius = BorderRadius.circular(isRecipeStyle ? 16 : 14);

      return RepaintBoundary(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: cardBorderRadius,
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: adHeight,
                    alignment: Alignment.center,
                    color: theme.colorScheme.surface,
                    child: SizedBox(
                      width: adWidth,
                      height: adHeight,
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => AdFreePassDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 12,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '8h',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 860,
          minHeight: 90,
          maxHeight: 110,
        ),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isRecipeStyle ? 16 : 14),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: (_loadFailed || AdService.isOffline)
              ? Stack(
                  children: [
                    OfflineCachedAdWidget(
                      payload: _cachedOfflinePayload ??
                          OfflineAdCacheService.getNextCachedAdSync(
                            style: widget.style.name,
                          ),
                      width: double.infinity,
                      height: 96,
                      accentColor: primaryColor,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => AdFreePassDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 12,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '8h',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(
                  height: 96,
                  width: double.infinity,
                ),
        ),
      ),
    );
  }
}
