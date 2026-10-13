import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/web_layout_provider.dart';
import '../screens/recipe_editor_screen.dart';
import '../services/recipe_share_service.dart';
import '../widgets/import_recipe_dialog.dart';

class RecipeImportHelper {
  /// Opens file picker to select and import a .chefy recipe file.
  static Future<RecipeImportResult?> importRecipeFromDevice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.import_recipe_dialog_title,
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.import_recipe_invalid_file,
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        );
        return null;
      }

      final jsonContent = utf8.decode(bytes);
      final allRecipes = await db.getAllRecipes();
      final preview =
          RecipeShareService.previewRecipeFromJson(jsonContent, allRecipes);

      if (!context.mounted) return null;

      final shouldImport =
          await ImportRecipeDialog.show(context, preview: preview);
      if (shouldImport != true || !context.mounted) return null;

      final importResult = await RecipeShareService.importRecipeFromJson(
        jsonContent: jsonContent,
        db: db,
        overrideRecipeName: preview.hasExistingRecipeWithSameName
            ? preview.suggestedName
            : null,
      );

      if (!context.mounted) return importResult;

      ref.invalidate(recipesWithFinancialsStreamProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.import_recipe_success(importResult.recipe.name),
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
          action: SnackBarAction(
            label: l10n.import_recipe_open_now_action,
            onPressed: () {
              if (MediaQuery.sizeOf(context).width >= 640) {
                ref
                    .read(webLayoutProvider.notifier)
                    .openRecipe(importResult.recipe.recipePk);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RecipeEditorScreen(
                      recipeId: importResult.recipe.recipePk,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
      return importResult;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.import_recipe_invalid_file}: $e',
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ),
      );
      return null;
    }
  }
}
