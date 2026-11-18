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

  NativeAd? _nativeAd;
  NativeAd? _stagingNativeAd;
  String? _loadedStyleKey;
  String? _currentStyleKey;
  NativeTemplateStyle? _currentTemplateStyle;
  int? _lastMeasuredInnerWidth;
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
    if (!AdService.isOffline && _nativeAd == null && !_isLoading) {
      _loadFailed = false;
      _scheduleAdLoad();
    } else if (AdService.isOffline && _nativeAd == null) {
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

    if (_nativeAd != null &&
        _isAdLoaded &&
        _adLoadedAt != null &&
        now.difference(_adLoadedAt!) >= AdService.kNativeAdRefreshThreshold) {
      if (AdService.isOffline) {
        return;
      }
      unawaited(_refreshNativeAdNonDestructively());
    }
  }

  (NativeTemplateStyle, String) _buildNativeStyle(ThemeData theme) {
    final isRecipe = widget.style == InlineAdCardStyle.recipe;
    final primaryColor =
        isRecipe ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final surfaceColor = theme.colorScheme.surfaceContainer;
    final styleKey =
        '${widget.style.name}_${theme.brightness.name}_${primaryColor.toARGB32()}_${surfaceColor.toARGB32()}';
    final style = NativeTemplateStyle(
      templateType: TemplateType.small,
      mainBackgroundColor: surfaceColor,
      cornerRadius: isRecipe ? 16.0 : 14.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: isRecipe
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSecondary,
        backgroundColor: primaryColor,
        style: NativeTemplateFontStyle.bold,
        size: 12.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.colorScheme.onSurface,
        style: NativeTemplateFontStyle.bold,
        size: 14.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.colorScheme.onSurfaceVariant,
        size: 11.5,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        size: 10.5,
      ),
    );
    return (style, styleKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final (style, styleKey) = _buildNativeStyle(Theme.of(context));
    _currentTemplateStyle = style;
    _currentStyleKey = styleKey;
    if (_loadedStyleKey != null && _loadedStyleKey != styleKey) {
      AdService.clearPreloadedNativeAds();
      if (_nativeAd != null && !_isLoading && !AdService.isOffline) {
        unawaited(_refreshNativeAdNonDestructively());
      }
    }

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
    if (!scrolling && _nativeAd == null && !_isLoading && !_loadFailed) {
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
    _nativeAd?.dispose();
    _nativeAd = null;
    _loadedStyleKey = null;
    _isAdLoaded = false;
    _isLoading = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshNativeAdNonDestructively() async {
    if (!AdService.isSupportedPlatform ||
        AdService.isOffline ||
        _isScrolling ||
        _isLoading ||
        _stagingNativeAd != null) {
      return;
    }
    final style = _currentTemplateStyle;
    final styleKey = _currentStyleKey;
    if (style == null || styleKey == null) return;

    _isLoading = true;
    final nextAd = AdService.createNativeAd(
      nativeTemplateStyle: style,
      onAdLoaded: (loaded) {
        if (!mounted) {
          loaded.dispose();
          _stagingNativeAd = null;
          return;
        }
        _stagingNativeAd = null;
        _nativeAd?.dispose();
        _nativeAd = loaded;
        _loadedStyleKey = styleKey;
        _adLoadedAt = DateTime.now();
        _isAdLoaded = true;
        _loadFailed = false;
        final innerWidth = (_lastMeasuredInnerWidth ?? 320).clamp(280, 560);
        final adHeight = (innerWidth / 4.0).clamp(96.0, 120.0).round();
        unawaited(
          OfflineAdCacheService.recordLiveAdLoaded(
            width: innerWidth,
            height: adHeight,
            style: widget.style.name,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      },
      onAdFailedToLoad: (error) {
        AdService.markOfflineFromAdError(error);
        _stagingNativeAd?.dispose();
        _stagingNativeAd = null;
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
    _stagingNativeAd = nextAd;
    await _stagingNativeAd!.load();
  }

  Future<void> _loadAdIfNeeded() async {
    if (!AdService.isSupportedPlatform || _isScrolling) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_nativeAd != null || _isLoading || _loadFailed) return;

    final innerWidth = _lastMeasuredInnerWidth;
    if (innerWidth == null || innerWidth < 280) {
      return;
    }
    final style = _currentTemplateStyle;
    final styleKey = _currentStyleKey;
    if (style == null || styleKey == null) return;

    final effectiveWidth = innerWidth.clamp(280, 560);
    final adHeight = (effectiveWidth / 4.0).clamp(96.0, 120.0).round();

    // 1. Try claiming a style-matched standby preloaded NativeAd from AdService
    final pooled = AdService.takePreloadedNativeAd(styleKey: styleKey);
    if (pooled != null) {
      _registerInPool();
      unawaited(
        OfflineAdCacheService.recordLiveAdLoaded(
          width: effectiveWidth,
          height: adHeight,
          style: widget.style.name,
        ),
      );
      if (mounted) {
        setState(() {
          _nativeAd = pooled;
          _loadedStyleKey = styleKey;
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

    final createdAd = AdService.createNativeAd(
      nativeTemplateStyle: style,
      onAdLoaded: (loaded) {
        if (mounted) {
          _registerInPool();
          unawaited(
            OfflineAdCacheService.recordLiveAdLoaded(
              width: effectiveWidth,
              height: adHeight,
              style: widget.style.name,
            ),
          );
          setState(() {
            _nativeAd = loaded;
            _loadedStyleKey = styleKey;
            _adLoadedAt = DateTime.now();
            _isAdLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        } else {
          loaded.dispose();
        }
      },
      onAdFailedToLoad: (error) {
        AdService.markOfflineFromAdError(error);
        _activePool.remove(this);
        if (mounted) {
          setState(() {
            _nativeAd?.dispose();
            _nativeAd = null;
            _loadedStyleKey = null;
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

    _nativeAd = createdAd;
    _nativeAd!.load();
  }

  void _disposeAd() {
    _activePool.remove(this);
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = null;
    _stagingNativeAd?.dispose();
    _stagingNativeAd = null;
    _nativeAd?.dispose();
    _nativeAd = null;
    _loadedStyleKey = null;
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
      if (next && _nativeAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next && _nativeAd == null && !_isLoading && !_loadFailed) {
        _loadAdIfNeeded();
      }
    });
    ref.listen<bool>(monetizationProvider.select((s) => s.isAdFree), (previous, next) {
      if (next && _nativeAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next && _nativeAd == null && !_isLoading && !_loadFailed) {
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final innerWidth = (constraints.maxWidth - 2.0)
                    .floor()
                    .clamp(0, 860);
                if (innerWidth >= 280 &&
                    _lastMeasuredInnerWidth != innerWidth) {
                  _lastMeasuredInnerWidth = innerWidth;
                  if (_nativeAd == null && !_isLoading && !_loadFailed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _scheduleAdLoad();
                    });
                  }
                }

                final effectiveInnerWidth =
                    innerWidth.toDouble().clamp(0.0, 560.0);
                final adHeight = (effectiveInnerWidth / 4.0).clamp(96.0, 120.0);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n?.ad_badge_label ?? 'AD',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => AdFreePassDialog.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        primaryColor.withValues(alpha: 0.45),
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
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: adHeight,
                      alignment: Alignment.center,
                      color: theme.colorScheme.surfaceContainer,
                      child: (_isAdLoaded && _nativeAd != null)
                          ? SizedBox(
                              width: effectiveInnerWidth,
                              height: adHeight,
                              child: AdWidget(ad: _nativeAd!),
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
                                  width: double.infinity,
                                  height: adHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.campaign_outlined,
                                          size: 16,
                                          color: theme
                                              .colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n?.ad_badge_label ?? 'AD',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant
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
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
