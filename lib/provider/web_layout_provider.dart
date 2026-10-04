import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

enum WebMiddleTab {
  recipes,
  ingredients,
  tools,
  settings,
}

enum WebRightPaneView {
  home,
  recipe,
  newRecipe,
  ingredient,
  newIngredient,
  tool,
  settingsGeneral,
  settingsCloudSync,
  settingsStyles,
  settingsLocale,
  settingsAbout,
}

class WebLayoutState {
  final WebMiddleTab middleTab;
  final WebRightPaneView rightPaneView;
  final String? selectedRecipeId;
  final Ingredient? selectedIngredient;
  final int? selectedToolIndex;
  final bool isHomeActive;
  final bool isCreatingIngredient;
  final Ingredient? leftPaneIngredient;
  final bool isCreatingLeftPaneIngredient;
  final String? newIngredientInitialName;

  const WebLayoutState({
    this.middleTab = WebMiddleTab.recipes,
    this.rightPaneView = WebRightPaneView.home,
    this.selectedRecipeId,
    this.selectedIngredient,
    this.selectedToolIndex,
    this.isHomeActive = true,
    this.isCreatingIngredient = false,
    this.leftPaneIngredient,
    this.isCreatingLeftPaneIngredient = false,
    this.newIngredientInitialName,
  });

  WebLayoutState copyWith({
    WebMiddleTab? middleTab,
    WebRightPaneView? rightPaneView,
    String? selectedRecipeId,
    bool clearRecipeId = false,
    Ingredient? selectedIngredient,
    bool clearIngredient = false,
    int? selectedToolIndex,
    bool clearTool = false,
    bool? isHomeActive,
    bool? isCreatingIngredient,
    Ingredient? leftPaneIngredient,
    bool clearLeftPaneIngredient = false,
    bool? isCreatingLeftPaneIngredient,
    String? newIngredientInitialName,
    bool clearNewIngredientInitialName = false,
  }) {
    return WebLayoutState(
      middleTab: middleTab ?? this.middleTab,
      rightPaneView: rightPaneView ?? this.rightPaneView,
      selectedRecipeId:
          clearRecipeId ? null : (selectedRecipeId ?? this.selectedRecipeId),
      selectedIngredient: clearIngredient
          ? null
          : (selectedIngredient ?? this.selectedIngredient),
      selectedToolIndex:
          clearTool ? null : (selectedToolIndex ?? this.selectedToolIndex),
      isHomeActive: isHomeActive ?? this.isHomeActive,
      isCreatingIngredient: isCreatingIngredient ?? this.isCreatingIngredient,
      leftPaneIngredient: clearLeftPaneIngredient
          ? null
          : (leftPaneIngredient ?? this.leftPaneIngredient),
      isCreatingLeftPaneIngredient: isCreatingLeftPaneIngredient ??
          this.isCreatingLeftPaneIngredient,
      newIngredientInitialName: clearNewIngredientInitialName
          ? null
          : (newIngredientInitialName ?? this.newIngredientInitialName),
    );
  }
}

class WebLayoutNotifier extends Notifier<WebLayoutState> {
  @override
  WebLayoutState build() {
    return const WebLayoutState();
  }

  void setMiddleTab(WebMiddleTab tab) {
    if (tab == WebMiddleTab.settings) {
      final isAlreadySettingsView = state.rightPaneView == WebRightPaneView.settingsGeneral ||
          state.rightPaneView == WebRightPaneView.settingsCloudSync ||
          state.rightPaneView == WebRightPaneView.settingsStyles ||
          state.rightPaneView == WebRightPaneView.settingsLocale ||
          state.rightPaneView == WebRightPaneView.settingsAbout;
      state = state.copyWith(
        middleTab: tab,
        rightPaneView: isAlreadySettingsView ? state.rightPaneView : WebRightPaneView.settingsGeneral,
        clearRecipeId: true,
        clearIngredient: true,
        isCreatingIngredient: false,
        clearLeftPaneIngredient: true,
        isCreatingLeftPaneIngredient: false,
        clearTool: true,
        isHomeActive: false,
      );
      return;
    }

    // If a recipe is currently open, keep it open while allowing
    // the middle column to browse recipes, ingredients, or tools.
    final isRecipeActive = (state.rightPaneView == WebRightPaneView.recipe &&
            state.selectedRecipeId != null) ||
        state.rightPaneView == WebRightPaneView.newRecipe;

    if (isRecipeActive) {
      state = state.copyWith(
        middleTab: tab,
        clearLeftPaneIngredient: tab != WebMiddleTab.ingredients,
        isCreatingLeftPaneIngredient:
            tab == WebMiddleTab.ingredients ? state.isCreatingLeftPaneIngredient : false,
        isHomeActive: false,
      );
      return;
    }

    // When no recipe is active, just switch the middle tab.
    state = state.copyWith(
      middleTab: tab,
      clearLeftPaneIngredient: tab != WebMiddleTab.ingredients,
      isCreatingLeftPaneIngredient:
          tab == WebMiddleTab.ingredients ? state.isCreatingLeftPaneIngredient : false,
      isHomeActive: state.rightPaneView == WebRightPaneView.home,
    );
  }

  void showHome() {
    state = state.copyWith(
      rightPaneView: WebRightPaneView.home,
      clearRecipeId: true,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: false,
      clearTool: true,
      isHomeActive: true,
    );
  }

  void openRecipe(String recipeId) {
    state = state.copyWith(
      middleTab: WebMiddleTab.recipes,
      rightPaneView: WebRightPaneView.recipe,
      selectedRecipeId: recipeId,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: false,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openNewRecipe() {
    state = state.copyWith(
      middleTab: WebMiddleTab.recipes,
      rightPaneView: WebRightPaneView.newRecipe,
      clearRecipeId: true,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: false,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openIngredient(Ingredient ingredient) {
    state = state.copyWith(
      middleTab: WebMiddleTab.ingredients,
      leftPaneIngredient: ingredient,
      isCreatingLeftPaneIngredient: false,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openNewIngredient({String? initialName}) {
    state = state.copyWith(
      middleTab: WebMiddleTab.ingredients,
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: true,
      newIngredientInitialName: initialName,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void closeLeftPaneIngredient() {
    state = state.copyWith(
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: false,
      clearNewIngredientInitialName: true,
    );
  }

  void closeIngredientDetail() {
    state = state.copyWith(
      clearLeftPaneIngredient: true,
      isCreatingLeftPaneIngredient: false,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearNewIngredientInitialName: true,
    );
  }

  void openTool(int toolIndex) {
    state = state.copyWith(
      middleTab: WebMiddleTab.tools,
      rightPaneView: WebRightPaneView.tool,
      selectedToolIndex: toolIndex,
      clearRecipeId: true,
      clearIngredient: true,
      isCreatingIngredient: false,
      isHomeActive: false,
    );
  }

  void openSettingsDetail(WebRightPaneView view) {
    state = state.copyWith(
      middleTab: WebMiddleTab.settings,
      rightPaneView: view,
      clearRecipeId: true,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void closeDetail() {
    state = state.copyWith(
      rightPaneView: WebRightPaneView.home,
      clearRecipeId: true,
      clearIngredient: true,
      isCreatingIngredient: false,
      clearTool: true,
      isHomeActive: true,
    );
  }
}

final webLayoutProvider =
    NotifierProvider<WebLayoutNotifier, WebLayoutState>(WebLayoutNotifier.new);

class RecipeCanLeaveGuardNotifier extends Notifier<Future<bool> Function()?> {
  @override
  Future<bool> Function()? build() => null;

  void setGuard(Future<bool> Function()? guard) {
    state = guard;
  }

  void clearIf(Future<bool> Function()? guard) {
    Future.microtask(() {
      if (!ref.mounted) return;
      if (state == guard) {
        state = null;
      }
    });
  }
}

final recipeCanLeaveGuardProvider =
    NotifierProvider<RecipeCanLeaveGuardNotifier, Future<bool> Function()?>(
  RecipeCanLeaveGuardNotifier.new,
);

