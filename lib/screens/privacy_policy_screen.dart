import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_logo.dart';
import '../services/url_launcher_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final sections = [
      (
        Icons.storage_rounded,
        l10n.settings_about_privacy_storage_title,
        l10n.settings_about_privacy_storage_desc,
        Colors.amber.shade800,
      ),
      (
        Icons.cloud_sync_outlined,
        l10n.settings_about_privacy_sync_title,
        l10n.settings_about_privacy_sync_desc,
        Colors.blue.shade700,
      ),
      (
        Icons.verified_user_outlined,
        l10n.settings_about_privacy_ownership_title,
        l10n.settings_about_privacy_ownership_desc,
        Colors.green.shade700,
      ),
      (
        Icons.no_accounts_outlined,
        l10n.settings_about_privacy_ads_title,
        l10n.settings_about_privacy_ads_desc,
        Colors.deepOrange.shade700,
      ),
      (
        Icons.notifications_active_outlined,
        l10n.settings_about_privacy_permissions_title,
        l10n.settings_about_privacy_permissions_desc,
        Colors.purple.shade700,
      ),
    ];

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushReplacementNamed('/');
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_about_privacy_terms),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/');
                },
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const AppIcon(size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chef&Cost',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Google Play Store Compliance • Package: com.chefandcost.app',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Policy Sections
              ...sections.map(
                (sec) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: sec.$4.withValues(alpha: 0.15),
                          child: Icon(sec.$1, size: 22, color: sec.$4),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sec.$2,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sec.$3,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Account Deletion Portal Card
              Card(
                elevation: 0,
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.settings_about_privacy_delete_portal,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have full control over your data. You can delete your account and all associated cloud backups directly from the app or via our web portal.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(l10n.settings_about_privacy_delete_portal),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/delete-account');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Contact Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settings_about_developer,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'kbradevp@gmail.com',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Email'),
                        onPressed: () {
                          UrlLauncherService.openUrl(
                            'mailto:kbradevp@gmail.com?subject=Chef%26Cost%20Privacy%20Inquiry',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
