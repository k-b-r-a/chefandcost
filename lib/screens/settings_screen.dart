import 'package:flutter/foundation.dart';
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
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db', 'bak'],
        withData: kIsWeb,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: const AppIcon(
                  size: 40,
                ),
                title: const Text(
                  'Chef&Cost',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(l10n.settings_about),
                trailing: Text(
                  '${l10n.settings_version} $kAppVersion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
