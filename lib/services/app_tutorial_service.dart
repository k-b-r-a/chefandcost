import 'dart:async' show FutureOr;
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

/// Container for the GlobalKeys used to highlight widgets during the Recipe List walkthrough tutorial.
class RecipeListTutorialKeys {
  final GlobalKey recipeCardKey;
  final GlobalKey recipeFinanceGridKey;

  RecipeListTutorialKeys({
    GlobalKey? recipeCardKey,
    GlobalKey? recipeFinanceGridKey,
  })  : recipeCardKey = recipeCardKey ?? GlobalKey(debugLabel: 'tutorial_recipeCardKey'),
        recipeFinanceGridKey = recipeFinanceGridKey ?? GlobalKey(debugLabel: 'tutorial_recipeFinanceGridKey');
}

/// Container for the GlobalKeys used to highlight widgets during the Recipe Editor walkthrough tutorial.
class RecipeEditorTutorialKeys {
  final GlobalKey recipeEditorFinanceKey;
  final GlobalKey recipeEditorIngredientsKey;
  final GlobalKey recipeEditorFirstIngredientKey;

  RecipeEditorTutorialKeys({
    GlobalKey? recipeEditorFinanceKey,
    GlobalKey? recipeEditorIngredientsKey,
    GlobalKey? recipeEditorFirstIngredientKey,
  })  : recipeEditorFinanceKey = recipeEditorFinanceKey ?? GlobalKey(debugLabel: 'tutorial_recipeEditorFinanceKey'),
        recipeEditorIngredientsKey = recipeEditorIngredientsKey ?? GlobalKey(debugLabel: 'tutorial_recipeEditorIngredientsKey'),
        recipeEditorFirstIngredientKey = recipeEditorFirstIngredientKey ?? GlobalKey(debugLabel: 'tutorial_recipeEditorFirstIngredientKey');
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
  static const String kTutorialCompletedKey = 'has_completed_app_walkthrough_tutorial_v2';
  static const String kTutorialRecipeListCompletedKey = 'has_completed_recipe_list_walkthrough_tutorial_v1';
  static const String kTutorialRecipeEditorCompletedKey = 'has_completed_recipe_editor_walkthrough_tutorial_v1';

  /// Global notifier to trigger a walkthrough replay from anywhere in the app.
  static final ValueNotifier<int> replayNotifier = ValueNotifier<int>(0);

  static Future<SharedPreferences> _getPrefs([SharedPreferences? prefs]) async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Checks if the main app walkthrough has been completed or skipped previously.
  static Future<bool> isTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    return p.getBool(kTutorialCompletedKey) ?? false;
  }

  /// Marks the main walkthrough as completed in persistent storage.
  static Future<void> markTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialCompletedKey, true);
  }

  /// Checks if the recipe list walkthrough has been completed or skipped previously.
  static Future<bool> isRecipeListTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    return p.getBool(kTutorialRecipeListCompletedKey) ?? false;
  }

  /// Marks the recipe list walkthrough as completed in persistent storage.
  static Future<void> markRecipeListTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialRecipeListCompletedKey, true);
  }

  /// Checks if the recipe editor walkthrough has been completed or skipped previously.
  static Future<bool> isRecipeEditorTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    return p.getBool(kTutorialRecipeEditorCompletedKey) ?? false;
  }

  /// Marks the recipe editor walkthrough as completed in persistent storage.
  static Future<void> markRecipeEditorTutorialCompleted([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialRecipeEditorCompletedKey, true);
  }

  /// Resets all walkthrough tutorials so they will run again.
  static Future<void> resetTutorial([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialCompletedKey, false);
    await p.setBool(kTutorialRecipeListCompletedKey, false);
    await p.setBool(kTutorialRecipeEditorCompletedKey, false);
  }

  /// Resets specifically the recipe list walkthrough status.
  static Future<void> resetRecipeListTutorial([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialRecipeListCompletedKey, false);
  }

  /// Resets specifically the recipe editor walkthrough status.
  static Future<void> resetRecipeEditorTutorial([SharedPreferences? prefs]) async {
    final p = await _getPrefs(prefs);
    await p.setBool(kTutorialRecipeEditorCompletedKey, false);
  }

  /// Signals that the tutorial should replay immediately.
  static void requestReplay() {
    replayNotifier.value++;
  }

  /// Alias for requestReplay.
  static void triggerReplay() => requestReplay();

  /// Calculates a screen-safe vertical position close to the target focus.
  static CustomTargetContentPosition calculateSafeTargetPosition({
    required BuildContext context,
    required GlobalKey keyTarget,
  }) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    const estimatedCardHeight = 260.0;
    const safeMargin = 16.0;
    const gap = 12.0;

    final ctx = keyTarget.currentContext;
    if (ctx == null) {
      return CustomTargetContentPosition(
        bottom: bottomPadding + 20.0,
        left: 0.0,
      );
    }

    final renderBox = ctx.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) {
      return CustomTargetContentPosition(
        bottom: bottomPadding + 20.0,
        left: 0.0,
      );
    }

    final pos = renderBox.localToGlobal(Offset.zero);
    final targetTop = pos.dy;
    final targetHeight = renderBox.size.height;
    final targetBottom = targetTop + targetHeight;

    final availableBelow =
        screenHeight - bottomPadding - safeMargin - targetBottom;
    final availableAbove = targetTop - topPadding - safeMargin;

    // Place below if there is enough space; otherwise place above
    final bool placeBelow;
    if (availableBelow >= estimatedCardHeight) {
      placeBelow = true;
    } else if (availableAbove >= estimatedCardHeight) {
      placeBelow = false;
    } else {
      placeBelow = availableBelow >= availableAbove;
    }

    if (placeBelow) {
      final maxAllowedTop =
          (screenHeight - bottomPadding - safeMargin - estimatedCardHeight)
              .clamp(topPadding + safeMargin, double.infinity);
      final desiredTop = targetBottom + gap;
      final top = desiredTop.clamp(topPadding + safeMargin, maxAllowedTop);
      return CustomTargetContentPosition(
        top: top,
        left: 0.0,
      );
    } else {
      final maxAllowedBottom =
          (screenHeight - topPadding - safeMargin - estimatedCardHeight)
              .clamp(bottomPadding + safeMargin, double.infinity);
      final desiredBottom = (screenHeight - targetTop) + gap;
      final bottom =
          desiredBottom.clamp(bottomPadding + safeMargin, maxAllowedBottom);
      return CustomTargetContentPosition(
        bottom: bottom,
        left: 0.0,
      );
    }
  }

  /// Helper to convert a list of TutorialStepInfo into TargetFocus items with screen-safe, close-to-focus positioning.
  static List<TargetFocus> _buildTargetFocusList(
    BuildContext context,
    List<TutorialStepInfo> rawSteps,
    AppLocalizations l10n,
  ) {
    final activeSteps = rawSteps.where((step) {
      final ctx = step.keyTarget.currentContext;
      if (ctx == null) return false;
      final renderBox = ctx.findRenderObject();
      return renderBox is RenderBox && renderBox.hasSize && renderBox.size.height > 0;
    }).toList();

    if (activeSteps.isEmpty) return const [];

    final totalSteps = activeSteps.length;
    final targets = <TargetFocus>[];

    for (int i = 0; i < totalSteps; i++) {
      final step = activeSteps[i];
      final stepIndex = i;

      final customPos = calculateSafeTargetPosition(
        context: context,
        keyTarget: step.keyTarget,
      );

      targets.add(
        TargetFocus(
          identify: step.id,
          keyTarget: step.keyTarget,
          shape: step.shape,
          radius: step.radius,
          enableOverlayTab: false,
          enableTargetTab: step.id == 'step_recipe_list_hold' ||
              step.id == 'step_recipe_editor_ingredient_hold',
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: customPos,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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

  /// Builds the list of TargetFocus targets based on currently mounted keys on Home.
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

    return _buildTargetFocusList(context, rawSteps, l10n);
  }

  /// Builds the list of TargetFocus targets for Recipe List screen.
  static List<TargetFocus> createRecipeListTargets({
    required BuildContext context,
    required RecipeListTutorialKeys keys,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const [];

    final rawSteps = <TutorialStepInfo>[
      // 1. Recipe Long-Press / Options
      TutorialStepInfo(
        id: 'step_recipe_list_hold',
        keyTarget: keys.recipeCardKey,
        align: ContentAlign.bottom,
        icon: Icons.touch_app_rounded,
        title: l10n.tutorial_recipe_list_hold_title,
        description: l10n.tutorial_recipe_list_hold_desc,
        gestureHint: l10n.tutorial_recipe_list_hold_hint,
        radius: 18.0,
      ),
      // 2. Financial Metrics Breakdown
      TutorialStepInfo(
        id: 'step_recipe_list_finance',
        keyTarget: keys.recipeFinanceGridKey,
        align: ContentAlign.bottom,
        icon: Icons.attach_money_rounded,
        title: l10n.tutorial_recipe_list_finance_title,
        description: l10n.tutorial_recipe_list_finance_desc,
        gestureHint: l10n.tutorial_recipe_list_finance_hint,
        radius: 14.0,
      ),
    ];

    return _buildTargetFocusList(context, rawSteps, l10n);
  }

  /// Builds the list of TargetFocus targets for Recipe Editor screen.
  static List<TargetFocus> createRecipeEditorTargets({
    required BuildContext context,
    required RecipeEditorTutorialKeys keys,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const [];

    final rawSteps = <TutorialStepInfo>[
      // 1. Financial Bar & Margin Calculator
      TutorialStepInfo(
        id: 'step_recipe_editor_finance',
        keyTarget: keys.recipeEditorFinanceKey,
        align: ContentAlign.top,
        icon: Icons.analytics_outlined,
        title: l10n.tutorial_editor_finance_title,
        description: l10n.tutorial_editor_finance_desc,
        gestureHint: l10n.tutorial_editor_finance_hint,
        radius: 16.0,
      ),
      // 2. Ingredient Long-Press / Quick Actions
      TutorialStepInfo(
        id: 'step_recipe_editor_ingredient_hold',
        keyTarget: keys.recipeEditorFirstIngredientKey,
        align: ContentAlign.bottom,
        icon: Icons.touch_app_rounded,
        title: l10n.tutorial_editor_ingredient_hold_title,
        description: l10n.tutorial_editor_ingredient_hold_desc,
        gestureHint: l10n.tutorial_editor_ingredient_hold_hint,
        radius: 14.0,
      ),
      // 3. Ingredients reordering & Portion Scaling gestures
      TutorialStepInfo(
        id: 'step_recipe_editor_gestures',
        keyTarget: keys.recipeEditorIngredientsKey,
        align: ContentAlign.bottom,
        icon: Icons.drag_indicator_rounded,
        title: l10n.tutorial_editor_gestures_title,
        description: l10n.tutorial_editor_gestures_desc,
        gestureHint: l10n.tutorial_editor_gestures_hint,
        radius: 14.0,
      ),
    ];

    return _buildTargetFocusList(context, rawSteps, l10n);
  }

  /// Common internal builder for TutorialCoachMark controllers.
  static TutorialCoachMark? _createTutorialWithTargets({
    required BuildContext context,
    required List<TargetFocus> targets,
    required Future<void> Function() onComplete,
    FutureOr<void> Function(String stepId)? onStepFocus,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
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
              alignment: 0.50,
            );
          } catch (_) {}
        }
        if (onStepFocus != null && target.identify != null) {
          await onStepFocus(target.identify!);
        }
        if (key != null &&
            target.contents != null &&
            target.contents!.isNotEmpty &&
            context.mounted) {
          final updatedPos = calculateSafeTargetPosition(
            context: context,
            keyTarget: key,
          );
          final oldContent = target.contents!.first;
          target.contents![0] = TargetContent(
            align: ContentAlign.custom,
            customPosition: updatedPos,
            padding: oldContent.padding,
            builder: oldContent.builder,
          );
        }
      },
      onFinish: () {
        onComplete();
        onFinish?.call();
      },
      onSkip: () {
        onComplete();
        onSkip?.call();
        return true;
      },
    );

    return tutorialInstance;
  }

  /// Instantiates a TutorialCoachMark controller for the Home walkthrough.
  static TutorialCoachMark? createTutorial({
    required BuildContext context,
    required AppTutorialKeys keys,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
  }) {
    final targets = createTargets(context: context, keys: keys);
    return _createTutorialWithTargets(
      context: context,
      targets: targets,
      onComplete: () => markTutorialCompleted(prefs),
      onFinish: onFinish,
      onSkip: onSkip,
    );
  }

  /// Shows the Home walkthrough tutorial immediately if valid targets exist.
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

  /// Checks if Home walkthrough should trigger on first launch.
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

  /// Shows the Recipe List walkthrough tutorial immediately if valid targets exist.
  static bool showRecipeListTutorial(
    BuildContext context, {
    required RecipeListTutorialKeys keys,
    FutureOr<void> Function(String stepId)? onStepFocus,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
  }) {
    final targets = createRecipeListTargets(context: context, keys: keys);
    if (targets.isEmpty) return false;

    final tutorial = _createTutorialWithTargets(
      context: context,
      targets: targets,
      onComplete: () => markRecipeListTutorialCompleted(prefs),
      onStepFocus: onStepFocus,
      onFinish: onFinish,
      onSkip: onSkip,
    );
    if (tutorial == null) return false;

    tutorial.show(context: context, rootOverlay: true);
    return true;
  }

  /// Checks if Recipe List walkthrough should trigger on first launch.
  static Future<bool> checkAndShowRecipeListTutorial(
    BuildContext context, {
    required RecipeListTutorialKeys keys,
    bool force = false,
    FutureOr<void> Function(String stepId)? onStepFocus,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
    int maxRetries = 3,
  }) async {
    if (!force) {
      if (!kIsWeb) {
        try {
          if (Platform.environment['FLUTTER_TEST'] == 'true') {
            return false;
          }
        } catch (_) {}
      }
      final isCompleted = await isRecipeListTutorialCompleted(prefs);
      if (isCompleted) return false;
    }

    if (!context.mounted) return false;

    final targets = createRecipeListTargets(context: context, keys: keys);
    if (targets.isEmpty && maxRetries > 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return false;
      return checkAndShowRecipeListTutorial(
        context,
        keys: keys,
        force: force,
        onStepFocus: onStepFocus,
        onFinish: onFinish,
        onSkip: onSkip,
        prefs: prefs,
        maxRetries: maxRetries - 1,
      );
    }

    if (targets.isEmpty) return false;

    return showRecipeListTutorial(
      context,
      keys: keys,
      onStepFocus: onStepFocus,
      onFinish: onFinish,
      onSkip: onSkip,
      prefs: prefs,
    );
  }

  /// Shows the Recipe Editor walkthrough tutorial immediately if valid targets exist.
  static bool showRecipeEditorTutorial(
    BuildContext context, {
    required RecipeEditorTutorialKeys keys,
    FutureOr<void> Function(String stepId)? onStepFocus,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
  }) {
    final targets = createRecipeEditorTargets(context: context, keys: keys);
    if (targets.isEmpty) return false;

    final tutorial = _createTutorialWithTargets(
      context: context,
      targets: targets,
      onComplete: () => markRecipeEditorTutorialCompleted(prefs),
      onStepFocus: onStepFocus,
      onFinish: onFinish,
      onSkip: onSkip,
    );
    if (tutorial == null) return false;

    tutorial.show(context: context, rootOverlay: true);
    return true;
  }

  /// Checks if Recipe Editor walkthrough should trigger on first launch.
  static Future<bool> checkAndShowRecipeEditorTutorial(
    BuildContext context, {
    required RecipeEditorTutorialKeys keys,
    bool force = false,
    FutureOr<void> Function(String stepId)? onStepFocus,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    SharedPreferences? prefs,
    int maxRetries = 3,
  }) async {
    if (!force) {
      if (!kIsWeb) {
        try {
          if (Platform.environment['FLUTTER_TEST'] == 'true') {
            return false;
          }
        } catch (_) {}
      }
      final isCompleted = await isRecipeEditorTutorialCompleted(prefs);
      if (isCompleted) return false;
    }

    if (!context.mounted) return false;

    final targets = createRecipeEditorTargets(context: context, keys: keys);
    if (targets.isEmpty && maxRetries > 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return false;
      return checkAndShowRecipeEditorTutorial(
        context,
        keys: keys,
        force: force,
        onStepFocus: onStepFocus,
        onFinish: onFinish,
        onSkip: onSkip,
        prefs: prefs,
        maxRetries: maxRetries - 1,
      );
    }

    if (targets.isEmpty) return false;

    return showRecipeEditorTutorial(
      context,
      keys: keys,
      onStepFocus: onStepFocus,
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    double horizontalAlignment = 0.0;
    const cardMaxWidth = 420.0;

    final keyCtx = step.keyTarget.currentContext;
    if (keyCtx != null && screenWidth > (cardMaxWidth + 32.0)) {
      final rb = keyCtx.findRenderObject();
      if (rb is RenderBox && rb.hasSize) {
        final pos = rb.localToGlobal(Offset.zero);
        final liveTargetCenterX = pos.dx + (rb.size.width / 2.0);
        final availableSpan = (screenWidth - cardMaxWidth) / 2.0;
        if (availableSpan > 0) {
          horizontalAlignment =
              ((liveTargetCenterX - (screenWidth / 2.0)) / availableSpan)
                  .clamp(-0.95, 0.95);
        }
      }
    }

    return Align(
      alignment: Alignment(horizontalAlignment, 0.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cardMaxWidth,
          maxHeight: (screenHeight * 0.42).clamp(220.0, 480.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
    ),
  );
  }
}
