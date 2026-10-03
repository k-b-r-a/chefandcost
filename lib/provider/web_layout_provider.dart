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

  const WebLayoutState({
    this.middleTab = WebMiddleTab.recipes,
    this.rightPaneView = WebRightPaneView.home,
    this.selectedRecipeId,
    this.selectedIngredient,
    this.selectedToolIndex,
    this.isHomeActive = true,
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
        clearTool: true,
        isHomeActive: false,
      );
      return;
    }

    // If a recipe is currently open in the right pane, keep it open
    // while allowing the middle column to browse recipes, ingredients, or tools.
    final isRecipeActive = (state.rightPaneView == WebRightPaneView.recipe &&
            state.selectedRecipeId != null) ||
        state.rightPaneView == WebRightPaneView.newRecipe;

    if (isRecipeActive) {
      state = state.copyWith(
        middleTab: tab,
        isHomeActive: false,
      );
      return;
    }

    if (tab == WebMiddleTab.recipes) {
      state = state.copyWith(
        middleTab: tab,
        rightPaneView: WebRightPaneView.recipe,
        clearIngredient: true,
        clearTool: true,
        isHomeActive: false,
      );
      return;
    }

    if (tab == WebMiddleTab.ingredients) {
      state = state.copyWith(
        middleTab: tab,
        rightPaneView: WebRightPaneView.ingredient,
        clearRecipeId: true,
        clearTool: true,
        isHomeActive: false,
      );
      return;
    }

    if (tab == WebMiddleTab.tools) {
      final isToolView = state.rightPaneView == WebRightPaneView.tool;
      state = state.copyWith(
        middleTab: tab,
        rightPaneView: isToolView ? state.rightPaneView : WebRightPaneView.tool,
        selectedToolIndex: state.selectedToolIndex ?? 0,
        clearRecipeId: true,
        clearIngredient: true,
        isHomeActive: false,
      );
      return;
    }

    state = state.copyWith(
      middleTab: tab,
      isHomeActive: false,
    );
  }

  void showHome() {
    state = state.copyWith(
      rightPaneView: WebRightPaneView.home,
      clearRecipeId: true,
      clearIngredient: true,
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
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openIngredient(Ingredient ingredient) {
    state = state.copyWith(
      middleTab: WebMiddleTab.ingredients,
      rightPaneView: WebRightPaneView.ingredient,
      selectedIngredient: ingredient,
      clearRecipeId: true,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openNewIngredient() {
    state = state.copyWith(
      middleTab: WebMiddleTab.ingredients,
      rightPaneView: WebRightPaneView.newIngredient,
      clearRecipeId: true,
      clearIngredient: true,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void openTool(int toolIndex) {
    state = state.copyWith(
      middleTab: WebMiddleTab.tools,
      rightPaneView: WebRightPaneView.tool,
      selectedToolIndex: toolIndex,
      clearRecipeId: true,
      clearIngredient: true,
      isHomeActive: false,
    );
  }

  void openSettingsDetail(WebRightPaneView view) {
    state = state.copyWith(
      middleTab: WebMiddleTab.settings,
      rightPaneView: view,
      clearRecipeId: true,
      clearIngredient: true,
      clearTool: true,
      isHomeActive: false,
    );
  }

  void closeDetail() {
    state = state.copyWith(
      rightPaneView: WebRightPaneView.home,
      clearRecipeId: true,
      clearIngredient: true,
      clearTool: true,
      isHomeActive: true,
    );
  }
}

final webLayoutProvider =
    NotifierProvider<WebLayoutNotifier, WebLayoutState>(WebLayoutNotifier.new);
