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

class _InlineAdCardState extends ConsumerState<InlineAdCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdIfNeeded();
  }

  void _loadAdIfNeeded() {
    if (!AdService.isSupportedPlatform) return;
    final adState = ref.read(adProvider);
    final monetization = ref.read(monetizationProvider);
    if (adState.isAdFree || monetization.isAdFree) return;
    if (_bannerAd != null || _isLoading) return;

    _isLoading = true;
    _bannerAd = AdService.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
            _isLoading = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        if (mounted) {
          setState(() {
            _bannerAd?.dispose();
            _bannerAd = null;
            _isAdLoaded = false;
            _isLoading = false;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for ad-free state updates to dismiss ad immediately
    ref.listen<AdState>(adProvider, (previous, next) {
      if (next.isAdFree && _bannerAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next.isAdFree && _bannerAd == null && !_isLoading) {
        _loadAdIfNeeded();
      }
    });
    ref.listen<MonetizationState>(monetizationProvider, (previous, next) {
      if (next.isAdFree && _bannerAd != null) {
        setState(() {
          _disposeAd();
        });
      } else if (!next.isAdFree && _bannerAd == null && !_isLoading) {
        _loadAdIfNeeded();
      }
    });

    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final adState = ref.watch(adProvider);
    final isMonetizationAdFree =
        ref.watch(monetizationProvider.select((s) => s.isAdFree));
    if (adState.isAdFree || isMonetizationAdFree || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isRecipe = widget.style == InlineAdCardStyle.recipe;
    final primaryColor = isRecipe ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final borderRadius = BorderRadius.circular(isRecipe ? 16 : 14);

    return Center(
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
                                      ? l10n.ad_sponsored_recipe
                                      : l10n.ad_sponsored_ingredient,
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
                                  l10n.ad_sponsored_label,
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
                            l10n.ad_card_subtitle,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      color: theme.colorScheme.surface,
                      child: AdWidget(ad: _bannerAd!),
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
