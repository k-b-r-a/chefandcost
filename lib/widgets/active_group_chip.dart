import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import 'group_management_sheet.dart';

/// Interactive chip widget displaying the current workspace visibility summary.
/// Tapping opens the [GroupManagementSheet] visibility filter sheet.
class ActiveGroupChip extends ConsumerWidget {
  final bool isCompact;

  const ActiveGroupChip({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final groups =
        ref.watch(groupsStreamProvider).asData?.value ?? const <Group>[];
    final activeGroups = groups.where((g) => !g.isDeleted).toList();
    final hiddenIds = ref.watch(hiddenWorkspaceIdsProvider);
    final visibleGroups = activeGroups
        .where((g) => !hiddenIds.contains(g.id))
        .toList();
    final totalCount = activeGroups.length;
    final visibleCount = visibleGroups.length;
    final hiddenCount = totalCount - visibleCount;

    final String label;
    final IconData groupIcon;
    final Color groupColor;
    final bool isFiltered;

    if (totalCount == 0 || hiddenCount == 0) {
      label = l10n.group_all_workspaces;
      groupIcon = Icons.visibility_rounded;
      groupColor = theme.colorScheme.primary;
      isFiltered = false;
    } else if (visibleCount == 0) {
      label = l10n.group_visible_count(0, totalCount);
      groupIcon = Icons.visibility_off_outlined;
      groupColor = theme.colorScheme.onSurfaceVariant;
      isFiltered = true;
    } else if (visibleCount == 1) {
      final single = visibleGroups.first;
      label = resolveWorkspaceDisplayName(single, l10n);
      groupIcon = getGroupIconData(single.iconName);
      groupColor = parseGroupColor(single.colorHex);
      isFiltered = true;
    } else {
      label = l10n.group_visible_count(visibleCount, totalCount);
      groupIcon = Icons.visibility_rounded;
      groupColor = theme.colorScheme.primary;
      isFiltered = true;
    }

    final Color chipBackground;
    final Color chipBorder;
    if (!isFiltered) {
      chipBackground = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.6,
      );
      chipBorder = theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    } else if (visibleCount == 0) {
      chipBackground = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      );
      chipBorder = theme.colorScheme.outline.withValues(alpha: 0.45);
    } else {
      chipBackground = groupColor.withValues(alpha: 0.14);
      chipBorder = groupColor.withValues(alpha: 0.55);
    }

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: l10n.group_switcher_tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => GroupManagementSheet.show(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: isCompact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: chipBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chipBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 18 : 20,
                  height: isCompact ? 18 : 20,
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      groupIcon,
                      size: isCompact ? 12 : 13,
                      color: groupColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: isCompact ? 18 : 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
