import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import 'ad_free_pass_button.dart';

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

  const InlineAdCard({
    super.key,
    this.style = InlineAdCardStyle.recipe,
  });

  @override
  ConsumerState<InlineAdCard> createState() => _InlineAdCardState();
}

class _InlineAdCardState extends ConsumerState<InlineAdCard>
    with AutomaticKeepAliveClientMixin {
  static const int _maxActiveInlineAds = 3;
  static final List<_InlineAdCardState> _activePool = [];

  BannerAd? _bannerAd;
  Timer? _loadDebounceTimer;
  ValueNotifier<bool>? _isScrollingNotifier;
  bool _isScrolling = false;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _loadFailed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scheduleAdLoad();
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

  void _loadAdIfNeeded() {
    if (!AdService.isSupportedPlatform || _isScrolling) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_bannerAd != null || _isLoading || _loadFailed) return;

    _isLoading = true;
    final createdAd = AdService.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          _registerInPool();
          setState(() {
            _isAdLoaded = true;
            _isLoading = false;
            _loadFailed = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
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
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    _loadFailed = false;
  }

  @override
  void dispose() {
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
    if (isAdFree || isMonetizationAdFree || _loadFailed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isRecipe = widget.style == InlineAdCardStyle.recipe;
    final primaryColor = isRecipe ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final borderRadius = BorderRadius.circular(isRecipe ? 16 : 14);

    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Card(
          margin: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isRecipe ? 6 : 4,
          ),
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: primaryColor,
                      child: Icon(
                        isRecipe ? Icons.restaurant_menu_rounded : Icons.shopping_basket_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isRecipe
                                      ? (l10n?.ad_sponsored_recipe ?? 'Sponsored Recipe')
                                      : (l10n?.ad_sponsored_ingredient ?? 'Sponsored Ingredient'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n?.ad_sponsored_label ?? 'AD',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onTertiaryContainer,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            l10n?.ad_card_subtitle ?? 'Chef&Cost • Watch pass to remove',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => AdFreePassDialog.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '8h',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    alignment: Alignment.center,
                    width: _bannerAd?.size.width.toDouble() ?? 320.0,
                    height: _bannerAd?.size.height.toDouble() ?? 50.0,
                    color: theme.colorScheme.surface,
                    child: (!_isScrolling && _isAdLoaded && _bannerAd != null)
                        ? AdWidget(ad: _bannerAd!)
                        : SizedBox(
                            width: _bannerAd?.size.width.toDouble() ?? 320.0,
                            height: _bannerAd?.size.height.toDouble() ?? 50.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.campaign_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n?.ad_sponsored_label ?? 'AD',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
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
      ),
    );
  }
}
