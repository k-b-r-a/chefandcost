import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'provider/database_provider.dart';

import 'screens/home_screen.dart';
import 'screens/recipe_editor_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/ingredients_screen.dart';
import 'screens/add_ingredient_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/kitchen_timers_screen.dart';
import 'screens/rule_of_three_screen.dart';
import 'screens/unit_converter_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/cloud_sync_screen.dart';
import 'provider/settings_provider.dart';
import 'provider/web_layout_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  await NotificationService().initialize();

  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const RecipetoolsApp(),
    ),
  );
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  final String physicsType;
  const CustomScrollBehavior(this.physicsType);

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (physicsType) {
      case 'bounce':
        return const BouncingScrollPhysics();
      case 'default':
      default:
        return super.getScrollPhysics(context);
    }
  }
}

class RecipetoolsApp extends ConsumerWidget {
  const RecipetoolsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    ThemeData buildTheme(Brightness brightness) {
      var colorScheme = ColorScheme.fromSeed(
        seedColor: settings.seedColor,
        brightness: brightness,
      );

      if (settings.highContrastText) {
        final isDark = brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        colorScheme = colorScheme.copyWith(
          onSurface: textColor,
          onSurfaceVariant: textColor,
          primary: isDark ? Colors.white : Colors.black,
          secondary: isDark ? Colors.white : Colors.black,
          onPrimary: isDark ? Colors.black : Colors.white,
          onSecondary: isDark ? Colors.black : Colors.white,
          onError: isDark ? Colors.black : Colors.white,
        );
      }

      final baseTheme = ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        fontFamily: settings.fontFamily == 'sans'
            ? 'Metropolis'
            : settings.fontFamily == 'butler'
                ? 'Butler'
                : null,
        pageTransitionsTheme: settings.animationsEnabled
            ? const PageTransitionsTheme()
            : const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: NoTransitionsBuilder(),
                  TargetPlatform.iOS: NoTransitionsBuilder(),
                  TargetPlatform.macOS: NoTransitionsBuilder(),
                  TargetPlatform.windows: NoTransitionsBuilder(),
                  TargetPlatform.linux: NoTransitionsBuilder(),
                  TargetPlatform.fuchsia: NoTransitionsBuilder(),
                },
              ),
      );

      var textTheme = baseTheme.textTheme;
      if (settings.fontFamily == 'sans') {
        textTheme = textTheme.apply(fontFamily: 'Metropolis');
      } else if (settings.fontFamily == 'butler') {
        textTheme = textTheme.apply(fontFamily: 'Butler');
      } else if (settings.fontFamily == 'serif') {
        textTheme = GoogleFonts.nunitoTextTheme(textTheme);
      } else if (settings.fontFamily == 'mono') {
        textTheme = GoogleFonts.inconsolataTextTheme(textTheme);
      } else if (settings.fontFamily == 'amatic') {
        textTheme = GoogleFonts.amaticScTextTheme(textTheme);
      } else if (settings.fontFamily == 'caveat') {
        textTheme = GoogleFonts.caveatTextTheme(textTheme);
      }

      if (settings.highContrastText) {
        final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
        textTheme = textTheme.apply(
          bodyColor: textColor,
          displayColor: textColor,
          decorationColor: textColor,
        );
      }

      return baseTheme.copyWith(
        textTheme: textTheme,
      );
    }

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.recipes_title,
      locale: settings.locale,
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      scrollBehavior: CustomScrollBehavior(settings.scrollBehavior),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(settings.fontSizeScale)),
          child: child!,
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final TextEditingController _webSearchController = TextEditingController();
  bool _isSearching = false;
  bool _showSearchContent = false;
  bool _isSearchHovered = false;
  bool _isAddHovered = false;

  late final List<Widget> _screens;

  void _navigateToTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _isSearching = false;
        _showSearchContent = false;
        ref.read(searchQueryProvider.notifier).setQuery('');
      });
      if (ref.read(settingsProvider).animationsEnabled) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(index);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateToTab: _navigateToTab),
      const RecipeListScreen(),
      const IngredientsScreen(),
      const ToolsScreen(),
      const SettingsScreen(),
    ];
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _webSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;
    final double middleWidth = screenWidth < 900
        ? 300.0
        : (screenWidth < 1200 ? 340.0 : 380.0);

    final pageView = PageView(
      controller: _pageController,
      physics: settings.animationsEnabled
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _isSearching = false;
          _showSearchContent = false;
          ref.read(searchQueryProvider.notifier).setQuery('');
        });
      },
      children: _screens,
    );

    if (isWide) {
      final webLayout = ref.watch(webLayoutProvider);
      final webNotifier = ref.read(webLayoutProvider.notifier);

      return Scaffold(
        body: Row(
          children: [
            _buildWebNavigationRail(
              context,
              settings,
              l10n,
              theme,
              webLayout,
              webNotifier,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: middleWidth,
              child: _buildWebMiddleColumn(
                context,
                settings,
                l10n,
                theme,
                webLayout,
                webNotifier,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _buildWebRightPane(
                context,
                settings,
                l10n,
                theme,
                webLayout,
                webNotifier,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: pageView,
      floatingActionButtonLocation: settings.leftHandedMode
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFab(context, settings, isWide: false),
      bottomNavigationBar: _buildFloatingNavBar(context, settings, l10n, theme),
    );
  }

  Widget _buildWebNavigationRail(
    BuildContext context,
    SettingsState settings,
    AppLocalizations l10n,
    ThemeData theme,
    WebLayoutState webLayout,
    WebLayoutNotifier webNotifier,
  ) {
    int selectedIndex = 0;
    if (webLayout.isHomeActive) {
      selectedIndex = 0;
    } else {
      switch (webLayout.middleTab) {
        case WebMiddleTab.recipes:
          selectedIndex = 1;
          break;
        case WebMiddleTab.ingredients:
          selectedIndex = 2;
          break;
        case WebMiddleTab.tools:
          selectedIndex = 3;
          break;
        case WebMiddleTab.settings:
          selectedIndex = 4;
          break;
      }
    }

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) async {
        if (index == 0 || index == 4) {
          final guard = ref.read(recipeCanLeaveGuardProvider);
          if (guard != null && !await guard()) return;
        }

        if (_webSearchController.text.isNotEmpty) {
          _webSearchController.clear();
          ref.read(searchQueryProvider.notifier).setQuery('');
        }
        switch (index) {
          case 0:
            webNotifier.showHome();
            break;
          case 1:
            webNotifier.setMiddleTab(WebMiddleTab.recipes);
            break;
          case 2:
            webNotifier.setMiddleTab(WebMiddleTab.ingredients);
            break;
          case 3:
            webNotifier.setMiddleTab(WebMiddleTab.tools);
            break;
          case 4:
            webNotifier.openSettingsDetail(WebRightPaneView.settingsGeneral);
            break;
        }
      },
      labelType: settings.showNavBarLabels
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      minWidth: 72,
      minExtendedWidth: 200,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final guard = ref.read(recipeCanLeaveGuardProvider);
            if (guard != null && !await guard()) return;
            webNotifier.showHome();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RecipeTools',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: IconButton(
              icon: Icon(
                settings.themeMode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : settings.themeMode == ThemeMode.light
                        ? Icons.light_mode_outlined
                        : Icons.brightness_auto_outlined,
              ),
              tooltip: 'Toggle Theme',
              onPressed: () {
                final nextMode = settings.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                ref.read(settingsProvider.notifier).setThemeMode(nextMode);
              },
            ),
          ),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: Icon(getNavBarIcon(0, false, settings.iconStyle)),
          selectedIcon: Icon(getNavBarIcon(0, true, settings.iconStyle)),
          label: Text(l10n.home_title),
        ),
        NavigationRailDestination(
          icon: Icon(getNavBarIcon(1, false, settings.iconStyle)),
          selectedIcon: Icon(getNavBarIcon(1, true, settings.iconStyle)),
          label: Text(l10n.recipes_title),
        ),
        NavigationRailDestination(
          icon: Icon(getNavBarIcon(2, false, settings.iconStyle)),
          selectedIcon: Icon(getNavBarIcon(2, true, settings.iconStyle)),
          label: Text(l10n.ingredients_title),
        ),
        NavigationRailDestination(
          icon: Icon(getNavBarIcon(3, false, settings.iconStyle)),
          selectedIcon: Icon(getNavBarIcon(3, true, settings.iconStyle)),
          label: Text(l10n.tools_title),
        ),
        NavigationRailDestination(
          icon: Icon(getNavBarIcon(4, false, settings.iconStyle)),
          selectedIcon: Icon(getNavBarIcon(4, true, settings.iconStyle)),
          label: Text(l10n.config_button),
        ),
      ],
    );
  }

  Widget _buildWebMiddleColumn(
    BuildContext context,
    SettingsState settings,
    AppLocalizations l10n,
    ThemeData theme,
    WebLayoutState webLayout,
    WebLayoutNotifier webNotifier,
  ) {
    if (webLayout.middleTab == WebMiddleTab.ingredients &&
        (webLayout.leftPaneIngredient != null || webLayout.isCreatingLeftPaneIngredient)) {
      return AddIngredientScreen(
        key: webLayout.leftPaneIngredient != null
            ? ValueKey('left_pane_ing_${webLayout.leftPaneIngredient!.ingredientPk}')
            : const ValueKey('left_pane_ing_new'),
        ingredient: webLayout.leftPaneIngredient,
        onClose: () => webNotifier.closeIngredientDetail(),
      );
    }

    Widget listWidget;
    switch (webLayout.middleTab) {
      case WebMiddleTab.recipes:
        listWidget = const RecipeListScreen(key: ValueKey('web_recipes_list'));
        break;
      case WebMiddleTab.ingredients:
        listWidget = const IngredientsScreen(key: ValueKey('web_ingredients_list'));
        break;
      case WebMiddleTab.tools:
        listWidget = const ToolsScreen(key: ValueKey('web_tools_list'));
        break;
      case WebMiddleTab.settings:
        listWidget = const SettingsScreen(key: ValueKey('web_settings_list'));
        break;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (webLayout.middleTab == WebMiddleTab.settings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.config_button,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 18),
                        tooltip: l10n.recipes_title,
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final guard = ref.read(recipeCanLeaveGuardProvider);
                          if (guard != null && !await guard()) return;
                          webNotifier.setMiddleTab(WebMiddleTab.recipes);
                        },
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          webLayout.middleTab == WebMiddleTab.recipes
                              ? Icons.menu_book_outlined
                              : (webLayout.middleTab == WebMiddleTab.ingredients
                                  ? Icons.egg_outlined
                                  : Icons.handyman_outlined),
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          webLayout.middleTab == WebMiddleTab.recipes
                              ? l10n.recipes_title
                              : (webLayout.middleTab == WebMiddleTab.ingredients
                                  ? l10n.ingredients_title
                                  : l10n.tools_title),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (webLayout.middleTab == WebMiddleTab.recipes) ...[
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: l10n.new_recipe_title,
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final guard = ref.read(recipeCanLeaveGuardProvider);
                            if (guard != null && !await guard()) return;
                            webNotifier.openNewRecipe();
                          },
                        ),
                      ] else if (webLayout.middleTab == WebMiddleTab.ingredients) ...[
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: l10n.new_ingredient_button,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            webNotifier.openNewIngredient();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (webLayout.middleTab != WebMiddleTab.tools) ...[
                  const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _webSearchController,
                    onChanged: (val) => ref.read(searchQueryProvider.notifier).setQuery(val),
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.localeName == 'es' ? 'Buscar en lista...' : 'Search list...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: _webSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _webSearchController.clear();
                                ref.read(searchQueryProvider.notifier).setQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        ),
        Expanded(
          child: listWidget,
        ),
      ],
    );
  }

  Widget _buildWebRightPane(
    BuildContext context,
    SettingsState settings,
    AppLocalizations l10n,
    ThemeData theme,
    WebLayoutState webLayout,
    WebLayoutNotifier webNotifier,
  ) {
    if (webLayout.selectedRecipeId != null ||
        webLayout.rightPaneView == WebRightPaneView.newRecipe) {
      if (webLayout.selectedRecipeId != null) {
        return RecipeEditorScreen(
          key: ValueKey('recipe_${webLayout.selectedRecipeId}'),
          recipeId: webLayout.selectedRecipeId,
          onClose: () => webNotifier.closeDetail(),
        );
      }
      return RecipeEditorScreen(
        key: const ValueKey('recipe_new'),
        onClose: () => webNotifier.closeDetail(),
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.ingredient ||
        webLayout.rightPaneView == WebRightPaneView.newIngredient) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            final double rightPanelWidth =
                (constraints.maxWidth * 0.42).clamp(340.0, 420.0);
            return Row(
              children: [
                Expanded(
                  child: HomeScreen(
                    onNavigateToTab: (index) {
                      if (index == 1) {
                        webNotifier.setMiddleTab(WebMiddleTab.recipes);
                      } else if (index == 2) {
                        webNotifier.setMiddleTab(WebMiddleTab.ingredients);
                      } else if (index == 3) {
                        webNotifier.setMiddleTab(WebMiddleTab.tools);
                      } else if (index == 4) {
                        webNotifier.openSettingsDetail(WebRightPaneView.settingsGeneral);
                      }
                    },
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
                SizedBox(
                  width: rightPanelWidth,
                  child: AddIngredientScreen(
                    key: webLayout.selectedIngredient != null
                        ? ValueKey('ingredient_${webLayout.selectedIngredient!.ingredientPk}')
                        : const ValueKey('ingredient_new'),
                    ingredient: webLayout.selectedIngredient,
                    onClose: () => webNotifier.closeIngredientDetail(),
                  ),
                ),
              ],
            );
          }

          return AddIngredientScreen(
            key: webLayout.selectedIngredient != null
                ? ValueKey('ingredient_${webLayout.selectedIngredient!.ingredientPk}')
                : const ValueKey('ingredient_new'),
            ingredient: webLayout.selectedIngredient,
            onClose: () => webNotifier.closeIngredientDetail(),
          );
        },
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.tool &&
        webLayout.selectedToolIndex != null) {
      Widget toolWidget;
      switch (webLayout.selectedToolIndex) {
        case 0:
          toolWidget = const KitchenTimersScreen();
          break;
        case 1:
          toolWidget = const RuleOfThreeScreen();
          break;
        case 2:
          toolWidget = const UnitConverterScreen();
          break;
        default:
          toolWidget = const HomeScreen();
      }
      return Stack(
        children: [
          toolWidget,
          Positioned(
            top: 14,
            left: 14,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.localeName == 'es' ? 'Volver al Inicio' : 'Back to Home',
              onPressed: () => webNotifier.showHome(),
            ),
          ),
        ],
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.settingsGeneral) {
      return SettingsGeneralScreen(
        key: const ValueKey('settings_general'),
        onClose: () => webNotifier.showHome(),
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.settingsCloudSync) {
      return CloudSyncScreen(
        key: const ValueKey('settings_cloud_sync'),
        onClose: () => webNotifier.showHome(),
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.settingsStyles) {
      return SettingsStylesScreen(
        key: const ValueKey('settings_styles'),
        onClose: () => webNotifier.showHome(),
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.settingsLocale) {
      return SettingsLocaleScreen(
        key: const ValueKey('settings_locale'),
        onClose: () => webNotifier.showHome(),
      );
    }

    if (webLayout.rightPaneView == WebRightPaneView.settingsAbout) {
      return SettingsAboutScreen(
        key: const ValueKey('settings_about'),
        onClose: () => webNotifier.showHome(),
      );
    }

    // Always Home by default!
    return HomeScreen(
      onNavigateToTab: (index) {
        if (index == 1) {
          webNotifier.setMiddleTab(WebMiddleTab.recipes);
        } else if (index == 2) {
          webNotifier.setMiddleTab(WebMiddleTab.ingredients);
        } else if (index == 3) {
          webNotifier.setMiddleTab(WebMiddleTab.tools);
        } else if (index == 4) {
          webNotifier.openSettingsDetail(WebRightPaneView.settingsGeneral);
        }
      },
    );
  }

  Widget _buildFloatingNavBar(
    BuildContext context,
    SettingsState settings,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final items = [
      (0, l10n.home_title),
      (1, l10n.recipes_title),
      (2, l10n.ingredients_title),
      (3, l10n.tools_title),
      (4, l10n.config_button),
    ];

    final double pillHeight = settings.showNavBarLabels ? 54.0 : 44.0;
    final animDuration = settings.animationsEnabled
        ? const Duration(milliseconds: 200)
        : Duration.zero;

    return SafeArea(
      top: false,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                height: pillHeight,
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    settings.fontSizeScale.clamp(0.85, 1.05),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / items.length;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Smooth sliding indicator pill
                        AnimatedAlign(
                          duration: animDuration,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment(
                            -1.0 + (_currentIndex * (2.0 / (items.length - 1))),
                            0,
                          ),
                          child: Container(
                            width: itemWidth - 6,
                            height: settings.showNavBarLabels ? 42 : 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Navigation item buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: items.map((item) {
                            final index = item.$1;
                            final label = item.$2;
                            final isSelected = _currentIndex == index;
                            final icon = getNavBarIcon(index, isSelected, settings.iconStyle);

                            return Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (_currentIndex != index) {
                                      setState(() {
                                        _currentIndex = index;
                                        _isSearching = false;
                                        _showSearchContent = false;
                                        ref.read(searchQueryProvider.notifier).setQuery('');
                                      });
                                      if (settings.animationsEnabled) {
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                        );
                                      } else {
                                        _pageController.jumpToPage(index);
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: settings.showNavBarLabels ? 4 : 7,
                                      horizontal: 2,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: isSelected ? 1.08 : 1.0,
                                          duration: animDuration,
                                          curve: Curves.easeOut,
                                          child: Icon(
                                            icon,
                                            size: 20,
                                            color: isSelected
                                                ? theme.colorScheme.onPrimaryContainer
                                                : theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (settings.showNavBarLabels) ...[
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: animDuration,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              letterSpacing: -0.3,
                                              color: isSelected
                                                  ? theme.colorScheme.onPrimaryContainer
                                                  : theme.colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            child: Text(label),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  Widget? _buildFab(BuildContext context, SettingsState settings, {bool isWide = false}) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isLeft = settings.leftHandedMode;

    // determine visibility based on current screen (Recipes: 1, Ingredients: 2)
    final bool showFab = _currentIndex == 1 || _currentIndex == 2;
    if (!showFab && isWide) return null;

    final anim400 = settings.animationsEnabled ? const Duration(milliseconds: 250) : Duration.zero;
    final anim300 = settings.animationsEnabled ? const Duration(milliseconds: 200) : Duration.zero;
    final anim200 = settings.animationsEnabled ? const Duration(milliseconds: 150) : Duration.zero;

    final double searchWidth = isWide ? 320.0 : screenWidth - 48;
    final double containerWidth = isWide
        ? (_isSearching ? 400.0 : 130.0)
        : screenWidth;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: anim400,
        curve: Curves.fastOutSlowIn,
        width: containerWidth,
        height: 120, // enough height for the "jump" animation
        padding: EdgeInsets.symmetric(horizontal: isWide ? 0 : 24.0),
        child: IgnorePointer(
          ignoring: !showFab,
          child: Stack(
            alignment: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
            children: [
              // search bar - expands horizontally from the left of add button
              AnimatedPositioned(
                duration: anim400,
                curve: Curves.fastOutSlowIn,
                right: isLeft ? null : (_isSearching ? 0 : 56 + 12),
                left: isLeft ? (_isSearching ? 0 : 56 + 12) : null,
                bottom: 0, // aligned at the same floor as the 56px add button
                child: AnimatedScale(
                  scale: showFab ? 1.0 : 0.0,
                  duration: anim300,
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: anim400,
                    curve: Curves.fastOutSlowIn,
                    width: _isSearching ? searchWidth : 40,
                    height: _isSearching ? 44 : 40,
                    decoration: BoxDecoration(
                      color: _isSearching
                          ? theme.colorScheme.surface.withValues(alpha: 0.65)
                          : (_isSearchHovered
                                ? Color.alphaBlend(
                                    theme.colorScheme.onSurface.withValues(
                                      alpha: 0.08,
                                    ),
                                    theme.colorScheme.secondaryContainer,
                                  )
                                : theme.colorScheme.secondaryContainer),
                      borderRadius: BorderRadius.circular(_isSearching ? 20 : 12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: _isSearching ? 0.4 : 0.1,
                        ),
                      ),
                      boxShadow: const [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_isSearching ? 20 : 12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _isSearching ? 8 : 0,
                          sigmaY: _isSearching ? 8 : 0,
                        ),
                        child: AnimatedSwitcher(
                          duration: anim200,
                          child: _isSearching
                              ? AnimatedOpacity(
                              duration: anim200,
                              opacity: _showSearchContent ? 1.0 : 0.0,
                              child: TextField(
                                  key: const ValueKey('search_field'),
                                  autofocus: true,
                                  onChanged: (value) {
                                    ref
                                        .read(searchQueryProvider.notifier)
                                        .setQuery(value);
                                  },
                                  style: theme.textTheme.bodyLarge,
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: l10n.search_hint,
                                    hintStyle: theme.textTheme.bodyLarge
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.only(
                                      left: 16,
                                      right: 8,
                                      bottom: 4,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 40,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 40,
                                    ),
                                    suffixIcon: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _isSearching = false;
                                          _showSearchContent = false;
                                          _isSearchHovered = false;
                                          ref
                                              .read(
                                                searchQueryProvider.notifier,
                                              )
                                              .setQuery('');
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              )
                            : InkWell(
                                key: const ValueKey('search_button'),
                                onTap: () {
                                  setState(() {
                                    _isSearching = true;
                                    _isSearchHovered = false;
                                  });
                                  Future.delayed(
                                    const Duration(milliseconds: 360),
                                    () {
                                      if (mounted && _isSearching) {
                                        setState(
                                          () => _showSearchContent = true,
                                        );
                                      }
                                    },
                                  );
                                },
                                onHover: (hovering) =>
                                    setState(() => _isSearchHovered = hovering),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: Icon(
                                    Icons.search,
                                    size: 20,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ),

            // add button - jumps up when searching, stays at the right/left
            AnimatedPositioned(
              duration: anim400,
              curve: Curves.fastOutSlowIn,
              right: isLeft ? null : 0,
              left: isLeft ? 0 : null,
              bottom: _isSearching ? 44 + 12 : 0, // moves up above search bar
              child: AnimatedScale(
                scale: showFab ? 1.0 : 0.0,
                duration: anim300,
                curve: Curves.easeInOut,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isAddHovered = true),
                  onExit: (_) => setState(() => _isAddHovered = false),
                  child: FloatingActionButton(
                    heroTag: _currentIndex == 2
                        ? 'add_ingredient_fab'
                        : 'add_recipe_fab',
                    elevation: 0,
                    hoverElevation: 0,
                    focusElevation: 0,
                    highlightElevation: 0,
                    backgroundColor: _isAddHovered
                        ? Color.alphaBlend(
                            theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            theme.colorScheme.secondaryContainer,
                          )
                        : theme.colorScheme.secondaryContainer,
                    onPressed: () {
                      if (_currentIndex == 1) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RecipeEditorScreen(),
                          ),
                        );
                      } else if (_currentIndex == 2) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddIngredientScreen(),
                          ),
                        );
                      }
                    },
                    child: Icon(
                      Icons.add,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}


IconData getNavBarIcon(int index, bool isSelected, String iconStyle) {
  if (isSelected) {
    switch (index) {
      case 0: return Icons.home;
      case 1: return Icons.menu_book;
      case 2: return Icons.inventory_2;
      case 3: return Icons.handyman;
      case 4: return Icons.settings;
    }
  }
  
  if (iconStyle == 'rounded') {
    switch (index) {
      case 0: return Icons.home_rounded;
      case 1: return Icons.menu_book_rounded;
      case 2: return Icons.inventory_2_rounded;
      case 3: return Icons.handyman_rounded;
      case 4: return Icons.settings_rounded;
    }
  } else if (iconStyle == 'sharp') {
    switch (index) {
      case 0: return Icons.home_sharp;
      case 1: return Icons.menu_book_sharp;
      case 2: return Icons.inventory_2_sharp;
      case 3: return Icons.handyman_sharp;
      case 4: return Icons.settings_sharp;
    }
  } else {
    // outlined
    switch (index) {
      case 0: return Icons.home_outlined;
      case 1: return Icons.menu_book_outlined;
      case 2: return Icons.inventory_2_outlined;
      case 3: return Icons.handyman_outlined;
      case 4: return Icons.settings_outlined;
    }
  }
  return Icons.home_outlined;
}
