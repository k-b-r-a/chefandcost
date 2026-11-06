import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Reusable application dialogs to collapse duplicate dialog implementations.
class AppDialogs {
  AppDialogs._();

  /// Shows a confirmation dialog with standard actions.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), softWrap: true),
        content: Text(message, softWrap: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText ?? (l10n?.cancel_button ?? 'Cancel')),
          ),
          ElevatedButton(
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText ?? (l10n?.done_button ?? 'OK')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a styled delete confirmation dialog with a warning icon.
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message, softWrap: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText ?? (l10n?.cancel_button ?? 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText ?? (l10n?.delete_button ?? 'Delete')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a text input prompt dialog (e.g. for recipe duplication or renaming).
  static Future<String?> promptText(
    BuildContext context, {
    required String title,
    String initialValue = '',
    String? labelText,
    String? confirmText,
    String? cancelText,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), softWrap: true),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: labelText,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelText ?? (l10n?.cancel_button ?? 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirmText ?? (l10n?.save_button ?? 'Save')),
          ),
        ],
      ),
    );
    return result;
  }
}

