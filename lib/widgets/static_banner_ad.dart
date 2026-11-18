import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import '../services/offline_ad_cache_service.dart';
import 'offline_cached_ad_widget.dart';

/// A lightweight static [BannerAd] widget for fixed top placements
/// (e.g. Tools, Rule of Three, Unit Converter, Add Ingredient, Kitchen Timers).
class StaticBannerAd extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry? margin;

  const StaticBannerAd({
    super.key,
    this.margin,
  });

  @override
  ConsumerState<StaticBannerAd> createState() => _StaticBannerAdState();
}

class _StaticBannerAdState extends ConsumerState<StaticBannerAd>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  AdSize? _adaptiveSize;
  int? _lastMeasuredWidth;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _loadFailed = false;
  DateTime? _lastLoadAttemptAt;
  CachedOfflineAdPayload? _cachedOfflinePayload;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cachedOfflinePayload = OfflineAdCacheService.getNextCachedAdSync(
      style: 'banner',
    );
    AdService.adRefreshTickNotifier.addListener(_onGlobalRefreshTick);
    AdService.isOfflineNotifier.addListener(_onOfflineStateChanged);
  }

  void _onOfflineStateChanged() {
    if (!mounted) return;
    if (!AdService.isOffline && _bannerAd == null && !_isLoading) {
      _loadFailed = false;
      _loadAdIfNeeded();
    } else if (AdService.isOffline && _bannerAd == null) {
      setState(() {});
    }
  }

  void _onGlobalRefreshTick() {
    if (!mounted || _isLoading) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;

    final now = DateTime.now();
    if (_loadFailed &&
        _lastLoadAttemptAt != null &&
        now.difference(_lastLoadAttemptAt!) >= AdService.kMinAdRequestCooldown) {
      _loadFailed = false;
      _loadAdIfNeeded();
    }
  }

  Future<void> _loadAdIfNeeded() async {
    if (!AdService.isSupportedPlatform || _isLoading || _loadFailed) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_bannerAd != null) return;

    if (AdService.isOffline) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
      return;
    }

    final width = _lastMeasuredWidth;
    if (width == null || width < 280) return;

    _lastLoadAttemptAt = DateTime.now();
    _isLoading = true;

    AdSize targetSize = AdSize.banner;
    try {
      final adaptive =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (adaptive != null) {
        targetSize = adaptive;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _adaptiveSize = targetSize;
    });

    final created = AdService.createBannerAd(
      size: targetSize,
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
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
            _isAdLoaded = false;
            _isLoading = false;
            _loadFailed = true;
          });
        }
      },
    );

    if (created == null) {
      _isLoading = false;
      return;
    }

    _bannerAd = created;
    await _bannerAd!.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    _loadFailed = false;
  }

  @override
  void dispose() {
    AdService.adRefreshTickNotifier.removeListener(_onGlobalRefreshTick);
    AdService.isOfflineNotifier.removeListener(_onOfflineStateChanged);
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    ref.listen<bool>(adProvider.select((s) => s.isAdFree), (previous, next) {
      if (next && _bannerAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next && _bannerAd == null && !_isLoading && !_loadFailed) {
        _loadAdIfNeeded();
      }
    });
    ref.listen<bool>(monetizationProvider.select((s) => s.isAdFree), (previous, next) {
      if (next && _bannerAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next && _bannerAd == null && !_isLoading && !_loadFailed) {
        _loadAdIfNeeded();
      }
    });

    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final isAdFree = ref.watch(adProvider.select((s) => s.isAdFree));
    final isMonetizationAdFree =
        ref.watch(monetizationProvider.select((s) => s.isAdFree));
    if (isAdFree || isMonetizationAdFree) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Padding(
        padding: widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth.floor() : 320;
            if (availableWidth >= 280 && _lastMeasuredWidth != availableWidth) {
              _lastMeasuredWidth = availableWidth;
              if (_bannerAd == null && !_isLoading && !_loadFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadAdIfNeeded();
                });
              }
            }

            final effectiveSize = _bannerAd?.size ?? _adaptiveSize ?? AdSize.banner;
            final bannerWidth = effectiveSize.width
                .toDouble()
                .clamp(0.0, availableWidth.toDouble());
            final bannerHeight = effectiveSize.height.toDouble();

            return Center(
              child: SizedBox(
                width: bannerWidth,
                height: bannerHeight,
                child: (_isAdLoaded && _bannerAd != null)
                    ? AdWidget(ad: _bannerAd!)
                    : (_loadFailed || AdService.isOffline)
                        ? OfflineCachedAdWidget(
                            payload: _cachedOfflinePayload ??
                                OfflineAdCacheService.getNextCachedAdSync(
                                  style: 'banner',
                                ),
                            width: bannerWidth,
                            height: bannerHeight,
                            accentColor: theme.colorScheme.primary,
                            compact: true,
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
              ),
            );
          },
        ),
      ),
    );
  }
}
