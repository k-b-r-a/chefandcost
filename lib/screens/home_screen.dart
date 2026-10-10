import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../database/database.dart';
import '../provider/database_provider.dart';
import '../provider/settings_provider.dart';
import '../provider/timers_provider.dart';
import '../utils/recipe_utils.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../widgets/tool_card.dart';
import '../provider/web_layout_provider.dart';
import '../database/sample_data.dart';

import 'recipe_editor_screen.dart';
import 'add_ingredient_screen.dart';
import 'kitchen_timers_screen.dart';
import 'rule_of_three_screen.dart';
import 'unit_converter_screen.dart';
import '../services/app_tutorial_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateToTab;
  final AppTutorialKeys? tutorialKeys;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.tutorialKeys,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return l10n.home_greeting_morning;
    } else if (hour < 19) {
      return l10n.home_greeting_afternoon;
    } else {
      return l10n.home_greeting_evening;
    }
  }

  String _getFormattedDate(String locale) {
    final now = DateTime.now();
    try {
      return DateFormat('EEEE, d MMMM', locale).format(now);
    } catch (_) {
      return DateFormat('EEEE, d MMMM', 'en').format(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final recipesAsync = ref.watch(recipesWithFinancialsStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          buildFloatingPillAppBar(
            context: context,
            title: l10n.home_title,
            controller: _scrollController,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100.0),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Greeting Banner
                      _buildGreetingCard(context, theme, l10n, settings),
                      const SizedBox(height: 16),

                      // 2. Active Timers Banner (Live countdown card if running)
                      const _LiveActiveTimersBanner(),

                      // 3. Quick Actions
                      KeyedSubtree(
                        key: widget.tutorialKeys?.quickActionsKey,
                        child: _buildQuickActionsSection(context, theme, l10n),
                      ),
                      const SizedBox(height: 20),

                      // 5. Recent Recipes
                      _buildRecentRecipesSection(
                        context: context,
                        theme: theme,
                        l10n: l10n,
                        settings: settings,
                        recipesAsync: recipesAsync,
                      ),
                      const SizedBox(height: 20),

                      // 6. Kitchen Tools Quick Launch
                      _buildKitchenToolsSection(context, theme, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Greeting Card ---
  Widget _buildGreetingCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    SettingsState settings,
  ) {
    final greeting = _getGreeting(l10n);
    final dateStr = _getFormattedDate(settings.locale.languageCode);
    final capitalizedDate = dateStr.isNotEmpty
        ? dateStr[0].toUpperCase() + dateStr.substring(1)
        : dateStr;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizedDate,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.restaurant_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }



  // --- 4. Quick Actions Section ---
  Widget _buildQuickActionsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.home_quick_actions,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickActionButton(
                context: context,
                theme: theme,
                label: l10n.new_recipe_title,
                icon: Icons.add_rounded,
                isPrimary: true,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openNewRecipe();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RecipeEditorScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                context: context,
                theme: theme,
                label: l10n.new_ingredient_button,
                icon: Icons.egg_outlined,
                isPrimary: false,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openNewIngredient();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddIngredientScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                context: context,
                theme: theme,
                label: l10n.timers_title,
                icon: Icons.timer_outlined,
                isPrimary: false,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(0);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const KitchenTimersScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                context: context,
                theme: theme,
                label: l10n.rule_of_three_title,
                icon: Icons.calculate_outlined,
                isPrimary: false,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(1);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RuleOfThreeScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                context: context,
                theme: theme,
                label: l10n.unit_converter_title,
                icon: Icons.swap_horiz_rounded,
                isPrimary: false,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(2);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UnitConverterScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPrimary
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. Recent Recipes Section ---
  Widget _buildRecentRecipesSection({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required SettingsState settings,
    required AsyncValue<List<RecipeWithFinancials>> recipesAsync,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: widget.tutorialKeys?.recentRecipesKey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.home_recent_recipes,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateToTab?.call(1),
                child: Text(
                  l10n.home_view_all,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        recipesAsync.when(
          data: (recipes) {
            if (recipes.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.no_recipes_found,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (MediaQuery.sizeOf(context).width >= 640) {
                              ref.read(webLayoutProvider.notifier).openNewRecipe();
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RecipeEditorScreen(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.new_recipe_title),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final db = ref.read(databaseProvider);
                            final res = await loadSampleData(db, clearFirst: false);
                            ref.invalidate(recipesStreamProvider);
                            ref.invalidate(recipesWithFinancialsStreamProvider);
                            ref.invalidate(ingredientsStreamProvider);
                            ref.invalidate(unitsProvider);
                            ref.invalidate(unitsStreamProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.sample_data_loaded_snackbar(res.recipesAdded, res.ingredientsAdded),
                                    softWrap: true,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: Text(
                            l10n.load_sample_data,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            final recentList = recipes.take(4).toList();

            return Column(
              children: recentList.map((item) {
                final recipe = item.recipe;
                final financials = item.financials;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (MediaQuery.sizeOf(context).width >= 640) {
                          ref
                              .read(webLayoutProvider.notifier)
                              .openRecipe(recipe.recipePk);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeEditorScreen(recipeId: recipe.recipePk),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: RecipeUtils.parseColor(
                                recipe.colour,
                                fallback: theme.colorScheme.primary,
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${RecipeUtils.formatNumber(recipe.defaultYield, decimalDigits: 0)} ${recipe.yieldName.isNotEmpty ? recipe.yieldName : l10n.unit_portions.toLowerCase()} • ${settings.currencySymbol}${RecipeUtils.formatNumber(financials.totalCost)} ${l10n.total_cost.toLowerCase()}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${RecipeUtils.formatNumber(recipe.targetProfitMargin * 100, decimalDigits: 0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  l10n.financial_margin,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text(l10n.error_prefix(e.toString()), softWrap: true)),
        ),
      ],
    );
  }

  // --- 6. Kitchen Tools Section ---
  Widget _buildKitchenToolsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.home_kitchen_tools,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => widget.onNavigateToTab?.call(3),
              child: Text(
                l10n.home_view_all,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: widget.tutorialKeys?.toolsSectionKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolCard(
                title: l10n.timers_title,
                subtitle: l10n.timers_desc,
                icon: Icons.timer_outlined,
                isCompact: true,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(0);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const KitchenTimersScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              ToolCard(
                title: l10n.rule_of_three_title,
                subtitle: l10n.rule_of_three_desc,
                icon: Icons.calculate_outlined,
                isCompact: true,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(1);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RuleOfThreeScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              ToolCard(
                title: l10n.unit_converter_title,
                subtitle: l10n.unit_converter_desc,
                icon: Icons.swap_horiz_rounded,
                isCompact: true,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width >= 640) {
                    ref.read(webLayoutProvider.notifier).openTool(2);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UnitConverterScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveActiveTimersBanner extends ConsumerWidget {
  const _LiveActiveTimersBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timers = ref.watch(kitchenTimersProvider);
    final runningTimers = timers.where((t) => t.isRunning && !t.isFinished).toList();
    final finishedTimers = timers.where((t) => t.isFinished).toList();

    if (runningTimers.isEmpty && finishedTimers.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final topTimer = runningTimers.isNotEmpty
        ? runningTimers.first
        : finishedTimers.first;

    final isDone = topTimer.isFinished;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDone
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDone
                  ? theme.colorScheme.error.withValues(alpha: 0.4)
                  : theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDone ? Icons.alarm_on_rounded : Icons.timer_rounded,
                    color: isDone ? theme.colorScheme.error : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDone ? l10n.timer_finished_banner : l10n.home_active_timers,
                      softWrap: true,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? theme.colorScheme.error
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const KitchenTimersScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.home_view_all,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topTimer.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDone
                              ? l10n.timer_finished_at(topTimer.formattedFinishedTime)
                              : topTimer.formattedTime,
                          softWrap: true,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDone
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(kitchenTimersProvider.notifier).toggleTimer(topTimer.id);
                    },
                    icon: Icon(
                      topTimer.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(kitchenTimersProvider.notifier).resetTimer(topTimer.id);
                    },
                    icon: Icon(
                      Icons.replay_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (!isDone && topTimer.totalSeconds > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: topTimer.progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
