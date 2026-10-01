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
import 'screens/settings_screen.dart';
import 'provider/settings_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  await NotificationService().initialize();

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
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _isSearching = false;
            _showSearchContent = false;
            ref.read(searchQueryProvider.notifier).setQuery('');
          });
        },
        children: _screens,
      ),
      floatingActionButtonLocation: settings.leftHandedMode
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFab(context, settings),
      bottomNavigationBar: _buildFloatingNavBar(context, settings, l10n, theme),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: SizedBox(
          height: pillHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
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
                          duration: const Duration(milliseconds: 250),
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
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
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
                                          duration: const Duration(milliseconds: 200),
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
                                            duration: const Duration(milliseconds: 200),
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
  );
}

  Widget? _buildFab(BuildContext context, SettingsState settings) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isLeft = settings.leftHandedMode;

    // determine visibility based on current screen (Recipes: 1, Ingredients: 2)
    final bool showFab = _currentIndex == 1 || _currentIndex == 2;

    return Container(
      width: screenWidth,
      height: 120, // enough height for the "jump" animation
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: IgnorePointer(
        ignoring: !showFab,
        child: Stack(
          alignment: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
          children: [
            // search bar - expands horizontally from the left of add button
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              right: isLeft ? null : (_isSearching ? 0 : 56 + 12),
              left: isLeft ? (_isSearching ? 0 : 56 + 12) : null,
              bottom: 0, // aligned at the same floor as the 56px add button
              child: AnimatedScale(
                scale: showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  width: _isSearching ? screenWidth - 48 : 40,
                  height: _isSearching ? 44 : 40,
                  decoration: BoxDecoration(
                    color: _isSearching
                        ? theme.colorScheme.surface.withValues(alpha: 0.7)
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
                        sigmaX: _isSearching ? 5 : 0,
                        sigmaY: _isSearching ? 5 : 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSearching
                            ? AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
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
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              right: isLeft ? null : 0,
              left: isLeft ? 0 : null,
              bottom: _isSearching ? 44 + 12 : 0, // moves up above search bar
              child: AnimatedScale(
                scale: showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
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
