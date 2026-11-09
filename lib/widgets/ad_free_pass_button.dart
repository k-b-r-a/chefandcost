import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../provider/ad_provider.dart';
import '../provider/monetization_provider.dart';
import '../services/ad_service.dart';
import '../utils/ui_utils.dart';

/// Compact ad-block icon button placed on the left of the App Bar.
///
/// Only renders an icon without text countdown.
/// When ads are active, displays an ad-block icon ([Icons.block_rounded])
/// that opens the 8-hour rewarded pass popup ([AdFreePassDialog]) when tapped.
/// When 8h ad-free pass is active, displays an active shield icon
/// and opens the popup showing the live countdown and upgrade options.
class AdFreePassButton extends ConsumerWidget {
  const AdFreePassButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide completely on Web, desktop, or Flutter test runners
    if (!AdService.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final adState = ref.watch(adProvider);
    final monetization = ref.watch(monetizationProvider);

    // Hide completely when the user is an active Cloud Sync subscriber
    if (adState.isSubscribed || monetization.hasActiveSubscription) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!adState.isAdFree && !monetization.isAdFree) {
      // Ads active: show ad block icon button to open 8h rewarded ad popup
      return Tooltip(
        message: l10n.ad_free_pass_watch_prompt,
        child: IconButton(
          icon: (adState.isLoadingRewardedAd || monetization.isLoadingRewardedAd)
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
          onPressed: (adState.isLoadingRewardedAd ||
                  monetization.isLoadingRewardedAd)
              ? null
              : () => AdFreePassDialog.show(context),
        ),
      );
    }

    // Unlocked / 8h active: icon-only status without countdown text in the button
    final remaining = monetization.remainingAdFreeTime > Duration.zero
        ? monetization.remainingAdFreeTime
        : adState.remainingAdFreeTime;
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
        onPressed: () => AdFreePassDialog.show(context),
      ),
    );
  }
}

/// 8-Hour Rewarded Ad-Free Pass Popup Dialog.
class AdFreePassDialog extends ConsumerStatefulWidget {
  const AdFreePassDialog({super.key});

  static Future<void> show(BuildContext context) {
    AdService.preloadRewardedAd();
    return showDialog<void>(
      context: context,
      builder: (ctx) => const AdFreePassDialog(),
    );
  }

  @override
  ConsumerState<AdFreePassDialog> createState() => _AdFreePassDialogState();
}

class _AdFreePassDialogState extends ConsumerState<AdFreePassDialog> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    AdService.preloadRewardedAd();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final monetization = ref.watch(monetizationProvider);
    final adState = ref.watch(adProvider);
    final notifier = ref.read(monetizationProvider.notifier);

    final bool isSubscribed =
        monetization.hasActiveSubscription || adState.isSubscribed;
    final bool isPassActive =
        monetization.isRewardedPassActive || (!isSubscribed && adState.isAdFree);
    final Duration remaining = monetization.remainingAdFreeTime > Duration.zero
        ? monetization.remainingAdFreeTime
        : adState.remainingAdFreeTime;

    return AlertDialog(
      key: const ValueKey('ad_free_pass_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isPassActive
                ? Colors.green.withValues(alpha: 0.15)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Icon(
              isPassActive ? Icons.shield_rounded : Icons.block_rounded,
              color: isPassActive ? Colors.green.shade700 : theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPassActive
                  ? l10n.ad_free_popup_active_title
                  : l10n.ad_free_popup_title,
              softWrap: true,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isPassActive
                    ? l10n.ad_free_popup_active_subtitle
                    : l10n.ad_free_popup_description,
                softWrap: true,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (isPassActive) ...[
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('ad_free_pass_countdown_box'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.ad_free_popup_remaining_time(
                            _formatDuration(remaining),
                          ),
                          softWrap: true,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey('watch_rewarded_ad_8h_btn'),
                onPressed: monetization.isLoadingRewardedAd
                    ? null
                    : () async {
                        await notifier.watchRewardedAdFor8Hours(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: monetization.isLoadingRewardedAd
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: Text(
                  isPassActive
                      ? l10n.ad_free_popup_extend_btn
                      : l10n.ad_free_popup_watch_btn,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!isSubscribed) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Text(
                  l10n.ad_free_popup_upgrade_divider,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('popup_subscribe_monthly_btn'),
                      onPressed: monetization.isLoadingPurchase
                          ? null
                          : () async {
                              final ok = await notifier.buyMonthly();
                              if (ok && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.subscription_monthly_btn,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      key: const ValueKey('popup_subscribe_annual_btn'),
                      onPressed: monetization.isLoadingPurchase
                          ? null
                          : () async {
                              final ok = await notifier.buyAnnual();
                              if (ok && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.subscription_annual_btn,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close_button, softWrap: true),
        ),
      ],
    );
  }
}
