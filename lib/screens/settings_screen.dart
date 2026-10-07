import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../provider/settings_provider.dart';
import '../provider/database_provider.dart';
import '../provider/cloud_sync_provider.dart';
import 'cloud_sync_screen.dart';
import '../provider/web_layout_provider.dart';
import '../database/sample_data.dart';
import '../widgets/app_logo.dart';
import '../constants.dart';
import '../utils/app_logger.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ScrollController scrollController = ScrollController();
    final settings = ref.watch(settingsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final webLayout = isWide ? ref.watch(webLayoutProvider) : null;

    return Scaffold(
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          buildFloatingPillAppBar(
            context: context,
            title: l10n.config_button,
            controller: scrollController,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          context,
                          ref: ref,
                          settings: settings,
                          title: l10n.settings_general,
                          subtitle: l10n.settings_category_data_subtitle,
                          icon: Icons.settings_applications_outlined,
                          iconColor: theme.colorScheme.primary,
                          bgColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          destination: const SettingsGeneralScreen(),
                          webView: WebRightPaneView.settingsGeneral,
                          isSelected: isWide && webLayout?.rightPaneView == WebRightPaneView.settingsGeneral,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildMenuTile(
                          context,
                          ref: ref,
                          settings: settings,
                          title: l10n.cloud_sync_title,
                          subtitle: l10n.settings_category_backup_subtitle,
                          icon: Icons.cloud_sync_outlined,
                          iconColor: Colors.orange,
                          bgColor: Colors.orange.withValues(alpha: 0.15),
                          destination: const CloudSyncScreen(),
                          webView: WebRightPaneView.settingsCloudSync,
                          isSelected: isWide && webLayout?.rightPaneView == WebRightPaneView.settingsCloudSync,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildMenuTile(
                          context,
                          ref: ref,
                          settings: settings,
                          title: l10n.settings_styles_title,
                          subtitle: l10n.settings_category_themes_subtitle,
                          icon: Icons.palette_outlined,
                          iconColor: Colors.deepPurple,
                          bgColor: Colors.deepPurple.withValues(alpha: 0.15),
                          destination: const SettingsStylesScreen(),
                          webView: WebRightPaneView.settingsStyles,
                          isSelected: isWide && webLayout?.rightPaneView == WebRightPaneView.settingsStyles,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildMenuTile(
                          context,
                          ref: ref,
                          settings: settings,
                          title: l10n.settings_locale_title,
                          subtitle: l10n.settings_category_locale_subtitle,
                          icon: Icons.translate,
                          iconColor: Colors.teal,
                          bgColor: Colors.teal.withValues(alpha: 0.15),
                          destination: const SettingsLocaleScreen(),
                          webView: WebRightPaneView.settingsLocale,
                          isSelected: isWide && webLayout?.rightPaneView == WebRightPaneView.settingsLocale,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildMenuTile(
                          context,
                          ref: ref,
                          settings: settings,
                          title: l10n.settings_about_app_title,
                          subtitle: l10n.settings_category_info_subtitle,
                          icon: Icons.info_outline,
                          iconColor: Colors.blue,
                          bgColor: Colors.blue.withValues(alpha: 0.15),
                          destination: const SettingsAboutScreen(),
                          webView: WebRightPaneView.settingsAbout,
                          isSelected: isWide && webLayout?.rightPaneView == WebRightPaneView.settingsAbout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required WidgetRef ref,
    required SettingsState settings,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Widget destination,
    WebRightPaneView? webView,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: bgColor,
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      onTap: () {
        if (settings.hapticFeedbackEnabled) {
          HapticFeedback.lightImpact();
        }
        final isWide = MediaQuery.sizeOf(context).width >= 640;
        if (isWide && webView != null) {
          ref.read(webLayoutProvider.notifier).openSettingsDetail(webView);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => destination),
          );
        }
      },
    );
  }
}

class SettingsGeneralScreen extends ConsumerWidget {
  final VoidCallback? onClose;
  const SettingsGeneralScreen({super.key, this.onClose});

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.read(settingsProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_reset_db_confirm),
        content: Text(l10n.settings_reset_db_warning),
        actions: [
          TextButton(
            onPressed: () {
              if (settings.hapticFeedbackEnabled) {
                HapticFeedback.lightImpact();
              }
              Navigator.pop(context);
            },
            child: Text(
              l10n.discard_button,
              softWrap: true,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final successText = l10n.settings_reset_db_success;
              Navigator.pop(context);
              try {
                if (settings.hapticFeedbackEnabled) {
                  HapticFeedback.heavyImpact();
                }
                final db = ref.read(databaseProvider);
                await db.resetDatabase();
                ref.invalidate(recipesStreamProvider);
                ref.invalidate(recipesWithFinancialsStreamProvider);
                ref.invalidate(ingredientsStreamProvider);
                ref.invalidate(unitsProvider);

                messenger.showSnackBar(
                  SnackBar(content: Text(successText, softWrap: true)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.error_prefix(e.toString()), softWrap: true)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.settings_reset_db, softWrap: true),
          ),
        ],
      ),
    );
  }

  void _showLoadSampleConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.science_outlined, size: 40, color: theme.colorScheme.primary),
        title: Text(l10n.load_sample_data, softWrap: true),
        content: Text(
          l10n.settings_sample_data_dialog_message,
          softWrap: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.discard_button,
              softWrap: true,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeLoadSample(context, ref, clearFirst: false);
            },
            child: Text(l10n.settings_sample_data_add_button, softWrap: true),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeLoadSample(context, ref, clearFirst: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text(l10n.settings_sample_data_replace_button, softWrap: true),
          ),
        ],
      ),
    );
  }

  Future<void> _executeLoadSample(
    BuildContext context,
    WidgetRef ref, {
    required bool clearFirst,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (settings.hapticFeedbackEnabled) {
        HapticFeedback.mediumImpact();
      }
      final db = ref.read(databaseProvider);
      final result = await loadSampleData(db, clearFirst: clearFirst);
      ref.invalidate(recipesStreamProvider);
      ref.invalidate(recipesWithFinancialsStreamProvider);
      ref.invalidate(ingredientsStreamProvider);
      ref.invalidate(unitsProvider);
      ref.invalidate(unitsStreamProvider);

      final snackbarMessage = clearFirst
          ? l10n.settings_sample_data_replaced_snackbar(
              result.recipesAdded,
              result.ingredientsAdded,
            )
          : l10n.sample_data_loaded_snackbar(
              result.recipesAdded,
              result.ingredientsAdded,
            );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            snackbarMessage,
            softWrap: true,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.error_prefix(e.toString()), softWrap: true)),
      );
    }
  }

  Future<void> _pickAndLoadLocalBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(cloudSyncProvider.notifier);

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.cloud_sync_load_local_backup_btn,
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
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
                        fileName,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.cloud_sync_load_local_backup_success
                : l10n.cloud_sync_load_local_backup_invalid,
            softWrap: true,
          ),
          backgroundColor: success
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.error_prefix(e.toString()), softWrap: true),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_general),
        centerTitle: true,
        leading: onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.back_to_home_tooltip,
                onPressed: onClose,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    secondary: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      child: Icon(Icons.vibration, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      l10n.settings_haptic_feedback,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.settings_haptic_feedback_desc,
                      softWrap: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (bool value) {
                      settingsNotifier.setHapticFeedbackEnabled(value);
                      if (value) {
                        HapticFeedback.mediumImpact();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      child: Icon(Icons.science_outlined, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      l10n.load_sample_data,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.settings_sample_data_subtitle,
                      softWrap: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      _showLoadSampleConfirmation(context, ref);
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                      child: Icon(Icons.file_open_outlined, color: theme.colorScheme.secondary),
                    ),
                    title: Text(
                      l10n.cloud_sync_load_local_backup_btn,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.cloud_sync_load_local_backup_desc,
                      softWrap: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      _pickAndLoadLocalBackup(context, ref);
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                      child: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                    ),
                    title: Text(
                      l10n.settings_reset_db,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.settings_reset_db_desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      _showResetConfirmation(context, ref);
                    },
                  ),
                ],
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

class SettingsStylesScreen extends ConsumerWidget {
  final VoidCallback? onClose;
  const SettingsStylesScreen({super.key, this.onClose});

  final List<Color> _accentColors = const [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.orange,
    Colors.red,
    Colors.pink,
  ];

  IconData _getPreviewIcon(int index, String style) {
    if (style == 'rounded') {
      switch (index) {
        case 0:
          return Icons.home_rounded;
        case 1:
          return Icons.menu_book_rounded;
        case 2:
          return Icons.inventory_2_rounded;
        case 3:
          return Icons.handyman_rounded;
        case 4:
          return Icons.settings_rounded;
        default:
          return Icons.star_rounded;
      }
    } else if (style == 'sharp') {
      switch (index) {
        case 0:
          return Icons.home_sharp;
        case 1:
          return Icons.menu_book_sharp;
        case 2:
          return Icons.inventory_2_sharp;
        case 3:
          return Icons.handyman_sharp;
        case 4:
          return Icons.settings_sharp;
        default:
          return Icons.star_sharp;
      }
    } else {
      switch (index) {
        case 0:
          return Icons.home_outlined;
        case 1:
          return Icons.menu_book_outlined;
        case 2:
          return Icons.inventory_2_outlined;
        case 3:
          return Icons.handyman_outlined;
        case 4:
          return Icons.settings_outlined;
        default:
          return Icons.star_outline;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Helper for haptic click
    void triggerHaptic() {
      if (settings.hapticFeedbackEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    // A helper method to build beautiful sections
    Widget buildSectionCard({
      required String title,
      required IconData icon,
      required List<Widget> children,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...children,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_styles_title),
        centerTitle: true,
        leading: onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.back_to_home_tooltip,
                onPressed: onClose,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
          children: [
            // 1. Theme & Color Palette
            buildSectionCard(
              title: l10n.settings_theme_title,
              icon: Icons.palette_outlined,
              children: [
                Text(
                  l10n.settings_theme_mode,
                  softWrap: true,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto),
                        label: Text(l10n.settings_theme_system, softWrap: true),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode),
                        label: Text(l10n.settings_theme_light, softWrap: true),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode),
                        label: Text(l10n.settings_theme_dark, softWrap: true),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) {
                      triggerHaptic();
                      settingsNotifier.setThemeMode(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.settings_theme_color,
                  softWrap: true,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _accentColors.map((color) {
                    final isSelected = settings.seedColor == color;
                    return SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: InkWell(
                          onTap: () {
                            triggerHaptic();
                            settingsNotifier.setSeedColor(color);
                          },
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: color,
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ChefAndCostText(fontSize: 16.5),
                            const SizedBox(height: 3),
                            Text(
                              l10n.settings_brand_theme_adapt_notice,
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
                ),
              ],
            ),

            // 2. Typography Settings
            buildSectionCard(
              title: l10n.settings_styles_font,
              icon: Icons.font_download_outlined,
              children: [
                Text(
                  l10n.settings_styles_font,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: ['system', 'sans', 'serif', 'mono', 'amatic', 'butler', 'caveat'].contains(settings.fontFamily)
                      ? settings.fontFamily
                      : 'system',
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(l10n.settings_styles_font_system),
                    ),
                    DropdownMenuItem(
                      value: 'sans',
                      child: Text(l10n.settings_styles_font_sans),
                    ),
                    DropdownMenuItem(
                      value: 'serif',
                      child: Text(l10n.settings_styles_font_serif),
                    ),
                    DropdownMenuItem(
                      value: 'mono',
                      child: Text(l10n.settings_styles_font_mono),
                    ),
                    DropdownMenuItem(
                      value: 'amatic',
                      child: Text(l10n.settings_styles_font_amatic),
                    ),
                    DropdownMenuItem(
                      value: 'butler',
                      child: Text(l10n.settings_styles_font_butler),
                    ),
                    DropdownMenuItem(
                      value: 'caveat',
                      child: Text(l10n.settings_styles_font_caveat),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      triggerHaptic();
                      settingsNotifier.setFontFamily(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.settings_font_size,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      settings.fontSizeScale == 0.85
                          ? l10n.settings_font_size_small
                          : settings.fontSizeScale == 1.0
                              ? l10n.settings_font_size_medium
                              : settings.fontSizeScale == 1.15
                                  ? l10n.settings_font_size_large
                                  : l10n.settings_font_size_xlarge,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.text_fields, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    Expanded(
                      child: Slider(
                        value: settings.fontSizeScale,
                        min: 0.85,
                        max: 1.3,
                        divisions: 3,
                        onChanged: (val) {
                          if (val != settings.fontSizeScale) {
                            triggerHaptic();
                          }
                          settingsNotifier.setFontSizeScale(val);
                        },
                      ),
                    ),
                    Icon(Icons.text_fields, size: 28, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.highContrastText,
                  title: Text(l10n.settings_styles_high_contrast, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settings_styles_high_contrast_desc),
                  onChanged: (val) {
                    triggerHaptic();
                    settingsNotifier.setHighContrastText(val);
                  },
                ),
              ],
            ),

            // 3. Icons & Visual Accents
            buildSectionCard(
              title: l10n.settings_styles_icon_style,
              icon: Icons.star_outline,
              children: [
                Text(
                  l10n.settings_styles_icon_style,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'outlined',
                        label: Text(l10n.settings_styles_icon_style_outlined),
                      ),
                      ButtonSegment(
                        value: 'rounded',
                        label: Text(l10n.settings_styles_icon_style_rounded),
                      ),
                      ButtonSegment(
                        value: 'sharp',
                        label: Text(l10n.settings_styles_icon_style_sharp),
                      ),
                    ],
                    selected: {settings.iconStyle},
                    onSelectionChanged: (selection) {
                      triggerHaptic();
                      settingsNotifier.setIconStyle(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final label = index == 0
                          ? l10n.home_title
                          : index == 1
                              ? l10n.recipes_title
                              : index == 2
                                  ? l10n.ingredients_title
                                  : index == 3
                                      ? l10n.tools_title
                                      : l10n.config_button;
                      return Column(
                        children: [
                          Icon(
                            _getPreviewIcon(index, settings.iconStyle),
                            size: 28,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.numberColorsEnabled,
                  title: Text(l10n.settings_styles_number_colors, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settings_styles_number_colors_desc),
                  onChanged: (val) {
                    triggerHaptic();
                    settingsNotifier.setNumberColorsEnabled(val);
                  },
                ),
              ],
            ),

            // 4. Navigation & Physics
            buildSectionCard(
              title: l10n.settings_styles_scroll,
              icon: Icons.swap_vert_outlined,
              children: [
                Text(
                  l10n.settings_styles_scroll,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'default',
                        label: Text(l10n.settings_styles_scroll_default),
                      ),
                      ButtonSegment(
                        value: 'bounce',
                        label: Text(l10n.settings_styles_scroll_bounce),
                      ),
                    ],
                    selected: {settings.scrollBehavior == 'bounce' ? 'bounce' : 'default'},
                    onSelectionChanged: (selection) {
                      triggerHaptic();
                      settingsNotifier.setScrollBehavior(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.animationsEnabled,
                  title: Text(l10n.settings_styles_animations, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settings_styles_animations_desc),
                  onChanged: (val) {
                    triggerHaptic();
                    settingsNotifier.setAnimationsEnabled(val);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.leftHandedMode,
                  title: Text(l10n.settings_styles_left_hand, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settings_styles_left_hand_desc),
                  onChanged: (val) {
                    triggerHaptic();
                    settingsNotifier.setLeftHandedMode(val);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.showNavBarLabels,
                  title: Text(l10n.settings_styles_show_nav_labels, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settings_styles_show_nav_labels_desc),
                  onChanged: (val) {
                    triggerHaptic();
                    settingsNotifier.setShowNavBarLabels(val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.settings_styles_navbar_size,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.settings_styles_navbar_size_desc,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'compact',
                        label: Text(l10n.settings_styles_navbar_size_compact),
                        icon: const Icon(Icons.density_small, size: 16),
                      ),
                      ButtonSegment(
                        value: 'normal',
                        label: Text(l10n.settings_styles_navbar_size_normal),
                        icon: const Icon(Icons.density_medium, size: 16),
                      ),
                      ButtonSegment(
                        value: 'large',
                        label: Text(l10n.settings_styles_navbar_size_large),
                        icon: const Icon(Icons.density_large, size: 16),
                      ),
                    ],
                    selected: {settings.navBarSize},
                    onSelectionChanged: (selection) {
                      triggerHaptic();
                      settingsNotifier.setNavBarSize(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildNavBarPreview(theme, settings, l10n),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildNavBarPreview(ThemeData theme, SettingsState settings, AppLocalizations l10n) {
    final double previewHeight;
    final double iconSize;
    final double fontSize;
    switch (settings.navBarSize) {
      case 'compact':
        previewHeight = settings.showNavBarLabels ? 46.0 : 38.0;
        iconSize = 16.0;
        fontSize = 9.0;
        break;
      case 'large':
        previewHeight = settings.showNavBarLabels ? 62.0 : 52.0;
        iconSize = 22.0;
        fontSize = 11.5;
        break;
      case 'normal':
      default:
        previewHeight = settings.showNavBarLabels ? 54.0 : 44.0;
        iconSize = 18.0;
        fontSize = 10.0;
        break;
    }

    final previewLabels = [
      l10n.home_title,
      l10n.recipes_title,
      l10n.ingredients_title,
      l10n.tools_title,
      l10n.config_button,
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: previewHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(previewLabels.length, (index) {
          final isSelected = index == 0;
          final iconData = _getPreviewIcon(index, settings.iconStyle);
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: isSelected
                  ? BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      size: iconSize,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    if (settings.showNavBarLabels) ...[
                      const SizedBox(height: 1),
                      Text(
                        previewLabels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SettingsLocaleScreen extends ConsumerWidget {
  final VoidCallback? onClose;
  const SettingsLocaleScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_locale_title),
        centerTitle: true,
        leading: onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.back_to_home_tooltip,
                onPressed: onClose,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settings_locale_lang,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'es',
                        label: Text(l10n.settings_locale_es),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(l10n.settings_locale_en),
                      ),
                    ],
                    selected: {settings.locale.languageCode},
                    onSelectionChanged: (selection) {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      settingsNotifier.setLocale(Locale(selection.first));
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),
                Text(
                  l10n.settings_format_decimals,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 1,
                        label: Text(l10n.settings_format_decimals_1),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text(l10n.settings_format_decimals_2),
                      ),
                    ],
                    selected: {settings.decimalDigits},
                    onSelectionChanged: (selection) {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      settingsNotifier.setDecimalDigits(selection.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),
                Text(
                  l10n.settings_format_mass_unit,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'g',
                        label: Text(l10n.settings_format_mass_g),
                      ),
                      ButtonSegment(
                        value: 'kg',
                        label: Text(l10n.settings_format_mass_kg),
                      ),
                    ],
                    selected: {settings.defaultMassUnit},
                    onSelectionChanged: (selection) {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      settingsNotifier.setDefaultMassUnit(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),
                Text(
                  l10n.settings_format_volume_unit,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'ml',
                        label: Text(l10n.settings_format_volume_ml),
                      ),
                      ButtonSegment(
                        value: 'l',
                        label: Text(l10n.settings_format_volume_l),
                      ),
                    ],
                    selected: {settings.defaultVolumeUnit},
                    onSelectionChanged: (selection) {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      settingsNotifier.setDefaultVolumeUnit(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),
                Text(
                  l10n.settings_format_currency,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: r'$',
                        label: Text(r'$'),
                      ),
                      ButtonSegment(
                        value: r'€',
                        label: Text(r'€'),
                      ),
                      ButtonSegment(
                        value: r'£',
                        label: Text(r'£'),
                      ),
                      ButtonSegment(
                        value: r'R$',
                        label: Text(r'R$'),
                      ),
                    ],
                    selected: {settings.currencySymbol},
                    onSelectionChanged: (selection) {
                      if (settings.hapticFeedbackEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      settingsNotifier.setCurrencySymbol(selection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}

class SettingsAboutScreen extends ConsumerWidget {
  final VoidCallback? onClose;
  const SettingsAboutScreen({super.key, this.onClose});

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, softWrap: true),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showChangelogDialog(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final changelog = isEs
        ? const [
            (
              '0.1.0-beta+7',
              'Octubre 2026',
              [
                'Corrección en selector de copia de seguridad local: eliminación de restricciones de extensiones para permitir seleccionar cualquier archivo SQLite.',
              ],
            ),
            (
              '0.1.0-beta+6',
              'Octubre 2026',
              [
                'Actualización oficial del correo de contacto y soporte del desarrollador (kbradevp@gmail.com).',
                'Optimizaciones de estabilidad y ajustes de despliegue en canal Beta.',
              ],
            ),
            (
              '0.1.0-beta+5',
              'Octubre 2026',
              [
                'Copia de seguridad local: exportación y carga de archivos SQLite desde el dispositivo.',
                'Nueva sección Acerca de con información del desarrollador, esquema DB y términos.',
                'Ajuste del tamaño de la barra de navegación y mejoras generales.',
              ],
            ),
            (
              '0.1.0-beta+4',
              'Octubre 2026',
              [
                'Sincronización en la nube con Firebase Firestore y Google Drive.',
                'Temporizadores de recetas con auto-dismiss y alarmas acústicas.',
                'Selector y buscador reactivo de ingredientes en recetas.',
                'Conversor de unidades optimizado sin ceros innecesarios.',
                'Regla de tres con soporte de decimales y unidades automáticas.',
                'Configuración del tamaño de la barra de navegación.',
                'Pantalla Acerca de con registro de cambios, privacidad, diagnóstico y licencias.',
              ],
            ),
            (
              '0.1.0-beta+3',
              'Septiembre 2026',
              [
                'Nueva barra de navegación inferior flotante adaptativa con indicador suave.',
                'Soporte completo de localización y accesibilidad en español e inglés.',
                'Ajustes de física de desplazamiento, transiciones y modo zurdo.',
              ],
            ),
            (
              '0.1.0-beta+2',
              'Agosto 2026',
              [
                'Métricas financieras por porción y receta.',
                'Reordenamiento interactivo de ingredientes en costos.',
                'Persistencia local con base de datos SQLite (Drift).',
              ],
            ),
            (
              '0.1.0-beta+1',
              'Julio 2026',
              [
                'Lanzamiento inicial de Chef&Cost.',
                'Gestión de recetas, ingredientes, conversión de medidas y herramientas.',
              ],
            ),
          ]
        : const [
            (
              '0.1.0-beta+7',
              'October 2026',
              [
                'Local backup picker fix: removed restrictive extension filters to allow selecting any SQLite backup file.',
              ],
            ),
            (
              '0.1.0-beta+6',
              'October 2026',
              [
                'Official developer support & contact email update (kbradevp@gmail.com).',
                'Beta channel deployment refinements and stability fixes.',
              ],
            ),
            (
              '0.1.0-beta+5',
              'October 2026',
              [
                'Local backup: import and export SQLite files directly to device storage.',
                'Revamped About screen with developer contact, DB schema version, and privacy terms.',
                'Navigation bar size preference and stability enhancements.',
              ],
            ),
            (
              '0.1.0-beta+4',
              'October 2026',
              [
                'Cloud synchronization with Firebase Firestore and Google Drive.',
                'Recipe cooking timers with auto-dismiss and audible alarms.',
                'Reactive ingredient picker and real-time query loading.',
                'Optimized unit converter without redundant zero padding.',
                'Rule of three with decimal point support and unit extraction.',
                'Navigation bar size preference in styles configuration.',
                'Revamped About screen with changelog, privacy terms, beta diagnostics, and licenses.',
              ],
            ),
            (
              '0.1.0-beta+3',
              'September 2026',
              [
                'Floating responsive bottom navigation bar with smooth indicator.',
                'Full localization and accessibility support.',
                'Motion physics, transition toggles, and left-handed layout mode.',
              ],
            ),
            (
              '0.1.0-beta+2',
              'August 2026',
              [
                'Advanced financial metrics (cost per portion and profit margins).',
                'Interactive reordering for recipe ingredient costs.',
                'Persistent offline-first database powered by SQLite / Drift.',
              ],
            ),
            (
              '0.1.0-beta+1',
              'July 2026',
              [
                'Initial release of Chef&Cost.',
                'Recipe costing, ingredient manager, units, and kitchen utilities.',
              ],
            ),
          ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.settings_about_changelog, softWrap: true),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: changelog.length,
              separatorBuilder: (_, index) => const Divider(height: 24),
              itemBuilder: (context, idx) {
                final entry = changelog[idx];
                final isCurrent = idx == 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'v${entry.$1}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? theme.colorScheme.primary : null,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          entry.$2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...entry.$3.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                point,
                                softWrap: true,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close_button),
          ),
        ],
      ),
    );
  }

  void _showPrivacyTermsDialog(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final terms = isEs
        ? const [
            (
              Icons.storage_rounded,
              'Almacenamiento Local Prioritario',
              'Tus ingredientes, recetas y costos se almacenan localmente en tu dispositivo mediante SQLite (Drift). Tus datos nunca salen de tu control sin tu consentimiento.',
            ),
            (
              Icons.cloud_sync_outlined,
              'Sincronización en la Nube Opcional',
              'La sincronización con Firebase y Google Drive es 100% opcional. Solo se activa si eliges iniciar sesión con tu cuenta.',
            ),
            (
              Icons.verified_user_outlined,
              'Propiedad Total de tus Datos',
              'Tus recetas y cálculos de rentabilidad son de tu exclusiva propiedad intelectual. Chef&Cost no comparte ni comercializa tu información.',
            ),
            (
              Icons.no_accounts_outlined,
              'Sin Rastreadores Publicitarios',
              'No utilizamos herramientas de rastreo publicitario de terceros ni vendemos datos personales.',
            ),
            (
              Icons.notifications_active_outlined,
              'Permisos del Sistema',
              'La aplicación únicamente solicita permisos de notificaciones y audio para avisarte cuando finaliza un temporizador de cocción.',
            ),
          ]
        : const [
            (
              Icons.storage_rounded,
              'Offline-First Local Storage',
              'Your ingredients, recipes, and cost data are stored securely on your device using SQLite (Drift). Your data stays strictly under your control.',
            ),
            (
              Icons.cloud_sync_outlined,
              'Opt-in Cloud Synchronization',
              'Synchronization with Firebase Firestore and Google Drive is 100% optional and only occurs if you explicitly log in.',
            ),
            (
              Icons.verified_user_outlined,
              'Full Data Ownership',
              'Your recipes and calculations belong exclusively to you. Chef&Cost does not claim ownership or distribute your culinary creations.',
            ),
            (
              Icons.no_accounts_outlined,
              'Zero Advertising Trackers',
              'We do not embed third-party advertising SDKs or monetize your personal culinary metrics.',
            ),
            (
              Icons.notifications_active_outlined,
              'System Permissions',
              'The application only requests notification and audio permissions to alert you when recipe cooking timers complete.',
            ),
          ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.settings_about_privacy_terms, softWrap: true),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: terms.length,
              separatorBuilder: (_, index) => const Divider(height: 20),
              itemBuilder: (context, idx) {
                final item = terms[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      child: Icon(item.$1, size: 18, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            softWrap: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close_button),
          ),
        ],
      ),
    );
  }

  void _showDebugLogsDialog(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    AppLogger.init();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final logs = AppLogger.logs;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.settings_about_debug_logs} (${logs.length})',
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: logs.isEmpty
                      ? Center(
                          child: Text(
                            l10n.settings_about_logs_empty,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: logs.length,
                            itemBuilder: (context, idx) {
                              final log = logs[idx];
                              Color levelColor;
                              switch (log.level) {
                                case LogLevel.error:
                                  levelColor = Colors.red;
                                  break;
                                case LogLevel.warn:
                                  levelColor = Colors.orange;
                                  break;
                                case LogLevel.debug:
                                  levelColor = Colors.purple;
                                  break;
                                case LogLevel.info:
                                  levelColor = Colors.green;
                                  break;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '[${log.formattedTime}] ',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '[${log.levelLabel}] ',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: levelColor,
                                        ),
                                      ),
                                      TextSpan(
                                        text: log.message,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Test Log'),
                  onPressed: () {
                    AppLogger.info('Manual test event triggered at ${DateTime.now()}');
                    setModalState(() {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    AppLogger.clear();
                    setModalState(() {});
                  },
                  child: Text(l10n.settings_about_logs_clear),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l10n.settings_about_logs_copy),
                  onPressed: () {
                    _copyToClipboard(
                      context,
                      AppLogger.exportText(),
                      l10n.settings_about_logs_copied,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final isBeta = kAppVersion.toLowerCase().contains('beta');

    Widget buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_about_app_title),
        centerTitle: true,
        leading: onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.back_to_home_tooltip,
                onPressed: onClose,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. App Header, Version & Database Schema
                buildCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    children: [
                      const AppIcon(size: 64),
                      const SizedBox(height: 12),
                      Text(
                        'Chef&Cost',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settings_about,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_outlined, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  'v$kAppVersion',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storage_rounded, size: 14, color: theme.colorScheme.secondary),
                                const SizedBox(width: 5),
                                Text(
                                  '${l10n.settings_about_db_schema} v${db.schemaVersion}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (isBeta ? Colors.orange : Colors.green).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isBeta ? Icons.science_outlined : Icons.check_circle_outline,
                                  size: 14,
                                  color: isBeta ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isBeta ? l10n.settings_about_channel_beta : l10n.settings_about_channel_stable,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isBeta ? Colors.orange.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Developer Card
                buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.code_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.settings_about_developer,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              'EZ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settings_about_developer_name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.settings_about_developer_role,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        l10n.settings_about_developer_email,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: l10n.settings_about_copy_email,
                            onPressed: () {
                              _copyToClipboard(
                                context,
                                l10n.settings_about_developer_email,
                                l10n.settings_about_email_copied,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Information, Changelog, Privacy & Licenses
                buildCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                          child: const Icon(Icons.history_rounded, color: Colors.amber),
                        ),
                        title: Text(
                          l10n.settings_about_changelog,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(l10n.settings_about_changelog_desc),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showChangelogDialog(context, theme, l10n),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withValues(alpha: 0.15),
                          child: const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
                        ),
                        title: Text(
                          l10n.settings_about_privacy_terms,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(l10n.settings_about_privacy_terms_desc),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPrivacyTermsDialog(context, theme, l10n),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.15),
                          child: const Icon(Icons.article_outlined, color: Colors.blue),
                        ),
                        title: Text(
                          l10n.settings_about_licenses,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(l10n.settings_about_licenses_desc),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showLicensePage(
                            context: context,
                            applicationName: 'Chef&Cost',
                            applicationVersion: kAppVersion,
                            applicationIcon: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: AppIcon(size: 48),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 4. Beta Debug & Diagnostics (Only displayed if beta app)
                if (isBeta)
                  buildCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withValues(alpha: 0.15),
                        child: const Icon(Icons.terminal_rounded, color: Colors.purple),
                      ),
                      title: Row(
                        children: [
                          Text(
                            l10n.settings_about_debug_logs,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BETA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(l10n.settings_about_debug_logs_desc),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDebugLogsDialog(context, theme, l10n),
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
