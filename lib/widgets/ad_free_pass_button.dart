import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../provider/ad_provider.dart';
import '../services/ad_service.dart';
import '../utils/ui_utils.dart';

/// Compact ad-block icon button placed on the left of the App Bar.
///
/// Only renders an icon without text countdown.
/// When ads are active, displays an ad-block icon ([Icons.block_rounded])
/// that triggers the 8-hour rewarded pass when tapped.
/// When 8h ad-free pass is active, displays an active shield icon
/// and provides the remaining time in tooltip and onTap.
class AdFreePassButton extends ConsumerWidget {
  const AdFreePassButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide completely on Web, desktop, or Flutter test runners
    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final adState = ref.watch(adProvider);

    // Hide completely when the user is an active Cloud Sync subscriber
    if (adState.isSubscribed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!adState.isAdFree) {
      // Ads active: show ad block icon button to watch rewarded ad
      return Tooltip(
        message: l10n.ad_free_pass_watch_prompt,
        child: IconButton(
          icon: adState.isLoadingRewardedAd
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.block_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
          tooltip: l10n.ad_free_pass_watch_prompt,
          onPressed: adState.isLoadingRewardedAd
              ? null
              : () async {
                  await ref.read(adProvider.notifier).watchRewardedAdFor8Hours(
                    onSuccess: () {
                      if (context.mounted) {
                        AppSnackBar.showSuccess(
                          context,
                          l10n.ad_free_pass_unlocked_snackbar,
                        );
                      }
                    },
                    onError: () {
                      if (context.mounted) {
                        AppSnackBar.showError(
                          context,
                          l10n.ad_free_pass_error_snackbar,
                        );
                      }
                    },
                  );
                },
        ),
      );
    }

    // Unlocked / 8h active: icon-only status without countdown text
    final remaining = adState.remainingAdFreeTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final formattedTime = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes}m';
    final activeTooltip = l10n.ad_free_pass_active(formattedTime);

    return Tooltip(
      message: activeTooltip,
      child: IconButton(
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.shield_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const Icon(
              Icons.check_rounded,
              size: 13,
              color: Colors.white,
            ),
          ],
        ),
        tooltip: activeTooltip,
        onPressed: () {
          AppSnackBar.show(context, activeTooltip);
        },
      ),
    );
  }
}
