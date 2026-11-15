import 'package:flutter/material.dart';
import '../database/database.dart';
import 'recipe_utils.dart';

class IngredientTextEditingController extends TextEditingController {
  List<Ingredient> _ingredients;
  final ColorScheme colorScheme;

  RegExp? _cachedRegex;
  Map<String, Ingredient> _lookupMap = const {};
  Map<String, Color> _colorCache = const {};

  IngredientTextEditingController({
    super.text,
    List<Ingredient>? ingredients,
    required this.colorScheme,
  }) : _ingredients = List<Ingredient>.unmodifiable(ingredients ?? const []) {
    _rebuildPatternCache();
  }

  List<Ingredient> get ingredients => _ingredients;

  @visibleForTesting
  RegExp? get cachedRegex => _cachedRegex;

  /// Updates the internal list of available ingredients for tagging.
  void updateIngredients(List<Ingredient> newIngredients) {
    if (_areIngredientsEqual(_ingredients, newIngredients)) return;
    _ingredients = List<Ingredient>.unmodifiable(newIngredients);
    _rebuildPatternCache();
    notifyListeners();
  }

  bool _areIngredientsEqual(List<Ingredient> a, List<Ingredient> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].ingredientPk != b[i].ingredientPk || a[i].name != b[i].name) {
        return false;
      }
    }
    return true;
  }

  void _rebuildPatternCache() {
    final valid = _ingredients
        .where((ing) => ing.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.name.trim().length.compareTo(a.name.trim().length));

    if (valid.isEmpty) {
      _cachedRegex = null;
      _lookupMap = const {};
      _colorCache = const {};
      return;
    }

    final lookup = <String, Ingredient>{};
    final colors = <String, Color>{};
    final escapedNames = <String>[];

    for (final ing in valid) {
      final trimmed = ing.name.trim();
      final key = trimmed.toLowerCase();
      lookup.putIfAbsent(key, () => ing);
      colors[ing.ingredientPk] =
          RecipeUtils.getIngredientColor(ing.name, colorScheme);
      escapedNames.add(RegExp.escape(trimmed));
    }

    final pattern = escapedNames.join('|');
    _cachedRegex = RegExp(
      '(?<![a-zA-ZáéíóúÁÉÍÓÚñÑüÜ])($pattern)(?![a-zA-ZáéíóúÁÉÍÓÚñÑüÜ])',
      caseSensitive: false,
    );
    _lookupMap = lookup;
    _colorCache = colors;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final regex = _cachedRegex;
    if (regex == null || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final List<InlineSpan> children = [];

    text.splitMapJoin(
      regex,
      onMatch: (Match match) {
        final matchedText = match[0]!;
        final matchedIng = _lookupMap[matchedText.toLowerCase()];
        final color = matchedIng != null
            ? (_colorCache[matchedIng.ingredientPk] ??
                RecipeUtils.getIngredientColor(matchedIng.name, colorScheme))
            : RecipeUtils.getIngredientColor(matchedText, colorScheme);

        children.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatched) {
        if (nonMatched.isNotEmpty) {
          children.add(TextSpan(text: nonMatched, style: style));
        }
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
