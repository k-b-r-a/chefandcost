import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../l10n/app_localizations.dart';

/// Container for the GlobalKeys used to highlight widgets during the walkthrough tutorial.
class AppTutorialKeys {
  final GlobalKey navBarKey;
  final GlobalKey quickActionsKey;
  final GlobalKey recentRecipesKey;
  final GlobalKey toolsSectionKey;

  AppTutorialKeys({
    GlobalKey? navBarKey,
    GlobalKey? quickActionsKey,
    GlobalKey? recentRecipesKey,
    GlobalKey? toolsSectionKey,
  })  : navBarKey = navBarKey ?? GlobalKey(debugLabel: 'tutorial_navBarKey'),
        quickActionsKey = quickActionsKey ?? GlobalKey(debugLabel: 'tutorial_quickActionsKey'),
        recentRecipesKey = recentRecipesKey ?? GlobalKey(debugLabel: 'tutorial_recentRecipesKey'),
        toolsSectionKey = toolsSectionKey ?? GlobalKey(debugLabel: 'tutorial_toolsSectionKey');
}

/// Information model describing an individual step in the guided tour.
class TutorialStepInfo {
  final String id;
  final GlobalKey keyTarget;
  final ContentAlign align;
  final IconData icon;
  final String title;
  final String description;
  final String? gestureHint;
  final ShapeLightFocus shape;
  final double radius;

  const TutorialStepInfo({
    required this.id,
    required this.keyTarget,
    required this.align,
    required this.icon,
    required this.title,
    required this.description,
    this.gestureHint,
    this.shape = ShapeLightFocus.RRect,
    this.radius = 18.0,
  });
}

/// Service managing the interactive, step-by-step walkthrough tutorial.
class AppTutorialService {
  static const String kTutorialCompletedKey = 'has_completed_app_walkthrough_tutorial_v1';

  /// Global notifier to trigger a walkthrough replay from anywhere in the app.
  static final ValueNotifier<int> replayNotifier = ValueNotifier<int>(0);

  static Future<SharedPreferences> _getPrefs([SharedPreferences? prefs]) async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Checks if the tutorial has been completed or skipped previously.
  static Future<bool> isTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    return p.getBool(kTutorialCompletedKey) ?? false;
  }

  /// Marks the walkthrough as completed in persistent storage.
  static Future<void> markTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialCompletedKey, true);
  }

  /// Resets the tutorial status so it will run again.
  static Future<void> resetTutorial([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialCompletedKey, false);
  }

  /// Signals that the tutorial should replay immediately.
  static void requestReplay() {
    replayNotifier.value++;
  }

  /// Alias for requestReplay.
  static void triggerReplay() => requestReplay();

  /// Builds the list of TargetFocus targets based on currently mounted keys.
  static List<TargetFocus> createTargets({
    required BuildContext context,
    required AppTutorialKeys keys,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const [];

    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final rawSteps = <TutorialStepInfo>[
      // 1. Navigation Bar & Gestures
      TutorialStepInfo(
        id: 'step_nav_bar',
        keyTarget: keys.navBarKey,
        align: isWide ? ContentAlign.right : ContentAlign.top,
        icon: Icons.swipe_rounded,
        title: l10n.tutorial_target_nav_title,
        description: l10n.tutorial_target_nav_desc,
        gestureHint: l10n.tutorial_target_nav_hint,
        radius: 18.0,
      ),
      // 2. Quick Actions
      TutorialStepInfo(
        id: 'step_quick_actions',
        keyTarget: keys.quickActionsKey,
        align: ContentAlign.bottom,
        icon: Icons.bolt_rounded,
        title: l10n.tutorial_target_quick_actions_title,
        description: l10n.tutorial_target_quick_actions_desc,
        gestureHint: l10n.tutorial_target_quick_actions_hint,
        radius: 18.0,
      ),
      // 3. Recent Recipes & Long-Press
      TutorialStepInfo(
        id: 'step_recent_recipes',
        keyTarget: keys.recentRecipesKey,
        align: ContentAlign.bottom,
        icon: Icons.touch_app_rounded,
        title: l10n.tutorial_target_recipes_title,
        description: l10n.tutorial_target_recipes_desc,
        gestureHint: l10n.tutorial_target_recipes_hint,
        radius: 20.0,
      ),
      // 4. Kitchen Tools & Timers
      TutorialStepInfo(
        id: 'step_tools_section',
        keyTarget: keys.toolsSectionKey,
        align: ContentAlign.top,
        icon: Icons.calculate_rounded,
        title: l10n.tutorial_target_tools_title,
        description: l10n.tutorial_target_tools_desc,
        gestureHint: l10n.tutorial_target_tools_hint,
        radius: 18.0,
      ),
    ];

    // Filter to targets whose widgets are currently mounted and have a valid size
    final activeSteps = rawSteps.where((step) {
      final ctx = step.keyTarget.currentContext;
      if (ctx == null) return false;
      final renderBox = ctx.findRenderObject();
      return renderBox is RenderBox && renderBox.hasSize && renderBox.size.height > 0;
    }).toList();

    if (activeSteps.isEmpty) return const [];

    final totalSteps = activeSteps.length;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final targets = <TargetFocus>[];

    for (int i = 0; i < totalSteps; i++) {
      final step = activeSteps[i];
      final stepIndex = i;

      // Dynamically select align based on target position to ensure content is never off-screen
      ContentAlign dynamicAlign = step.align;
      final ctx = step.keyTarget.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject();
        if (renderBox is RenderBox && renderBox.hasSize) {
          final pos = renderBox.localToGlobal(Offset.zero);
          dynamicAlign = pos.dy > (screenHeight * 0.45)
              ? ContentAlign.top
              : ContentAlign.bottom;
        }
      }

      targets.add(
        TargetFocus(
          identify: step.id,
          keyTarget: step.keyTarget,
          shape: step.shape,
          radius: step.radius,
          enableOverlayTab: false,
          enableTargetTab: false,
          contents: [
            TargetContent(
              align: dynamicAlign,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              builder: (ctx, controller) {
                return _buildStepCard(
                  context: ctx,
                  controller: controller,
                  step: step,
                  stepIndex: stepIndex,
                  totalSteps: totalSteps,
                  l10n: l10n,
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }

  /// Instantiates a TutorialCoachMark controller configured with callbacks.
  static TutorialCoachMark? createTutorial({
    required BuildContext context,
    required AppTutorialKeys keys,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
  }) {
    final targets = createTargets(context: context, keys: keys);
    if (targets.isEmpty) return null;

    TutorialCoachMark? tutorialInstance;

    tutorialInstance = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.82,
      paddingFocus: 8,
      hideSkip: true, // We embed dedicated skip controls in every step card
      beforeFocus: (target) async {
        final key = target.keyTarget;
        final ctx = key?.currentContext;
        if (ctx != null) {
          try {
            await Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } catch (_) {}
        }
      },
      onFinish: () {
        markTutorialCompleted(prefs);
        onFinish?.call();
      },
      onSkip: () {
        markTutorialCompleted(prefs);
        onSkip?.call();
        return true;
      },
    );

    return tutorialInstance;
  }

  /// Shows the tutorial immediately if valid targets exist.
  static bool showTutorial(
    BuildContext context, {
    required AppTutorialKeys keys,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
  }) {
    final tutorial = createTutorial(
      context: context,
      keys: keys,
      onFinish: onFinish,
      onSkip: onSkip,
      prefs: prefs,
    );
    if (tutorial == null) return false;

    tutorial.show(context: context, rootOverlay: true);
    return true;
  }

  /// Checks if the user is launching for the first time and automatically triggers the tutorial.
  static Future<bool> checkAndShowTutorial(
    BuildContext context, {
    required AppTutorialKeys keys,
    bool force = false,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
    int maxRetries = 3,
  }) async {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        if (uri.queryParameters['tutorial'] == 'true' ||
            uri.queryParameters['replay'] == 'true' ||
            uri.queryParameters['walkthrough'] == 'true') {
          force = true;
          await resetTutorial(prefs);
        }
      } catch (_) {}
    }

    if (!force) {
      if (!kIsWeb) {
        try {
          if (Platform.environment['FLUTTER_TEST'] == 'true') {
            return false;
          }
        } catch (_) {}
      }
      final isCompleted = await isTutorialCompleted(prefs);
      if (isCompleted) return false;
    }

    if (!context.mounted) return false;

    final targets = createTargets(context: context, keys: keys);
    if (targets.isEmpty && maxRetries > 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return false;
      return checkAndShowTutorial(
        context,
        keys: keys,
        force: force,
        onFinish: onFinish,
        onSkip: onSkip,
        prefs: prefs,
        maxRetries: maxRetries - 1,
      );
    }

    if (targets.isEmpty) return false;

    return showTutorial(
      context,
      keys: keys,
      onFinish: onFinish,
      onSkip: onSkip,
      prefs: prefs,
    );
  }

  /// Builds the custom target focus card containing step counter, description, gesture hints, and controls.
  static Widget _buildStepCard({
    required BuildContext context,
    required TutorialCoachMarkController controller,
    required TutorialStepInfo step,
    required int stepIndex,
    required int totalSteps,
    required AppLocalizations l10n,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Step Badge & Skip Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              step.icon,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.tutorial_step_counter(stepIndex + 1, totalSteps),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(
                          l10n.tutorial_action_skip,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => controller.skip(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  step.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),

                // Highlight Gesture Hint Banner (if present)
                if (step.gestureHint != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.gestureHint!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Navigation Controls (Previous, Next / Finish)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (stepIndex > 0)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => controller.previous(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: Text(l10n.tutorial_action_prev),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => controller.next(),
                      icon: Icon(
                        stepIndex == totalSteps - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                      ),
                      label: Text(
                        stepIndex == totalSteps - 1
                            ? l10n.tutorial_action_finish
                            : l10n.tutorial_action_next,
                      ),
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
