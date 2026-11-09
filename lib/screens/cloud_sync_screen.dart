import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../provider/cloud_sync_provider.dart';
import '../services/url_launcher_service.dart';
import '../utils/cloud_sync_service.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../widgets/gooey_toast.dart';
import '../widgets/subscription_paywall_card.dart';

class CloudSyncScreen extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const CloudSyncScreen({super.key, this.onClose});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _hasCheckedTermsOnOpen = false;
  String? _localError;
  String? _localSuccess;

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDateTime(DateTime dt, String locale) {
    try {
      final format = DateFormat.yMMMd(locale).add_Hm();
      return format.format(dt);
    } catch (_) {
      final format = DateFormat.yMMMd('en').add_Hm();
      return format.format(dt);
    }
  }

  String _resolveMessage(String msg, AppLocalizations l10n) {
    switch (msg) {
      case 'error_sign_in_canceled':
        return l10n.cloud_sync_sign_in_canceled;
      case 'error_drive_permission_denied':
        return l10n.cloud_sync_error_drive_permission_denied;
      case 'error_network':
        return l10n.cloud_sync_error_network;
      case 'error_requires_recent_login':
        return l10n.cloud_sync_delete_account_reauth_required;
      case 'cloud_sync_delete_account_success':
        return l10n.cloud_sync_delete_account_success;
      case 'cloud_sync_delete_cloud_data_success':
        return l10n.cloud_sync_delete_cloud_data_success;
      case 'cloud_sync_delete_all_backups_success':
        return l10n.cloud_sync_delete_all_backups_success;
      case 'cloud_sync_terms_required_warning':
        return l10n.cloud_sync_terms_required_warning;
      case 'cloud_sync_subscription_required':
        return l10n.cloud_sync_subscription_required;
      default:
        return msg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final syncState = ref.watch(cloudSyncProvider);
    final syncNotifier = ref.read(cloudSyncProvider.notifier);

    // On first open, prompt acceptance if terms not accepted and user not signed in
    if (!_hasCheckedTermsOnOpen && !syncState.loading) {
      _hasCheckedTermsOnOpen = true;
      if (!syncState.hasAcceptedTerms && !syncState.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showTermsDialog(context, syncNotifier, theme, l10n);
          }
        });
      }
    }

    // Listen to changes in success/error messages to show SnackBar notifications
    ref.listen<CloudSyncState>(cloudSyncProvider, (previous, next) {
      if (!_hasCheckedTermsOnOpen && !next.loading) {
        _hasCheckedTermsOnOpen = true;
        if (!next.hasAcceptedTerms && !next.signedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showTermsDialog(context, syncNotifier, theme, l10n);
            }
          });
        }
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        final resolved = _resolveMessage(next.errorMessage!, l10n);
        GooeyToast.showError(context, message: resolved);
        if (next.errorMessage == 'cloud_sync_subscription_required' && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              SubscriptionPaywallCard.showPaywallDialog(context);
            }
          });
        }
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        final resolved = _resolveMessage(next.successMessage!, l10n);
        GooeyToast.showSuccess(context, message: resolved);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              buildFloatingPillAppBar(
                context: context,
                title: l10n.cloud_sync_title,
                controller: _scrollController,
                leading: widget.onClose != null
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: l10n.back_to_home_tooltip,
                        onPressed: widget.onClose,
                      )
                    : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSettingsCard(syncState, syncNotifier, theme, l10n),
                          const SizedBox(height: 16),
                          _buildTermsStatusCard(syncState, syncNotifier, theme, l10n),
                          if (syncState.storageType != CloudSyncStorageType.localDirectory) ...[
                            const SizedBox(height: 16),
                            const SubscriptionPaywallCard(),
                          ],
                          const SizedBox(height: 24),
                          if (syncState.storageType == CloudSyncStorageType.firestore) ...[
                            if (syncState.signedIn) ...[
                              _buildFirestoreConnectedCard(syncState, syncNotifier, theme, l10n),
                              const SizedBox(height: 24),
                              _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                            ] else ...[
                              _buildFirestoreAuthCard(syncState, syncNotifier, theme, l10n),
                            ],
                          ] else if (syncState.storageType == CloudSyncStorageType.googleDrive) ...[
                            _buildConnectionHeader(syncState, syncNotifier, theme, l10n),
                            const SizedBox(height: 24),
                            if (syncState.signedIn) ...[
                              _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                              const SizedBox(height: 24),
                              _buildBackupsListHeader(syncState, syncNotifier, theme, l10n),
                              const SizedBox(height: 12),
                              if (syncState.backups.isEmpty)
                                _buildEmptyBackupsPlaceholder(theme, l10n)
                              else
                                _buildBackupsList(syncState, syncNotifier, theme, l10n),
                            ],
                          ] else ...[
                            _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                            const SizedBox(height: 24),
                            _buildBackupsListHeader(syncState, syncNotifier, theme, l10n),
                            const SizedBox(height: 12),
                            if (syncState.backups.isEmpty)
                              _buildEmptyBackupsPlaceholder(theme, l10n)
                            else
                              _buildBackupsList(syncState, syncNotifier, theme, l10n),
                          ],
                          const SizedBox(height: 24),
                          _buildLocalBackupCard(syncNotifier, theme, l10n),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (syncState.isSyncing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            ),
          if (syncState.loading)
            Container(
              key: const ValueKey('cloud_sync_modal_barrier'),
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isGoogleDrive = state.storageType == CloudSyncStorageType.googleDrive;
    final isFirestore = state.storageType == CloudSyncStorageType.firestore;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cloud_sync_sync_target,
              softWrap: true,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CloudSyncStorageType>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              ),
              segments: [
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.firestore,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: Text(
                    l10n.cloud_sync_target_firestore,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.googleDrive,
                  icon: const Icon(Icons.cloud_outlined),
                  label: Text(
                    l10n.cloud_sync_target_drive,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                  enabled: !kIsWeb,
                ),
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.localDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    l10n.cloud_sync_target_local,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                  enabled: !kIsWeb,
                ),
              ],
              selected: {state.storageType},
              onSelectionChanged: (Set<CloudSyncStorageType> newSelection) {
                setState(() {
                  _localError = null;
                  _localSuccess = null;
                });
                notifier.setStorageType(newSelection.first);
              },
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.cloud_sync_desc_web,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isFirestore) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_sync_outlined, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.cloud_sync_desc_firestore,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!isGoogleDrive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.cloud_sync_desc_local,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTermsStatusCard(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (state.storageType == CloudSyncStorageType.localDirectory) {
      return const SizedBox.shrink();
    }

    final accepted = state.hasAcceptedTerms;

    if (accepted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 18, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.cloud_sync_terms_accepted_badge,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
              ),
            ),
            InkWell(
              onTap: () => _showTermsDialog(context, notifier, theme, l10n, viewOnly: true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  l10n.cloud_sync_terms_review_btn,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  softWrap: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.cloud_sync_terms_banner_unaccepted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showTermsDialog(context, notifier, theme, l10n),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.rule, size: 16),
              label: Text(
                l10n.cloud_sync_terms_review_btn,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showTermsDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n, {
    bool viewOnly = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: viewOnly,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.cloud_sync_terms_dialog_title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.cloud_sync_terms_dialog_subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTermsBullet(
                      theme,
                      Icons.cloud_sync_outlined,
                      l10n.cloud_sync_terms_firestore_title,
                      l10n.cloud_sync_terms_firestore_desc,
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet(
                      theme,
                      Icons.cloud_outlined,
                      l10n.cloud_sync_terms_drive_title,
                      l10n.cloud_sync_terms_drive_desc,
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet(
                      theme,
                      Icons.lock_outline,
                      l10n.cloud_sync_terms_privacy_title,
                      l10n.cloud_sync_terms_privacy_desc,
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet(
                      theme,
                      Icons.delete_outline,
                      l10n.cloud_sync_terms_control_title,
                      l10n.cloud_sync_terms_control_desc,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => UrlLauncherService.openPrivacyPolicy(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.language_outlined, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.cloud_sync_terms_view_privacy,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                softWrap: true,
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (viewOnly) ...[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.close_button, softWrap: true),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  l10n.cloud_sync_terms_decline_btn,
                  softWrap: true,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await notifier.acceptTerms();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  l10n.cloud_sync_terms_accept_btn,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTermsBullet(
    ThemeData theme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                softWrap: true,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _ensureTermsAccepted(
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) async {
    final accepted = await _showTermsDialog(context, notifier, theme, l10n);
    return accepted == true;
  }

  Widget _buildConnectionHeader(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final IconData headerIcon =
        state.signedIn ? Icons.cloud_done_outlined : Icons.backup_outlined;

    final String headerTitle =
        state.signedIn ? l10n.cloud_sync_connected : l10n.cloud_sync_disconnected;

    final String headerDesc = l10n.cloud_sync_desc;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
              child: Icon(
                headerIcon,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              headerTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (state.signedIn && state.email != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      state.email!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              headerDesc,
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!state.signedIn)
              ElevatedButton.icon(
                onPressed: () async {
                  if (!state.hasAcceptedTerms) {
                    final accepted = await _ensureTermsAccepted(notifier, theme, l10n);
                    if (!accepted) return;
                  }
                  notifier.signIn();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login),
                label: Text(
                  l10n.cloud_sync_connect_btn,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (!state.hasAcceptedTerms) {
                        final accepted = await _ensureTermsAccepted(notifier, theme, l10n);
                        if (!accepted) return;
                      }
                      notifier.signIn();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.switch_account),
                    label: Text(l10n.cloud_sync_switch_account, softWrap: true),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => notifier.signOut(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      l10n.cloud_sync_disconnect_btn,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDisconnectGoogle(context, notifier, l10n, theme),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.link_off),
                    label: Text(
                      l10n.cloud_sync_revoke_google_btn,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupActionsCard(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isFirestore = state.storageType == CloudSyncStorageType.firestore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: (state.loading || state.isSyncing) ? null : () => notifier.syncTwoWay(),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: state.isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(
            isFirestore
                ? l10n.cloud_sync_sync_now
                : l10n.cloud_sync_sync_btn,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (!isFirestore) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmBackup(context, notifier, l10n),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              l10n.cloud_sync_backup_btn,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _showForceOverwriteDialog(context, notifier, l10n),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          label: Text(
            l10n.force_overwrite_cloud_btn,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupsListHeader(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.cloud_sync_backups_header,
          softWrap: true,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => notifier.refreshBackups(),
              visualDensity: VisualDensity.compact,
            ),
            if (state.backups.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete_sweep_outlined, size: 20, color: theme.colorScheme.error),
                onPressed: () => _confirmDeleteAllBackups(context, notifier, l10n, theme),
                tooltip: l10n.cloud_sync_delete_all_backups_btn,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyBackupsPlaceholder(ThemeData theme, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.cloud_sync_no_backups,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsList(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.backups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final backup = state.backups[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  child: Icon(Icons.storage, color: theme.colorScheme.secondary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backup.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatBytes(backup.sizeBytes),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.circle,
                            size: 4,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDateTime(backup.dateCreated, l10n.localeName),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!kIsWeb)
                      IconButton(
                        icon: Icon(Icons.file_download_outlined, color: theme.colorScheme.secondary),
                        onPressed: () async {
                          final selectedDirectory = await FilePicker.platform.getDirectoryPath(
                            dialogTitle: l10n.cloud_sync_save_copy_dialog_title,
                          );
                          if (selectedDirectory != null) {
                            notifier.downloadBackup(backup.id, backup.name, selectedDirectory);
                          }
                        },
                        tooltip: l10n.cloud_sync_save_copy_tooltip,
                      ),
                    IconButton(
                      icon: Icon(Icons.sync, color: theme.colorScheme.secondary),
                      onPressed: () => _confirmSyncWithBackup(context, notifier, backup.id, l10n),
                      tooltip: l10n.cloud_sync_merge_tooltip,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore, color: theme.colorScheme.primary),
                      onPressed: () => _confirmRestore(context, notifier, backup.id, l10n),
                      tooltip: l10n.cloud_sync_restore_tooltip,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () => _confirmDelete(context, notifier, backup.id, l10n),
                      tooltip: l10n.cloud_sync_delete_tooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _showForceOverwriteDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
  ) {
    final challengeController = TextEditingController();
    bool understoodRisk = false;
    bool isMatch = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  understoodRisk ? Icons.lock_outline_rounded : Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    understoodRisk
                        ? l10n.force_overwrite_challenge_title
                        : l10n.force_overwrite_first_confirm_title,
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: understoodRisk
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.force_overwrite_first_confirm_desc,
                    softWrap: true,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
              secondChild: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.force_overwrite_challenge_desc,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('force_overwrite_challenge_input'),
                    controller: challengeController,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: l10n.force_overwrite_challenge_placeholder,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        isMatch = value == 'OVERWRITE';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  l10n.discard_button,
                  softWrap: true,
                ),
              ),
              if (!understoodRisk)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setModalState(() {
                      understoodRisk = true;
                    });
                  },
                  child: Text(
                    l10n.force_overwrite_understand_risk,
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              else
                ElevatedButton(
                  key: const ValueKey('force_overwrite_confirm_final_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: isMatch
                      ? () async {
                          Navigator.of(dialogContext).pop();
                          final success = await notifier.forceOverwriteCloud();
                          if (context.mounted) {
                            if (success) {
                              GooeyToast.showSuccess(
                                context,
                                message: l10n.force_overwrite_success_toast,
                              );
                            } else {
                              GooeyToast.showError(
                                context,
                                message: l10n.force_overwrite_failure_toast,
                              );
                            }
                          }
                        }
                      : null,
                  child: Text(
                    l10n.force_overwrite_confirm_final_btn,
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _confirmSyncWithBackup(
    BuildContext context,
    CloudSyncNotifier notifier,
    String backupId,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sync),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.cloud_sync_sync_confirm_title)),
          ],
        ),
        content: Text(l10n.cloud_sync_sync_with_backup_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.syncTwoWay(targetBackupId: backupId);
            },
            child: Text(l10n.cloud_sync_sync_btn),
          ),
        ],
      ),
    );
  }

  void _confirmBackup(BuildContext context, CloudSyncNotifier notifier, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_backup_confirm_title),
        content: Text(l10n.cloud_sync_backup_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.createBackup();
            },
            child: Text(l10n.save_button),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(
    BuildContext context,
    CloudSyncNotifier notifier,
    String backupId,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_restore_confirm_title),
        content: Text(l10n.cloud_sync_restore_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              notifier.restoreBackup(backupId);
            },
            child: Text(l10n.settings_reset_db_confirm),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CloudSyncNotifier notifier,
    String backupId,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_delete_confirm_title),
        content: Text(l10n.cloud_sync_delete_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              notifier.deleteBackup(backupId);
            },
            child: Text(l10n.delete_button),
          ),
        ],
      ),
    );
  }

  Widget _buildFirestoreAuthCard(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final hasError = _localError != null || (state.errorMessage != null && !state.signedIn);
    final errorText = _localError ?? state.errorMessage;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top branding / header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cloud_sync_connect_account_title,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.cloud_sync_connect_account_subtitle,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Google Sign-In Button
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: state.loading
                    ? null
                    : () async {
                        if (!state.hasAcceptedTerms) {
                          final accepted = await _ensureTermsAccepted(notifier, theme, l10n);
                          if (!accepted) return;
                        }
                        setState(() {
                          _localError = null;
                          _localSuccess = null;
                        });
                        notifier.signInWithGoogle();
                      },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleIcon(),
                    const SizedBox(width: 12),
                    Text(
                      l10n.cloud_sync_continue_google,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Text(
                    l10n.cloud_sync_or_email,
                    softWrap: true,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mode Toggle (Iniciar Sesión vs Registrarse)
            SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(
                    l10n.sign_in_button,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(
                    l10n.cloud_sync_create_account,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              selected: {_isRegisterMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _isRegisterMode = newSelection.first;
                  _localError = null;
                  _localSuccess = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Email Field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.cloud_sync_email_label,
                hintText: l10n.cloud_sync_email_hint,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                suffixIcon: _emailController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _emailController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (_) {
                if (_localError != null) setState(() => _localError = null);
              },
            ),
            const SizedBox(height: 12),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleEmailAuth(notifier, theme, l10n),
              decoration: InputDecoration(
                labelText: l10n.cloud_sync_password_label,
                hintText: l10n.cloud_sync_password_hint,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              onChanged: (_) {
                if (_localError != null) setState(() => _localError = null);
              },
            ),

            // Forgot Password (only in Sign In mode)
            if (!_isRegisterMode) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: state.loading ? null : () => _handleForgotPassword(notifier, l10n),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Text(
                    l10n.cloud_sync_forgot_password,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],

            // Local or Server Error Banner
            if (hasError && errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resolveMessage(errorText, l10n),
                        softWrap: true,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Local Success Banner
            if (_localSuccess != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _localSuccess!,
                        softWrap: true,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: state.loading ? null : () => _handleEmailAuth(notifier, theme, l10n),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: state.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isRegisterMode ? Icons.person_add_outlined : Icons.login,
                        size: 20,
                      ),
                label: Text(
                  _isRegisterMode
                      ? l10n.cloud_sync_create_account
                      : l10n.sign_in_button,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreConnectedCard(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final email = state.email ?? l10n.cloud_sync_authenticated_user;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    String? currentUid;
    try {
      if (Firebase.apps.isNotEmpty) {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      }
    } catch (_) {}

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.cloud_sync_connected_to_firestore,
                            softWrap: true,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (currentUid != null) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: currentUid!));
                            GooeyToast.showSuccess(
                              context,
                              message: l10n.cloud_sync_uid_copied,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'UID: $currentUid',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(
                    l10n.cloud_sync_disconnect_btn,
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => _showSignOutConfirmDialog(context, notifier, l10n),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.cloud_off_outlined, size: 18),
                  label: Text(
                    l10n.cloud_sync_delete_cloud_data_btn,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  onPressed: () => _showDeleteCloudDataConfirmDialog(context, notifier, l10n, theme),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: Text(
                    l10n.cloud_sync_delete_account_btn,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  onPressed: () => _showDeleteAccountConfirmDialog(context, notifier, l10n, theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDisconnectGoogle(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_revoke_google_btn, softWrap: true),
        content: Text(
          l10n.cloud_sync_sign_out_confirm_message,
          softWrap: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button, softWrap: true),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              notifier.disconnectGoogleAccount();
            },
            child: Text(l10n.cloud_sync_revoke_google_btn, softWrap: true),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllBackups(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_delete_all_backups_confirm_title, softWrap: true),
        content: Text(l10n.cloud_sync_delete_all_backups_confirm_desc, softWrap: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button, softWrap: true),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              notifier.deleteAllBackups();
            },
            child: Text(l10n.delete_button, softWrap: true),
          ),
        ],
      ),
    );
  }

  void _showDeleteCloudDataConfirmDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.cloud_sync_delete_cloud_data_confirm_title,
                softWrap: true,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.cloud_sync_delete_cloud_data_confirm_desc,
          softWrap: true,
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.discard_button, softWrap: true),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final success = await notifier.deleteFirestoreCloudData();
              if (context.mounted && success) {
                GooeyToast.showSuccess(
                  context,
                  message: l10n.cloud_sync_delete_cloud_data_success,
                );
              }
            },
            child: Text(l10n.delete_button, softWrap: true),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final passwordConfirmController = TextEditingController();
    bool obscureConfirmPassword = true;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPasswordProvider = currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.cloud_sync_delete_account_title,
                  softWrap: true,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cloud_sync_delete_account_confirm_desc,
                  softWrap: true,
                  style: theme.textTheme.bodyMedium,
                ),
                if (isPasswordProvider) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.cloud_sync_delete_account_password_prompt,
                    softWrap: true,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordConfirmController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: l10n.cloud_sync_password_hint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => UrlLauncherService.openDeleteAccount(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.settings_about_privacy_delete_portal,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.discard_button, softWrap: true),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () async {
                final password = isPasswordProvider ? passwordConfirmController.text.trim() : null;
                Navigator.of(dialogCtx).pop();
                final success = await notifier.deleteAccountAndCloudData(
                  password: (password != null && password.isNotEmpty) ? password : null,
                );
                if (context.mounted && success) {
                  GooeyToast.showSuccess(
                    context,
                    message: l10n.cloud_sync_delete_account_success,
                  );
                }
              },
              child: Text(l10n.cloud_sync_delete_account_confirm_btn, softWrap: true),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutConfirmDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloud_sync_sign_out_confirm_title, softWrap: true),
        content: Text(
          l10n.cloud_sync_sign_out_confirm_message,
          softWrap: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button, softWrap: true),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              notifier.signOut();
            },
            child: Text(l10n.cloud_sync_sign_out_confirm_title, softWrap: true),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmailAuth(
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) async {
    final syncState = ref.read(cloudSyncProvider);
    if (!syncState.hasAcceptedTerms) {
      final accepted = await _ensureTermsAccepted(notifier, theme, l10n);
      if (!accepted) return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localError = l10n.cloud_sync_error_invalid_email;
        _localSuccess = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _localError = l10n.cloud_sync_error_short_password;
        _localSuccess = null;
      });
      return;
    }

    setState(() {
      _localError = null;
      _localSuccess = null;
    });

    notifier.signInWithEmail(
      email: email,
      password: password,
      isRegister: _isRegisterMode,
    );
  }

  void _handleForgotPassword(CloudSyncNotifier notifier, AppLocalizations l10n) {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localError = l10n.cloud_sync_error_invalid_email;
        _localSuccess = null;
      });
      return;
    }

    setState(() {
      _localError = null;
      _localSuccess = l10n.cloud_sync_reset_email_sent;
    });

    notifier.sendPasswordReset(email);
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
            fontFamily: 'sans-serif',
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndLoadLocalBackup(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.cloud_sync_load_local_backup_btn,
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final fileName = file.name;

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.file_open_rounded, size: 36, color: Theme.of(ctx).colorScheme.primary),
          title: Text(l10n.cloud_sync_load_local_backup_confirm_title, softWrap: true),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cloud_sync_load_local_backup_confirm_desc(fileName),
                softWrap: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined, size: 18, color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$fileName (${_formatBytes(file.size)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.discard_button, softWrap: true),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              ),
              child: Text(l10n.cloud_sync_load_local_backup_btn, softWrap: true),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final success = await notifier.restoreFromLocalFile(
        filePath: file.path ?? '',
        fileBytes: file.bytes,
      );

      if (!context.mounted) return;

      if (success) {
        GooeyToast.showSuccess(
          context,
          message: l10n.cloud_sync_load_local_backup_success,
        );
      } else {
        GooeyToast.showError(
          context,
          message: l10n.cloud_sync_load_local_backup_invalid,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      GooeyToast.showError(
        context,
        message: l10n.error_prefix(e.toString()),
      );
    }
  }

  Future<void> _exportLocalBackup(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
  ) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.cloud_sync_save_copy_dialog_title,
      );
      if (selectedDirectory == null || !context.mounted) return;

      final success = await notifier.exportLocalBackup(selectedDirectory);
      if (!context.mounted) return;

      if (success) {
        GooeyToast.showSuccess(
          context,
          message: l10n.cloud_sync_export_local_backup_success,
        );
      } else {
        GooeyToast.showError(
          context,
          message: l10n.cloud_sync_save_copy_dialog_title,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      GooeyToast.showError(
        context,
        message: l10n.error_prefix(e.toString()),
      );
    }
  }

  Widget _buildLocalBackupCard(
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  child: Icon(Icons.storage_rounded, color: theme.colorScheme.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cloud_sync_local_backup_title,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.cloud_sync_local_backup_desc,
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _pickAndLoadLocalBackup(context, notifier, l10n),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(
                l10n.cloud_sync_load_local_backup_btn,
                softWrap: true,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _exportLocalBackup(context, notifier, l10n),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  l10n.cloud_sync_export_local_backup_btn,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
