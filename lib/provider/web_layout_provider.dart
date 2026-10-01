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
