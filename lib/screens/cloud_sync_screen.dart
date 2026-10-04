import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
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
                          _buildConnectionHeader(syncState, syncNotifier, theme, l10n),
                          const SizedBox(height: 24),
                          if (syncState.signedIn) ...[
                            _buildBackupActionsCard(syncState, syncNotifier, theme, l10n),
                            const SizedBox(height: 24),
                            if (syncState.storageType != CloudSyncStorageType.firestore) ...[
                              _buildBackupsListHeader(theme, l10n),
                              const SizedBox(height: 12),
                              if (syncState.backups.isEmpty)
                                _buildEmptyBackupsPlaceholder(theme, l10n)
                              else
                                _buildBackupsList(syncState, syncNotifier, theme, l10n),
                            ] else ...[
                              _buildFirestoreSyncInfoCard(theme, l10n),
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
                      ? 'Sincronización multiplataforma (Web y Móvil) mediante Cloud Firestore. Optimizado para el plan gratuito Spark (ingredientes integrados y consultas diferenciales).'
                      : 'Cross-platform sync between Web and Mobile via Cloud Firestore. Optimized for Firebase Spark plan (embedded ingredients & differential queries).',
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
    final isFirestore = state.storageType == CloudSyncStorageType.firestore;

    IconData headerIcon;
    if (isFirestore) {
      headerIcon = state.signedIn ? Icons.cloud_sync : Icons.cloud_off_outlined;
    } else if (isLocal) {
      headerIcon = Icons.folder_shared_outlined;
    } else {
      headerIcon = state.signedIn ? Icons.cloud_done_outlined : Icons.backup_outlined;
    }

    String headerTitle;
    if (isFirestore) {
      headerTitle = state.signedIn
          ? (l10n.localeName == 'es' ? 'Conectado a Firestore' : 'Connected to Firestore')
          : (l10n.localeName == 'es' ? 'Firestore no conectado' : 'Firestore Not Connected');
    } else if (isLocal) {
      headerTitle = l10n.cloud_sync_sandbox_badge;
    } else {
      headerTitle = state.signedIn ? l10n.cloud_sync_connected : l10n.cloud_sync_disconnected;
    }

    String headerDesc;
    if (isFirestore) {
      headerDesc = l10n.localeName == 'es'
          ? 'Sincronización manual bajo demanda con resolución de conflictos último-en-escribir (LWW). Los cambios locales recientes se conservan.'
          : 'Manual on-demand sync with Last-Write-Wins (LWW) conflict resolution. Recent local edits are never wiped.';
    } else if (isLocal) {
      headerDesc = l10n.cloud_sync_sandbox_desc;
    } else {
      headerDesc = l10n.cloud_sync_desc;
    }

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
                  if (isFirestore) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.localeName == 'es' ? 'Copiar ID' : 'Copy Sync ID',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.email ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.localeName == 'es'
                                ? 'ID copiado al portapapeles'
                                : 'Sync ID copied to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
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
                if (isFirestore)
                  Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showEmailAuthDialog(context, notifier, l10n),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.email_outlined),
                            label: Text(
                              l10n.localeName == 'es' ? 'Acceder con Email' : 'Sign in with Email',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => notifier.signInWithGoogle(),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: Text(
                              l10n.localeName == 'es' ? 'Continuar con Google' : 'Continue with Google',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => notifier.signIn(),
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: Text(
                              l10n.localeName == 'es' ? 'Entrar como Invitado' : 'Continue as Guest',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showSetSyncIdDialog(context, notifier, l10n),
                            icon: const Icon(Icons.pin_outlined, size: 18),
                            label: Text(
                              l10n.localeName == 'es' ? 'Ingresar Sync ID' : 'Set Sync ID',
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
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
                      ),
                    ],
                  )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (isFirestore)
                      OutlinedButton.icon(
                        onPressed: () => _showSetSyncIdDialog(context, notifier, l10n),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.sync_alt),
                        label: Text(l10n.localeName == 'es' ? 'Cambiar Sync ID' : 'Change Sync ID'),
                      )
                    else
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
                ? (l10n.localeName == 'es' ? 'Sincronizar ahora (Bidireccional)' : 'Sync Now (Two-Way)')
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

  Widget _buildFirestoreSyncInfoCard(ThemeData theme, AppLocalizations l10n) {
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.localeName == 'es'
                      ? 'Arquitectura Spark Plan (Sin cargos)'
                      : 'Spark Plan Architecture (Zero-cost)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSyncFeatureRow(
              theme,
              icon: Icons.filter_alt_outlined,
              title: l10n.localeName == 'es' ? 'Consultas Diferenciales' : 'Differential Queries',
              description: l10n.localeName == 'es'
                  ? 'Solo se consultan y transfieren los registros editados después de la última sincronización.'
                  : 'Only records edited after the last sync are queried and transferred.',
            ),
            const SizedBox(height: 10),
            _buildSyncFeatureRow(
              theme,
              icon: Icons.layers_outlined,
              title: l10n.localeName == 'es' ? 'Ingredientes Integrados' : 'Embedded Ingredients',
              description: l10n.localeName == 'es'
                  ? 'Los ingredientes y pasos se integran dentro de cada receta para consumir 1 sola operación por receta.'
                  : 'Ingredients and steps are embedded directly in each recipe document to consume only 1 doc read/write.',
            ),
            const SizedBox(height: 10),
            _buildSyncFeatureRow(
              theme,
              icon: Icons.rule_outlined,
              title: l10n.localeName == 'es' ? 'Resolución LWW No Destructiva' : 'Non-Destructive LWW',
              description: l10n.localeName == 'es'
                  ? 'Gana la última edición (updated_at). Las recetas y modificaciones locales más recientes nunca se borran.'
                  : 'Last-write-wins based on updated_at. Newer local edits and un-synced recipes are never overwritten.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncFeatureRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
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

  void _showEmailAuthDialog(
    BuildContext context,
    CloudSyncNotifier notifier,
    AppLocalizations l10n,
  ) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isRegister = false;
    bool obscurePassword = true;
    String? localError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isEs = l10n.localeName == 'es';
          return AlertDialog(
            title: Text(
              isRegister
                  ? (isEs ? 'Crear cuenta' : 'Create Account')
                  : (isEs ? 'Iniciar sesión con Email' : 'Sign in with Email'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(isEs ? 'Iniciar sesión' : 'Sign In'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(isEs ? 'Registrarse' : 'Register'),
                      ),
                    ],
                    selected: {isRegister},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setDialogState(() {
                        isRegister = newSelection.first;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isEs ? 'Correo electrónico' : 'Email address',
                      hintText: 'ejemplo@correo.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: isEs ? 'Contraseña' : 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (!isRegister) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() {
                              localError = isEs
                                  ? 'Ingresa tu correo para restablecer la contraseña.'
                                  : 'Enter your email to reset your password.';
                            });
                            return;
                          }
                          Navigator.of(context).pop();
                          notifier.sendPasswordReset(email);
                        },
                        child: Text(
                          isEs ? '¿Olvidaste tu contraseña?' : 'Forgot password?',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.discard_button),
              ),
              ElevatedButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  final password = passwordController.text;

                  if (email.isEmpty || !email.contains('@')) {
                    setDialogState(() {
                      localError = isEs
                          ? 'Por favor ingresa un correo electrónico válido.'
                          : 'Please enter a valid email address.';
                    });
                    return;
                  }

                  if (password.length < 6) {
                    setDialogState(() {
                      localError = isEs
                          ? 'La contraseña debe tener al menos 6 caracteres.'
                          : 'Password must be at least 6 characters.';
                    });
                    return;
                  }

                  Navigator.of(context).pop();
                  notifier.signInWithEmail(
                    email: email,
                    password: password,
                    isRegister: isRegister,
                  );
                },
                child: Text(
                  isRegister
                      ? (isEs ? 'Crear cuenta' : 'Create Account')
                      : (isEs ? 'Ingresar' : 'Sign In'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSetSyncIdDialog(BuildContext context, CloudSyncNotifier notifier, AppLocalizations l10n) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localeName == 'es' ? 'ID de Sincronización' : 'Sync ID / Pairing Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.localeName == 'es'
                  ? 'Ingresa el mismo ID de sincronización en tu navegador Web y en tu teléfono móvil para vincular ambas instancias.'
                  : 'Enter the same Sync ID on your Web browser and mobile phone to pair both devices.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.localeName == 'es' ? 'ID de sincronización' : 'Sync ID',
                hintText: 'e.g. my-kitchen-sync-123',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.discard_button),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                notifier.setCustomFirestoreUserId(text);
              }
              Navigator.of(context).pop();
            },
            child: Text(l10n.save_button),
          ),
        ],
      ),
    );
  }
}
