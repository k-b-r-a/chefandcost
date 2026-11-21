import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import 'gooey_toast.dart';

/// Available icons for workspace / venue identification.
const List<({String id, IconData icon, String label})> kGroupIcons = [
  (id: 'storefront', icon: Icons.storefront_rounded, label: 'Principal'),
  (id: 'restaurant', icon: Icons.restaurant_rounded, label: 'Cocina'),
  (id: 'cake', icon: Icons.cake_outlined, label: 'Pastelería'),
  (id: 'local_bar', icon: Icons.local_bar_outlined, label: 'Bar / Barra'),
  (id: 'coffee', icon: Icons.coffee_rounded, label: 'Cafetería'),
  (id: 'bakery_dining', icon: Icons.bakery_dining_rounded, label: 'Panadería'),
  (id: 'lunch_dining', icon: Icons.lunch_dining_rounded, label: 'Fast Food'),
  (id: 'business', icon: Icons.business_rounded, label: 'Central'),
];

/// Available preset colors for workspace / venue badges.
const List<String> kGroupColors = [
  '4CAF50', // Green
  'FF9800', // Orange
  '2196F3', // Blue
  'E91E63', // Pink / Rose
  '9C27B0', // Purple
  '009688', // Teal
  'F44336', // Red
  '607D8B', // Blue Grey
];

IconData getGroupIconData(String? iconName) {
  if (iconName == null) return Icons.storefront_rounded;
  for (final item in kGroupIcons) {
    if (item.id == iconName) return item.icon;
  }
  return Icons.storefront_rounded;
}

Color parseGroupColor(
  String? colorHex, {
  Color fallback = const Color(0xFF4CAF50),
}) {
  if (colorHex == null || colorHex.isEmpty) return fallback;
  try {
    String hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return fallback;
  }
}

String resolveWorkspaceDisplayName(Group group, AppLocalizations l10n) {
  if (group.id == 'group_default_principal' &&
      (group.name == 'Principal' || group.name == 'Main')) {
    return l10n.group_default_name;
  }
  return group.name;
}

/// Modal bottom sheet allowing users to toggle visibility, create, edit,
/// and soft-delete operational workspaces / venues.
class GroupManagementSheet extends ConsumerWidget {
  const GroupManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GroupManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(groupsStreamProvider);
    final hiddenIds = ref.watch(hiddenWorkspaceIdsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.groups_title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.group_management_subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showAddOrEditGroupDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.group_add_new),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Group List
            Flexible(
              child: groupsAsync.when(
                data: (groups) {
                  final activeList = groups.where((g) => !g.isDeleted).toList();
                  final activeIds = activeList.map((g) => g.id).toList();
                  final visibleCount = activeList
                      .where((g) => !hiddenIds.contains(g.id))
                      .length;
                  final allVisible =
                      activeList.isEmpty || visibleCount == activeList.length;

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    itemCount: activeList.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        void toggleAllVisibility() {
                          final notifier = ref.read(
                            hiddenWorkspaceIdsProvider.notifier,
                          );
                          if (allVisible && activeIds.isNotEmpty) {
                            notifier.hideAllWorkspaces(activeIds);
                          } else {
                            notifier.showAllWorkspaces();
                          }
                        }

                        return Material(
                          color: allVisible
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: toggleAllVisibility,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: allVisible
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.5,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.25),
                                  width: allVisible ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.all_inclusive_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.group_all_workspaces,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (!allVisible &&
                                            activeList.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            l10n.group_visible_count(
                                              visibleCount,
                                              activeList.length,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'workspace_visibility_all',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      allVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_outlined,
                                      size: 22,
                                      color: allVisible
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    tooltip: allVisible
                                        ? l10n.group_toggle_visibility_hide
                                        : l10n.group_toggle_visibility_show,
                                    onPressed: toggleAllVisibility,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final group = activeList[index - 1];
                      final isVisible = !hiddenIds.contains(group.id);
                      final groupColor = parseGroupColor(group.colorHex);
                      final iconData = getGroupIconData(group.iconName);
                      final groupDisplayName = resolveWorkspaceDisplayName(
                        group,
                        l10n,
                      );

                      void toggleRowVisibility() {
                        ref
                            .read(hiddenWorkspaceIdsProvider.notifier)
                            .toggleWorkspaceVisibility(group.id);
                      }

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isVisible ? 1.0 : 0.55,
                        child: Material(
                          color: isVisible
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: toggleRowVisibility,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isVisible
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.5,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.25),
                                  width: isVisible ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Badge avatar
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: groupColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: groupColor.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: groupColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Workspace Name
                                  Expanded(
                                    child: Text(
                                      groupDisplayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: isVisible
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),

                                  // Actions (Edit / Delete / Eye Toggle)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    tooltip: l10n.group_edit,
                                    onPressed: () => _showAddOrEditGroupDialog(
                                      context,
                                      ref,
                                      existingGroup: group,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: activeList.length <= 1
                                          ? theme.colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.3)
                                          : theme.colorScheme.error,
                                    ),
                                    tooltip: l10n.group_delete,
                                    onPressed: activeList.length <= 1
                                        ? () {
                                            GooeyToast.showWarning(
                                              context,
                                              message:
                                                  l10n.group_delete_cannot_last,
                                            );
                                          }
                                        : () => _confirmDeleteGroup(
                                            context,
                                            ref,
                                            group,
                                          ),
                                  ),
                                  IconButton(
                                    key: ValueKey(
                                      'workspace_visibility_${group.id}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      isVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_outlined,
                                      size: 22,
                                      color: isVisible
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    tooltip: isVisible
                                        ? l10n.group_toggle_visibility_hide
                                        : l10n.group_toggle_visibility_show,
                                    onPressed: toggleRowVisibility,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error: $e'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditGroupDialog(
    BuildContext context,
    WidgetRef ref, {
    Group? existingGroup,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _GroupEditorDialog(
        existingGroup: existingGroup,
        onSave: (name, colorHex, iconName) async {
          final db = ref.read(databaseProvider);
          if (existingGroup == null) {
            final newId = const Uuid().v4();
            await db.insertGroup(
              GroupsCompanion(
                id: drift.Value(newId),
                name: drift.Value(name),
                colorHex: drift.Value(colorHex),
                iconName: drift.Value(iconName),
                isActive: const drift.Value(true),
                createdAt: drift.Value(DateTime.now()),
                updatedAt: drift.Value(DateTime.now()),
                isDeleted: const drift.Value(false),
              ),
            );
          } else {
            await db.updateGroup(
              existingGroup.copyWith(
                name: name,
                colorHex: drift.Value(colorHex),
                iconName: drift.Value(iconName),
                updatedAt: DateTime.now(),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.group_delete),
        content: Text(l10n.group_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel_button),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete_button),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.softDeleteGroup(group.id);
      await ref
          .read(hiddenWorkspaceIdsProvider.notifier)
          .removeWorkspaceId(group.id);

      // Keep legacy activeGroupIdProvider consistent if it pointed to this deleted group
      final activeId = ref.read(activeGroupIdProvider);
      if (activeId == group.id) {
        await ref
            .read(activeGroupIdProvider.notifier)
            .setActiveGroupId(kAllGroupsId);
      }
    }
  }
}

class _GroupEditorDialog extends StatefulWidget {
  final Group? existingGroup;
  final Future<void> Function(String name, String colorHex, String iconName)
  onSave;

  const _GroupEditorDialog({this.existingGroup, required this.onSave});

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  late final TextEditingController _nameController;
  late String _selectedColorHex;
  late String _selectedIconName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingGroup?.name ?? '',
    );
    _selectedColorHex = widget.existingGroup?.colorHex ?? kGroupColors.first;
    _selectedIconName = widget.existingGroup?.iconName ?? kGroupIcons.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.existingGroup != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.group_edit : l10n.group_add_new),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Input
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: l10n.group_name_label,
                hintText: l10n.group_name_hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Icon Picker
            Text(
              l10n.group_icon_label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kGroupIcons.map((item) {
                final isSelected = _selectedIconName == item.id;
                return InkWell(
                  onTap: () => setState(() => _selectedIconName = item.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color Picker
            Text(
              l10n.group_color_label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kGroupColors.map((hex) {
                final color = parseGroupColor(hex);
                final isSelected = _selectedColorHex == hex;
                return InkWell(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel_button),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _isSaving = true);
                  await widget.onSave(
                    name,
                    _selectedColorHex,
                    _selectedIconName,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save_button),
        ),
      ],
    );
  }
}
