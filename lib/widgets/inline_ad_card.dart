import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import '../services/offline_ad_cache_service.dart';
import 'ad_free_pass_button.dart';
import 'offline_cached_ad_widget.dart';

enum InlineAdCardStyle {
  recipe,
  ingredient,
}

/// An inline Ad Card widget that renders as a native item box inside
/// the Recipes and Ingredients lists/grids.
///
/// Watches [adProvider] and returns [SizedBox.shrink] if the user is ad-free,
/// if on an unsupported platform (Web/Desktop), or if the ad fails to load.
class InlineAdCard extends ConsumerStatefulWidget {
  final InlineAdCardStyle style;
  final EdgeInsetsGeometry? margin;

  const InlineAdCard({
    super.key,
    this.style = InlineAdCardStyle.recipe,
    this.margin,
  });

  @override
  ConsumerState<InlineAdCard> createState() => _InlineAdCardState();
}

class _InlineAdCardState extends ConsumerState<InlineAdCard>
    with AutomaticKeepAliveClientMixin {
  static const int _maxActiveInlineAds = 3;
  static final List<_InlineAdCardState> _activePool = [];

  BannerAd? _bannerAd;
  BannerAd? _stagingBannerAd;
  CachedOfflineAdPayload? _cachedOfflinePayload;
  Timer? _loadDebounceTimer;
  ValueNotifier<bool>? _isScrollingNotifier;
  bool _isScrolling = false;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _loadFailed = false;
  DateTime? _adLoadedAt;
  DateTime? _lastLoadAttemptAt;

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
    _scheduleAdLoad();
  }

  void _onOfflineStateChanged() {
    if (!mounted) return;
    if (!AdService.isOffline && _bannerAd == null && !_isLoading) {
      _loadFailed = false;
      _scheduleAdLoad();
    } else if (AdService.isOffline && _bannerAd == null) {
      setState(() {});
    }
  }

  void _onGlobalRefreshTick() {
    if (!mounted || _isScrolling || _isLoading) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;

    final now = DateTime.now();
    if (_loadFailed &&
        _lastLoadAttemptAt != null &&
        now.difference(_lastLoadAttemptAt!) >= AdService.kMinAdRequestCooldown) {
      _loadFailed = false;
      _scheduleAdLoad();
      return;
    }

    if (_bannerAd != null &&
        _isAdLoaded &&
        _adLoadedAt != null &&
        now.difference(_adLoadedAt!) >= AdService.kBannerAdRefreshThreshold) {
      if (AdService.isOffline) {
        return;
      }
      unawaited(_refreshBannerNonDestructively());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextNotifier =
        Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (_isScrollingNotifier != nextNotifier) {
      _isScrollingNotifier?.removeListener(_onScrollStateChanged);
      _isScrollingNotifier = nextNotifier;
      _isScrolling = _isScrollingNotifier?.value ?? false;
      _isScrollingNotifier?.addListener(_onScrollStateChanged);
      if (_isScrolling) {
        _loadDebounceTimer?.cancel();
      }
    }
  }

  void _onScrollStateChanged() {
    final scrolling = _isScrollingNotifier?.value ?? false;
    if (_isScrolling == scrolling) return;
    if (mounted) {
      setState(() {
        _isScrolling = scrolling;
      });
    } else {
      _isScrolling = scrolling;
    }
    if (!scrolling && _bannerAd == null && !_isLoading && !_loadFailed) {
      _scheduleAdLoad();
    } else if (scrolling) {
      _loadDebounceTimer?.cancel();
    }
  }

  void _scheduleAdLoad() {
    if (_isScrolling) return;
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && !_isScrolling) {
        _loadAdIfNeeded();
      }
    });
  }

  void _registerInPool() {
    _activePool.remove(this);
    while (_activePool.length >= _maxActiveInlineAds) {
      final oldest = _activePool.removeAt(0);
      oldest._evictFromPool();
    }
    _activePool.add(this);
  }

  void _evictFromPool() {
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshBannerNonDestructively() async {
    if (!AdService.isSupportedPlatform ||
        AdService.isOffline ||
        _isScrolling ||
        _isLoading ||
        _stagingBannerAd != null) {
      return;
    }
    _isLoading = true;
    final targetSize = _bannerAd?.size ?? AdSize.banner;
    final nextAd = AdService.createBannerAd(
      size: targetSize,
      onAdLoaded: () {
        if (!mounted) {
          _stagingBannerAd?.dispose();
          _stagingBannerAd = null;
          return;
        }
        final loaded = _stagingBannerAd;
        _stagingBannerAd = null;
        if (loaded != null) {
          _bannerAd?.dispose();
          _bannerAd = loaded;
          _adLoadedAt = DateTime.now();
          _isAdLoaded = true;
          _loadFailed = false;
          unawaited(
            OfflineAdCacheService.recordLiveAdLoaded(
              width: loaded.size.width,
              height: loaded.size.height,
              style: widget.style.name,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      },
      onAdFailedToLoad: (error) {
        AdService.markOfflineFromAdError(error);
        _stagingBannerAd?.dispose();
        _stagingBannerAd = null;
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
    if (nextAd == null) {
      _isLoading = false;
      return;
    }
    _stagingBannerAd = nextAd;
    await _stagingBannerAd!.load();
  }

  Future<void> _loadAdIfNeeded() async {
    if (!AdService.isSupportedPlatform || _isScrolling) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_bannerAd != null || _isLoading || _loadFailed) return;

    // 1. Try claiming a standby preloaded banner from AdService's in-memory pool
    final pooled = AdService.takePreloadedBannerAd();
    if (pooled != null) {
      _registerInPool();
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
          _adLoadedAt = DateTime.now();
          _isAdLoaded = true;
          _isLoading = false;
          _loadFailed = false;
        });
      } else {
        pooled.dispose();
      }
      return;
    }

    // 2. If offline and no pooled ad is available, show cached offline ad immediately
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
    const AdSize targetSize = AdSize.banner;
    if (!mounted) {
      _isLoading = false;
      return;
    }

    final createdAd = AdService.createBannerAd(
      size: targetSize,
      onAdLoaded: () {
        if (mounted) {
          _registerInPool();
          unawaited(
            OfflineAdCacheService.recordLiveAdLoaded(
              width: targetSize.width,
              height: targetSize.height,
              style: widget.style.name,
            ),
          );
          setState(() {
            _adLoadedAt = DateTime.now();
            _isAdLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        AdService.markOfflineFromAdError(error);
        _activePool.remove(this);
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

    if (createdAd == null) {
      _isLoading = false;
      return;
    }

    _bannerAd = createdAd;
    _bannerAd!.load();
  }

  void _disposeAd() {
    _activePool.remove(this);
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = null;
    _stagingBannerAd?.dispose();
    _stagingBannerAd = null;
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
    _isScrollingNotifier?.removeListener(_onScrollStateChanged);
    _isScrollingNotifier = null;
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Listen for ad-free state updates to dismiss ad immediately
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
    final l10n = AppLocalizations.of(context);
    final isRecipe = widget.style == InlineAdCardStyle.recipe;
    final primaryColor =
        isRecipe ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final borderRadius = BorderRadius.circular(isRecipe ? 16 : 14);
    final adWidth = _bannerAd?.size.width.toDouble() ?? 320.0;
    final adHeight = _bannerAd?.size.height.toDouble() ?? 50.0;

    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            margin: widget.margin ??
                EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isRecipe ? 6 : 4,
                ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
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
                  child: (!_isScrolling && _isAdLoaded && _bannerAd != null)
                      ? SizedBox(
                          width: adWidth,
                          height: adHeight,
                          child: AdWidget(ad: _bannerAd!),
                        )
                      : (_loadFailed || AdService.isOffline)
                          ? OfflineCachedAdWidget(
                              payload: _cachedOfflinePayload ??
                                  OfflineAdCacheService.getNextCachedAdSync(
                                    style: widget.style.name,
                                  ),
                              width: double.infinity,
                              height: adHeight,
                              accentColor: primaryColor,
                              compact: adHeight < 60,
                            )
                          : SizedBox(
                          width: adWidth,
                          height: adHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.campaign_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n?.ad_badge_label ?? 'AD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          color: theme.colorScheme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
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
}
