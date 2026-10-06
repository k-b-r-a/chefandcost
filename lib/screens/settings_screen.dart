import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../provider/settings_provider.dart';
import '../provider/database_provider.dart';
import 'cloud_sync_screen.dart';
import '../provider/web_layout_provider.dart';
import '../database/sample_data.dart';
import '../widgets/app_logo.dart';

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
                          subtitle: l10n.localeName == 'es' ? 'Gestión de datos de la app' : 'App data management',
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
                          subtitle: l10n.localeName == 'es' ? 'Respaldar y restaurar en Google Drive' : 'Back up and restore on Google Drive',
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
                          subtitle: l10n.localeName == 'es' ? 'Temas, colores y tamaño de letra' : 'Themes, colors and font size',
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
                          subtitle: l10n.localeName == 'es' ? 'Idioma y formato numérico' : 'Language and number formatting',
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
                          subtitle: l10n.localeName == 'es' ? 'Versión e información' : 'Version and information',
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
              l10n.localeName == 'es' ? 'Cancelar' : 'Cancel',
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
                  SnackBar(content: Text(successText)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.settings_reset_db),
          ),
        ],
      ),
    );
  }

  void _showLoadSampleConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEs = l10n.localeName == 'es';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.science_outlined, size: 40, color: theme.colorScheme.primary),
        title: Text(isEs ? 'Cargar datos de ejemplo' : 'Load sample data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEs
                  ? 'Esta acción cargará ingredientes culinarios y recetas completas (con pasos, temporizadores y márgenes de ganancia) para probar la aplicación.'
                  : 'This will load culinary ingredients and full recipes (with steps, timers, and profit margins) to test the application.',
            ),
            const SizedBox(height: 16),
            Text(
              isEs
                  ? '¿Cómo deseas cargar los datos?'
                  : 'How would you like to load the data?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isEs ? 'Cancelar' : 'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeLoadSample(context, ref, clearFirst: false);
            },
            child: Text(isEs ? 'Añadir a los actuales' : 'Add to current'),
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
            child: Text(isEs ? 'Reemplazar todo' : 'Replace all'),
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
    final isEs = l10n.localeName == 'es';

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

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Datos de ejemplo cargados: ${result.recipesAdded} recetas y ${result.ingredientsAdded} ingredientes'
                : 'Sample data loaded: ${result.recipesAdded} recipes and ${result.ingredientsAdded} ingredients',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
                tooltip: l10n.localeName == 'es' ? 'Volver al Inicio' : 'Back to Home',
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.settings_haptic_feedback_desc,
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
                      l10n.localeName == 'es' ? 'Cargar datos de ejemplo' : 'Load sample data',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.localeName == 'es'
                          ? 'Carga ingredientes y recetas de prueba para evaluar la app'
                          : 'Load test ingredients and recipes to evaluate the app',
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
    switch (index) {
      case 0:
        if (style == 'rounded') return Icons.home_rounded;
        if (style == 'sharp') return Icons.home_sharp;
        return Icons.home_outlined;
      case 1:
        if (style == 'rounded') return Icons.inventory_2_rounded;
        if (style == 'sharp') return Icons.inventory_2_sharp;
        return Icons.inventory_2_outlined;
      case 2:
        if (style == 'rounded') return Icons.handyman_rounded;
        if (style == 'sharp') return Icons.handyman_sharp;
        return Icons.handyman_outlined;
      case 3:
        if (style == 'rounded') return Icons.settings_rounded;
        if (style == 'sharp') return Icons.settings_sharp;
        return Icons.settings_outlined;
      default:
        return Icons.star_outline;
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
                tooltip: l10n.localeName == 'es' ? 'Volver al Inicio' : 'Back to Home',
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
                        label: Text(l10n.settings_theme_system),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode),
                        label: Text(l10n.settings_theme_light),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode),
                        label: Text(l10n.settings_theme_dark),
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
                              l10n.localeName == 'es'
                                  ? 'El icono y la marca se adaptan al tema seleccionado'
                                  : 'The icon and branding adapt to your selected theme',
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
                    children: List.generate(4, (index) {
                      final label = index == 0
                          ? l10n.recipes_title
                          : index == 1
                              ? l10n.ingredients_title
                              : index == 2
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
              ],
            ),
          ],
        ),
      ),
    ),
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
                tooltip: l10n.localeName == 'es' ? 'Volver al Inicio' : 'Back to Home',
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
                tooltip: l10n.localeName == 'es' ? 'Volver al Inicio' : 'Back to Home',
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
                  '${l10n.settings_version} 1.0.0+1',
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
