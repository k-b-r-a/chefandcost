import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import '../provider/web_layout_provider.dart';
import '../screens/recipe_editor_screen.dart';
import '../services/recipe_share_service.dart';
import '../widgets/import_recipe_dialog.dart';

class RecipeImportHelper {
  static bool _isImportInProgress = false;

  /// Returns true if an import dialog or operation is currently active.
  static bool get isImportInProgress => _isImportInProgress;

  /// Opens file picker to select and import a .chefy recipe file.
  static Future<RecipeImportResult?> importRecipeFromDevice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_isImportInProgress) {
      debugPrint('RecipeImportHelper: Import already in progress, ignoring duplicate call');
      return null;
    }
    _isImportInProgress = true;
    final l10n = AppLocalizations.of(context)!;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.import_recipe_dialog_title,
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      Uint8List? bytes = pickedFile.bytes;
      if ((bytes == null || bytes.isEmpty) && !kIsWeb && pickedFile.path != null) {
        final file = File(pickedFile.path!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

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
      if (!context.mounted) return null;
      return await _executeImportFromString(
        context,
        ref,
        jsonContent: jsonContent,
        sourceFileName: pickedFile.name,
      );
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
    } finally {
      _isImportInProgress = false;
    }
  }

  /// Imports a recipe from raw JSON content string, displaying the
  /// preview confirmation dialog and handling insertion & notifications.
  static Future<RecipeImportResult?> importRecipeFromString(
    BuildContext context,
    WidgetRef ref, {
    required String jsonContent,
    String? sourceFileName,
  }) async {
    if (_isImportInProgress) {
      debugPrint('RecipeImportHelper: Import already in progress, ignoring duplicate call');
      return null;
    }
    _isImportInProgress = true;
    try {
      return await _executeImportFromString(
        context,
        ref,
        jsonContent: jsonContent,
        sourceFileName: sourceFileName,
      );
    } finally {
      _isImportInProgress = false;
    }
  }

  static Future<RecipeImportResult?> _executeImportFromString(
    BuildContext context,
    WidgetRef ref, {
    required String jsonContent,
    String? sourceFileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    try {
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

      try {
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
      } catch (_) {}
      return importResult;
    } catch (e) {
      if (!context.mounted) return null;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.import_recipe_invalid_file}: $e',
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      } catch (_) {}
      return null;
    }
  }
}
