import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/offline_ad_cache_service.dart';
import 'ad_free_pass_button.dart';

/// Renders a persistent, disk-cached promotional ad when the device is offline
/// or live AdMob loading fails, preventing users from bypassing ads by disabling
/// Wi-Fi or mobile data.
class OfflineCachedAdWidget extends StatelessWidget {
  final CachedOfflineAdPayload payload;
  final double width;
  final double height;
  final Color accentColor;
  final bool compact;

  const OfflineCachedAdWidget({
    super.key,
    required this.payload,
    required this.width,
    required this.height,
    required this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final (IconData icon, String title, String subtitle) =
        switch (payload.creativeIndex % 3) {
      0 => (
          Icons.cloud_sync_rounded,
          l10n?.offline_ad_pro_title ?? 'Chef&Cost Cloud Sync & Pro',
          l10n?.offline_ad_pro_subtitle ??
              'Sync recipes across devices & remove all ads permanently',
        ),
      1 => (
          Icons.trending_up_rounded,
          l10n?.offline_ad_costing_title ?? 'Protect Your Kitchen Margins',
          l10n?.offline_ad_costing_subtitle ??
              'Upgrade to Pro for real-time cloud backup & zero ads',
        ),
      _ => (
          Icons.shield_rounded,
          l10n?.offline_ad_pass_title ?? 'Want 8 Hours Without Ads?',
          l10n?.offline_ad_pass_subtitle ??
              'Connect to the internet to watch 1 short video or upgrade to Pro',
        ),
    };

    final ctaLabel = l10n?.offline_ad_cta ?? 'Go Ad-Free';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AdFreePassDialog.show(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 340;
            final effectiveCompact = compact || isNarrow;
            final showIcon = constraints.maxWidth >= 280;

            return Container(
              width: width,
              height: height,
              padding: EdgeInsets.symmetric(
                horizontal: effectiveCompact ? 10 : 14,
                vertical: effectiveCompact ? 4 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    accentColor.withValues(alpha: 0.14),
                    theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Row(
                children: [
                  if (showIcon) ...[
                    Container(
                      width: effectiveCompact ? 32 : 40,
                      height: effectiveCompact ? 32 : 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: effectiveCompact ? 18 : 22,
                        color: accentColor,
                      ),
                    ),
                    SizedBox(width: isNarrow ? 8 : 10),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: effectiveCompact ? 12 : 13,
                          ),
                        ),
                        if (!effectiveCompact || height >= 48)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: effectiveCompact ? 10 : 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 6 : 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ctaLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isNarrow ? 10 : 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
