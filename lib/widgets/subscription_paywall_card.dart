import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../provider/cloud_sync_provider.dart';
import '../provider/monetization_provider.dart';
import 'gooey_toast.dart';

class SubscriptionPaywallCard extends ConsumerWidget {
  final bool isCompact;
  final VoidCallback? onSubscribed;

  const SubscriptionPaywallCard({
    super.key,
    this.isCompact = false,
    this.onSubscribed,
  });

  static Future<void> showPaywallDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SubscriptionPaywallCard(
                  onSubscribed: () {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      AppLocalizations.of(ctx)?.close_button ?? 'Close',
                      softWrap: true,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final monetization = ref.watch(monetizationProvider);
    final cloudState = ref.watch(cloudSyncProvider);
    final notifier = ref.read(monetizationProvider.notifier);

    final bool isSubscribed =
        monetization.canUseCloudSync || cloudState.isSubscribed;
    final String? activePlan =
        monetization.activePlanId ?? cloudState.subscriptionPlan;
    final bool isAnnual =
        activePlan != null && activePlan.toLowerCase().contains('annual');
    final bool isLifetime = activePlan != null &&
        (activePlan.toLowerCase().contains('lifetime') ||
            activePlan.toLowerCase().contains('vip') ||
            activePlan.toLowerCase().contains('owner'));

    ref.listen<MonetizationState>(monetizationProvider, (previous, next) {
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        final msg = _resolveMessage(next.successMessage!, l10n);
        if (context.mounted) {
          GooeyToast.showSuccess(context, message: msg);
        }
        if (next.hasActiveSubscription) {
          onSubscribed?.call();
        }
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        final msg = _resolveMessage(next.errorMessage!, l10n);
        if (context.mounted) {
          GooeyToast.showError(context, message: msg);
        }
      }
    });

    if (isSubscribed) {
      return Card(
        key: const ValueKey('subscription_active_card'),
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            l10n.subscription_active_badge,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLifetime
                          ? l10n.subscription_active_plan_lifetime
                          : (isAnnual
                              ? l10n.subscription_active_plan_annual
                              : l10n.subscription_active_plan_monthly),
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      key: const ValueKey('subscription_paywall_card'),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.subscription_card_title,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.subscription_card_subtitle,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildBenefitRow(
              theme,
              Icons.cloud_done_rounded,
              l10n.subscription_benefit_cloud,
            ),
            const SizedBox(height: 8),
            _buildBenefitRow(
              theme,
              Icons.block_rounded,
              l10n.subscription_benefit_ad_free,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth >= 420;
                final monthlyBtn = _buildPlanButton(
                  context: context,
                  key: const ValueKey('subscribe_monthly_199_btn'),
                  theme: theme,
                  title: l10n.subscription_monthly_title,
                  priceLabel: l10n.subscription_monthly_price,
                  buttonLabel: l10n.subscription_monthly_btn,
                  isHighlighted: false,
                  isLoading: monetization.isLoadingPurchase,
                  onTap: () => notifier.buyMonthly(),
                );
                final annualBtn = _buildPlanButton(
                  context: context,
                  key: const ValueKey('subscribe_annual_1499_btn'),
                  theme: theme,
                  title: l10n.subscription_annual_title,
                  priceLabel: l10n.subscription_annual_price,
                  buttonLabel: l10n.subscription_annual_btn,
                  badgeText: l10n.subscription_annual_savings_badge,
                  isHighlighted: true,
                  isLoading: monetization.isLoadingPurchase,
                  onTap: () => notifier.buyAnnual(),
                );

                if (useRow) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: monthlyBtn),
                      const SizedBox(width: 12),
                      Expanded(child: annualBtn),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    annualBtn,
                    const SizedBox(height: 10),
                    monthlyBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                key: const ValueKey('restore_purchases_btn'),
                onPressed: monetization.isLoadingPurchase
                    ? null
                    : () => notifier.restorePurchases(),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text(
                  l10n.subscription_restore_btn,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanButton({
    required BuildContext context,
    required Key key,
    required ThemeData theme,
    required String title,
    required String priceLabel,
    required String buttonLabel,
    String? badgeText,
    required bool isHighlighted,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeText != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            softWrap: true,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            priceLabel,
            softWrap: true,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            key: key,
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isHighlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondaryContainer,
              foregroundColor: isHighlighted
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    buttonLabel,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _resolveMessage(String code, AppLocalizations l10n) {
    switch (code) {
      case 'subscription_activated_success':
        return l10n.subscription_activated_success;
      case 'subscription_restored_success':
        return l10n.subscription_restored_success;
      case 'subscription_restore_none_found':
        return l10n.subscription_restore_none_found;
      case 'subscription_purchase_canceled':
        return l10n.subscription_purchase_canceled;
      case 'subscription_store_unavailable':
        return l10n.subscription_store_unavailable;
      case 'ad_free_pass_unlocked_snackbar':
        return l10n.ad_free_pass_unlocked_snackbar;
      default:
        return code;
    }
  }
}
