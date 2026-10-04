import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../provider/cloud_sync_provider.dart';
import '../utils/cloud_sync_service.dart';
import '../widgets/floating_pill_app_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final syncState = ref.watch(cloudSyncProvider);
    final syncNotifier = ref.read(cloudSyncProvider.notifier);

    // Listen to changes in success/error messages to show SnackBar notifications
    ref.listen<CloudSyncState>(cloudSyncProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: theme.colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
                        tooltip: l10n.localeName == 'es'
                            ? 'Volver al Inicio'
                            : 'Back to Home',
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
                          const SizedBox(height: 24),
                          if (syncState.storageType == CloudSyncStorageType.firestore) ...[
                            if (syncState.signedIn) ...[
                              _buildFirestoreConnectedCard(syncState, syncNotifier, theme, l10n),
                              const SizedBox(height: 24),
                              _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                            ] else ...[
                              _buildFirestoreAuthCard(syncState, syncNotifier, theme, l10n),
                            ],
                          ] else ...[
                            _buildConnectionHeader(syncState, syncNotifier, theme, l10n),
                            const SizedBox(height: 24),
                            if (syncState.signedIn) ...[
                              _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                              const SizedBox(height: 24),
                              _buildBackupsListHeader(theme, l10n),
                              const SizedBox(height: 12),
                              if (syncState.backups.isEmpty)
                                _buildEmptyBackupsPlaceholder(theme, l10n)
                              else
                                _buildBackupsList(syncState, syncNotifier, theme, l10n),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (syncState.loading)
            Container(
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
              l10n.localeName == 'es' ? 'Destino de Sincronización' : 'Sync Target',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CloudSyncStorageType>(
              segments: [
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.firestore,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('Firestore'),
                ),
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.googleDrive,
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Google Drive'),
                  enabled: !kIsWeb,
                ),
                ButtonSegment<CloudSyncStorageType>(
                  value: CloudSyncStorageType.localDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.localeName == 'es' ? 'Directorio Local' : 'Local Directory'),
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
                        l10n.localeName == 'es'
                            ? 'En la Web, la sincronización se realiza mediante Cloud Firestore para sincronizar datos en tiempo real entre tu navegador y la aplicación móvil. Los respaldos en archivo de Google Drive están disponibles en dispositivos móviles y de escritorio.'
                            : 'On Web, sync is powered by Cloud Firestore to synchronize data in real-time between your browser and mobile app. Google Drive file backups are available on mobile and desktop devices.',
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.localeName == 'es'
                      ? 'Sincronización multiplataforma (Web y Móvil) en tiempo real mediante Cloud Firestore.'
                      : 'Real-time cross-platform sync between Web and Mobile via Cloud Firestore.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ] else if (!isGoogleDrive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.localeName == 'es'
                      ? 'El modo Directorio Local guarda tus respaldos en el almacenamiento local del dispositivo. No requiere conexión a Internet ni una cuenta de Google.'
                      : 'Local Directory mode stores your backups in the device\'s local storage. It does not require internet connection or a Google Account.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionHeader(
    CloudSyncState state,
    CloudSyncNotifier notifier,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isLocal = state.storageType == CloudSyncStorageType.localDirectory;

    final IconData headerIcon = isLocal
        ? Icons.folder_shared_outlined
        : (state.signedIn ? Icons.cloud_done_outlined : Icons.backup_outlined);

    final String headerTitle = isLocal
        ? l10n.cloud_sync_sandbox_badge
        : (state.signedIn ? l10n.cloud_sync_connected : l10n.cloud_sync_disconnected);

    final String headerDesc = isLocal
        ? l10n.cloud_sync_sandbox_desc
        : l10n.cloud_sync_desc;

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
            if (isLocal) ...[
              const SizedBox(height: 4),
              Text(
                l10n.localeName == 'es' ? 'Copia Local' : 'Local Backup',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (state.signedIn && state.email != null) ...[
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isLocal) ...[
              const SizedBox(height: 20),
              if (!state.signedIn)
                ElevatedButton.icon(
                  onPressed: () => notifier.signIn(),
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
                      onPressed: () => notifier.signIn(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.switch_account),
                      label: Text(l10n.localeName == 'es' ? 'Cambiar cuenta' : 'Switch account'),
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
                        l10n.localeName == 'es' ? 'Cerrar sesión' : 'Sign Out',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
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
    final isSim = state.storageType == CloudSyncStorageType.localDirectory;
    final isFirestore = state.storageType == CloudSyncStorageType.firestore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSim) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.developer_mode, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cloud_sync_sandbox_badge,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.cloud_sync_sandbox_desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: () => _confirmSync(context, notifier, l10n),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.sync),
          label: Text(
            isFirestore
                ? (l10n.localeName == 'es' ? 'Sincronizar ahora' : 'Sync Now')
                : l10n.cloud_sync_sync_btn,
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBackupsListHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.cloud_sync_backups_header,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => ref.read(cloudSyncProvider.notifier).refreshBackups(),
          visualDensity: VisualDensity.compact,
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
                            dialogTitle: l10n.localeName == 'es'
                                ? 'Seleccionar carpeta para guardar la copia'
                                : 'Select folder to save backup',
                          );
                          if (selectedDirectory != null) {
                            notifier.downloadBackup(backup.id, backup.name, selectedDirectory);
                          }
                        },
                        tooltip: l10n.localeName == 'es' ? 'Guardar copia en...' : 'Save backup to...',
                      ),
                    IconButton(
                      icon: Icon(Icons.sync, color: theme.colorScheme.secondary),
                      onPressed: () => _confirmSyncWithBackup(context, notifier, backup.id, l10n),
                      tooltip: l10n.cloud_sync_merge_tooltip,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore, color: theme.colorScheme.primary),
                      onPressed: () => _confirmRestore(context, notifier, backup.id, l10n),
                      tooltip: 'Restore',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () => _confirmDelete(context, notifier, backup.id, l10n),
                      tooltip: 'Delete',
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

  void _confirmSync(BuildContext context, CloudSyncNotifier notifier, AppLocalizations l10n) {
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
        content: Text(l10n.cloud_sync_sync_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.syncTwoWay();
            },
            child: Text(l10n.cloud_sync_sync_btn),
          ),
        ],
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
    final isEs = l10n.localeName == 'es';
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
                        isEs ? 'Conecta tu cuenta' : 'Connect Your Account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEs
                            ? 'Sincroniza tus recetas automáticamente entre Web y Móvil'
                            : 'Sync your recipes in real-time across Web and Mobile',
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
                    : () {
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
                      isEs ? 'Continuar con Google' : 'Continue with Google',
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
                    isEs ? 'o con correo electrónico' : 'or with email',
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
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(isEs ? 'Iniciar Sesión' : 'Sign In'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(isEs ? 'Crear Cuenta' : 'Create Account'),
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
                labelText: isEs ? 'Correo electrónico' : 'Email address',
                hintText: 'ejemplo@correo.com',
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
              onSubmitted: (_) => _handleEmailAuth(notifier, isEs),
              decoration: InputDecoration(
                labelText: isEs ? 'Contraseña' : 'Password',
                hintText: isEs ? 'Mínimo 6 caracteres' : 'At least 6 characters',
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
                  onPressed: state.loading ? null : () => _handleForgotPassword(notifier, isEs),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Text(
                    isEs ? '¿Olvidaste tu contraseña?' : 'Forgot password?',
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
                        errorText,
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
                onPressed: state.loading ? null : () => _handleEmailAuth(notifier, isEs),
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
                      ? (isEs ? 'Crear Cuenta' : 'Create Account')
                      : (isEs ? 'Iniciar Sesión' : 'Sign In'),
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
    final isEs = l10n.localeName == 'es';
    final email = state.email ?? (isEs ? 'Usuario autenticado' : 'Authenticated user');
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

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
        child: Row(
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
                        isEs ? 'Conectado a Firestore' : 'Connected to Firestore',
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                isEs ? 'Cerrar sesión' : 'Sign Out',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onPressed: () => _showSignOutConfirmDialog(context, notifier, l10n),
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
    final isEs = l10n.localeName == 'es';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEs ? 'Cerrar sesión' : 'Sign Out'),
        content: Text(
          isEs
              ? '¿Deseas desconectar tu cuenta de este dispositivo? Las recetas locales no se borrarán.'
              : 'Do you want to disconnect your account from this device? Local recipes will not be deleted.',
        ),
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
              notifier.signOut();
            },
            child: Text(isEs ? 'Cerrar sesión' : 'Sign Out'),
          ),
        ],
      ),
    );
  }

  void _handleEmailAuth(CloudSyncNotifier notifier, bool isEs) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localError = isEs
            ? 'Por favor ingresa un correo electrónico válido.'
            : 'Please enter a valid email address.';
        _localSuccess = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _localError = isEs
            ? 'La contraseña debe tener al menos 6 caracteres.'
            : 'Password must be at least 6 characters.';
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

  void _handleForgotPassword(CloudSyncNotifier notifier, bool isEs) {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localError = isEs
            ? 'Ingresa tu correo arriba para recibir el enlace de restablecimiento.'
            : 'Enter your email above to receive the password reset link.';
        _localSuccess = null;
      });
      return;
    }

    setState(() {
      _localError = null;
      _localSuccess = isEs
          ? 'Enlace enviado a $email. Revisa tu bandeja de entrada o spam.'
          : 'Reset link sent to $email. Check your inbox or spam.';
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
}
