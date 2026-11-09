import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import 'ad_free_pass_button.dart';

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

class _SmartBannerAdWidgetState extends ConsumerState<SmartBannerAdWidget> {
  NativeAd? _nativeAd;
  BannerAd? _bannerAd;
  bool _isNativeLoaded = false;
  bool _isBannerLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdIfNeeded();
  }

  void _loadAdIfNeeded() {
    if (!AdService.isSupportedPlatform) return;
    final adState = ref.read(adNotifierProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_nativeAd != null || _bannerAd != null || _isLoading) return;

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
        if (mounted) {
          setState(() {
            _isNativeLoaded = true;
            _isLoading = false;
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
    _bannerAd = AdService.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isBannerLoaded = true;
            _isLoading = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        if (mounted) {
          setState(() {
            _bannerAd?.dispose();
            _bannerAd = null;
            _isBannerLoaded = false;
            _isLoading = false;
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
  }

  @override
  void dispose() {
    _disposeAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in ad-free state to dispose ad when unlocked
    ref.listen<AdState>(adNotifierProvider, (previous, next) {
      if (next.isAdFree && (_nativeAd != null || _bannerAd != null)) {
        setState(() {
          _disposeAds();
        });
      } else if (!next.isAdFree && _nativeAd == null && _bannerAd == null && !_isLoading) {
        _loadAdIfNeeded();
      }
    });
    ref.listen<MonetizationState>(monetizationProvider, (previous, next) {
      if (next.isAdFree && (_nativeAd != null || _bannerAd != null)) {
        setState(() {
          _disposeAds();
        });
      } else if (!next.isAdFree && _nativeAd == null && _bannerAd == null && !_isLoading) {
        _loadAdIfNeeded();
      }
    });

    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final adState = ref.watch(adNotifierProvider);
    final isMonetizationAdFree =
        ref.watch(monetizationProvider.select((s) => s.isAdFree));
    if (adState.isAdFree || isMonetizationAdFree) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isRecipeStyle = widget.style == SmartBannerAdStyle.recipe;
    final primaryColor = isRecipeStyle ? theme.colorScheme.primary : theme.colorScheme.secondary;

    // 1. If Native Ad is loaded, render as native card
    if (_isNativeLoaded && _nativeAd != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 860,
            minHeight: 90,
            maxHeight: 110,
          ),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isRecipeStyle ? 16 : 14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
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
      );
    }

    // 2. If Banner Ad is loaded (fallback or standard style)
    if (_isBannerLoaded && _bannerAd != null) {
      final adWidgetBody = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          color: theme.colorScheme.surface,
          child: AdWidget(ad: _bannerAd!),
        ),
      );

      if (widget.style == SmartBannerAdStyle.standard) {
        return Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: adWidgetBody,
        );
      }

      final cardBorderRadius = BorderRadius.circular(isRecipeStyle ? 16 : 14);

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: cardBorderRadius,
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
                          isRecipeStyle
                              ? Icons.restaurant_menu_rounded
                              : Icons.shopping_basket_rounded,
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
                                    isRecipeStyle
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
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n?.ad_badge_label ?? 'AD',
                                    style: TextStyle(
                                      fontSize: 8.5,
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
                                Icons.play_circle_outline,
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
                  Center(child: adWidgetBody),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
